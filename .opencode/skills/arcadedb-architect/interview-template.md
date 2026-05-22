# ArcadeDB Architect — Interview Template

Progressive discovery process for extracting all information needed to design a complete ArcadeDB schema, indexes, and deployment configuration. Ask these questions BEFORE writing any SQL or Docker files.

---

## Phase 1: Domain Discovery

Broad exploration of entities, their properties, and how they relate. The goal is to build a conceptual model before mapping it to ArcadeDB types.

### Q1.1 — What are the core entities in your domain?

> **Why this matters**: Determines the initial set of types. Entities with identity and relationships become VERTEX TYPE; standalone records become DOCUMENT TYPE; relationships become EDGE TYPE.

**Example answer (agent-memory)**:
> "The system tracks: journal entries, people, projects, tasks, notes, audio transcripts, content tags, agent personas. There are also user profiles and coaching sessions."

**Design decision**: 8 VERTEX TYPE (JournalEntry, Person, Project, Task, Note, AudioTranscript, ContentTag, AgentPersona), 2 DOCUMENT TYPE (UserProfile, CoachingSession).

### Q1.2 — For each entity, list its properties and their data types.

> **Why this matters**: Determines the `CREATE PROPERTY` statements and data type choices. String lengths, date formats, nested structures, and list types all affect indexing and query patterns.

**Example answer (agent-memory)**:
> | Entity | Property | Type | Notes |
> |--------|----------|------|-------|
> | JournalEntry | date | DATE | ISO format: '2026-01-05' |
> | JournalEntry | content | STRING | Long text, needs full-text search |
> | JournalEntry | weekNumber | INTEGER | Pre-computed for time-series bucketing |
> | JournalEntry | emotionalIntensity | STRING | Categorical: positive/frustrated/reflective/neutral/accomplished |
> | UserProfile | bigFiveOpenness | INTEGER | 0–100 score |
> | CoachingSession | questions | LIST | Array of strings |
> | CoachingSession | insights | LIST | Array of strings |

**Design decision**: `weekNumber` pre-computed and stored because `format(date, ...)` is not available in ArcadeDB SQL. LIST type for arrays. DATE stored in ISO format.

**ArcadeDB constraint**: `format(date, 'yyyy-MM-dd')` is NOT available — pre-compute time buckets as explicit properties (weekNumber, dayName, hourBucket) or use TIMESERIES TYPE.

### Q1.3 — Which entities should connect to which others? Describe the relationships.

> **Why this matters**: Determines EDGE TYPE definitions, direction (from→to), and whether edges need properties. Also reveals which entities MUST be VERTEX TYPE (only vertices can be endpoints).

**Example answer (agent-memory)**:
> - JournalEntry MENTIONS Person/Project/Task (one journal entry can mention many things)
> - Task BELONGS_TO Project (each task belongs to one project)
> - Person COLLABORATES_ON Project (many-to-many)
> - AudioTranscript RECORDED_DURING JournalEntry (transcript captured during a journaling session)
> - Note REFERENCES Person/Project
> - JournalEntry HAS_TAG ContentTag

**Design decision**: 6 EDGE TYPE. MENTIONS connects JournalEntry to multiple target types (Person, Project, Task) — works because ArcadeDB edges are type-flexible at the target.

**ArcadeDB constraint**: Edges can only connect VERTEX TYPE endpoints. If you need a relationship to/from an entity, that entity MUST be a VERTEX TYPE, not DOCUMENT TYPE. This was the key reason UserProfile and CoachingSession are DOCUMENT TYPE — they don't participate in graph traversals.

### Q1.4 — Are there inheritance relationships between entities?

> **Why this matters**: ArcadeDB supports type inheritance (`EXTENDS`). Children inherit properties and indexes. However, Cypher does NOT resolve parent type labels to subtypes — `:Entity` won't match `Person` if Person EXTENDS Entity.

**Example answer (graph-rag)**:
> "Person, Concept, and Organization are all types of Entity with a `name` property."

**Design decision**: Used `CREATE VERTEX TYPE Person IF NOT EXISTS EXTENDS Entity` for schema reuse, but Cypher queries must explicitly match `:Person`, not `:Entity`.

