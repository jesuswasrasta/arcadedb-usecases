---
name: arcadedb-architect
description: "Systematic discovery-driven ArcadeDB schema design. Run a structured interview before writing any SQL, Docker, or Java code — produces type classification, edge maps, index strategy, plugin config, and validated DDL."
---

# ArcadeDB Architect

Use this skill when designing a new ArcadeDB database from scratch. The architect's
job is to extract requirements through a structured interview and produce a complete,
validated schema design BEFORE any SQL or Docker files are written.

## Mandatory First Step: Interview Template

**Every new database design MUST start with the interview template** at
`.opencode/skills/arcadedb-architect/interview-template.md`.

This template covers 5 discovery phases:

| Phase | Topic | Key Questions |
|-------|-------|--------------|
| 1 | Domain Discovery | Entities, properties, relationships, inheritance |
| 2 | Query Patterns | Top queries, languages, UNION/JOIN needs, frequency |
| 3 | Access Patterns | Data volumes, read/write ratio, multi-tenancy |
| 4 | Special Requirements | Full-text, vectors, time-series, graph traversal, materialized views |
| 5 | Connectivity & Deployment | Protocols, languages, infrastructure, credentials |

Do NOT skip any phase. Each phase reveals constraints that affect later decisions.

## Architect Workflow

### Phase 0 — Run the Interview

Ask all questions from the interview template across all 5 phases. Use the
**ArcadeDB Constraints Checklist** (template §Quick Reference) to probe for
hidden requirements. Collect answers before proceeding to design.

### Phase 1 — Produce Type Classification Table

Map every entity to its ArcadeDB type using the decision matrix
(template §Appendix A):

| Entity | ArcadeDB Type | Reason |
|--------|--------------|--------|
| ... | VERTEX / DOCUMENT / TIMESERIES | justification |

Key rules:
- Entities with relationships → **VERTEX TYPE** (required for edge endpoints)
- Standalone records, caches, materialized views → **DOCUMENT TYPE**
- High-frequency append (>1/sec), time-windowed aggregation, retention → **TIMESERIES TYPE**

### Phase 2 — Produce Edge Type Map

Document every relationship with direction, edge type name, and properties:

```
[Source VERTEX] --EDGE_TYPE--> [Target VERTEX]
```

Include direction, cardinality, and any edge properties. Verify every endpoint
is a VERTEX TYPE — edges cannot connect DOCUMENT TYPE.

### Phase 3 — Produce Index Strategy

For every query from Phase 2 of the interview, identify the indexes needed:

| Type | Property | Index Type | Reason |
|------|----------|-----------|--------|
| ... | ... | UNIQUE / NOTUNIQUE / FULL_TEXT / RANGE / LSM_VECTOR / DICTIONARY / SPATIAL | justification |

Use the decision matrix (template §Appendix B). Prefer covering indexes for
high-frequency queries. Use composite indexes where queries filter on multiple
fields together.

### Phase 4 — Produce Plugin & Port Configuration

Determine Docker `JAVA_OPTS` and ports based on Phase 5 interview answers:

```yaml
JAVA_OPTS: >-
  -Darcadedb.server.rootPassword=arcadedb
  -Darcadedb.server.plugins=<plugins>
  -Darcadedb.bolt.defaultDatabase=<DB_NAME>
ports:
  - "2480:2480"
  # 5432: Postgres plugin
  # 7687: Bolt plugin
```

- HTTP API (2480) is always available — no plugin needed
- Bolt (7687) → `BoltProtocolPlugin`
- Postgres wire (5432) → `Postgres:com.arcadedb.postgres.PostgresProtocolPlugin`
- Comma-separate multiple plugins

### Phase 5 — Write SQL Files

Produce `sql/01-schema.sql` and `sql/02-data.sql` following the constitution:

- One statement per line
- `--` comments at line start only
- No trailing semicolons
- Order: types → properties → indexes (schema); INSERT INTO → CREATE EDGE (data)

### Phase 6 — Validate Against Constraints Checklist

Verify the design against every item in the ArcadeDB Constraints Checklist
(template §Quick Reference). For each constraint that applies, confirm the
workaround is designed:

