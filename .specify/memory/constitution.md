<!--
  Sync Impact Report

  Version change: 0.0.0 (template) → 1.0.0 (initial) → 1.0.1 (patch)

  Amendments:
  - [1.0.1] SQL Discipline: fix trailing semicolons rule (contradiction:
    MUST NOT vs "stripped by setup.sh") → allow semicolons, stripped by
    setup.sh

  Modified sections (all new — initial fill from template):
  - PROJECT_NAME → "ArcadeDB Use Cases"
  - PRINCIPLE_1 → "I. Standalone Demos"
  - PRINCIPLE_2 → "II. Canonical Layout"
  - PRINCIPLE_3 → "III. HTTP API First"
  - PRINCIPLE_4 → "IV. SQL Discipline"
  - PRINCIPLE_5 → "V. CI-Gated Quality"
  - SECTION_2 → "Technology Constraints"
  - SECTION_3 → "Development Workflow"
  - Governance rules → defined
  - Version/date footer → set

  Templates requiring updates:
  - .specify/templates/plan-template.md ✅ (no change needed)
  - .specify/templates/spec-template.md ✅ (no change needed)
  - .specify/templates/tasks-template.md ✅ (no change needed)
  - .specify/templates/checklist-template.md ✅ (no change needed)
  - AGENTS.md ✅ (constitution reference + image name)
  - README.md ✅ (no change needed)

  Follow-up TODOs: none
-->

# ArcadeDB Use Cases Constitution

## Core Principles

### I. Standalone Demos

Each use case directory MUST be fully self-contained with zero shared
dependencies. Every use case includes its own docker-compose.yml, setup.sh,
SQL files, queries, README, and optionally Java/JS/Python modules. No use case
depends on another — independent testing, independent evolution.

### II. Canonical Layout

Every use case MUST follow the exact directory structure: docker-compose.yml,
setup.sh, sql/01-schema.sql, sql/02-data.sql, queries/queries.sh, README.md,
and optionally java/ (Maven with maven-assembly-plugin). setup.sh MUST read SQL
line-by-line, skip blanks/comments, strip trailing semicolons. queries.sh MUST
use curl + jq '.result'. Java MUST use RemoteDatabase with tryRun wrapper.
Deviations require explicit justification.

### III. HTTP API First

ArcadeDB's HTTP API is the primary integration surface. All query verification
uses curl against /api/v1/query and /api/v1/command. Java demos use
RemoteDatabase (HTTP protocol), not embedded mode. Bolt and Postgres wire
protocol are documented exceptions with explicit justification in the use case
README.

### IV. SQL Discipline

SQL files MUST contain one statement per line. Blank lines and whole-line
comments (-- at line start, optionally preceded by whitespace) are skipped by
setup.sh. Trailing semicolons are allowed and stripped by setup.sh
(`${line%%;}`). This rigor enables deterministic processing and clean diffs.

### V. CI-Gated Quality

Every use case MUST have a CI workflow with matrix runners [curl, java]. All
runners must pass. Docker Compose lifecycle (up, healthcheck, down) MUST be
managed entirely in CI. No PR merges without green CI. ArcadeDB API quirks
discovered during development MUST be documented in AGENTS.md.

## Technology Constraints

- **ArcadeDB**: 26.5.1 pinned across all use cases
- **Java**: 21 for all JVM code
- **HTTP API**: port 2480 (default)
- **Postgres wire**: port 5432 (when plugin enabled)
- **Bolt**: port 7687 (when plugin enabled)
- **Root password**: MUST be set via JAVA_OPTS
  (`-Darcadedb.server.rootPassword=arcadedb`) — env var form does not work
- **Postgres plugin**:
  `-Darcadedb.server.plugins=Postgres:com.arcadedb.postgres.PostgresProtocolPlugin`
- **Bolt plugin**: `-Darcadedb.server.plugins=BoltProtocolPlugin` (or
  comma-separated for multiple), plus
  `-Darcadedb.bolt.defaultDatabase=<DB_NAME>`
- **Healthcheck**: curl -sf http://localhost:2480/api/v1/ready, interval 5s,
  retries 20

## Development Workflow

- **Start**: `docker compose up -d`
- **Wait**: healthcheck (curl -sf /api/v1/ready)
- **Setup**: `./setup.sh` (creates DB, applies schema, seeds data)
- **Verify curl**: `./queries/queries.sh`
- **Verify Java**: `cd java && mvn package && java -jar target/<name>.jar`
- **Teardown**: `docker compose down`
- **New use case**: create directory, add all required files, verify with CI
- **Agent/Skill**: define opencode agents in .opencode/, skills via
  skill-creator pattern, commands as .specify/extensions/ markdown files

## Governance

- This constitution supersedes AGENTS.md; AGENTS.md is the derived
  quick-reference
- Amendments require: documented rationale, PR with constitution + AGENTS.md
  sync, compliance review
- New use cases MUST pass constitution compliance review before merging
- ArcadeDB API quirks discovered during development MUST be documented in
  AGENTS.md
- Constitution versioning follows semver: MAJOR for principle changes, MINOR
  for new sections, PATCH for clarifications
- Version and dates recorded in the footer line

**Version**: 1.0.1 | **Ratified**: 2026-05-22 | **Last Amended**: 2026-05-22
