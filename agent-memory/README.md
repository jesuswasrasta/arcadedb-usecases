# Agent-Memory

ArcadeDB multi-model demo: personal assistant with memory (journaling, people, projects, tasks, notes, audio transcripts, coaching).

Demonstrates:
- **Graph traversal** — MENTIONS, COLLABORATES_ON, BELONGS_TO edges between entities
- **Full-text search** — CONTAINSTEXT across JournalEntry and Note types
- **Time-series aggregation** — weekly journal entries by emotional intensity
- **Document hybrid** — UserProfile + CoachingSession cross-type query
- **Multi-step agent simulation** — tag frequency → associated people → task discovery

## Schema

| Type | Count | Elements |
|------|-------|----------|
| Vertex types | 8 | JournalEntry, Person, Project, Task, Note, AudioTranscript, ContentTag, AgentPersona |
| Edge types | 6 | MENTIONS, HAS_TAG, BELONGS_TO, COLLABORATES_ON, REFERENCES, RECORDED_DURING |
| Document types | 2 | UserProfile, CoachingSession |

## Query patterns

| # | Pattern | Language | Description |
|---|---------|----------|-------------|
| Q1 | Graph traversal | Cypher | Who shares projects with Marco? |
| Q2 | Full-text search | SQL | Search "team" across entries and notes |
| Q3 | Time-series agg | SQL | Entries per week per emotional intensity |
| Q4 | Document hybrid | SQL | User profile + coaching sessions |
| Q5 | Multi-step agent | SQL + Cypher | Tag frequency → people → tasks (dynamic) |

## Run

```bash
docker compose up -d
./setup.sh
./queries/queries.sh       # curl-based
cd java && mvn package && java -jar target/agent-memory.jar
docker compose down -v
```

Ports: 2480 (HTTP API).
