# Design: ArcadeDB Agents, Skills & Commands

**Date**: 2026-05-22
**Status**: Implementing
**Language**: English (all artifacts — skills, agents, commands)
**Constitution**: `.specify/memory/constitution.md`

## Summary

Design and implement a system of composable AI agents, modular skills, and
opencode commands for working with any ArcadeDB server. The repo's 10 use
cases serve as validation targets, starting with `recommendation-engine`.

## Architecture

Three layers, each independently testable:

```
Commands (/arcadedb.*)
    ↓ invoke
Agents (compose skills)
    ↓ use
Skills (atomic capabilities)
    ↓ target
ArcadeDB Server (HTTP / Bolt / PGWire)
    ↑ validated against
Use Cases (recommendation-engine → ...)
```

### Skills

Small, focused, interchangeable — each owns one capability.

| Skill | Capability |
|-------|-----------|
| `arcadedb-provisioning` | Docker Compose lifecycle, healthcheck, setup.sh patterns |
| `arcadedb-query` | HTTP API queries via curl, RemoteDatabase, pagination |
| `arcadedb-schema-design` | Type definitions, indexes, relationships, SQL discipline |
| `arcadedb-vector` | LSM_VECTOR index, vectorNeighbors, cosine similarity |
| `arcadedb-time-series` | Time buckets, retention policies, aggregation patterns |
| `arcadedb-bolt` | Neo4j Java driver v6.1.0, Bolt protocol v4, Cypher over Bolt |
| `arcadedb-pgwire` | Postgres wire protocol, JDBC connection patterns |
| `arcadedb-java` | RemoteDatabase API, tryRun/printHeader wrappers, Maven setup |

### Agents

Compose skills by role. Each agent is an opencode subagent with specific
skill references and a system prompt tailored to its role.

- **arcadedb-architect**: schema design + provisioning + best-practice
  deployment patterns. Helps define the right ArcadeDB setup for a use case.
- **arcadedb-query-expert**: all query protocols (HTTP, Bolt, PGWire) +
  vector similarity + time-series. Specialises in data extraction.
- **arcadedb-operator**: provisioning (Docker, config) + health monitoring +
  troubleshooting. Manages server lifecycle.

### Commands

Opencode commands in `.opencode/commands/`:

| Command | Description |
|---------|-------------|
| `/arcadedb.query` | Execute SQL/Cypher against a running ArcadeDB server |
| `/arcadedb.schema` | Show, create, or compare schemas |
| `/arcadedb.provision` | Start/configure a server via Docker Compose |
| `/arcadedb.validate` | Validate a setup against repo conventions |

## Implementation Order

```
Phase 1: Skills Foundation
  - arcadedb-provisioning  (needed to spin up servers)
  - arcadedb-query         (needed to talk to servers)
  → validate on recommendation-engine curl tests

Phase 2: Domain Skills
  - arcadedb-schema-design
  - arcadedb-vector
  - arcadedb-time-series
  → validate on recommendation-engine Java queries

Phase 3: Protocol Skills
  - arcadedb-bolt
  - arcadedb-pgwire
  - arcadedb-java
  → validate on graph-rag (Bolt) + iam/supply-chain (PGWire)

Phase 4: Agents
  - arcadedb-architect
  - arcadedb-query-expert
  - arcadedb-operator
  → validate by running agent tasks against recommendation-engine

Phase 5: Commands
  - /arcadedb.query
  - /arcadedb.schema
  - /arcadedb.provision
  - /arcadedb.validate
  → validate each command end-to-end
```

## File Layout

```
.opencode/
├── skills/
│   ├── arcadedb-provisioning/SKILL.md
│   ├── arcadedb-query/SKILL.md
│   ├── arcadedb-schema-design/SKILL.md
│   ├── arcadedb-vector/SKILL.md
│   ├── arcadedb-time-series/SKILL.md
│   ├── arcadedb-bolt/SKILL.md
│   ├── arcadedb-pgwire/SKILL.md
│   └── arcadedb-java/SKILL.md
├── agents/
│   ├── arcadedb-architect.md
│   ├── arcadedb-query-expert.md
│   └── arcadedb-operator.md
└── commands/
    ├── arcadedb.query.md
    ├── arcadedb.schema.md
    ├── arcadedb.provision.md
    └── arcadedb.validate.md

docs/plans/2026-05-22-arcadedb-agents-skills-design.md  ← this file
```

## Validation Strategy

Each skill is validated by running a concrete task against
`recommendation-engine/` first, then progressively against other use cases:

1. Start server: `./arcadedb-provisioning` → `docker compose up -d`
2. Run queries: `./arcadedb-query` → execute the use case's queries.sh
3. Verify results match expected output from the use case's queries.sh

Agents are validated by executing a complete workflow:
- Architect: "Set up a graph + vector use case for product recommendations"
- Query Expert: "Find top-5 similar products using vector similarity"
- Operator: "Check server health and restart if needed"

## References

- ArcadeDB HTTP API: `/api/v1/query`, `/api/v1/command`, `/api/v1/server`
- Use case conventions documented in `AGENTS.md`
- Constitution: `.specify/memory/constitution.md`
