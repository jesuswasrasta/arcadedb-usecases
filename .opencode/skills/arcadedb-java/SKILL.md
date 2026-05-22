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
