#!/usr/bin/env bash
# Agent-Memory — all five query patterns via curl
# Prerequisites: ArcadeDB running, setup.sh already executed, jq installed
# Usage: ./queries/queries.sh

set -euo pipefail

ARCADEDB_URL="${ARCADEDB_URL:-http://localhost:2480}"
ARCADEDB_USER="${ARCADEDB_USER:-root}"
ARCADEDB_PASS="${ARCADEDB_PASS:-arcadedb}"
AUTH="${ARCADEDB_USER}:${ARCADEDB_PASS}"
DB="AgentMemory"
QUERY_URL="${ARCADEDB_URL}/api/v1/query/${DB}"

query() {
  local lang="$1" cmd="$2"
  jq -cn --arg l "$lang" --arg c "$cmd" '{"language":$l,"command":$c}' \
    | curl -s -u "$AUTH" -X POST "$QUERY_URL" \
        -H "Content-Type: application/json" -d @- \
    | jq '.result' 2>/dev/null || echo "[]"
}

echo_hline() {
  echo "────────────────────────────────────────────────────────────────────────"
}

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Q1: Graph Traversal ==="
echo "Who shares projects with Marco? — traverse MENTIONS edges via Cypher"
echo_hline
query "cypher" "
MATCH (f:Person {name: 'Marco Bellini'})-[:MENTIONS]-(j:JournalEntry)-[:MENTIONS]-(p:Person)
WHERE p <> f
RETURN p.name AS colleague, count(DISTINCT j) AS mentions
ORDER BY mentions DESC
"
echo_hline

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Q2: Full-Text Search ==="
echo "Search for 'team' in JournalEntry and Note content (two queries, UNION not supported)"
echo_hline
echo "--- JournalEntry matches ---"
query "sql" "SELECT date AS ts, content FROM JournalEntry WHERE content CONTAINSTEXT 'team'"
echo_hline
echo "--- Note matches ---"
query "sql" "SELECT createdAt AS ts, content FROM Note WHERE content CONTAINSTEXT 'team'"
echo_hline

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Q3: Time-Series Aggregation ==="
echo "Entries per week per emotional intensity"
echo_hline
query "sql" "
SELECT weekNumber, emotionalIntensity, count(*) AS entries
FROM JournalEntry
GROUP BY weekNumber, emotionalIntensity
ORDER BY weekNumber, emotionalIntensity
"
echo_hline

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Q4: Document Hybrid Query ==="
echo "User profile + coaching sessions for CBT Reframer"
echo_hline
echo "--- User Profile ---"
query "sql" "SELECT name, role FROM UserProfile"
echo_hline
echo "--- Coaching Session ---"
query "sql" "SELECT sessionId, date, agentPersona, questions FROM CoachingSession WHERE agentPersona = 'CBT Reframer'"
echo_hline

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Q5: Multi-Step Agent Simulation ==="
echo "Step 1: Tag frequency (most used tags)"
echo_hline
query "sql" "
SELECT out('HAS_TAG').name AS tag, count(*) AS freq
FROM JournalEntry
GROUP BY tag
ORDER BY freq DESC
LIMIT 3
"
echo_hline

echo "Step 2: People associated with 'achievement' tag (Cypher)"
echo_hline
query "cypher" "
MATCH (j:JournalEntry)-[:HAS_TAG]->(t:ContentTag {name: 'achievement'}),
      (j)-[:MENTIONS]->(p:Person)
RETURN DISTINCT p.name, count(j) AS entry_count
"
echo_hline

echo "Step 3: Tasks for projects of those people (SQL pattern match)"
echo "Note: names hardcoded since cross-model IN subqueries are not supported"
echo_hline
query "sql" "
SELECT p.name AS person, pr.name AS project, t.content AS task, t.state
FROM (
  MATCH {type: Person, as: p, where: (name IN ['Marco Bellini', 'Claudio Rossi'])}
        .out('COLLABORATES_ON'){as: pr}
        .in('BELONGS_TO'){as: t}
  RETURN p, pr, t
)
"
echo_hline

echo ""
echo "All queries complete."