**ArcadeDB constraint**: If Cypher is a primary query language, avoid deep inheritance hierarchies. Prefer flat types with explicit labels in MATCH clauses. Inheritance works well for SQL and property/index reuse.

---

## Phase 2: Query Patterns

Understand what questions the database must answer, in what language, and how frequently.

### Q2.1 — List the top 5–10 queries the system must support. Write them in plain language, then pseudo-query.

> **Why this matters**: Determines index types, query language choice (SQL vs Cypher), JOIN patterns, and aggregation strategies. Also reveals whether UNION (not supported) would be needed.

**Example answer (agent-memory)**:
> | # | Plain language | Pseudo-query |
> |---|---------------|-------------|
> | Q1 | Who shares projects with Marco? | Traverse MENTIONS from JournalEntry to find people co-mentioned |
> | Q2 | Search for "team" across journal entries and notes | Full-text search on content fields |
> | Q3 | How many entries per week per emotional intensity? | Time-series GROUP BY weekNumber, emotionalIntensity |
> | Q4 | Get user profile and coaching sessions for a specific agent | Document queries + filter |
> | Q5 | Find tasks for projects of people associated with the most frequent emotional tag | Multi-step: tag frequency → people → projects → tasks |

**Design decision**: Q1 used Cypher MATCH, Q2 used two SQL queries (UNION not available), Q3 used SQL GROUP BY on pre-computed weekNumber, Q4 used separate queries (cross-type JOIN not available), Q5 used dynamic SQL with String.format in Java.

**ArcadeDB constraints flagged**:
- Q2 needed two queries because UNION is not supported
- Q4 needed separate queries because cross-type JOIN (`FROM t1, t2`) is not supported
- Q5 used dynamic query building with Java String.format

### Q2.2 — For each query, what language do you expect to use? SQL, Cypher, or both?

> **Why this matters**: Determines plugin configuration (Bolt for Cypher, HTTP for SQL). Also affects index design — Cypher MATCH benefits from EDGE TYPE definitions even without explicit edge indexes.

**Example answer (agent-memory)**:
> | Query | Language | Reason |
> |-------|----------|--------|
> | Q1 (graph traversal) | Cypher | Multi-hop traversal cleaner in Cypher |
> | Q2 (full-text search) | SQL | CONTAINSTEXT is SQL-only |
> | Q3 (time-series agg) | SQL | GROUP BY aggregation |
> | Q4 (document hybrid) | SQL | Document queries |
> | Q5 (multi-step agent) | Cypher + SQL | Cypher for traversal, SQL for MATCH pattern |

**Design decision**: No Bolt plugin needed (Cypher works over HTTP API). INDEX: FULL_TEXT on JournalEntry.content and Note.content for CONTAINSTEXT. NOTUNIQUE on JournalEntry.date and weekNumber for time-series aggregation.

### Q2.3 — Do any queries need to combine results from multiple types into a single result set?

> **Why this matters**: ArcadeDB does NOT support UNION. Cross-type JOIN (`FROM TypeA, TypeB`) is also not supported. If the user needs combined results, you must design workarounds: application-side merge, pre-aggregated DOCUMENT TYPE views, or denormalization.

**Example answer (agent-memory)**:
> "Yes, Q2 needs to search both JournalEntry and Note for the same text. Q4 needs to show user profile alongside coaching sessions."

**Design decision**: Q2 runs two separate queries (one per type) and merges results in application code. Q4 does the same. This is an acceptable pattern for moderate result sizes.

**ArcadeDB constraint**: If the user needs true UNION or cross-type JOIN with high frequency, consider denormalizing into a single DOCUMENT TYPE with a `type` discriminator field.

### Q2.4 — What's the expected query frequency and latency tolerance?

> **Why this matters**: High-frequency queries need covering indexes. Analytics queries tolerate slower response but need aggregation support. Real-time queries need efficient traversal patterns.

**Example answer (agent-memory)**:
> "This is a personal assistant. Queries are on-demand, not high throughput. Latency under 2 seconds is fine. Q5 is the most complex but runs occasionally."

**Design decision**: No covering indexes needed. Full-text index is acceptable even for moderate scan. No continuous aggregates needed for time-series.

---

## Phase 3: Access Patterns

