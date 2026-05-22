-- ============================================================
-- Agent-Memory: Seed Data
-- 5 persons, 3 projects, 5 journal entries, 5 tasks, 3 notes,
-- 3 audio transcripts, 5 tags, 3 agent personas, 1 profile,
-- 2 coaching sessions, and all relationship edges
-- ============================================================

-- Persons
INSERT INTO Person SET name = 'Marco Bellini', function = 'CTO', team = 'Platform Team'
INSERT INTO Person SET name = 'Claudio Rossi', function = 'Staff Engineer', team = 'Platform Team'
INSERT INTO Person SET name = 'Paolo Fontana', function = 'Senior Developer', team = 'Product Team'
INSERT INTO Person SET name = 'Luca Villa', function = 'Tech Lead', team = 'Platform Team'
INSERT INTO Person SET name = 'Simone Bianchi', function = 'Product Manager', team = 'Product Team'

-- Projects
INSERT INTO Project SET name = 'Stratus Platform', type = 'infrastructure', status = 'active'
INSERT INTO Project SET name = 'Talk Bolzano: FP in Practice', type = 'talk', status = 'completed'
INSERT INTO Project SET name = 'Harmonia Platform Evolution', type = 'product', status = 'active'

-- Journal Entries (5)
INSERT INTO JournalEntry SET date = '2026-01-05', dayName = 'Monday', weekNumber = 2, emotionalIntensity = 'positive', content = 'Sprint planning went well. Discussed Stratus Platform migration strategy with Marco. Clear roadmap for Q1.'
INSERT INTO JournalEntry SET date = '2026-01-06', dayName = 'Tuesday', weekNumber = 2, emotionalIntensity = 'frustrated', content = 'Deep work on data migration. The legacy schema is more tangled than expected. Need to rethink the partitioning approach.'
INSERT INTO JournalEntry SET date = '2026-01-07', dayName = 'Wednesday', weekNumber = 2, emotionalIntensity = 'reflective', content = 'Had a coaching session with CBT Reframer about impostor syndrome triggered by the migration complexity. Identified cognitive distortion patterns. Useful insights about reframing challenges.'
INSERT INTO JournalEntry SET date = '2026-01-12', dayName = 'Monday', weekNumber = 3, emotionalIntensity = 'neutral', content = 'Sprint planning with Simone for Harmonia Platform. Some disagreement on prioritization but reached a compromise. Cross-team dependencies remain challenging.'
INSERT INTO JournalEntry SET date = '2026-01-14', dayName = 'Wednesday', weekNumber = 3, emotionalIntensity = 'accomplished', content = 'Breakthrough on Stratus migration! Found a clean way to handle the data partitioning using event-sourcing patterns. Claudio helped debug the edge cases.'

-- Tasks (5)
INSERT INTO Task SET content = 'Review Stratus migration PR', state = 'todo', deadline = '2026-01-20', createdAt = '2026-01-05 09:00:00'
INSERT INTO Task SET content = 'Prepare Harmonia API documentation', state = 'todo', deadline = '2026-01-25', createdAt = '2026-01-12 10:30:00'
INSERT INTO Task SET content = 'Schedule FP talk rehearsal', state = 'todo', deadline = '2026-01-18', createdAt = '2026-01-05 11:00:00'
INSERT INTO Task SET content = 'Set up CI/CD for Stratus staging', state = 'maybe', createdAt = '2026-01-06 14:00:00'
INSERT INTO Task SET content = 'Read "Functional Programming in Scala"', state = 'maybe', createdAt = '2026-01-07 20:00:00'

-- Notes (3)
INSERT INTO Note SET content = 'Event-driven architecture with Kafka and Debezium for Stratus data pipeline', type = 'learning', createdAt = '2026-01-05 15:30:00'
INSERT INTO Note SET content = 'Marco suggested using trait-based inheritance for the domain model instead of deep hierarchies', type = 'observation', createdAt = '2026-01-06 11:15:00'
INSERT INTO Note SET content = 'Explore Rust for CLI tooling — performance and safety without the GC overhead', type = 'idea', createdAt = '2026-01-12 09:45:00'

-- Audio Transcripts (3)
INSERT INTO AudioTranscript SET title = 'Morning walk brain dump', summary = 'Thoughts on Stratus partitioning strategy and team dynamics', recordedAt = '2026-01-06'
INSERT INTO AudioTranscript SET title = 'Sci-fi worldbuilding idea', summary = 'A society where memories are tradeable commodities', recordedAt = '2026-01-07'
INSERT INTO AudioTranscript SET title = 'Team Atlas retro thoughts', summary = 'Reflections on the team retro — communication improvements and process tweaks', recordedAt = '2026-01-12'

