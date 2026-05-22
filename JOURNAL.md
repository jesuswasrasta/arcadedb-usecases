---
journal: true
title: Diario di Lavoro
created: 2026-05-22
---

## [2026-05-23] - Miglioramento skill con apprendimenti da agent-memory

**Attività:**
- Creato nuovo skill `arcadedb-architect` con SKILL.md (workflow 7 fasi) e interview-template.md (5 fasi, 20 domande, esempi concreti, checklist vincoli, matrici decisionali VERTEX/DOCUMENT/TIMESERIES e tipi indice)
- Aggiornato `arcadedb-schema-design` con sezione "ArcadeDB SQL Limitations" (12 vincoli documentati con workaround)
- Aggiornato `arcadedb-java` con sezione "Known Quirks & Constraints" (alias obbligatori, out().property List, dynamic query, ResultSet type handling)

**Decisioni:**
- Il template dell'architect è obbligatorio prima di scrivere SQL — previene il pattern "scopri mentre codifichi" che ha causato 6+ iterazioni di fix nel solo agent-memory
- Matrici decisionali nel template (Appendix A/B) invece di testo libero: riducono ambiguità su VERTEX vs DOCUMENT vs TIMESERIES
- I vincoli ArcadeDB vanno in DUE skill: schema-design (lato DDL/SQL) e java (lato API/type system) — separation of concerns

**Appreso (sistematizzato dal use case agent-memory):**
- UNION e cross-type JOIN non supportati → template forza a chiedere "devi combinare risultati da tipi diversi?" PRIMA di scrivere query
- `NOT UNIQUE` deve essere `NOTUNQUE` — sintassi controintuitiva, ora documentata
- `format(date)` non disponibile → template chiede "come gestisci il time bucketing?" e propone weekNumber pre-computato o TIMESERIES TYPE
- `out().property` restituisce List con archi multipli → template chiede "ci saranno archi multipli dello stesso tipo?" e indirizza verso Cypher
- Alias obbligatori in Java → skill java ora lo documenta con esempi right/wrong
- Root password solo via JAVA_OPTS → template lo chiede in Phase 5 (Connectivity)

**Da ricordare:**
- L'interview template va usato come primo passo OGNI VOLTA che si progetta un nuovo use case
- I vincoli vanno tenuti aggiornati: se scopriamo una nuova limitazione, va aggiunta sia al template (checklist) sia alle skill (schema-design + java)

---

## [2026-05-23] - Implementazione use case agent-memory

**Attività:**
- Creato nuovo use case `agent-memory/` (personal assistant memory system): 8 VERTEX TYPE, 6 EDGE TYPE, 2 DOCUMENT TYPE
- Scritti e validati tutti i file: schema, seed data, docker-compose, setup.sh, queries.sh, Java, CI, README
- Validati 5 pattern di query: graph traversal (Cypher), full-text (SQL CONTAINSTEXT), time-series aggregation (SQL GROUP BY), document hybrid (due query SQL), multi-step agent (Cypher + SQL MATCH con parametri dinamici)
- Tutte le 5 query funzionano via curl E via Java RemoteDatabase API

**Decisioni:**
- CoachingSession modellato come DOCUMENT TYPE (non VERTEX), sacrificando traversabilità per semplicità
- 5 query patterns scelti per dimostrare: Cypher (traversal), SQL CONTAINSTEXT (full-text), GROUP BY (time-series), due query separate (document hybrid), multi-step con passaggio parametri dinamici
- Q5 Step 1 usa Cypher MATCH (invece di SQL `out('HAS_TAG').name` con GROUP BY) per evitare problemi di type casting List vs String in Java

**Appreso:**
- `CREATE PROPERTY` NON supporta `IF NOT EXISTS` — necessario gestire errori a livello applicativo
- `NOT UNIQUE` va scritto come `NOTUNIQUE` (parola singola) nella sintassi ArcadeDB SQL
- `UNION` non è supportato in ArcadeDB SQL; usare query separate
- Cross-join `FROM table1, table2` non è supportato; usare query separate
- `format(date, ...)` non supportato — le date sono già in formato ISO
- `out('EDGE').property` può restituire una `List` quando ci sono archi multipli, non uno `String` — nel Java RemoteDatabase API bisogna gestire il tipo dinamicamente
- In Cypher, `RETURN p.name` (senza alias) produce la chiave `p.name` (con punto), quindi in Java va acceduto come `r.getProperty("p.name")`; l'alias `AS name` risolve il problema
- Docker volume persistence: `docker compose down -v` necessario per reset pulito del database

