package com.arcadedb.examples;

import com.arcadedb.query.sql.executor.Result;
import com.arcadedb.query.sql.executor.ResultSet;
import com.arcadedb.remote.RemoteDatabase;
import java.util.ArrayList;
import java.util.List;
import java.util.stream.Collectors;

public class AgentMemory {

  private static final String HOST     = System.getenv().getOrDefault("ARCADEDB_HOST", "localhost");
  private static final int    PORT     = Integer.parseInt(System.getenv().getOrDefault("ARCADEDB_PORT", "2480"));
  private static final String DB_NAME  = "AgentMemory";
  private static final String USER     = System.getenv().getOrDefault("ARCADEDB_USER", "root");
  private static final String PASSWORD = System.getenv().getOrDefault("ARCADEDB_PASS", "arcadedb");

  public static void main(String[] args) {
    try (RemoteDatabase db = new RemoteDatabase(HOST, PORT, DB_NAME, USER, PASSWORD)) {
      tryRun(() -> runQuery1GraphTraversal(db), "Q1: Graph Traversal");
      tryRun(() -> runQuery2FullTextSearch(db), "Q2: Full-Text Search");
      tryRun(() -> runQuery3TimeSeries(db), "Q3: Time-Series Aggregation");
      tryRun(() -> runQuery4HybridQuery(db), "Q4: Document Hybrid");
      tryRun(() -> runQuery5MultiStep(db), "Q5: Multi-Step Agent");
    }
    System.out.println("\nAll queries complete.");
  }