-- Content Tags (5)
INSERT INTO ContentTag SET name = 'achievement', category = 'emotional'
INSERT INTO ContentTag SET name = 'frustration', category = 'emotional'
INSERT INTO ContentTag SET name = 'learning', category = 'psychological'
INSERT INTO ContentTag SET name = 'cognitive-distortion', category = 'psychological'
INSERT INTO ContentTag SET name = 'external-frustration', category = 'situational'

-- Agent Personas (3)
INSERT INTO AgentPersona SET name = 'CBT Reframer', framework = 'Cognitive Behavioral Therapy', interactionStyle = 'Socratic'
INSERT INTO AgentPersona SET name = 'Stoic Mentor', framework = 'Stoicism', interactionStyle = 'Analytical'
INSERT INTO AgentPersona SET name = 'Pattern Analyst', framework = 'Pattern Recognition', interactionStyle = 'Analytical'

-- User Profile (document type)
INSERT INTO UserProfile SET name = 'Alessandro Riva', role = 'Staff Engineer', bigFiveOpenness = 85, bigFiveConscientiousness = 73, bigFiveExtraversion = 77, bigFiveAgreeableness = 88, bigFiveNeuroticism = 78, workingStyleSummary = 'Strategic thinker, social pattern recognition, needs external structure for execution'

-- Coaching Sessions (document type)
INSERT INTO CoachingSession SET sessionId = '2026-01-07-cbt-reframer', date = '2026-01-07', agentPersona = 'CBT Reframer', questions = ['Why do I feel like a fraud when facing complex migrations?', 'What evidence contradicts the belief that I am not competent enough?'], insights = ['Identified impostor syndrome triggered by novel situations outside expertise comfort zone', 'Reframed the migration complexity as a learning opportunity rather than a competence test']
INSERT INTO CoachingSession SET sessionId = '2026-01-05-stoic-mentor', date = '2026-01-05', agentPersona = 'Stoic Mentor', questions = ['How do I handle the frustration of cross-team dependencies slowing us down?', 'What is within my control in this situation?'], insights = ['Only our response to delays is within our control — the dependencies themselves are indifferent', 'Use the delay as an opportunity to deepen platform documentation and prepare for the next sprint']

-- ============================================================
-- EDGES
-- ============================================================

-- COLLABORATES_ON: Person → Project (4 edges)
CREATE EDGE COLLABORATES_ON FROM (SELECT FROM Person WHERE name = 'Marco Bellini') TO (SELECT FROM Project WHERE name = 'Stratus Platform')
CREATE EDGE COLLABORATES_ON FROM (SELECT FROM Person WHERE name = 'Claudio Rossi') TO (SELECT FROM Project WHERE name = 'Stratus Platform')
CREATE EDGE COLLABORATES_ON FROM (SELECT FROM Person WHERE name = 'Luca Villa') TO (SELECT FROM Project WHERE name = 'Stratus Platform')
CREATE EDGE COLLABORATES_ON FROM (SELECT FROM Person WHERE name = 'Simone Bianchi') TO (SELECT FROM Project WHERE name = 'Harmonia Platform Evolution')

-- MENTIONS: JournalEntry → Person/Project/Task (11 edges)
CREATE EDGE MENTIONS FROM (SELECT FROM JournalEntry WHERE date = '2026-01-05') TO (SELECT FROM Person WHERE name = 'Marco Bellini')
CREATE EDGE MENTIONS FROM (SELECT FROM JournalEntry WHERE date = '2026-01-05') TO (SELECT FROM Project WHERE name = 'Stratus Platform')
CREATE EDGE MENTIONS FROM (SELECT FROM JournalEntry WHERE date = '2026-01-06') TO (SELECT FROM Project WHERE name = 'Stratus Platform')
CREATE EDGE MENTIONS FROM (SELECT FROM JournalEntry WHERE date = '2026-01-07') TO (SELECT FROM Person WHERE name = 'Claudio Rossi')
CREATE EDGE MENTIONS FROM (SELECT FROM JournalEntry WHERE date = '2026-01-07') TO (SELECT FROM Project WHERE name = 'Stratus Platform')
CREATE EDGE MENTIONS FROM (SELECT FROM JournalEntry WHERE date = '2026-01-07') TO (SELECT FROM Task WHERE content LIKE 'Read "Functional Programming in Scala"%')
CREATE EDGE MENTIONS FROM (SELECT FROM JournalEntry WHERE date = '2026-01-12') TO (SELECT FROM Person WHERE name = 'Simone Bianchi')
CREATE EDGE MENTIONS FROM (SELECT FROM JournalEntry WHERE date = '2026-01-12') TO (SELECT FROM Project WHERE name = 'Harmonia Platform Evolution')
CREATE EDGE MENTIONS FROM (SELECT FROM JournalEntry WHERE date = '2026-01-14') TO (SELECT FROM Person WHERE name = 'Marco Bellini')
CREATE EDGE MENTIONS FROM (SELECT FROM JournalEntry WHERE date = '2026-01-14') TO (SELECT FROM Person WHERE name = 'Claudio Rossi')
CREATE EDGE MENTIONS FROM (SELECT FROM JournalEntry WHERE date = '2026-01-14') TO (SELECT FROM Project WHERE name = 'Stratus Platform')

