---
name: arcadedb-query
description: "Query ArcadeDB via HTTP API (SQL and Cypher). Use when executing queries, analyzing results, or extracting data from a running ArcadeDB server."
---

# ArcadeDB Query

Use this skill to execute queries against an ArcadeDB server via the HTTP API.
Covers both SQL (ArcadeDB dialect) and Cypher.

## CRITICAL RULES

- Always confirm the server is running and the database exists before querying
- SQL queries go to `/api/v1/query/<db>`; DDL commands go to
  `/api/v1/command/<db>`
- Use `jq '.result'` to extract results from the JSON response
- Escape JSON strings properly in curl payloads — use `jq` for encoding
- Cypher query language is `sql` (not `cypher`) in the HTTP API

## Quick Reference

```bash
# Default connection
ARCADEDB_URL=${ARCADEDB_URL:-http://localhost:2480}
ARCADEDB_USER=${ARCADEDB_USER:-root}
ARCADEDB_PASS=${ARCADEDB_PASS:-arcadedb}
AUTH="${ARCADEDB_USER}:${ARCADEDB_PASS}"
QUERY_URL="${ARCADEDB_URL}/api/v1/query/${DB}"
```

### Query (SELECT / MATCH / TRAVERSE)

Standard helper (from repo convention — uses `language` parameter):

```bash
query() {
  local lang="$1" cmd="$2"
  jq -cn --arg l "$lang" --arg c "$cmd" \
    '{"language":$l,"command":$c}' \
    | curl -sf -u "$AUTH" -X POST "$QUERY_URL" \
        -H "Content-Type: application/json" -d @- \
    | jq '.result'
}

# SQL query
query "sql" "SELECT FROM V LIMIT 10"

# Cypher query
query "cypher" "MATCH (n) RETURN n LIMIT 10"

# With params
query "sql" "SELECT FROM V WHERE name = ?"
```

Direct curl equivalent:

```bash
# SQL query
curl -s -u "$AUTH" "$ARCADEDB_URL/api/v1/query/${DB}/sql" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg cmd 'SELECT FROM V LIMIT 10' '{"language":"sql","command":$cmd}')" \
  | jq '.result'

# Cypher (language = 'cypher', command is pure Cypher)
curl -s -u "$AUTH" "$ARCADEDB_URL/api/v1/query/${DB}/sql" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg cmd 'MATCH (n) RETURN n LIMIT 10' '{"language":"cypher","command":$cmd}')" \
  | jq '.result'
```

### Command (DDL: CREATE, INSERT, UPDATE, DELETE)

```bash
COMMAND_URL="${ARCADEDB_URL}/api/v1/command/${DB}"

send_command() {
  local cmd="$1"
  jq -cn --arg c "$cmd" '{"language":"sql","command":$c}' \
    | curl -sf -u "$AUTH" -X POST "$COMMAND_URL" \
        -H "Content-Type: application/json" -d @- \
    | jq '.result'
}

# Create type
send_command "CREATE VERTEX TYPE Person IF NOT EXISTS"

# Insert
send_command "INSERT INTO Person SET name = 'Alice'"

# Direct curl equivalent
curl -s -u "$AUTH" "$ARCADEDB_URL/api/v1/command/${DB}/sql" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg cmd 'SELECT 1 as test' '{"language":"sql","command":$cmd}')" \
  | jq '.result'
```

### Server Operations

```bash
# Create database
curl -s $AUTH "$ARCADEDB_URL/api/v1/server" \
  -H "Content-Type: application/json" \
  -d '{"command": "create database <DB_NAME>"}'

# List databases
curl -s $AUTH "$ARCADEDB_URL/api/v1/databases" | jq '.'

# Check server info
curl -s $AUTH "$ARCADEDB_URL/api/v1/server" | jq '.'
```

## Query Patterns

### Graph Traversal

```sql
-- Traverse edges
SELECT FROM V WHERE @class = 'Person'
SELECT expand(out('FRIEND')) FROM Person WHERE name = 'Alice'

-- Shortest path (ArcadeSQL)
SELECT shortestPath(from: (SELECT FROM Person WHERE name = 'Alice'),
                    to: (SELECT FROM Person WHERE name = 'Bob'),
                    direction: 'BOTH',
                    edgeType: 'FRIEND')

-- Match pattern (ArcadeSQL)
MATCH {type: Person, where: (name = 'Alice')}
      -FRIEND->
      {type: Person}
RETURN $matches
```

### Full-text Search

```sql
-- Requires full-text index on the field
SELECT FROM V WHERE SEARCH_CLASS('Alice', 'name')
```

### Pagination

```sql
SELECT FROM V LIMIT 20 SKIP 0
SELECT FROM V ORDER BY @rid LIMIT 20 SKIP 20
```

### Aggregation

```sql
SELECT name, count(*) as cnt FROM V GROUP BY name ORDER BY cnt DESC
```

## Query Helper Functions (from repo conventions)

```bash
# queries.sh standard helpers
QUERY_URL="${ARCADEDB_URL}/api/v1/query/${DB}"

query() {
  local lang="$1" cmd="$2"
  jq -cn --arg l "$lang" --arg c "$cmd" \
    '{"language":$l,"command":$c}' \
    | curl -sf -u "$AUTH" -X POST "$QUERY_URL" \
        -H "Content-Type: application/json" -d @- \
    | jq '.result'
}

COMMAND_URL="${ARCADEDB_URL}/api/v1/command/${DB}"

send_command() {
  local cmd="$1"
  jq -cn --arg c "$cmd" '{"language":"sql","command":$c}' \
    | curl -sf -u "$AUTH" -X POST "$COMMAND_URL" \
        -H "Content-Type: application/json" -d @- \
    | jq '.result'
}
```

Note: the `query()` helper takes `language` as first argument (`sql` or
`cypher`) and the query as second. Both use `jq -cn` with `--arg` for safe
JSON encoding — never manually construct JSON payloads.

## ArcadeDB API Quirks

- `vectorDistance()` is NOT available — use `vectorNeighbors()` instead
- `SEARCH_INDEX()` is NOT supported in WHERE — use `SEARCH_CLASS()`
- `LET $var = (SELECT ... GROUP BY ...)` is NOT supported — use nested
  subqueries
- The `language` parameter distinguishes `sql` from `cypher` in the HTTP API
- Edges require VERTEX TYPE endpoints (not DOCUMENT TYPE)