- [ ] UNION needed? → Application-side merge or denormalized DOCUMENT TYPE
- [ ] Cross-type JOIN needed? → Separate queries or denormalization
- [ ] Cypher + inheritance? → Flat types or explicit subtype labels in MATCH
- [ ] Time bucketing? → Pre-computed properties or TIMESERIES TYPE
- [ ] Vector search? → `vectorNeighbors()` with LSM_VECTOR index
- [ ] Full-text search? → `CONTAINSTEXT` or `SEARCH_CLASS()`
- [ ] `out().property` with multiple edges? → Application-side iteration
- [ ] Java property access? → Always `AS alias` in queries
- [ ] `NOTUNIQUE` syntax? → No space between NOT and UNIQUE

### Phase 7 — Generate Java Boilerplate (if needed)

If Phase 5 interview indicates Java connectivity, produce a skeleton project
following the repo conventions:

```
java/
├── pom.xml    (maven-assembly-plugin for fat JAR)
└── src/main/java/com/arcadedb/examples/<ClassName>.java
```

Java class includes: env var config, `tryRun()` wrapper, `printHeader()` helper,
`RemoteDatabase` (HTTP) or Neo4j driver (Bolt) connection, and one query method
per query from Phase 2 of the interview.

## CRITICAL RULES

- **Interview first, design second** — never write SQL without completing all 5
  interview phases
- **VERTEX TYPE for graph participants** — any entity that needs edges MUST be
  a VERTEX TYPE; DOCUMENT TYPE cannot be edge endpoints
- **No UNION** — design application-side merge or denormalized DOCUMENT TYPE views
- **No cross-type JOIN** — separate queries per type; consider denormalization
  for high-frequency combined access
- **Cypher doesn't resolve parent labels** — if using inheritance, Cypher MATCH
  must use concrete subtype labels, not parent type labels
- **`format(date, ...)` not available** — pre-compute time buckets as explicit
  properties (weekNumber, dayName, hourBucket) or use TIMESERIES TYPE
- **`vectorDistance()` not available** — use `vectorNeighbors('Type[prop]', v, k)`
  with LSM_VECTOR index, or `vectorCosineSimilarity()` for scalar
- **`SEARCH_INDEX()` not in WHERE** — use `CONTAINSTEXT` (single field) or
  `SEARCH_CLASS('query')` (all full-text fields of a type)
- **Root password via JAVA_OPTS only** — `-Darcadedb.server.rootPassword=...`
  (env var form does NOT work)
- **One statement per line in SQL files** — setup.sh reads line-by-line
- **ArcadeDB 26.5.1** — pinned version across all environments
- **Bolt protocol v4** — use Neo4j Java driver `6.1.0`

## Reference Skills

The architect produces schemas consumed by these skills:

| Skill | Use |
|-------|-----|
| `arcadedb-schema-design` | DDL syntax: CREATE TYPE, CREATE PROPERTY, CREATE INDEX |
| `arcadedb-provisioning` | Docker Compose, plugins, healthchecks, lifecycle |
| `arcadedb-vector` | LSM_VECTOR indexes, `vectorNeighbors()`, cosine similarity |
| `arcadedb-time-series` | TIMESERIES TYPE, SHARDS, RETENTION, continuous aggregates |
| `arcadedb-java` | RemoteDatabase API, Maven fat JAR, `tryRun()` patterns |
| `arcadedb-bolt` | Neo4j driver, Cypher over Bolt, default database config |
| `arcadedb-pgwire` | PostgreSQL wire protocol, JDBC, Node.js `pg` driver |

## Output: What the Architect Delivers

After completing the interview and all 7 workflow phases, produce these
deliverables:

1. **Type Classification Table** — every entity mapped to VERTEX / DOCUMENT / TIMESERIES with justification
2. **Edge Type Map** — every relationship with direction, edge type name, and properties
3. **Index Strategy** — every index with type, property, and query justification
4. **Plugin & Port Configuration** — JAVA_OPTS snippet and port mapping
5. **SQL Files** — `sql/01-schema.sql` and `sql/02-data.sql`
6. **Query Strategy** — for each query: language, UNION/JOIN workarounds, expected index usage
7. **Constraints Addressed** — completed checklist of ArcadeDB limitations with workarounds
