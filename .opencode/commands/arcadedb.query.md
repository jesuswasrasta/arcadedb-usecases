---
description: "Execute SQL or Cypher queries against an ArcadeDB server. Specify database, query language, and query text."
---

# Execute ArcadeDB Query

Execute SQL or Cypher queries against a running ArcadeDB server and return
the results.

## User Input

```text
$ARGUMENTS
```

## Pre-Execution

Verify connection parameters are available. If missing, use defaults:
- Host: `localhost`
- Port: `2480`
- User: `root`
- Password: `arcadedb`

## Execution

1. Parse the user input for: database name, query language (sql/cypher),
   and query text
2. Construct the curl command and execute it
3. Use `jq '.result'` to extract and display results

## Output

```bash
# SQL query
curl -s -u root:arcadedb \
  "http://localhost:2480/api/v1/query/<DB>/sql" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg cmd '<QUERY>' '{"command": $cmd}')" | jq '.result'

# Cypher (language parameter is still 'sql', command starts with CYPHER)
curl -s -u root:arcadedb \
  "http://localhost:2480/api/v1/query/<DB>/sql" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg cmd 'CYPHER <QUERY>' '{"command": $cmd}')" | jq '.result'

# DDL command
curl -s -u root:arcadedb \
  "http://localhost:2480/api/v1/command/<DB>/sql" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg cmd '<DDL>' '{"command": $cmd}')" | jq '.result'
```

## Error Handling

- If server is unreachable: suggest checking docker compose ps
- If 401: suggest checking root password config
- If database not found: suggest creating it first
