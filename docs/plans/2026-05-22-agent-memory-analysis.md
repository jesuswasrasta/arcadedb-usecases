# Agent-Memory — Domain Analysis

> Esplorazione dell'ecosistema `marvin/` e dei reference use case `graph-rag/` e `knowledge-graphs/` per progettare il nuovo use case `agent-memory`.

## Reference use case pattern

Sia `graph-rag/` che `knowledge-graphs/` seguono questa struttura identica:

```
<use-case>/
├── docker-compose.yml          # arcadedata/arcadedb:26.5.1
├── setup.sh                    # wait → create DB → apply sql/
├── sql/
│   ├── 01-schema.sql           # CREATE VERTEX/EDGE/DOCUMENT TYPE, CREATE INDEX
│   └── 02-data.sql             # INSERT INTO ... SET + CREATE EDGE FROM ... TO ...
├── queries/
│   └── queries.sh              # funzione query(lang, cmd) con jq, 5-6 pattern
├── java/
│   ├── pom.xml                 # maven-assembly-plugin per fat JAR
│   └── src/main/java/com/arcadedb/examples/<ClassName>.java
└── README.md
```

### Convenzioni chiave

| Aspetto | Convenzione |
|---------|-------------|
| SQL files | One statement per line, blank lines e `-- comment` skippati da setup.sh |
| setup.sh | `send_sql()` con jq + curl, `apply_file()` line-by-line |
| queries.sh | `query(language, command)` → `jq '.result'` |
| Java | `RemoteDatabase` (HTTP), `tryRun(Runnable, String)`, `printHeader(String, String)` |
| Docker | `JAVA_OPTS` per rootPassword, healthcheck con curl su `/api/v1/ready` |
| DB name | Uguale al nome del use case (es. `GraphRAG`, `KnowledgeGraph`) |

### Differenze tra i due

| Aspetto | graph-rag | knowledge-graphs |
|---------|-----------|------------------|
| Porte extra | 7687 (Bolt) | — |
| Driver Java | neo4j-java-driver (Bolt) | RemoteDatabase (HTTP) |
| Plugin | BoltProtocolPlugin | — |
| Vertex types | 5 (Chunk, Entity, Person, Concept, Organization) | 4 (Researcher, Institution, Topic, Paper) |
| Edge types | 4 (MENTIONS, RELATES_TO, WORKS_AT, AUTHORED) | 4 (CO_AUTHORED, CITES, COVERS, AFFILIATED_WITH) |
| Document types | — | 1 (PaperActivity) |
| Query languages | SQL + Cypher | SQL + Cypher |
| Features | Vector, Full-text, Graph | Vector, Full-text, Graph, Time-series |

---

## Ecosistema `marvin/` — Domain entities

Marvin è un personal AI assistant timeline-first. Ogni entità è memorizzata come file markdown con relazioni cross-referenced via path relativi.

### Directory structure

```
marvin/
├── profile/           # User profile (Big Five, professional, working style)
├── journal/           # Daily journal entries: YEAR/WEEK/D-dayname-DATE.md
├── notes/             # Ephemeral notes: YYYY-MM-DD-HHMM-note.md
├── tasks/             # 3-state: maybe.md, todo.md, archive.md
├── people/            # Person profiles: name.md
├── projects/          # Project context: name.md
├── reference/         # External docs, meeting transcripts
├── audio/             # Voice memo transcripts: title.txt
├── work-evaluation/   # Performance reviews
├── specs/             # Feature specifications
├── logs/              # Audit logs
└── .opencode/         # Skills, agents, commands
```

### Entity map

