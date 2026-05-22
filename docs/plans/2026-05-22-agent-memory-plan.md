# Agent-Memory — Implementation Plan

> Nuovo use case ArcadeDB per dimostrare capacità multi-modello applicate al dominio
> di un assistente personale con memoria (journaling, people, projects, tasks, note).
> Ispirato all'ecosistema `marvin/`.

## Quick reference

| Property | Value |
|----------|-------|
| DB Name | `AgentMemory` |
| Ports | 2480 (HTTP) |
| Plugins | Nessuno |
| Driver Java | `RemoteDatabase` (HTTP) |
| Vertex types | 8 |
| Edge types | 6 |
| Document types | 2 |
| Query patterns | 5 |
| Query languages | SQL + Cypher |

---

## 1. Project structure

```
agent-memory/
├── docker-compose.yml
├── setup.sh
├── README.md
├── sql/
│   ├── 01-schema.sql
│   └── 02-data.sql
├── queries/
│   └── queries.sh
└── java/
    ├── pom.xml
    └── src/main/java/com/arcadedb/examples/AgentMemory.java
```

---

## 2. Schema (`sql/01-schema.sql`)

### Vertex types (8)

```sql
CREATE VERTEX TYPE JournalEntry IF NOT EXISTS;
CREATE PROPERTY $1 DATE;
CREATE PROPERTY $1 STRING;
CREATE PROPERTY $1 STRING;
CREATE PROPERTY $1 INTEGER;
CREATE PROPERTY $1 STRING;

CREATE VERTEX TYPE Person IF NOT EXISTS;
CREATE PROPERTY $1 STRING;
CREATE PROPERTY $1 STRING;
CREATE PROPERTY $1 STRING;

CREATE VERTEX TYPE Project IF NOT EXISTS;
CREATE PROPERTY $1 STRING;
CREATE PROPERTY $1 STRING;
CREATE PROPERTY $1 STRING;

CREATE VERTEX TYPE Task IF NOT EXISTS;
CREATE PROPERTY $1 STRING;
CREATE PROPERTY $1 STRING;
CREATE PROPERTY $1 DATE;
CREATE PROPERTY $1 DATETIME;

CREATE VERTEX TYPE Note IF NOT EXISTS;
CREATE PROPERTY $1 STRING;
CREATE PROPERTY $1 STRING;
CREATE PROPERTY $1 DATETIME;

CREATE VERTEX TYPE AudioTranscript IF NOT EXISTS;
CREATE PROPERTY $1 STRING;
CREATE PROPERTY $1 STRING;
CREATE PROPERTY $1 DATE;

CREATE VERTEX TYPE ContentTag IF NOT EXISTS;
CREATE PROPERTY $1 STRING;
CREATE PROPERTY $1 STRING;

CREATE VERTEX TYPE AgentPersona IF NOT EXISTS;
CREATE PROPERTY $1 STRING;
CREATE PROPERTY $1 STRING;
CREATE PROPERTY $1 STRING;
```

### Edge types (6)

```sql
CREATE EDGE TYPE MENTIONS IF NOT EXISTS;
CREATE EDGE TYPE HAS_TAG IF NOT EXISTS;
CREATE EDGE TYPE BELONGS_TO IF NOT EXISTS;
CREATE EDGE TYPE COLLABORATES_ON IF NOT EXISTS;
CREATE EDGE TYPE REFERENCES IF NOT EXISTS;
CREATE EDGE TYPE RECORDED_DURING IF NOT EXISTS;
```

### Document types (2)

```sql
CREATE DOCUMENT TYPE UserProfile IF NOT EXISTS;
CREATE PROPERTY $1 STRING;
CREATE PROPERTY $1 STRING;
CREATE PROPERTY $1 INTEGER;
CREATE PROPERTY $1 INTEGER;
CREATE PROPERTY $1 INTEGER;
CREATE PROPERTY $1 INTEGER;
CREATE PROPERTY $1 INTEGER;
CREATE PROPERTY $1 STRING;

CREATE DOCUMENT TYPE CoachingSession IF NOT EXISTS;
CREATE PROPERTY $1 STRING;
CREATE PROPERTY $1 DATE;
CREATE PROPERTY $1 STRING;
CREATE PROPERTY $1 LIST;
CREATE PROPERTY $1 LIST;
```

