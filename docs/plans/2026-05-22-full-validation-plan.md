# Full Validation Plan — All 10 Use Cases

**Date**: 2026-05-22
**Objective**: Validate every skill, agent, and command against every use case
**Method**: Sequential (single Docker host, shared port 2480)

## Tiered Execution Order

From simplest (least dependencies) to most complex:

| # | Use Case | Extra Ports | Extra Modules | Unique Features |
|---|----------|-------------|---------------|-----------------|
| 1 | recommendation-engine | — | — | ✅ done |
| 2 | knowledge-graphs | — | — | query-only validation |
| 3 | customer-360 | — | — | wget healthcheck |
| 4 | social-network-analytics | — | — | materialized views, DOCUMENT TYPE metrics |
| 5 | fraud-detection | — | — | Cypher queries |
| 6 | graph-rag | 7687 (Bolt) | langchain4j/ | Bolt protocol, vector |
| 7 | supply-chain | 5432 (PG) | js/ | Postgres wire + Node.js |
| 8 | feature-store | 5432 (PG) | js/ | Postgres wire + Node.js |
| 9 | iam | 5432, 7687 | python/ | Postgres + Bolt + Python |
| 10 | realtime-analytics | 3000 (Grafana) | grafana/ | Grafana sidecar, wget healthcheck |

## Per-Use-Case Procedure

### Standard steps (all 10)

```
1. docker compose up -d
2. wait for ready
3. ./setup.sh
4. ./queries/queries.sh
5. cd java && mvn package --no-transfer-progress && java -jar target/<artifact>.jar
6. docker compose down -v
```

### Extra steps by use case

#### graph-rag
```
7. cd langchain4j && mvn package --no-transfer-progress && java -jar target/*.jar
```

#### supply-chain, feature-store
```
7. cd js && node <script>.js
```

#### iam
```
7. cd python && pip install -r requirements.txt && python iam.py
8. cd python && pip install -r requirements-cypher.txt && python iam_cypher.py   # Bolt path
```

#### realtime-analytics
```
7. Verify Grafana dashboard is accessible on http://localhost:3000
```

## Skills Coverage Map

| Skill | Tested by |
|-------|-----------|
| `arcadedb-provisioning` | all 10 — Docker lifecycle, healthcheck patterns |
| `arcadedb-query` | all 10 — curl/jq query patterns |
| `arcadedb-schema-design` | all 10 — type definitions, indexes, relationships |
| `arcadedb-vector` | recommendation-engine, graph-rag, customer-360 |
| `arcadedb-time-series` | recommendation-engine, realtime-analytics, social-network-analytics |
| `arcadedb-bolt` | graph-rag, iam |
| `arcadedb-pgwire` | supply-chain, iam, feature-store |
| `arcadedb-java` | all 10 — RemoteDatabase, tryRun, Maven assembly |

## Agents & Commands Test Scenarios

### Commands (tested interactively during validation)

- `/arcadedb.provision` — invoke after docker compose up to verify it generates correct setup.sh patterns
- `/arcadedb.query` — test with a live use case DB to verify query execution across language variants
- `/arcadedb.schema` — inspect schema of a running use case DB
- `/arcadedb.validate` — verify a use case directory against repo conventions

### Agents (prompted once during validation)

- `arcadedb-architect` — ask to evaluate schema design for 1-2 use cases
- `arcadedb-query-expert` — ask to write/enhance a query for 1-2 use cases
- `arcadedb-operator` — ask to check server health and configuration

## Success Criteria per Use Case

| Step | Success |
|------|---------|
| docker compose up | Container starts, healthcheck passes within 60s |
| setup.sh | All SQL runs without errors, DB exists |
| queries.sh | All queries return non-empty results (jq '.result' has data) |
| Java build | `mvn package` succeeds, fat JAR produced |
| Java run | All queries return non-empty results, no exceptions |
| Extra modules | Node.js/Python scripts connect and query successfully |
| docker compose down | Container removed, volumes cleaned |

## Failure Handling

- **SQL failure**: Check error message, fix SQL, re-run setup.sh (DB already exists, `IF NOT EXISTS` guards)
- **Query failure**: ArcadeDB may return error in `.error` field — check `jq '.result'` and `jq '.error'`
- **Port conflict**: Ensure previous use case is fully down before starting next
- **Java failure**: Check dependency resolution, verify ArcadeDB version in POM
- **No automatic retry** — each failure is investigated before proceeding

## Estimated Effort

| Tier | Use Cases | Est. Time |
|------|-----------|-----------|
| Tier 1 (simple, no extras) | 4 | ~5 min each |
| Tier 2 (Cypher/vector) | 2 | ~10 min each |
| Tier 3 (Bolt/Postgres extra modules) | 3 | ~15 min each |
| Tier 4 (Grafana) | 1 | ~10 min |
| **Total** | **10** | **~75 min** |

## Dependency Notes

- **No concurrency**: only 1 port 2480, all sequential
- **Port conflicts**: 5432 shared by supply-chain, feature-store, iam — must be sequential
- **Maven cache**: `~/.m2/repository` grows with each build, acceptable (~200MB total)
- **Docker images**: `arcadedata/arcadedb:26.5.1` already cached from recommendation-engine run; `grafana/grafana-oss:13.0.1` pulled when needed
- **Language runtimes**: Java 21 (mise), Node.js (check availability), Python 3 (check availability)
