# AGENTS.md — ArcadeDB Use Cases

> **Authoritative constitution**: `.specify/memory/constitution.md` — this file is the derived quick-reference.

10 self-contained demos showing [ArcadeDB](https://arcadedb.com) multi-model features. Each directory is standalone — no shared dependencies.

## Use Cases (all ArcadeDB 26.5.1, Java 21, HTTP API on port 2480)

| Directory | DB Name | Extra ports | Extra notes |
|-----------|---------|-------------|-------------|
| `recommendation-engine/` | `RecommendationEngine` | — | — |
| `knowledge-graphs/` | `KnowledgeGraph` | — | — |
| `graph-rag/` | `GraphRAG` | 7687 (Bolt) | Also has `langchain4j/` sibling module; both use `neo4j-java-driver:6.1.0` |
| `fraud-detection/` | `FraudDetection` | — | Uses Cypher |
| `realtime-analytics/` | `RealtimeAnalytics` | — | Ships Grafana sidecar (`grafana/` dir with dashboards) |
| `social-network-analytics/` | `SocialNetworkAnalytics` | — | Materialized views, DOCUMENT TYPE for metrics |
| `supply-chain/` | `SupplyChain` | 5432 (Postgres) | Also has `js/` (Node.js + pg) |
| `iam/` | `IAM` | 5432 (Postgres), 7687 (Bolt) | Also has `python/` (psycopg) |
| `customer-360/` | `Customer360` | — | — |
| `feature-store/` | `FeatureStore` | 5432 (Postgres) | Also has `js/` (Node.js + pg) |

## Every Use Case Layout

```
<use-case>/
├── docker-compose.yml          # Single arcadedata/arcadedb service (26.5.1)
├── setup.sh                    # Waits for ready, creates DB, applies sql/
├── sql/
│   ├── 01-schema.sql           # One statement per line
│   └── 02-data.sql             # INSERTs + CREATE EDGE, one per line
├── queries/
│   └── queries.sh              # curl-based demos via query() helper
├── java/
│   ├── pom.xml                 # maven-assembly-plugin for fat JAR
│   └── src/main/java/com/arcadedb/examples/<ClassName>.java
└── README.md
```

`graph-rag/` additionally has `langchain4j/` with its own `pom.xml`. Some use cases add `js/` or `python/` for PostgreSQL-protocol demos.

## Critical Conventions

### SQL Files
- **One statement per line** — `setup.sh` reads line-by-line, strips trailing semicolons
- Blank lines and `-- comment` lines (only at line start, optionally preceded by whitespace) are skipped

### setup.sh Pattern
- Env vars: `ARCADEDB_URL` (default `http://localhost:2480`), `ARCADEDB_USER` (root), `ARCADEDB_PASS` (arcadedb)
- Creates database via `POST /api/v1/server` with `{"command": "create database <DB_NAME>"}`
- `send_sql()` uses `jq` to JSON-encode, POSTs to `/api/v1/command/<DB>`
- `apply_file()` reads line-by-line, skips blanks/comments

### queries.sh Pattern
- Same env vars as setup.sh
- `query(language, command)` POSTs to `/api/v1/query/<DB>`, pipes through `jq '.result'`
- Some use cases also define `send_command()` for `/api/v1/command/<DB>`

### Java Pattern
- Package: `com.arcadedb.examples`, fat JAR via `maven-assembly-plugin` with `appendAssemblyId=false`
- Config from env vars: `ARCADEDB_HOST`, `ARCADEDB_PORT` (or `ARCADEDB_BOLT_PORT`), `ARCADEDB_USER`, `ARCADEDB_PASS`
- `tryRun(Runnable, String)` wrapper for graceful per-query error handling
- `printHeader(String, String)` for formatted output
- Uses `com.arcadedb.remote.RemoteDatabase` (HTTP API) or Neo4j driver for Bolt

### Docker Compose
- Root password via `JAVA_OPTS: "-Darcadedb.server.rootPassword=arcadedb"` (the env var form doesn't work)
- Healthcheck: `curl -sf` or `wget --spider -q` against `http://localhost:2480/api/v1/ready`, interval 5s, retries 20
- Postgres plugin: `-Darcadedb.server.plugins=Postgres:com.arcadedb.postgres.PostgresProtocolPlugin`
- Bolt plugin: `-Darcadedb.server.plugins=BoltProtocolPlugin` (or comma-separated for multiple), plus `-Darcadedb.bolt.defaultDatabase=<DB_NAME>`

## ArcadeDB API Quirks

- `vectorDistance()` not available — use `vectorNeighbors('TypeName[property]', vector, k)` with `LSM_VECTOR` index
- Vector index format: `TypeName[propertyName]`
- `LET $var = (SELECT ... GROUP BY ...)` not supported
- `SEARCH_INDEX()` not supported in WHERE — use `SEARCH_CLASS('query')` for full-text
- Cypher doesn't resolve parent type labels to subtypes (`:Entity` won't match `Person`)
- Edges require VERTEX TYPE endpoints (not DOCUMENT TYPE)
- `Neo4jEmbeddingStore` from LangChain4j doesn't work with ArcadeDB (uses `SHOW VECTOR INDEX` DDL); use direct Neo4j driver + `CosineSimilarity`
- Bolt protocol: ArcadeDB implements protocol v4; current driver `6.1.0` works

## CI (`.github/workflows/`)

One workflow per use case, all identical pattern:
```yaml
matrix:
  runner: [curl, java]
```
Steps: checkout → (if java) setup-java + cache ~/.m2 → `docker compose up -d` → `./setup.sh` → curl queries or `mvn package --no-transfer-progress && java -jar target/<name>.jar` → `docker compose down` (always()).

Action SHAs pinned. Also has `claude.yml` (issue/PR comment trigger) and `claude-code-review.yml` (PR review via Anthropic action).

## Git & PR

- Branch: `feat/<use-case>`, `infra/`
- Commits: `feat(<scope>):`, `fix(<scope>):`, `ci:`, `docs:`, `chore:`
- Dependabot for Docker + Maven; Mergify auto-merges approved Dependabot PRs with `[skip ci]`
- Pre-commit hooks: prettier (java, xml), shfmt, YAML/JSON/XML checkers

## Docs

Design docs in `docs/plans/` with date prefix: `*-design.md` (architecture), `*-ci.md` (CI spec), `*.md` without suffix (implementation plans).

## Serena (LSP-based Code Navigation)

**Obbligatorio** — Serena è l'unico strumento autorizzato per navigare, cercare e modificare il codice sorgente. È molto più efficiente e precisa di grep/rg/ag perché opera a livello di simboli tramite Language Server Protocol.

- **All'avvio sessione**: verifica che Serena sia attiva e che il progetto sia inizializzato (`serena_activate_project` se necessario). Se non lo è, inizializzalo prima di qualsiasi operazione sul codice.
- **Code search/modification**: MUST usare la skill `serena`. Non usare grep, ripgrep, ag, sed, o regex-only tools per code transformations.
- **Refactoring**: usa `serena_jet_brains_rename`, `serena_jet_brains_move`, `serena_jet_brains_safe_delete` per operazioni di refactoring — aggiornano automaticamente tutti i riferimenti.
- **Fallback**: solo se Serena non è disponibile o non supporta il linguaggio, si può usare temporaneamente grep, ma va segnalato a Nando.

## Journal

Uso obbligatorio della skill `.opencode/skills/journal/SKILL.md`:

- **All'avvio sessione** — leggi le ultime 1-2 entry di `JOURNAL.md` e chiedi a Nando se ci sono cose da riprendere/continuare. Se non trova il file, ignora. Poi verifica che Serena sia attiva.
- **A fine feature** — quando implementi una feature, la completi o ne cambi direzione, invoca `salva sul journal` per fissare attività, decisioni e apprendimenti prima di chiudere.

<!-- SPECKIT START -->
For additional context about technologies to be used, project structure,
shell commands, and other important information, read the current plan
<!-- SPECKIT END -->