Understand data volumes, read/write ratios, and multi-tenancy requirements.

### Q3.1 — What are the expected data volumes? Per entity, per day, total over time.

> **Why this matters**: Determines index type selection (DICTIONARY vs UNIQUE vs NOTUNIQUE), whether TIMESERIES TYPE is needed, and retention strategy.

**Example answer (agent-memory)**:
> | Entity | Initial | Growth | Notes |
> |--------|---------|--------|-------|
> | JournalEntry | ~10 | 1/day | Small dataset, personal |
> | Person | ~15 | 1/month | Infrequent changes |
> | Task | ~20 | 3/week | Growing slowly |
> | Total | <1000 | <5000/year | Tiny dataset |

**Design decision**: Simple NOTUNIQUE indexes suffice. No TIMESERIES TYPE needed — the data volume doesn't justify it. No sharding or retention strategy needed.

**Counter-example (realtime-analytics)**:
> "100 sensors reporting every 10 seconds, 30 services reporting every 5 seconds, 90-day retention."

**Design decision**: Used TIMESERIES TYPE with SHARDS 16, RETENTION 90 DAYS. Continuous aggregates for hourly rollups. NOT DOCUMENT TYPE — TIMESERIES TYPE is purpose-built for this scale.

### Q3.2 — What's the read/write ratio? Is this read-heavy, write-heavy, or balanced?

> **Why this matters**: Write-heavy workloads benefit from TIMESERIES TYPE (optimized append). Read-heavy workloads need more indexes. Balanced workloads need careful index selection to avoid write amplification.

**Example answer (agent-memory)**:
> "Read-heavy. Journal entries are written once per day, but queries run multiple times per session. The coaching agent reads old entries frequently."

**Design decision**: Aggressive indexing is acceptable (low write cost). Full-text index added even for moderate content sizes.

### Q3.3 — Is this single-tenant or multi-tenant? If multi-tenant, how is data isolated?

> **Why this matters**: ArcadeDB databases are isolated. Multi-tenant can be: separate databases per tenant, shared database with tenant_id field, or separate VERTEX TYPE per tenant. Each has different provisioning implications.

**Example answer (agent-memory)**:
> "Single-tenant. One user, one database."

**Design decision**: No multi-tenancy concerns. Simple database name `AgentMemory`.

**Alternative answer (SaaS)**:
> "Multi-tenant SaaS. 1000 tenants, each with their own data, never cross-tenant queries."

**Design decision**: Option A: Separate database per tenant (strong isolation, more Docker complexity). Option B: `tenantId` field on every type + UNIQUE composite index (simpler ops, risk of cross-tenant leaks). The question determines the provisioning strategy.

---

## Phase 4: Special Requirements

Identify features that need specific ArcadeDB capabilities.

### Q4.1 — Do you need full-text search? On which fields?

> **Why this matters**: Full-text search requires FULL_TEXT indexes and uses `CONTAINSTEXT` in WHERE clauses. `SEARCH_INDEX()` is NOT supported in WHERE — use `SEARCH_CLASS('query')` instead. Full-text is type-scoped (one type per query, no cross-type search).

**Example answer (agent-memory)**:
> "Yes. Search for keywords in journal entry content and note content."

**Design decision**: FULL_TEXT indexes on JournalEntry.content and Note.content. Queries use `WHERE content CONTAINSTEXT 'keyword'`. Two separate queries since UNION not supported.

**ArcadeDB constraint**: `SEARCH_INDEX()` is NOT supported in WHERE clauses. Use `SEARCH_CLASS('query')` for full-text search across all full-text-indexed fields of a type. `CONTAINSTEXT` works on a single field.

### Q4.2 — Do you need vector similarity search? What embeddings, what dimensions?

> **Why this matters**: Vector search requires LSM_VECTOR indexes with explicit dimensions and similarity function. `vectorDistance()` is NOT available — use `vectorNeighbors('TypeName[property]', vector, k)` for index-based search or `vectorCosineSimilarity()` for scalar scoring.

**Example answer (fraud-detection)**:
> "Yes. Customer profiles are 8-dimensional embeddings for behavioral similarity. Transaction behavior patterns are also 8-dimensional. Need to find similar customers and similar transactions."