  // ── Q1: Graph Traversal (Cypher) ─────────────────────────────────────────
  // "Who shares projects with Marco?" — traverse MENTIONS edges
  private static void runQuery1GraphTraversal(RemoteDatabase db) {
    printHeader("Q1: Graph Traversal",
        "Who shares projects with Marco Bellini? — traverse MENTIONS edges via Cypher");

    String cypher = """
        MATCH (f:Person {name: 'Marco Bellini'})-[:MENTIONS]-(j:JournalEntry)-[:MENTIONS]-(p:Person)
        WHERE p <> f
        RETURN p.name AS colleague, count(DISTINCT j) AS mentions
        ORDER BY mentions DESC""";

    try (ResultSet rs = db.query("cypher", cypher)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  %-20s | mentions: %s%n",
            r.getProperty("colleague"),
            r.getProperty("mentions"));
      }
    }
  }

  // ── Q2: Full-Text Search (SQL) ───────────────────────────────────────────
  // Search for "team" across JournalEntry and Note using CONTAINSTEXT
  // Note: UNION not available in ArcadeDB SQL, so two separate queries
  private static void runQuery2FullTextSearch(RemoteDatabase db) {
    printHeader("Q2: Full-Text Search",
        "Search for 'team' across JournalEntry and Note content");

    System.out.println("  --- JournalEntry matches ---");
    try (ResultSet rs = db.query("sql",
        "SELECT date AS ts, content FROM JournalEntry WHERE content CONTAINSTEXT 'team'")) {
      while (rs.hasNext()) {
        Result r = rs.next();
        String content = r.getProperty("content");
        System.out.printf("    %-12s | %s%n",
            r.getProperty("ts"),
            content != null ? content.substring(0, Math.min(content.length(), 70)) : "");
      }
    }

    System.out.println("  --- Note matches ---");
    try (ResultSet rs = db.query("sql",
        "SELECT createdAt AS ts, content FROM Note WHERE content CONTAINSTEXT 'team'")) {
      while (rs.hasNext()) {
        Result r = rs.next();
        String content = r.getProperty("content");
        System.out.printf("    %-12s | %s%n",
            r.getProperty("ts"),
            content != null ? content.substring(0, Math.min(content.length(), 70)) : "");
      }
    }
  }

  // ── Q3: Time-Series Aggregation (SQL) ───────────────────────────────────
  // Entries per week per emotional intensity
  private static void runQuery3TimeSeries(RemoteDatabase db) {
    printHeader("Q3: Time-Series Aggregation",
        "Entries per week per emotional intensity");

    String sql = """
        SELECT weekNumber, emotionalIntensity, count(*) AS entries
        FROM JournalEntry
        GROUP BY weekNumber, emotionalIntensity
        ORDER BY weekNumber, emotionalIntensity""";

    try (ResultSet rs = db.query("sql", sql)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("  Week %-2d | %-20s | %d entries%n",
            ((Number) r.getProperty("weekNumber")).intValue(),
            r.getProperty("emotionalIntensity"),
            ((Number) r.getProperty("entries")).intValue());
      }
    }
  }

  // ── Q4: Document Hybrid (SQL) ───────────────────────────────────────────
  // User profile + coaching sessions for a given agent
  // Note: Cross-type JOIN not supported in ArcadeDB SQL, so two queries
  private static void runQuery4HybridQuery(RemoteDatabase db) {
    printHeader("Q4: Document Hybrid Query",
        "User profile + coaching sessions for CBT Reframer");

    System.out.println("  --- User Profile ---");
    try (ResultSet rs = db.query("sql", "SELECT name, role FROM UserProfile")) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("    Name: %s (%s)%n", r.getProperty("name"), r.getProperty("role"));
      }
    }

    System.out.println("  --- Coaching Session ---");
    try (ResultSet rs = db.query("sql",
        "SELECT sessionId, date, agentPersona, questions FROM CoachingSession WHERE agentPersona = 'CBT Reframer'")) {
      while (rs.hasNext()) {
        Result r = rs.next();
        @SuppressWarnings("unchecked")
        List<String> questions = (List<String>) r.getProperty("questions");
        System.out.printf("    Session: %s on %s (agent: %s)%n",
            r.getProperty("sessionId"),
            r.getProperty("date"),
            r.getProperty("agentPersona"));
        if (questions != null) {
          for (int i = 0; i < questions.size(); i++) {
            System.out.printf("      Q%d: %s%n", i + 1, questions.get(i));
          }
        }
      }
    }
  }

  // ── Q5: Multi-Step Agent Simulation (SQL + Cypher) ──────────────────────
  // Step 1: Tag frequency (Cypher — traverses Tag <- HAS_TAG for scalar tags)
  // Step 2: People associated with top tags (Cypher)
  // Step 3: Tasks for projects of those people (SQL MATCH pattern, dynamic)
  private static void runQuery5MultiStep(RemoteDatabase db) {
    printHeader("Q5: Multi-Step Agent Simulation",
        "Tag frequency -> associated people -> tasks of their projects");

    // Step 1: Tag frequency (Cypher — gives scalar tag names per row)
    System.out.println("  --- Step 1: Tag frequency ---");
    String cypher1 = """
        MATCH (t:ContentTag)<-[:HAS_TAG]-(j:JournalEntry)
        RETURN t.name AS tag, count(j) AS freq
        ORDER BY freq DESC
        LIMIT 3""";

    List<String> topTags = new ArrayList<>();
    try (ResultSet rs = db.query("cypher", cypher1)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        String tag = r.getProperty("tag");
        Number freq = r.getProperty("freq");
        topTags.add(tag);
        System.out.printf("    %-25s | freq: %s%n", tag, freq);
      }
    }

    if (topTags.isEmpty()) {
      System.out.println("  No tags found. Skipping remaining steps.");
      return;
    }

    // Step 2: People associated with the top tag (Cypher)
    String topTag = topTags.get(0);
    System.out.printf("  --- Step 2: People associated with '%s' tag (Cypher) ---%n", topTag);
    String cypher2 = String.format("""
        MATCH (j:JournalEntry)-[:HAS_TAG]->(t:ContentTag {name: '%s'}),
              (j)-[:MENTIONS]->(p:Person)
        RETURN DISTINCT p.name AS name, count(j) AS entry_count""", topTag.replace("'", "''"));

    List<String> people = new ArrayList<>();
    try (ResultSet rs = db.query("cypher", cypher2)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        String name = r.getProperty("name");
        Number count = r.getProperty("entry_count");
        people.add(name);
        System.out.printf("    %-20s | entries: %s%n", name, count);
      }
    }

    if (people.isEmpty()) {
      System.out.println("  No people found. Skipping Step 3.");
      return;
    }

    // Step 3: Tasks for projects of those people (SQL MATCH pattern, dynamically built)
    System.out.println("  --- Step 3: Tasks for projects of those people (SQL MATCH) ---");
    String idList = people.stream()
        .map(name -> "'" + name.replace("'", "''") + "'")
        .collect(Collectors.joining(", "));
    String sql3 = String.format("""
        SELECT p.name AS person, pr.name AS project, t.content AS task, t.state AS state
        FROM (
          MATCH {type: Person, as: p, where: (name IN [%s])}
                .out('COLLABORATES_ON'){as: pr}
                .in('BELONGS_TO'){as: t}
          RETURN p, pr, t
        )""", idList);

    try (ResultSet rs = db.query("sql", sql3)) {
      while (rs.hasNext()) {
        Result r = rs.next();
        System.out.printf("    %-20s | %-40s | %-55s | %s%n",
            r.getProperty("person"),
            r.getProperty("project"),
            r.getProperty("task"),
            r.getProperty("state"));
      }
    }
  }

  // ── Utilities ──────────────────────────────────────────────────────────────
  private static void tryRun(Runnable r, String name) {
    try {
      r.run();
    } catch (Exception e) {
      System.err.println("[" + name + " FAILED] " + e.getMessage());
      e.printStackTrace();
    }
  }

  private static void printHeader(String title, String description) {
    System.out.println("\n" + "=".repeat(70));
    System.out.println("  " + title);
    System.out.println("  " + description);
    System.out.println("=".repeat(70));
  }
}
