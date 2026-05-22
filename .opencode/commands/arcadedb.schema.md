---
description: "Show, create, or compare ArcadeDB schemas. Inspect types, properties, indexes, and type hierarchy."
---

# ArcadeDB Schema

Inspect or modify the schema of an ArcadeDB database. Can show types,
properties, indexes, or generate DDL from an existing schema.

## User Input

```text
$ARGUMENTS
```

## Pre-Execution

Verify connection to a running ArcadeDB server with the specified database.

## Execution

1. Parse the user input for operation (show/create/compare) and database name
2. For **show**: list types, properties, or indexes via schema queries
3. For **create**: generate DDL from a description of entities and
   relationships
4. For **compare**: diff two schema definitions

## Schema Inspection Commands

```bash
# List all types
curl -s -u root:arcadedb \
  "http://localhost:2480/api/v1/command/<DB>/sql" \
  -H "Content-Type: application/json" \
  -d '{"command": "SELECT FROM schema:types"}' | jq '.result'

# Show type properties
curl -s -u root:arcadedb \
  "http://localhost:2480/api/v1/command/<DB>/sql" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg cmd 'SELECT expand(properties) FROM schema:class WHERE name = \"<TYPE>\"' '{"command": $cmd}')" | jq '.result'

# Show indexes
curl -s -u root:arcadedb \
  "http://localhost:2480/api/v1/command/<DB>/sql" \
  -H "Content-Type: application/json" \
  -d '{"command": "SELECT FROM schema:indexes"}' | jq '.result'
```

## DDL Generation

When generating DDL, follow the canonical pattern:

```sql
CREATE VERTEX TYPE <Name> IF NOT EXISTS
CREATE PROPERTY <Name>.<property> <TYPE> [(constraint)]
CREATE INDEX <Name>.<property> ON <Name> (<property>) <INDEX_TYPE>
```

One statement per line, no trailing semicolons in source files.