### Indexes

```sql
CREATE INDEX IF NOT EXISTS ON JournalEntry (date) NOTUNIQUE;
CREATE INDEX IF NOT EXISTS ON JournalEntry (weekNumber) NOTUNIQUE;
CREATE INDEX IF NOT EXISTS ON Person (name) UNIQUE;
CREATE INDEX IF NOT EXISTS ON Project (name) UNIQUE;
CREATE INDEX IF NOT EXISTS ON ContentTag (name) UNIQUE;
CREATE INDEX IF NOT EXISTS ON CoachingSession (agentPersona) NOTUNIQUE;
CREATE INDEX IF NOT EXISTS ON JournalEntry (content) FULL_TEXT;
CREATE INDEX IF NOT EXISTS ON Note (content) FULL_TEXT;
```

Note: `weekNumber` index ottimizza Q3 (GROUP BY week). `agentPersona` index
ottimizza Q4 (filtro per agente su document type).

---

## 3. Sample data (`sql/02-data.sql`)

### Seed data overview

| Type | Count | Entities |
|------|-------|----------|
| Person | 5 | Marco Bellini, Claudio Rossi, Paolo Fontana, Luca Villa, Simone Bianchi |
| Project | 3 | Stratus Platform, Talk Bolzano: FP in Practice, Harmonia Platform Evolution |
| JournalEntry | 5 | 2026-01-01 through 2026-01-09 (2 weeks) |
| Task | 5 | Mix of todo/maybe states, with/without deadlines |
| Note | 3 | idea, observation, learning |
| AudioTranscript | 3 | Brain dump, Sci-fi idea, Team Atlas discussion |
| ContentTag | 5 | achievement, frustration, learning, cognitive-distortion, external-frustration |
| AgentPersona | 3 | CBT Reframer, Stoic Mentor, Pattern Analyst |
| UserProfile | 1 | Alessandro Riva |
| CoachingSession | 2 | 2026-01-07-cbt-reframer, 2026-01-05-stoic-mentor |
| COLLABORATES_ON edges | 4 | Person → Project |
| MENTIONS edges | 11 | JournalEntry → Person/Project |
| HAS_TAG edges | 6 | JournalEntry → ContentTag |
| BELONGS_TO edges | 4 | Task → Project |

### Relationship graph

```
                    ┌──────────────────┐
                    │   UserProfile    │ (doc)
                    └──────────────────┘
                            │ informs
                            ▼
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│  AgentPersona │◄────│ CoachingSession│────►│ JournalEntry  │
└──────────────┘     └──────────────┘     └──────┬───────┘
       │ (USES)           (doc)             │    │    │
                                            │    │    │
                    ┌───────────────────────┘    │    └──────────┐
                    ▼                            ▼               ▼
            ┌──────────────┐             ┌──────────────┐ ┌──────────────┐
            │  ContentTag  │             │    Person    │ │   Project    │
            └──────────────┘             └──────┬───────┘ └──────┬───────┘
                   ▲ (HAS_TAG)                  │               │
                   │                            │ COLLABORATES_ON│
                   │                            ▼               ▼
            ┌──────────────┐             ┌──────────────────────────┐
            │ JournalEntry │◄──── RECORDED_DURING ──── AudioTranscript
            └──────────────┘
                   │
                   │ MENTIONS
                   ▼
            ┌──────────────┐     ┌──────────────┐
            │    Task      │────►│   Project    │
            └──────────────┘     └──────────────┘
               BELONGS_TO

            ┌──────────────┐
            │    Note      │────► Person/Project
            └──────────────┘    REFERENCES
```

