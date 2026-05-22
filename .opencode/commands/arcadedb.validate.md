---
description: "Validate an ArcadeDB setup against repo conventions. Checks Docker Compose, SQL discipline, setup.sh pattern, and query correctness."
---

# ArcadeDB Validate

Validate an ArcadeDB use case directory against the conventions defined in
the project constitution and AGENTS.md.

## User Input

```text
$ARGUMENTS
```

## Validation Checks

1. **Docker Compose**: check for required fields (image version 26.5.1,
   healthcheck, JAVA_OPTS root password)
2. **SQL Discipline**: verify one statement per line, no trailing semicolons,
   correct comment format
3. **Setup Script**: verify setup.sh follows the standard pattern (env vars,
   create database, send_sql, apply_file)
4. **Query Script**: verify queries.sh uses the query() helper with correct
   curl + jq pattern
5. **Directory Structure**: verify required files exist (docker-compose.yml,
   setup.sh, sql/01-schema.sql, sql/02-data.sql, queries/queries.sh,
   README.md)
6. **Healthcheck**: verify the server can be reached and the database exists

## Execution

```bash
# Check directory structure
ls use-case/docker-compose.yml use-case/setup.sh use-case/sql/01-schema.sql

# Verify image version
grep 'arcadedb/arcadedb:' use-case/docker-compose.yml | grep '26.5.1'

# Check JAVA_OPTS root password
grep 'rootPassword' use-case/docker-compose.yml

# Verify SQL line discipline
awk 'NF && !/^--/' use-case/sql/01-schema.sql | wc -l

# Run setup in check mode
cd use-case && bash -n setup.sh && echo "Syntax OK"
```

## Output

For each check, report:
- ✅ Pass
- ⚠️ Warning
- ❌ Fail (with remediation suggestion)
