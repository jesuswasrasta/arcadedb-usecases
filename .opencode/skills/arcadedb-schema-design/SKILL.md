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
