---
name: journal
description: >
  Salva sul journal quando Nando dice "salva sul journal",
  "ricordati questo", "chiudi sessione".
---

# Journal Workflow

Il file `JOURNAL.md` si trova nella **root del progetto** (`<project-root>/JOURNAL.md`).
Serve a tracciare sessioni di lavoro, decisioni e learnings in ordine cronologico inverso.

## 1. Prepara

Se `JOURNAL.md` esiste già e ha modifiche non committate, chiedi a Nando se
committarle prima di procedere. Se preferisce non farlo, procedi comunque.
Se trovi entry fuori ordine cronologico, avvisa Nando.

## 2. Inizializza (solo prima volta)

Se `JOURNAL.md` **non esiste**, crealo con questo frontmatter YAML:

```yaml
---
journal: true
title: Diario di Lavoro
created: YYYY-MM-DD
---
```

Poi procedi al passaggio 3.

## 3. Scrivi

Aggiungi la nuova entry in **cima** a `JOURNAL.md`, subito dopo
il frontmatter YAML (ordine cronologico inverso). Non modificare
il frontmatter.

```
## [YYYY-MM-DD] - [Titolo sessione]

**Attività:**
- [cosa è stato fatto]

**Decisioni:**
- [decisioni con motivazione e impatto]

**Appreso:**
- [opzionale]

**Da ricordare:**
- [opzionale]

---
```

## 4. Committa

Staged `JOURNAL.md` con `git add JOURNAL.md` e committa con
conventional commit in italiano (es. `docs(journal): ...`).
Chiedi a Nando se vuole includere altri file.