-- HAS_TAG: JournalEntry → ContentTag (6 edges)
CREATE EDGE HAS_TAG FROM (SELECT FROM JournalEntry WHERE date = '2026-01-05') TO (SELECT FROM ContentTag WHERE name = 'achievement')
CREATE EDGE HAS_TAG FROM (SELECT FROM JournalEntry WHERE date = '2026-01-06') TO (SELECT FROM ContentTag WHERE name = 'frustration')
CREATE EDGE HAS_TAG FROM (SELECT FROM JournalEntry WHERE date = '2026-01-07') TO (SELECT FROM ContentTag WHERE name = 'learning')
CREATE EDGE HAS_TAG FROM (SELECT FROM JournalEntry WHERE date = '2026-01-07') TO (SELECT FROM ContentTag WHERE name = 'cognitive-distortion')
CREATE EDGE HAS_TAG FROM (SELECT FROM JournalEntry WHERE date = '2026-01-12') TO (SELECT FROM ContentTag WHERE name = 'external-frustration')
CREATE EDGE HAS_TAG FROM (SELECT FROM JournalEntry WHERE date = '2026-01-14') TO (SELECT FROM ContentTag WHERE name = 'achievement')

-- BELONGS_TO: Task → Project (4 edges)
CREATE EDGE BELONGS_TO FROM (SELECT FROM Task WHERE content LIKE 'Review Stratus migration PR%') TO (SELECT FROM Project WHERE name = 'Stratus Platform')
CREATE EDGE BELONGS_TO FROM (SELECT FROM Task WHERE content LIKE 'Prepare Harmonia API documentation%') TO (SELECT FROM Project WHERE name = 'Harmonia Platform Evolution')
CREATE EDGE BELONGS_TO FROM (SELECT FROM Task WHERE content LIKE 'Schedule FP talk rehearsal%') TO (SELECT FROM Project WHERE name = 'Talk Bolzano: FP in Practice')
CREATE EDGE BELONGS_TO FROM (SELECT FROM Task WHERE content LIKE 'Set up CI/CD for Stratus staging%') TO (SELECT FROM Project WHERE name = 'Stratus Platform')

-- RECORDED_DURING: AudioTranscript → JournalEntry (3 edges)
CREATE EDGE RECORDED_DURING FROM (SELECT FROM AudioTranscript WHERE title = 'Morning walk brain dump') TO (SELECT FROM JournalEntry WHERE date = '2026-01-06')
CREATE EDGE RECORDED_DURING FROM (SELECT FROM AudioTranscript WHERE title = 'Sci-fi worldbuilding idea') TO (SELECT FROM JournalEntry WHERE date = '2026-01-07')
CREATE EDGE RECORDED_DURING FROM (SELECT FROM AudioTranscript WHERE title = 'Team Atlas retro thoughts') TO (SELECT FROM JournalEntry WHERE date = '2026-01-12')

-- REFERENCES: Note → Person/Project (3 edges)
CREATE EDGE REFERENCES FROM (SELECT FROM Note WHERE content LIKE 'Event-driven architecture with Kafka%') TO (SELECT FROM Person WHERE name = 'Marco Bellini')
CREATE EDGE REFERENCES FROM (SELECT FROM Note WHERE content LIKE 'Event-driven architecture with Kafka%') TO (SELECT FROM Project WHERE name = 'Stratus Platform')
CREATE EDGE REFERENCES FROM (SELECT FROM Note WHERE content LIKE 'Marco suggested using trait-based inheritance%') TO (SELECT FROM Person WHERE name = 'Marco Bellini')