---

## 4. Query patterns (`queries/queries.sh`)

### Q1 — Graph traversal: "Who shares projects with Marco?"

Trova tutte le persone che collaborano agli stessi progetti di Marco Bellini,
usando MENTIONS delle journal entries come proxy di attività condivisa.

**Language:** Cypher
**Signal:** Graph traversal

```cypher
MATCH (f:Person {name: 'Marco Bellini'})-[:MENTIONS]-(j:JournalEntry)-[:MENTIONS]-(p:Person)
WHERE p <> f
RETURN p.name AS colleague, count(DISTINCT j) AS mentions
ORDER BY mentions DESC
```

### Q2 — Full-text search: "Cerca 'team' in entries e notes"

Cerca una keyword attraverso due tipi di contenuto (JournalEntry e Note)
usando `CONTAINSTEXT` e `UNION`.

**Language:** SQL
**Signal:** Full-text

```sql
(SELECT format(date, 'yyyy-MM-dd') AS ts, content, 'journal' AS source
 FROM JournalEntry
 WHERE content CONTAINSTEXT 'team')
UNION
(SELECT format(createdAt, 'yyyy-MM-dd'), content, 'note'
 FROM Note
 WHERE content CONTAINSTEXT 'team')
ORDER BY ts
```

### Q3 — Time-series: "Entries per week per emotional intensity"

Aggregazione settimanale delle journal entries per livello di intensità emotiva.

**Language:** SQL
**Signal:** Time-series aggregation

```sql
SELECT weekNumber, emotionalIntensity, count(*) AS entries
FROM JournalEntry
GROUP BY weekNumber, emotionalIntensity
ORDER BY weekNumber, emotionalIntensity
```

### Q4 — Hybrid document/vertex: "User profile + coaching sessions"

Join tra un document type (UserProfile) e un document type (CoachingSession)
per mostrare profilo utente e sessioni di coaching di un dato agente.

**Language:** SQL
**Signal:** Document query

```sql
SELECT p.name, p.role, c.sessionId, c.date, c.agentPersona, c.questions
FROM UserProfile p, CoachingSession c
WHERE c.agentPersona = 'CBT Reframer'
```

### Q5 — Multi-step agent simulation

Simula un agente che:
1. Trova i tag più frequenti (SQL)
2. Trova le persone menzionate in entries con 'achievement' tag (Cypher)
3. Trova i task dei progetti di quelle persone (Cypher)

**Language:** SQL + Cypher (multi-step)
**Signal:** Graph + Document hybrid

```sql
-- Step 1: Tag frequency
SELECT out('HAS_TAG').name AS tag, count(*) AS freq
FROM JournalEntry
GROUP BY tag
ORDER BY freq DESC
LIMIT 3
```

```cypher
-- Step 2: People associated with 'achievement' tag
MATCH (j:JournalEntry)-[:HAS_TAG]->(t:ContentTag {name: 'achievement'}),
      (j)-[:MENTIONS]->(p:Person)
RETURN DISTINCT p.name, count(j) AS entry_count
```

```sql
-- Step 3: Tasks for projects of those people
SELECT p.name AS person, pr.name AS project, t.content AS task, t.state
FROM (
  MATCH {type: Person, as: p, where: (name IN ['Marco Bellini', 'Claudio Rossi'])}
        .out('COLLABORATES_ON'){as: pr}
        .in('BELONGS_TO'){as: t}
  RETURN p, pr, t
)
```

---

## 5. Java module

### Dependencies

- `com.arcadedb:arcadedb-engine` (per `RemoteDatabase`)
- `maven-assembly-plugin` per fat JAR
- Package: `com.arcadedb.examples.AgentMemory`

### Structure