**Design decision**: LSM_VECTOR indexes on Customer.profile_embedding (8 dims, COSINE) and Transaction.behavior_embedding (8 dims, COSINE). Queries use `vectorNeighbors('Customer[profile_embedding]', $vec, 10)`.

**ArcadeDB constraint**: Vector index format is `TypeName[propertyName]` (bracket notation, not dot). `vectorCosineSimilarity()` is a full-scan function — for large datasets, always prefer `vectorNeighbors()` with LSM_VECTOR index.

### Q4.3 — Do you need time-series data? What frequency, retention, aggregation?

> **Why this matters**: High-frequency time-series data (>1 point/second) should use TIMESERIES TYPE (not DOCUMENT TYPE). Low-frequency data (<1 point/hour) can use DOCUMENT TYPE with pre-computed buckets. TIMESERIES TYPE supports SHARDS, RETENTION, continuous aggregates, and specialized functions (`ts.timeBucket`, `ts.rate`, `ts.percentile`, `ts.interpolate`).

**Example answer (realtime-analytics)**:
> "Yes. 100 sensors at 10-second intervals, 90-day retention. Need hourly aggregation, 99th percentile, gap filling."

**Design decision**: TIMESERIES TYPE SensorReading with SHARDS 16, RETENTION 90 DAYS. Continuous aggregate for hourly rollups. Specialized queries using `ts.timeBucket('1h', ts)`, `ts.percentile(temperature, 0.99)`, `ts.interpolate(temperature, 'linear', ts)`.

**Counter-example (agent-memory)**:
> "Time-series only in the sense of weekly journal aggregation. One entry per day."

**Design decision**: NOT TIMESERIES TYPE. Used VERTEX TYPE JournalEntry with pre-computed `weekNumber` INTEGER property + NOTUNIQUE index. Simple `GROUP BY weekNumber` aggregation.

### Q4.4 — Do you need graph traversal? How many hops? Any specific traversal patterns?

> **Why this matters**: Graph traversal needs EDGE TYPE definitions and VERTEX TYPE endpoints. Single-hop with conditions works well in SQL MATCH. Multi-hop needs Cypher MATCH. Direction matters for performance.

**Example answer (agent-memory)**:
> "Yes. Need to find people co-mentioned in journal entries with Marco (2-hop: Person→JournalEntry→Person). Also need to find tasks for projects of specific people (2-hop: Person→Project→Task)."

**Design decision**: Q1 used Cypher `MATCH (f:Person)-[:MENTIONS]-(j:JournalEntry)-[:MENTIONS]-(p:Person)`. Q5 used SQL MATCH pattern for `Person.out('COLLABORATES_ON').in('BELONGS_TO')`. Both patterns are 2-hop traversals.

**ArcadeDB constraint**: Cypher doesn't resolve parent type labels. `:Entity` won't match subtypes. Edges require VERTEX TYPE endpoints. `out('EDGE_TYPE').property` returns a List when multiple edges exist — use Cypher or iterate in application code.

### Q4.5 — Do you need materialized views, continuous aggregates, or denormalized DOCUMENT TYPE views?

> **Why this matters**: Denormalized DOCUMENT TYPE can serve as materialized views for frequently accessed aggregations, avoiding expensive multi-step queries. Continuous aggregates (TIMESERIES TYPE only) auto-maintain rollups.

**Example answer (social-network-analytics)**:
> "Need engagement metrics (likes, shares, comments) per post for real-time dashboards."

**Design decision**: DOCUMENT TYPE EngagementMetric with postRid, recordedAt, likes, shares, comments. Updated on each engagement event. Acts as a denormalized materialized view. Queries are simple `SELECT FROM EngagementMetric WHERE postRid = ?`.

**Example answer (realtime-analytics)**:
> "Hourly temperature rollups for dashboard."

**Design decision**: `CREATE CONTINUOUS AGGREGATE hourly_sensor_temps` on TIMESERIES TYPE. Auto-maintained by ArcadeDB.

---

## Phase 5: Connectivity & Deployment

Determine how applications connect and how the database is provisioned.

### Q5.1 — What protocols do your applications need? HTTP API, Bolt (Neo4j driver), Postgres wire protocol?