| Entity | File/Dir | Key fields | Relationships |
|--------|----------|------------|---------------|
| **JournalEntry** | `journal/YEAR/WEEK/D-DAY-DATE.md` | `date`, `content`, `emotionalIntensity`, tags (YAML), agent_used | MENTIONS → Person/Project/Task; HAS_TAG → ContentTag; HAS_SESSION → CoachingSession |
| **Note** | `notes/YYYY-MM-DD-HHMM-note.md` | `content`, `type` (learning/observation/general), `createdAt` | REFERENCES → Person/Project |
| **Task** | `tasks/{maybe,todo,archive}.md` | `content`, `state` (maybe/todo/archive), `status` (DONE/UNDONE), `deadline`, `createdAt` | BELONGS_TO → Project |
| **Thought/Idea** | `notes/thoughts-and-ideas.md` | `content`, `createdAt`, `status` (active/archived) | REFERENCES → Project |
| **Person** | `people/NAME.md` | `name`, `function`, `team`, personality profile | COLLABORATES_ON → Project; MENTIONED_IN ← JournalEntry |
| **Project** | `projects/NAME.md` | `name`, `type`, `status`, team members | HAS_MEMBER ← Person; HAS_TASK ← Task; MENTIONED_IN ← JournalEntry |
| **Reference** | `reference/FILE.md` | `title`, `source`, `content` | MENTIONED_IN ← JournalEntry |
| **AudioTranscript** | `audio/TITLE.txt` | `title`, `summary`, description, `recordedAt` | RECORDED_DURING → JournalEntry |
| **ContentTag** | YAML frontmatter journal | `name`, `category` (emotional/psychological/situational/meta) | TAGGED_BY ← JournalEntry |
| **AgentPersona** | `.opencode/agents/ID.md` | `agent_id`, `name`, `framework`, `interactionStyle` | USED_IN → CoachingSession |
| **CoachingSession** | Ephemeral (in-memory) | `sessionId`, `date`, `agentPersona`, questions, insights | LINKED_TO → JournalEntry |
| **PatternInsight** | Regenerated on-demand | `pattern_type`, `description`, evidence entries | REFERENCES → JournalEntry |
| **UserProfile** | `profile/*.md` | Big Five scores, professional bg, working style | INFORMS → CoachingSession |

### Relazioni chiave (graph)

```
Person --- COLLABORATES_ON --- Project
Person <--- MENTIONS --- JournalEntry
Project <--- MENTIONS --- JournalEntry
Task <--- MENTIONS --- JournalEntry
Task --- BELONGS_TO --- Project
Note --- REFERENCES --- Person/Project
JournalEntry --- HAS_TAG --- ContentTag
AudioTranscript --- RECORDED_DURING --- JournalEntry
JournalEntry --- HAS_SESSION --- CoachingSession (doc)
CoachingSession --- USES --- AgentPersona
UserProfile (doc) --- INFORMS --- CoachingSession
```

### Data volume nel marvin reale

| Entity | Count | Note |
|--------|-------|------|
| Journal entries | ~7 | 2025 week 50 + 2026 weeks 01-03 |
| People | 11 | Colleghi Synthex |
| Projects | 2 | Stratus Platform, Talk Bolzano: FP in Practice |
| Tasks | ~13 | In todo.md |
| Notes | 1 | + archived ideas |
| Audio transcripts | 10 | Voice memos from Jan 2026 |
| References | 9 | Meeting notes, Gemini transcripts |
| Agent personas | 5 | CBT, Stoic, Pattern, Shadow, Expressive |
| Content tags | ~10 | emotional + psychological + situational |

---

## Domain modeling considerations for ArcadeDB

### Cosa modellare come VERTEX TYPE

Entità con identità, relazioni, e che partecipano a traversals:
- **JournalEntry** — nodo centrale del grafo, si collega a tutto
- **Person** — persone menzionate, collaboratori
- **Project** — progetti attivi
- **Task** — attività con stato
- **Note** — appunti rapidi
- **AudioTranscript** — trascrizioni vocali
- **ContentTag** — tag emotivi/psicologici (categorizzazione)
- **AgentPersona** — agenti di coaching (framework teorico)

### Cosa modellare come EDGE TYPE

Relazioni semantiche tra entità:
- **MENTIONS** — JournalEntry → Person/Project/Task
- **HAS_TAG** — JournalEntry → ContentTag
- **BELONGS_TO** — Task → Project
- **COLLABORATES_ON** — Person → Project
- **REFERENCES** — Note → Person/Project
- **RECORDED_DURING** — AudioTranscript → JournalEntry

### Cosa modellare come DOCUMENT TYPE

Dati che non partecipano a traversals ma servono per query document-oriented:
- **UserProfile** — profilo statico dell'utente (Big Five, ruolo, working style)
- **CoachingSession** — sessioni di coaching (sessionId, date, agent, questions, insights)
