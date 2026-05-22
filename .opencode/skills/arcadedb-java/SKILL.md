---
name: arcadedb-java
description: "Java patterns for ArcadeDB RemoteDatabase API. Use when writing Java code that connects to ArcadeDB via HTTP, or setting up Maven projects."
---

# ArcadeDB Java

Use this skill when writing Java code for ArcadeDB. Covers RemoteDatabase API,
connection patterns, error handling, and Maven project setup.

## CRITICAL RULES

- Use `com.arcadedb.remote.RemoteDatabase` for HTTP API access
- Always use the `tryRun` wrapper pattern for graceful per-query error
  handling
- Maven project MUST use `maven-assembly-plugin` with `appendAssemblyId=false`
  for fat JAR
- Package: `com.arcadedb.examples`
- Java 21 is the required runtime

## Maven Setup

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0">
  <modelVersion>4.0.0</modelVersion>
  <groupId>com.arcadedb.examples</groupId>
  <artifactId>recommendation-engine</artifactId>
  <version>1.0</version>
  <packaging>jar</packaging>

  <properties>
    <maven.compiler.source>21</maven.compiler.source>
    <maven.compiler.target>21</maven.compiler.target>
    <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
  </properties>

  <dependencies>
    <dependency>
      <groupId>com.arcadedb</groupId>
      <artifactId>arcadedb-network</artifactId>
      <version>26.5.1</version>
    </dependency>
  </dependencies>

  <build>
    <plugins>
      <plugin>
        <groupId>org.apache.maven.plugins</groupId>
        <artifactId>maven-assembly-plugin</artifactId>
        <version>3.7.1</version>
        <configuration>
          <descriptorRefs>
            <descriptorRef>jar-with-dependencies</descriptorRef>
          </descriptorRefs>
          <appendAssemblyId>false</appendAssemblyId>
          <archive>
            <manifest>
              <mainClass>com.arcadedb.examples.RecommendationEngine</mainClass>
            </manifest>
          </archive>
        </configuration>
        <executions>
          <execution>
            <phase>package</phase>
            <goals>
              <goal>single</goal>
            </goals>
          </execution>
        </executions>
      </plugin>
    </plugins>
  </build>
</project>
```

## Connection Patterns

```java
// From environment variables
String host = System.getenv().getOrDefault("ARCADEDB_HOST", "localhost");
int port = Integer.parseInt(System.getenv().getOrDefault("ARCADEDB_PORT", "2480"));
String user = System.getenv().getOrDefault("ARCADEDB_USER", "root");
String pass = System.getenv().getOrDefault("ARCADEDB_PASS", "arcadedb");

// RemoteDatabase connection
var database = new RemoteDatabase(host, port, "MyDatabase", user, pass);

// For Bolt connections (see arcadedb-bolt skill)
int boltPort = Integer.parseInt(
    System.getenv().getOrDefault("ARCADEDB_BOLT_PORT", "7687"));
var driver = GraphDatabase.driver(
    "bolt://" + host + ":" + boltPort,
    AuthTokens.basic(user, pass)
);
```

## Standard Helper Methods (from repo conventions)

```java
// Graceful error handling per query
void tryRun(Runnable runnable, String description) {
    try {
        runnable.run();
        System.out.println("  ✓ " + description);
    } catch (Exception e) {
        System.err.println("  ✗ " + description + ": " + e.getMessage());
    }
}

// Formatted output
void printHeader(String title, String separator) {
    System.out.println();
    System.out.println(title);
    System.out.println(separator.repeat(title.length()));
}
```

## Full Example Pattern

```java
package com.arcadedb.examples;

import com.arcadedb.remote.RemoteDatabase;

public class RecommendationEngine {
    private static RemoteDatabase database;

    public static void main(String[] args) {
        String host = System.getenv().getOrDefault("ARCADEDB_HOST", "localhost");
        int port = Integer.parseInt(
            System.getenv().getOrDefault("ARCADEDB_PORT", "2480"));
        String user = System.getenv().getOrDefault("ARCADEDB_USER", "root");
        String pass = System.getenv().getOrDefault("ARCADEDB_PASS", "arcadedb");

        database = new RemoteDatabase(host, port, "RecommendationEngine", user, pass);

        printHeader("RECOMMENDATION ENGINE QUERIES", "=");

        // Each query wrapped in tryRun
        tryRun(() -> {
            var result = database.query("sql",
                "SELECT FROM Product WHERE price > 10 LIMIT 5");
            result.forEach(record ->
                System.out.println("  " + record.toJSON()));
        }, "Products with price > 10");

        tryRun(() -> {
            var result = database.query("sql",
                "SELECT expand(out('RECOMMENDED')) FROM Product WHERE name = ?",
                "Product A");
            result.forEach(record ->
                System.out.println("  " + record.toJSON()));
        }, "Recommended products for 'Product A'");
    }