> **Why this matters**: Determines Docker plugin configuration and port exposure. HTTP API is always available on 2480. Bolt requires `BoltProtocolPlugin` on 7687. Postgres requires `Postgres:com.arcadedb.postgres.PostgresProtocolPlugin` on 5432.

**Example answer (iam)**:
> "Backend services connect via Postgres JDBC for SQL queries. A graph analysis tool connects via Bolt for Cypher exploration."

**Design decision**: Both plugins enabled: `-Darcadedb.server.plugins=BoltProtocolPlugin,Postgres:com.arcadedb.postgres.PostgresProtocolPlugin`. Ports 5432 and 7687 exposed. `-Darcadedb.bolt.defaultDatabase=IAM`.

**Example answer (agent-memory)**:
> "Just HTTP API. The Java application uses RemoteDatabase over HTTP."

**Design decision**: No plugins needed. Only port 2480 exposed.

### Q5.2 — What languages/frameworks will connect to ArcadeDB?

> **Why this matters**: Determines Java boilerplate patterns and client library choices. Java uses `RemoteDatabase` (HTTP) or Neo4j driver (Bolt). Node.js uses `pg` (Postgres wire). Python uses `psycopg2` (Postgres wire). Multiple languages may need the Postgres plugin for JDBC/ODBC connectivity.

**Example answer (agent-memory)**:
> "Java 21, using RemoteDatabase over HTTP."

**Design decision**: Java boilerplate with `RemoteDatabase(HOST, PORT, DB_NAME, USER, PASSWORD)`, `db.query("sql", query)` and `db.query("cypher", query)`. Fat JAR via maven-assembly-plugin.

**Example answer (supply-chain)**:
> "Node.js backend using Postgres protocol for SQL, plus a Java analytics module using Bolt."

**Design decision**: Postgres plugin for Node.js `pg` driver. Bolt plugin for Java `neo4j-java-driver:6.1.0`. Two separate Docker services or both plugins on one instance.

### Q5.3 — What infrastructure? Docker Compose for dev, Kubernetes for prod, bare metal?

> **Why this matters**: Determines docker-compose.yml structure, volume persistence, healthcheck configuration, and plugin setup. Dev environments typically use `docker compose down -v` for clean state. Production needs persistent volumes.

**Example answer (agent-memory)**:
> "Docker Compose for development and CI. Clean state between runs."

**Design decision**: Docker compose with healthcheck on `/api/v1/ready`, no persistent volumes (clean state), `JAVA_OPTS` for root password. Standard `wait_for_ready()` in setup.sh.

### Q5.4 — Database name and access credentials?