```java
public class AgentMemory {
  // Config da env: ARCADEDB_HOST, ARCADEDB_PORT, ARCADEDB_USER, ARCADEDB_PASS

  public static void main(String[] args) {
    try (RemoteDatabase db = new RemoteDatabase(HOST, PORT, "AgentMemory", USER, PASSWORD)) {
      tryRun(() -> runQuery1GraphTraversal(db), "Q1: Graph traversal");
      tryRun(() -> runQuery2FullTextSearch(db), "Q2: Full-text search");
      tryRun(() -> runQuery3TimeSeries(db), "Q3: Time-series aggregation");
      tryRun(() -> runQuery4HybridQuery(db), "Q4: Document hybrid");
      tryRun(() -> runQuery5MultiStep(db), "Q5: Multi-step agent");
    }
  }

  // tryRun, printHeader, truncate utilities
}
```

### Query methods (5, matching queries.sh)

| Method | Language | What it does |
|--------|----------|--------------|
| `runQuery1GraphTraversal` | Cypher | Trova colleghi di Marco per progetto condiviso |
| `runQuery2FullTextSearch` | SQL | Cerca keyword in JournalEntry e Note, unisce risultati |
| `runQuery3TimeSeries` | SQL | Aggrega entries per week/intensity |
| `runQuery4HybridQuery` | SQL | UserProfile + CoachingSession join |
| `runQuery5MultiStep` | SQL + Cypher | Steps: tag frequency → people → tasks |

---

## 6. Docker Compose

```yaml
services:
  arcadedb:
    image: arcadedata/arcadedb:26.5.1
    ports:
      - "2480:2480"
    environment:
      JAVA_OPTS: "-Darcadedb.server.rootPassword=arcadedb"
    healthcheck:
      test: ["CMD", "curl", "-sf", "http://localhost:2480/api/v1/ready"]
      interval: 5s
      timeout: 3s
      retries: 20
      start_period: 10s
```

Standard — nessun plugin extra (HTTP API basta per SQL e Cypher).

---

## 7. CI workflow

`.github/workflows/agent-memory.yml` — stesso pattern degli altri:

```yaml
name: agent-memory
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        runner: [curl, java]
    steps:
      - uses: actions/checkout@v4
      - if: matrix.runner == 'java'
        uses: actions/setup-java@v4
        with:
          java-version: 21
          distribution: temurin
          cache: maven
      - run: docker compose up -d
        working-directory: agent-memory
      - run: ./setup.sh
        working-directory: agent-memory
      - if: matrix.runner == 'curl'
        run: ./queries/queries.sh
        working-directory: agent-memory
      - if: matrix.runner == 'java'
        run: |
          cd java && mvn package --no-transfer-progress && \
          java -jar target/agent-memory.jar
        working-directory: agent-memory
      - run: docker compose down -v
        working-directory: agent-memory
```

---

## 8. Implementation order

1. `docker-compose.yml`
2. `sql/01-schema.sql`
3. `sql/02-data.sql`
4. `setup.sh`
5. `queries/queries.sh`
6. `java/pom.xml`
7. `java/.../AgentMemory.java`
8. `README.md`
9. `.github/workflows/agent-memory.yml`

---

### Note su CoachingSession

CoachingSession è modellato come DOCUMENT TYPE, non VERTEX TYPE. Questo significa
che **non partecipa a graph traversals** — non si può fare
`MATCH (j:JournalEntry)-->(c:CoachingSession)`. È una scelta deliberata: le
sessioni sono dati ausiliari senza relazioni entranti nel grafo. Per Q4 si
usa un semplice join SQL tra document type, che è sufficiente.

---

## 9. Rischi e note

- `MATCH` con `IN` subquery non supportata in ArcadeDB → i multi-step richiedono
  hardcoding degli ID nel secondo step (stessa limitation di knowledge-graphs)
- Cypher non risolve parent type labels ai subtypes (`:Entity` non matcha `:Person`)
  → usiamo sempre type names esatti
- `CONTAINSTEXT` funziona in SQL ma non supporta operatori booleani avanzati
  come `SEARCH_INDEX` → per full-text semplice va bene
