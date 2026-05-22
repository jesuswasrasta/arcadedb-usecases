---
name: arcadedb-schema-design
description: "ArcadeDB schema design and type management. Use when defining vertex/edge types, indexes, properties, and relationships."
---

# ArcadeDB Schema Design

Use this skill to design, create, or modify ArcadeDB schemas. Covers type
hierarchy, property definitions, indexes, and relationship modeling.

## CRITICAL RULES

- One statement per line in SQL files — setup.sh reads line-by-line
- DDL commands use POST to `/api/v1/command/<db>/sql`
- Edges require VERTEX TYPE endpoints (not DOCUMENT TYPE)
- CREATE TYPE creates by default a DOCUMENT TYPE — add `TYPE VERTEX` or
  `TYPE EDGE` explicitly for graph elements
- ArcadeDB supports type inheritance: children inherit properties and indexes

## Type Hierarchy

```sql
-- Document type (non-graph, no edges)
CREATE DOCUMENT TYPE Metric IF NOT EXISTS

-- Vertex type (participates in graph edges)
CREATE VERTEX TYPE Person IF NOT EXISTS

-- Edge type (connects vertices)
CREATE EDGE TYPE FRIEND IF NOT EXISTS

-- With inheritance
CREATE VERTEX TYPE Employee EXTENDS Person IF NOT EXISTS
CREATE VERTEX TYPE User EXTENDS Person IF NOT EXISTS
```

**Cypher caveat**: Cypher does NOT resolve parent type labels to subtypes.
`:Person` won't match `Employee` or `User`.

## Properties

```sql
-- With data type
CREATE PROPERTY Person.name STRING
CREATE PROPERTY Person.age INTEGER
CREATE PROPERTY Person.email STRING (maxWidth 255)

-- Embedded types
CREATE PROPERTY Person.address EMBEDDED
CREATE PROPERTY Person.tags EMBEDDEDLIST STRING

-- With mandatory/not null
CREATE PROPERTY Person.name STRING (mandatory true)

-- Default values
CREATE PROPERTY Person.createdAt DATETIME (default "sysdate()")
```

### Supported Types

| Type | Description |
|------|-------------|
| STRING | Text |
| INTEGER | 32-bit int |
| LONG | 64-bit int |
| FLOAT | 32-bit float |
| DOUBLE | 64-bit float |
| BOOLEAN | true/false |
| DATETIME | Date + time |
| DATE | Date only |
| BINARY | Binary data |
| EMBEDDED | Nested document |
| EMBEDDEDLIST | List of embedded |
| EMBEDDEDSET | Set of embedded |
| EMBEDDEDMAP | Map of embedded |
| LINK | Single reference to another record |
| LINKLIST | List of references |
| LINKSET | Set of references |
| LINKMAP | Map of references |
| STRINGLIST | List of strings |
| INTEGERLIST | List of integers |

## Indexes

```sql
-- Unique index
CREATE INDEX IF NOT EXISTS ON Person (name) UNIQUE

-- Not unique
CREATE INDEX IF NOT EXISTS ON Person (name) NOTUNIQUE

-- Full-text index (for SEARCH_CLASS)
CREATE INDEX IF NOT EXISTS ON Person (name) FULLTEXT

-- Dictionary (unique + hash)
CREATE INDEX IF NOT EXISTS ON Person (email) DICTIONARY

-- Composite index
CREATE INDEX IF NOT EXISTS ON Person (name, age) NOTUNIQUE

-- Range index (for comparisons)
CREATE INDEX IF NOT EXISTS ON Person (age) RANGE

-- Spatial index
CREATE INDEX IF NOT EXISTS ON Place (location) SPATIAL

-- Vector index (for similarity search — see arcadedb-vector skill)
CREATE INDEX IF NOT EXISTS ON Product (embedding) LSM_VECTOR
  METADATA { dimensions: 4, similarity: 'COSINE' }
```

### Index Types

| Type | Use Case |
|------|----------|
| UNIQUE | Enforce uniqueness, fast lookup |
| NOTUNIQUE | Speed up queries without uniqueness |
| FULLTEXT | Full-text search via SEARCH_CLASS() |
| DICTIONARY | Unique + hash-based, single field |
| RANGE | Range queries (>, <, BETWEEN) |
| SPATIAL | Geo queries |
| LSM_VECTOR | Vector similarity search |

## Relationships

```sql
-- Simple edge (no properties)
CREATE EDGE FRIEND FROM (SELECT FROM Person WHERE name = 'Alice')
                 TO   (SELECT FROM Person WHERE name = 'Bob')

-- Edges with properties (requires EDGE TYPE with properties)
CREATE PROPERTY FRIEND.since DATETIME
CREATE EDGE FRIEND FROM (SELECT FROM Person WHERE name = 'Alice')
                 TO   (SELECT FROM Person WHERE name = 'Bob')
                 SET since = '2024-01-01'

-- Using LINK type
CREATE PROPERTY Person.address LINK Address
```

## Schema Inspection

```sql
-- List all types
SELECT FROM schema:types

-- Show type properties
SELECT expand(properties) FROM schema:class WHERE name = 'Person'

-- Show indexes
SELECT FROM schema:indexes

-- Show type hierarchy
SELECT name, superClass FROM schema:class ORDER BY name
```

## SQL Discipline (from constitution)

- One statement per line
- Blank lines and lines starting with `--` are skipped
- No trailing semicolons in source files (stripped by setup.sh)
- No inline comments