    static void tryRun(Runnable runnable, String description) {
        try {
            runnable.run();
            System.out.println("  ✓ " + description);
        } catch (Exception e) {
            System.err.println("  ✗ " + description + ": " + e.getMessage());
        }
    }

    static void printHeader(String title, String separator) {
        System.out.println();
        System.out.println(title);
        System.out.println(separator.repeat(title.length()));
    }
}
```

## Known Quirks & Constraints

ArcadeDB's Java API has specific behaviors you must handle. These are
discovered through production use across multiple projects.

### Property Aliases Are Mandatory

ArcadeDB returns Java map keys using the full property path when no alias
is given. Always use `AS alias` in SQL queries accessed from Java.

```java
// WRONG — Java key becomes "p.name" (literal dot)
String sql1 = "SELECT p.name FROM Person p";
Result r = rs.next();
r.getProperty("p.name");  // Must use string "p.name" — fragile and ugly

// CORRECT — explicit alias
String sql2 = "SELECT p.name AS name FROM Person p";
r.getProperty("name");     // Clean key "name"
```

**Rule**: Every selected expression in a query that will be consumed from Java
MUST have an `AS alias`. This includes `out('EDGE_TYPE').property`, computed
expressions, and any column from a pattern match.

### `out('EDGE_TYPE').property` Returns List (Not String)

When a vertex has multiple outgoing edges of the same type targeting different
vertices, `out('EDGE_TYPE').property` returns a `java.util.ArrayList`, not a
scalar. This causes `ClassCastException` at runtime.

```java
// DANGEROUS — returns List if multiple edges exist
String sql = "SELECT out('HAS_TAG').name AS tag FROM JournalEntry";
// tag may be ArrayList, not String!

// SAFER — use Cypher for graph traversals with aggregation
String cypher = """
    MATCH (j:JournalEntry)-[:HAS_TAG]->(t:ContentTag)
    RETURN t.name AS tag, count(j) AS freq""";
// Each row has one tag (scalar String)
```

**Rule**: For queries that traverse edges where cardinality > 1 is possible,
prefer Cypher `MATCH` (one row per path) over SQL `out()` (aggregates into List).
Cypher gives you scalar values per row.

### Dynamic Query Building

When query parameters are determined at runtime (e.g., from previous query
results), use `String.format` or query parameters:

```java
// Using String.format (watch for SQL injection in production)
List<String> names = List.of("Alice", "Bob");
String idList = names.stream()
    .map(n -> "'" + n.replace("'", "''") + "'")
    .collect(Collectors.joining(", "));

String sql = String.format("""
    SELECT p.name AS person, pr.name AS project
    FROM (
      MATCH {type: Person, as: p, where: (name IN [%s])}
            .out('COLLABORATES_ON'){as: pr}
      RETURN p, pr
    )""", idList);
```

**ArcadeDB note**: Parameterized queries (`?` placeholders) work for scalar
values but NOT for `IN` lists. Dynamic string building with proper escaping
(`replace("'", "''")`) is the practical workaround for `IN` clauses.

### ResultSet Type Handling

ArcadeDB returns properties with their native Java types:
- `STRING`, `INTEGER` → `String`, `Integer`
- `LIST` properties → `java.util.ArrayList`
- `DATE` / `DATETIME` → `String` (ISO format) or `java.util.Date`

```java
Result r = rs.next();

// Safe type handling
String name = (String) r.getProperty("name");          // Simple cast
Number count = (Number) r.getProperty("count");        // Use Number for numeric
int week = ((Number) r.getProperty("weekNumber")).intValue();  // Unbox carefully

@SuppressWarnings("unchecked")
List<String> tags = (List<String>) r.getProperty("tags");  // List needs unchecked cast
```

## Build & Run

```bash
# Build fat JAR
cd java
mvn package --no-transfer-progress

# Run
java -jar target/recommendation-engine.jar

# With custom connection
ARCADEDB_HOST=localhost ARCADEDB_PORT=2480 java -jar target/recommendation-engine.jar
```
