---
name: arcadedb-pgwire
description: "PostgreSQL wire protocol connectivity with ArcadeDB. Use when connecting to ArcadeDB via JDBC/Postgres wire protocol for SQL queries."
---

# ArcadeDB PGWire

Use this skill when connecting to ArcadeDB via the PostgreSQL wire protocol.
ArcadeDB implements the Postgres wire protocol, allowing any Postgres-compatible
client (psql, JDBC, Node.js pg, Python psycopg) to connect.

## CRITICAL RULES

- Enable Postgres plugin via `JAVA_OPTS`
- Default port is 5432 (same as PostgreSQL)
- Authentication uses ArcadeDB credentials (`root`/password)
- Database names must match ArcadeDB database names (case-sensitive)
- Not all PostgreSQL features are supported — this is the wire protocol only

## Enabling PGWire

```yaml
# docker-compose.yml
services:
  arcadedb:
    image: arcadedb/arcadedb:26.5.1
    environment:
      JAVA_OPTS: >-
        -Darcadedb.server.rootPassword=arcadedb
        -Darcadedb.server.plugins=Postgres:com.arcadedb.postgres.PostgresProtocolPlugin
    ports:
      - "5432:5432"
```

## Connection Strings

```bash
# psql
psql -h localhost -p 5432 -U root -d MyDB

# JDBC
jdbc:postgresql://localhost:5432/MyDB?user=root&password=arcadedb

# Node.js (pg)
const { Pool } = require('pg');
const pool = new Pool({
  host: 'localhost',
  port: 5432,
  user: 'root',
  password: 'arcadedb',
  database: 'MyDB'
});

# Python (psycopg)
import psycopg2
conn = psycopg2.connect(
  host='localhost',
  port=5432,
  user='root',
  password='arcadedb',
  dbname='MyDB'
)
```

## Node.js Example

```javascript
const { Pool } = require('pg');

async function main() {
  const pool = new Pool({
    host: process.env.ARCADEDB_HOST || 'localhost',
    port: parseInt(process.env.ARCADEDB_PORT || '5432'),
    user: process.env.ARCADEDB_USER || 'root',
    password: process.env.ARCADEDB_PASS || 'arcadedb',
    database: 'SupplyChain'
  });

  // Query
  const res = await pool.query(
    "SELECT FROM Supplier WHERE location CONTAINS 'China'"
  );
  console.log(JSON.stringify(res.rows, null, 2));

  // Insert
  await pool.query(
    "INSERT INTO Supplier SET name = 'Acme Corp', location = 'China'"
  );

  await pool.end();
}
```

## Python Example

```python
import psycopg2
import os

conn = psycopg2.connect(
    host=os.getenv('ARCADEDB_HOST', 'localhost'),
    port=int(os.getenv('ARCADEDB_PORT', '5432')),
    user=os.getenv('ARCADEDB_USER', 'root'),
    password=os.getenv('ARCADEDB_PASS', 'arcadedb'),
    dbname='IAM'
)
cur = conn.cursor()
cur.execute("SELECT FROM User WHERE role = 'admin'")
for row in cur.fetchall():
    print(row)
cur.close()
conn.close()
```

## SQL Over PGWire

```sql
-- ArcadeDB SQL dialect works over PGWire
SELECT FROM V LIMIT 10

-- DDL also works
CREATE VERTEX TYPE IF NOT EXISTS Product
CREATE PROPERTY Product.name STRING

-- INSERT
INSERT INTO Product SET name = 'Widget'

-- ArcadeDB-specific functions work
SELECT shortestPath(from: (SELECT FROM V LIMIT 1), to: (SELECT FROM V LIMIT 1))
```

## Known Issues

- PGWire supports ArcadeDB SQL, not PostgreSQL SQL — queries use ArcadeDB
  dialect
- `pg` Node.js library may need `pg-cursor` for large result sets
- Not all PostgreSQL client features work (e.g., prepared statements may
  behave differently)
- Transaction support follows ArcadeDB semantics, not PostgreSQL