> **Why this matters**: Database name is used in setup.sh (`POST /api/v1/server`), Java code (`RemoteDatabase` constructor), Bolt default database config, and all queries. Root password must be set via `JAVA_OPTS` (env var doesn't work).

**Example answer (agent-memory)**:
> "Database: `AgentMemory`. Root password: `arcadedb`. No additional users needed."

**Design decision**: `-Darcadedb.server.rootPassword=arcadedb` in JAVA_OPTS. Database created via `POST /api/v1/server` with `{"command": "create database AgentMemory"}`.

**ArcadeDB constraint**: Root password MUST be set via `JAVA_OPTS: "-Darcadedb.server.rootPassword=..."`. The env var form (`ARCADEDB_ROOT_PASSWORD` or similar) does NOT work.

---

## Summary: What the Architect Will Produce

After completing all five phases, the architect delivers:

### 1. Type Classification Table
| Entity | ArcadeDB Type | Reason |
|--------|--------------|--------|
| (each) | VERTEX / DOCUMENT / TIMESERIES | justification |

### 2. Edge Type Map
```
[Source VERTEX] --EDGE_TYPE--> [Target VERTEX]
```
With direction and any edge properties.

### 3. Index Strategy
| Type | Property | Index Type | Reason |
|------|----------|-----------|--------|
| (each) | (each) | UNIQUE/NOTUNIQUE/FULL_TEXT/RANGE/LSM_VECTOR | justification |

### 4. Plugin & Port Configuration
```yaml
JAVA_OPTS: >-
  -Darcadedb.server.rootPassword=...
  -Darcadedb.server.plugins=...
  -Darcadedb.bolt.defaultDatabase=...
ports:
  - "2480:2480"
  # optionally: 5432, 7687
```

### 5. SQL File Plan
```
01-schema.sql: types → properties → indexes
02-data.sql:   INSERT INTO + CREATE EDGE
```

### 6. Query Strategy
For each query from Phase 2:
- Language (SQL, Cypher, or multi-step)
- Whether UNION workaround is needed
- Whether application-side merge is needed
- Expected index usage

### 7. Known Constraints Addressed
Checklist of ArcadeDB limitations that affect this design:
- [ ] UNION needed? → Workaround designed
- [ ] Cross-type JOIN needed? → Workaround designed
- [ ] Inheritance used? → Cypher label resolution accounted for
- [ ] `format(date, ...)` needed? → Pre-computed buckets designed
- [ ] `vectorDistance()` needed? → Using `vectorNeighbors()` or `vectorCosineSimilarity()`
- [ ] `SEARCH_INDEX()` needed? → Using `CONTAINSTEXT` or `SEARCH_CLASS()`
- [ ] `out().property` returning List? → Application code handles it
- [ ] Property aliases in Java? → Always use `AS alias`
- [ ] `NOT UNIQUE` syntax? → Written as `NOTUNIQUE`

---

## Quick Reference: ArcadeDB Constraints Checklist

Use this during the interview to probe for hidden requirements.

| Constraint | Question to ask |
|-----------|----------------|
| No UNION | "Do you need to combine results from different types?" |
| No cross-type JOIN | "Do you need to join a vertex type with a document type in one query?" |
| Cypher doesn't resolve parent labels | "If using inheritance, will Cypher queries match on the parent type?" |
| `format(date, ...)` not available | "Do you need to group by hour/day/week? How will you handle time bucketing?" |
| `vectorDistance()` not available | "Which vector function do you need — neighbor search or pairwise distance?" |
| `SEARCH_INDEX()` not in WHERE | "How do you plan to do full-text search?" |
| Edges need VERTEX endpoints | "Do any of your document types need to participate in graph relationships?" |
| `out().property` returns List with multiple edges | "Will any entity have multiple outgoing edges of the same type to different targets?" |
| `NOT UNIQUE` must be `NOTUNIQUE` | (No question — just remember the syntax) |
| Root password via JAVA_OPTS only | "How do you plan to set the root password?" |
| Property aliases critical in Java | "Will you access query results from Java? Always use AS aliases." |
| Bolt protocol v4 (driver 6.1.0) | "Which Neo4j driver version do you plan to use?" |

---

## Appendix A: Decision Matrix — VERTEX vs DOCUMENT vs TIMESERIES

| Criterion | VERTEX TYPE | DOCUMENT TYPE | TIMESERIES TYPE |
|-----------|-----------|--------------|----------------|
| Participates in graph edges | **Yes** | No | No |
| Has relationships to other entities | **Yes** | No | No |
| Queried via Cypher MATCH | **Yes** | No | No (use SQL on continuous aggregates) |
| High-frequency append (>1/sec) | No | No | **Yes** |
| Needs time-windowed aggregation | Manual | Manual | **Built-in** (timeBucket, rate, percentile) |
| Needs retention policy | Manual DELETE | Manual DELETE | **Built-in** (RETENTION) |
| Standalone record, no relationships | Overkill | **Yes** | No |
| Materialized view / denormalized cache | Overkill | **Yes** | Only for time-series |
| Vector similarity search | Yes | Yes | No |

## Appendix B: Decision Matrix — Index Types

| Query Pattern | Index Type | Example |
|--------------|-----------|---------|
| Lookup by unique ID | UNIQUE | `Account.accountId` |
| Lookup by non-unique field | NOTUNIQUE | `JournalEntry.date` |
| Range queries (>, <, BETWEEN) | RANGE | `Metric.timestamp` |
| Full-text keyword search | FULL_TEXT | `JournalEntry.content` |
| Exact match + hash-based | DICTIONARY | `User.email` |
| Vector similarity (kNN) | LSM_VECTOR | `Product.embedding` |
| Geo/spatial queries | SPATIAL | `Place.location` |
| Composite lookup | Composite UNIQUE/NOTUNIQUE | `Person(name, age)` |
