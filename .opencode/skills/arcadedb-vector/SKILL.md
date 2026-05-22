---
name: arcadedb-vector
description: "Vector similarity search in ArcadeDB. Use when working with vector embeddings, LSM_VECTOR indexes, cosine similarity, and vectorNeighbors."
---

# ArcadeDB Vector

Use this skill for vector similarity search with ArcadeDB. Covers index
creation, vector queries, and integration patterns.

## CRITICAL RULES

- `vectorDistance()` is NOT available — alternatives are `vectorNeighbors()` (index-based, returns k results) and `vectorCosineSimilarity()` (inline scalar function)
- Vector index format: `TypeName[propertyName]`
- Must create `LSM_VECTOR` index on the vector property before querying via `vectorNeighbors()`
- Vector property type must be `EMBEDDEDLIST DOUBLE` or `LIST`
- `vectorCosineSimilarity()` does NOT require an index — works on any vector property as a scalar function

## Creating Vector Indexes

```sql
-- Create vector property (LIST is used in practice; EMBEDDEDLIST DOUBLE works too)
CREATE PROPERTY Product.embedding IF NOT EXISTS LIST

-- Create LSM_VECTOR index (required for vectorNeighbors)
-- METADATA with dimensions and similarity function is required
CREATE INDEX IF NOT EXISTS ON Product (embedding) LSM_VECTOR
  METADATA { dimensions: 4, similarity: 'COSINE' }
```

## Querying with Vector Similarity

Two approaches:

**1. `vectorNeighbors()` — index-based, returns k results**

```sql
-- Find top-k nearest neighbors
SELECT FROM Product
WHERE vectorNeighbors('Product[embedding]', [0.1, 0.2, 0.3, 0.4], 5)

-- With projection (score is the similarity value)
SELECT name, category,
       vectorNeighbors('Product[embedding]', [0.1, 0.2, 0.3, 0.4], 5) AS score
FROM Product
```

**2. `vectorCosineSimilarity()` — inline scalar, works without index**

```sql
-- Score all rows by cosine similarity to the query vector
SELECT name, category,
       vectorCosineSimilarity(embedding, [0.1, 0.2, 0.3, 0.4]) AS similarity
FROM Product
ORDER BY similarity DESC

-- Filter by similarity threshold
SELECT name, category,
       vectorCosineSimilarity(embedding, [0.1, 0.2, 0.3, 0.4]) AS similarity
FROM Product
WHERE vectorCosineSimilarity(embedding, [0.1, 0.2, 0.3, 0.4]) > 0.8
```

## Reference Patterns

```sql
-- Creating sample vector data
CREATE VERTEX TYPE Product IF NOT EXISTS
CREATE PROPERTY Product.name STRING
CREATE PROPERTY Product.category STRING
CREATE PROPERTY Product.embedding IF NOT EXISTS LIST
CREATE INDEX IF NOT EXISTS ON Product (embedding) LSM_VECTOR
  METADATA { dimensions: 4, similarity: 'COSINE' }

INSERT INTO Product SET name = 'Product A', category = 'electronics',
  embedding = [0.1, 0.2, 0.3, 0.4]

INSERT INTO Product SET name = 'Product B', category = 'electronics',
  embedding = [0.15, 0.25, 0.35, 0.45]

-- Hybrid query: vector similarity + filter
SELECT FROM Product
WHERE vectorNeighbors('Product[embedding]', [0.12, 0.22, 0.32, 0.42], 5)
  AND category = 'electronics'
```

## Bolt Protocol with Vector (Java)

```java
import org.neo4j.driver.*;

try (var session = driver.session(SessionConfig.forDatabase("db"))) {
    var result = session.run(
        "CYPHER MATCH (p:Product) " +
        "WHERE vectorNeighbors('Product[embedding]', $vec, 5) " +
        "RETURN p.name, p.category ORDER BY p.name",
        parameters("vec", Arrays.asList(0.1, 0.2, 0.3, 0.4))
    );
    while (result.hasNext()) {
        System.out.println(result.next().asMap());
    }
}
```

## Known Issues

- `vectorNeighbors()` is an index-based search — it always returns exactly `k`
  results if k items exist in the index
- Vector dimension must match across all indexed records
- `vectorCosineSimilarity()` is a full-scan function — use `vectorNeighbors()` with
  `LSM_VECTOR` index for large datasets to avoid performance degradation