## ArcadeDB SQL Limitations

These constraints are discovered through production use across multiple
projects. Always check this list BEFORE designing a schema.

### No UNION

ArcadeDB SQL does NOT support `UNION` / `UNION ALL`. You cannot combine
results from multiple types in a single query.

**Workarounds** (choose based on data volume):
- **Application-side merge**: Run one query per type, merge results in Java/Python
- **Denormalized DOCUMENT TYPE**: Pre-aggregate results into a single DOCUMENT TYPE
  with a `source` discriminator field and update it on writes
- **Single base type**: If types share structure, use a common VERTEX TYPE with
  inheritance and query the parent

### No Cross-Type JOIN

`FROM TypeA, TypeB` and `FROM TypeA JOIN TypeB ON ...` across different types
is NOT supported. JOINs only work within `MATCH` patterns on vertices connected
by edges.

**Workarounds**:
- Separate queries + application-side correlation
- Denormalize related data into a single DOCUMENT TYPE
- Use EDGE TYPE to connect entities if a graph relationship exists

### `NOT UNIQUE` → `NOTUNIQUE`

The syntax is a single word: `CREATE INDEX ... NOTUNIQUE`. Writing
`NOT UNIQUE` (with space) causes a parse error.

```sql
-- CORRECT
CREATE INDEX ON Person (name) NOTUNIQUE

-- WRONG — parse error
CREATE INDEX ON Person (name) NOT UNIQUE
```

### No `IF NOT EXISTS` on `CREATE PROPERTY`

`CREATE TYPE IF NOT EXISTS` works, but `CREATE PROPERTY` does not support
`IF NOT EXISTS`. If a property already exists, the statement fails.

**Workaround**: Use `CREATE PROPERTY ... IF NOT EXISTS` in SQL files as a
convention, but be aware it may fail during re-runs. The `setup.sh` pattern
handles this by applying files only on fresh databases.

### No `format(date, ...)`

ArcadeDB SQL has no date formatting function like `format(date, 'yyyy-MM-dd')`.
You cannot extract year, month, week, or day components dynamically in queries.

**Workaround**: Pre-compute time buckets as explicit INTEGER properties on the
type: `weekNumber`, `dayName`, `hourBucket`. Populate them during INSERT and
use them directly in `GROUP BY`.

```sql
CREATE PROPERTY JournalEntry.weekNumber INTEGER
CREATE INDEX ON JournalEntry (weekNumber) NOTUNIQUE

-- Query uses pre-computed bucket
SELECT weekNumber, count(*) FROM JournalEntry GROUP BY weekNumber
```

**Alternative**: For high-frequency data (>1/sec), use TIMESERIES TYPE which
has built-in `ts.timeBucket()` function.

### `out('EDGE_TYPE').property` Returns List

When a vertex has multiple outgoing edges of the same type targeting different
vertices, `out('EDGE_TYPE').property` returns a `java.util.ArrayList` — not a
scalar. This causes `ClassCastException` in Java.

**Workaround**: Use Cypher `MATCH` for multi-edge traversals (one row per path)
instead of SQL `out().property` (aggregates into List).

### Cypher Parent Label Resolution

Cypher does NOT resolve parent type labels to subtypes. If `Employee EXTENDS Person`,
`:Person` in a Cypher `MATCH` will NOT match `Employee` vertices.

**Workaround**: Use concrete subtype labels in Cypher queries:
```cypher
-- WRONG — won't match Employee or User
MATCH (p:Person) RETURN p

-- CORRECT — match each subtype explicitly
MATCH (p) WHERE p.@type IN ['Person', 'Employee', 'User'] RETURN p
```

### `SEARCH_INDEX()` Not in WHERE

`SEARCH_INDEX()` is NOT supported in WHERE clauses. Use these instead:
- `CONTAINSTEXT 'keyword'` — searches a single full-text indexed field
- `SEARCH_CLASS('query')` — searches ALL full-text indexed fields of a type

```sql
-- Single field
SELECT FROM JournalEntry WHERE content CONTAINSTEXT 'team'

-- All full-text fields of a type
SELECT FROM JournalEntry WHERE SEARCH_CLASS('team OR sprint')
```

### Vector Functions

`vectorDistance()` is NOT available. Use:
- `vectorNeighbors('TypeName[propertyName]', vector, k)` — index-based kNN
  search (requires LSM_VECTOR index)
- `vectorCosineSimilarity(field, vector)` — full-scan scalar function

**Vector index format**: `TypeName[propertyName]` (bracket notation, not dot).

### Root Password via JAVA_OPTS Only

The root password MUST be set via `JAVA_OPTS`:
```yaml
JAVA_OPTS: "-Darcadedb.server.rootPassword=arcadedb"
```

Environment variable forms like `ARCADEDB_ROOT_PASSWORD` do NOT work.

### Edges Require VERTEX TYPE Endpoints

Edges can only connect VERTEX TYPE to VERTEX TYPE. DOCUMENT TYPE cannot be
edge endpoints. If an entity needs to participate in graph relationships,
it MUST be a VERTEX TYPE.

### No `CREATE PROPERTY ... IF NOT EXISTS`

The `IF NOT EXISTS` clause works for `CREATE TYPE` but NOT for `CREATE PROPERTY`.
If re-running schema SQL on an existing database, property creation statements
will fail with "property already exists" errors.
