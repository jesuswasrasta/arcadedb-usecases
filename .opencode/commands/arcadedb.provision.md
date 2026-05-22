---
description: "Provision an ArcadeDB server via Docker Compose. Start, configure, or tear down an instance."
---

# ArcadeDB Provision

Start, configure, or tear down an ArcadeDB server instance using Docker
Compose. Supports custom configuration, plugin enabling, and healthcheck
waiting.

## User Input

```text
$ARGUMENTS
```

## Execution

1. Parse the user input for operation (up/down/restart/status), database
   name, plugins, and port mappings
2. Generate or use an existing docker-compose.yml
3. Execute the Docker Compose lifecycle command
4. Wait for healthcheck if starting

## Docker Compose Template

```yaml
services:
  arcadedb:
    image: arcadedb/arcadedb:26.5.1
    environment:
      JAVA_OPTS: >-
        -Darcadedb.server.rootPassword=arcadedb
        -Darcadedb.server.plugins=<PLUGINS>
        -Darcadedb.bolt.defaultDatabase=<DB_NAME>
    ports:
      - "<HTTP_PORT>:2480"
      - "<BOLT_PORT>:7687"
      - "<PG_PORT>:5432"
    healthcheck:
      test: curl -sf http://localhost:2480/api/v1/ready || exit 1
      interval: 5s
      retries: 20
      start_period: 10s
```

## Operations

```bash
# Start
docker compose up -d

# Wait for ready
until curl -sf http://localhost:2480/api/v1/ready; do sleep 2; done

# Create database
curl -s -u root:arcadedb \
  "http://localhost:2480/api/v1/server" \
  -H "Content-Type: application/json" \
  -d '{"command": "create database <DB_NAME>"}'

# Status
docker compose ps

# Stop
docker compose down

# Full reset
docker compose down -v
```
