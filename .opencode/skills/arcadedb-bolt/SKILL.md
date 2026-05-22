---
name: arcadedb-bolt
description: "Bolt protocol connectivity with ArcadeDB. Use when connecting to ArcadeDB via the Neo4j Bolt driver for Cypher queries."
---

# ArcadeDB Bolt

Use this skill when connecting to ArcadeDB via the Bolt protocol. ArcadeDB
implements Bolt protocol v4; use Neo4j Java driver 6.1.0.

## CRITICAL RULES

- ArcadeDB implements Bolt protocol v4 (NOT v5)
- Use `neo4j-java-driver:6.1.0` (newer versions target v5 and may not work)
- Set default database via `-Darcadedb.bolt.defaultDatabase=<DB_NAME>`
- Enable Bolt: `-Darcadedb.server.plugins=BoltProtocolPlugin`
- Cypher does NOT resolve parent type labels to subtypes — `:Person` won't
  match `Employee`

## Enabling Bolt

```yaml
# docker-compose.yml
services:
  arcadedb:
    image: arcadedb/arcadedb:26.5.1
    environment:
      JAVA_OPTS: >-
        -Darcadedb.server.rootPassword=arcadedb
        -Darcadedb.server.plugins=BoltProtocolPlugin
        -Darcadedb.bolt.defaultDatabase=GraphRAG
    ports:
      - "7687:7687"
```

## Maven Dependency

```xml
<dependency>
  <groupId>org.neo4j.driver</groupId>
  <artifactId>neo4j-java-driver</artifactId>
  <version>6.1.0</version>
</dependency>
```

## Java Connection Patterns

```java
import org.neo4j.driver.*;

// Connect
var driver = GraphDatabase.driver(
    "bolt://localhost:7687",
    AuthTokens.basic("root", "arcadedb")
);

// Default database (set via config above)
try (var session = driver.session(SessionConfig.forDatabase("GraphRAG"))) {
    var result = session.run("CYPHER MATCH (n) RETURN n LIMIT 10");
    while (result.hasNext()) {
        var record = result.next();
        System.out.println(record.get("n").asMap());
    }
}

// Or specify database per session
try (var session = driver.session(SessionConfig.forDatabase("MyDB"))) {
    // queries...
}

driver.close();
```

## Cypher Queries Over Bolt

```cypher
// Match with filter
CYPHER MATCH (p:Person)
WHERE p.name = $name
RETURN p.name, p.age

// Create vertex
CYPHER CREATE (p:Person {name: $name, age: $age})

// Create edge
CYPHER MATCH (a:Person {name: $from}),
            (b:Person {name: $to})
CREATE (a)-[:FRIEND {since: $since}]->(b)

// Vector similarity (via SQL function in Cypher)
CYPHER MATCH (p:Product)
WHERE vectorNeighbors('Product[embedding]', $vec, 5)
RETURN p.name, p.category
```

## Full Example (from graph-rag use case)

```java
var driver = GraphDatabase.driver(
    "bolt://localhost:7687",
    AuthTokens.basic("root", "arcadedb")
);

try (var session = driver.session(SessionConfig.forDatabase("GraphRAG"))) {
    // Create vector index via SQL
    session.run("CREATE PROPERTY Document.embedding EMBEDDEDLIST DOUBLE");
    session.run("CREATE INDEX Document.embedding ON Document (embedding) LSM_VECTOR");

    // Insert with vector
    session.run(
        "CYPHER CREATE (d:Document {title: $title, content: $content}) " +
        "SET d.embedding = $embedding",
        parameters(
            "title", "ArcadeDB Guide",
            "content", "How to use ArcadeDB...",
            "embedding", Arrays.asList(0.1, 0.2, 0.3)
        )
    );

    // Vector search
    var result = session.run(
        "CYPHER MATCH (d:Document) " +
        "WHERE vectorNeighbors('Document[embedding]', $query, 3) " +
        "RETURN d.title, d.content",
        parameters("query", Arrays.asList(0.15, 0.25, 0.35))
    );

    while (result.hasNext()) {
        var record = result.next();
        System.out.println(record.get("d.title").asString());
    }
}
```

## Known Issues

- `Neo4jEmbeddingStore` from LangChain4j does NOT work with ArcadeDB (uses
  `SHOW VECTOR INDEX` DDL not supported by ArcadeDB)
- Bolt default database MUST be configured server-side — the driver cannot
  switch databases dynamically for the initial handshake
- Transaction auto-commit is the default; explicit transactions use
  `session.beginTransaction()`
