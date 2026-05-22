---
name: arcadedb-time-series
description: "Time-series data modeling and query patterns in ArcadeDB. Use when working with time-bucketed metrics, IoT data, retention, and temporal aggregations."
---

# ArcadeDB Time Series

Use this skill for time-series data modeling, ingestion, and querying in
ArcadeDB. Covers bucketing strategies, aggregation patterns, and retention.

## CRITICAL RULES

- Use DOCUMENT TYPE for time-series metrics (no edges needed)
- Always include a timestamp property with DATETIME type
- Bucket time-series data for query performance (hourly/daily buckets)
- Index timestamp fields with RANGE index for range queries

## Schema Patterns

```sql
-- Metric point (raw)
CREATE DOCUMENT TYPE Metric IF NOT EXISTS
CREATE PROPERTY Metric.name STRING
CREATE PROPERTY Metric.value DOUBLE
CREATE PROPERTY Metric.timestamp DATETIME
CREATE PROPERTY Metric.tags EMBEDDEDMAP STRING
CREATE INDEX Metric.timestamp ON Metric (timestamp) RANGE
CREATE INDEX Metric.name ON Metric (name) NOTUNIQUE

-- Bucketed metric (pre-aggregated)
CREATE DOCUMENT TYPE MetricHourly IF NOT EXISTS
CREATE PROPERTY MetricHourly.name STRING
CREATE PROPERTY MetricHourly.bucket DATETIME
CREATE PROPERTY MetricHourly.min DOUBLE
CREATE PROPERTY MetricHourly.max DOUBLE
CREATE PROPERTY MetricHourly.avg DOUBLE
CREATE PROPERTY MetricHourly.count INTEGER
CREATE PROPERTY MetricHourly.sum DOUBLE
CREATE INDEX MetricHourly.bucket ON MetricHourly (bucket) RANGE
CREATE INDEX MetricHourly.name ON MetricHourly (name) NOTUNIQUE
```

## Inserting Time-Series Data

```sql
INSERT INTO Metric SET name = 'cpu_usage',
  value = 78.5,
  timestamp = '2024-01-15 10:30:00',
  tags = {"host": "server1", "region": "us-east"}

INSERT INTO Metric SET name = 'memory_usage',
  value = 66.2,
  timestamp = '2024-01-15 10:30:00',
  tags = {"host": "server1", "region": "us-east"}
```

## Query Patterns

```sql
-- Raw data in time range
SELECT FROM Metric
WHERE name = 'cpu_usage'
  AND timestamp BETWEEN '2024-01-15 00:00:00' AND '2024-01-15 23:59:59'
ORDER BY timestamp ASC

-- Latest value
SELECT FROM Metric
WHERE name = 'cpu_usage'
ORDER BY timestamp DESC
LIMIT 1

-- Aggregation over time range
SELECT name,
       min(value) as min_val,
       max(value) as max_val,
       avg(value) as avg_val,
       count(*) as count,
       sum(value) as sum_val
FROM Metric
WHERE name = 'cpu_usage'
  AND timestamp BETWEEN '2024-01-15 00:00:00' AND '2024-01-16 00:00:00'

-- Group by time bucket (using string formatting)
SELECT name,
       format(timestamp, 'yyyy-MM-dd HH:00') as hour,
       avg(value) as avg_val,
       count(*) as count
FROM Metric
WHERE name = 'cpu_usage'
  AND timestamp BETWEEN '2024-01-15 00:00:00' AND '2024-01-16 00:00:00'
GROUP BY name, format(timestamp, 'yyyy-MM-dd HH:00')
ORDER BY hour ASC

-- Time-series with graph context
SELECT expand(out('HAS_METRIC'))
FROM Server WHERE name = 'server1'
WHERE @class = 'Metric'
  AND name = 'cpu_usage'
  AND timestamp BETWEEN '2024-01-15 00:00:00' AND '2024-01-15 23:59:59'
ORDER BY timestamp ASC
```

## Retention Patterns

```sql
-- Delete raw data older than 30 days
DELETE FROM Metric WHERE timestamp < sysdate(-30)

-- Archive by moving to hourly buckets before deletion
-- (done application-side: query, aggregate, insert into MetricHourly, delete raw)
```

## Recommendation Engine Pattern (from repo)

```sql
-- From recommendation-engine use case
CREATE DOCUMENT TYPE Metric IF NOT EXISTS
CREATE PROPERTY Metric.name STRING
CREATE PROPERTY Metric.timestamp LONG
CREATE PROPERTY Metric.value DOUBLE
CREATE INDEX Metric.name ON Metric (name) NOTUNIQUE
CREATE INDEX Metric.timestamp ON Metric (timestamp) RANGE
```