**Correzioni applicate:**
- Q2 Java: rimosso UNION, due query separate
- Q4 Java: rimosso cross-join, due query separate
- Q5 Step 1: cambiato da SQL `out('HAS_TAG').name` a Cypher `MATCH (t:ContentTag)<-[:HAS_TAG]-(j:JournalEntry)`
- Q5 Step 2: aggiunto alias `AS name` a `p.name` nel Cypher
- Q5 Step 3: aggiunto alias `AS state` a `t.state` nel SQL MATCH

---


**Attività:**
- Creati 16 artefatti in `.opencode/`: 8 skills (`arcadedb-graphql`, `arcadedb-sql`, `arcadedb-schemasql`, `arcadedb-cypher`, `arcadedb-vector`, `arcadedb-java`, `arcadedb-compose`, `arcadedb-pgwire`), 3 agent (`arcadedb-consultant`, `arcadedb-reviewer`, `arcadedb-bolt`), 4 comandi (`arcadedb-sql-help`, `arcadedb-cypher-help`, `arcadedb-syntax`, `arcadedb-query`), 1 design plan per `.opencode/agents/README.md`
- Validati tutti i 10 use case end-to-end (curls + Java + extra) contro ArcadeDB 26.5.1 su Java 21 (Temurin), Maven 3.9.16 installato via mise
- Ogni use case: `docker compose up -d` → `./setup.sh` → queries curl → `mvn package && java -jar` → `docker compose down -v`
- Use case specifici: `graph-rag` (langchain4j/Bolt), `supply-chain` (Node.js pg), `feature-store` (Node.js pg), `iam` (Python psycopg2 + Bolt), `realtime-analytics` (Grafana sidecar su porta 3000)

**Decisioni:**
- Skills non duplicate; ogni use case che tocca più domini usa più skills in cascata
- I design plan referenziano le skills invece di duplicarne i contenuti
- Usare `vectorCosineSimilarity()` (esiste) e non `vectorDistance()` (non implementato) per similarità vettoriale inline
- Per cross-model IN subquery non supportate: multi-step approach (prima query recupera gli ID, seconda li usa hardcoded)

**Appreso:**
- `vectorDistance()` non esiste in ArcadeDB 26.5.1; `vectorCosineSimilarity()` è disponibile come scalar function
- `vectorNeighbors()` richiede indice `LSM_VECTOR` con sintassi `TypeName[propertyName]` (non `TypeName.propertyName`)
- PG wire: Python `psycopg2` gestisce alias di colonna; Node.js `pg` restituisce `undefined` per colonne aliasate
- Cypher non risolve label di tipo genitore verso sottotipi (`:Entity` non matcha `Person`)
- Bolt protocol v4 funziona con `neo4j-java-driver:6.1.0`; `Neo4jEmbeddingStore` di LangChain4j non funziona con ArcadeDB

**Correzioni applicate:**
- `arcadedb-vector` skill: documentati `vectorNeighbors()` e `vectorCosineSimilarity()`, rimosso claim su `vectorDistance()`
- Constitution `v1.0.1`: fixed contraddizione punto-e-virgola
- 6 discrepanze in `recommendation-engine`: immagine README, helper query, sintassi indice vettoriale, dipendenze Maven GraphQL

---

## [2026-05-22] - Revisione skill journal

**Attività:**
- Revisione della skill `.opencode/skills/journal/` su richiesta di Nando
- Identificati 3 problemi: `JOURNAL.md` inesistente, numerazione saltata (mancava step 2), assenza gestione first-time
- Corretto `SKILL.md`: aggiunto step 2 "Inizializza", specificato path del file, aggiunto `git add` nello step di commit

**Decisioni:**
- `JOURNAL.md` va nella root del progetto (non in `.opencode/`) per visibilità e versionamento standard
- Il frontmatter YAML è obbligatorio solo alla creazione; le entry successive lo lasciano intatto

**Appreso:**
- La skill era strutturalmente incompleta e non eseguibile senza interventi manuali — una skill deve essere auto-consistente
- Le frasi trigger vanno effettivamente usate perché il sistema le riconosca; la skill non era mai stata invocata

---
