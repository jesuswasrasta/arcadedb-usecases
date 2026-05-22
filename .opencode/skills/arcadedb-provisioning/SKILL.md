---
name: arcadedb-provisioning
description: "Docker Compose lifecycle management for ArcadeDB servers. Use when starting, stopping, configuring, or health-checking an ArcadeDB instance via Docker."
---

# ArcadeDB Provisioning

Use this skill when you need to spin up, configure, or tear down an ArcadeDB
server via Docker Compose.

## CRITICAL RULES

- Always wait for healthcheck before running setup or queries
- Root password MUST be set via `JAVA_OPTS` (env var form does NOT work)
- Use pinned version `arcadedb/arcadedb:26.5.1` across all environments
- Teardown (`docker compose down`) MUST happen after verification — never
  leave containers running in CI

## Quick Reference

```bash
# Default ports (from repo convention)
ARCADEDB_HTTP_PORT=2480
ARCADEDB_PG_PORT=5432
ARCADEDB_BOLT_PORT=7687
```

### Standard docker-compose.yml

```yaml
services:
  arcadedb:
    image: arcadedata/arcadedb:26.5.1
    environment:
      JAVA_OPTS: >-
        -Darcadedb.server.rootPassword=arcadedb
        -Darcadedb.server.plugins=BoltProtocolPlugin
    ports:
      - "2480:2480"
    healthcheck:
      test: curl -sf http://localhost:2480/api/v1/ready || exit 1
      interval: 5s
      retries: 20
      start_period: 10s
```

### Lifecycle

```bash
# Start
docker compose up -d

# Wait for ready
until curl -sf http://localhost:2480/api/v1/ready; do
  echo "Waiting for ArcadeDB..."
  sleep 3
done

# Verify
docker compose ps

# Stop
docker compose down

# Stop + clean volumes
docker compose down -v
```

## Enabling Plugins

### Bolt Protocol
```yaml
JAVA_OPTS: >-
  -Darcadedb.server.rootPassword=arcadedb
  -Darcadedb.server.plugins=BoltProtocolPlugin
  -Darcadedb.bolt.defaultDatabase=<DB_NAME>
```

### Postgres Wire Protocol
```yaml
JAVA_OPTS: >-
  -Darcadedb.server.rootPassword=arcadedb
  -Darcadedb.server.plugins=Postgres:com.arcadedb.postgres.PostgresProtocolPlugin
```

### Multiple plugins
```yaml
JAVA_OPTS: >-
  -Darcadedb.server.rootPassword=arcadedb
  -Darcadedb.server.plugins=BoltProtocolPlugin,Postgres:com.arcadedb.postgres.PostgresProtocolPlugin
  -Darcadedb.bolt.defaultDatabase=<DB_NAME>
```

## Healthcheck Patterns

```bash
# Simple ready check
curl -sf http://localhost:2480/api/v1/ready

# Check if database exists
curl -u root:arcadedb http://localhost:2480/api/v1/databases

# Wait loop (used in setup.sh)
wait_for_ready() {
  local url=${ARCADEDB_URL:-http://localhost:2480}
  echo "Waiting for ArcadeDB at $url..."
  for i in $(seq 1 30); do
    if curl -sf "$url/api/v1/ready" > /dev/null 2>&1; then
      echo "ArcadeDB ready"
      return 0
    fi
    sleep 2
  done
  echo "Timeout waiting for ArcadeDB"
  return 1
}
```

## Configuration Reference

| Setting | `JAVA_OPTS` flag | Default |
|---------|-----------------|---------|
| Root password | `-Darcadedb.server.rootPassword=` | `root` |
| HTTP port | `-Darcadedb.server.httpPort=` | `2480` |
| Plugins | `-Darcadedb.server.plugins=` | — |
| Bolt default DB | `-Darcadedb.bolt.defaultDatabase=` | — |
| Data directory | `-Darcadedb.server.databaseDirectory=` | `./databases` |

## Troubleshooting

```bash
# Check logs
docker compose logs arcadedb

# Stream logs
docker compose logs -f arcadedb

# Check if port is listening
curl -v http://localhost:2480/api/v1/ready

# If healthcheck fails, give more time
docker compose up -d && sleep 15

# Reset everything
docker compose down -v && docker compose up -d
```
