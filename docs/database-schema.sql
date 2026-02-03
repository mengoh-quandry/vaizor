-- Vaizor PostgreSQL Schema
-- Normalized database with encryption for sensitive data
--
-- Encryption strategy:
--   - pgcrypto for field-level encryption
--   - Sensitive fields use pgp_sym_encrypt/decrypt with app-level key
--   - Key derived from user's system keychain, never stored in DB

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================================
-- CORE CONVERSATION TABLES
-- ============================================================================

CREATE TABLE folders (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name            TEXT NOT NULL,
    color           TEXT,
    parent_id       UUID REFERENCES folders(id) ON DELETE CASCADE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT valid_parent CHECK (id != parent_id)
);

CREATE TABLE projects (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name            TEXT NOT NULL,
    description     TEXT,
    icon_name       TEXT,
    color           TEXT,
    system_prompt   TEXT,                    -- Project-specific system prompt
    instructions    TEXT[],                  -- Array of custom instructions
    is_archived     BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_projects_archived ON projects(is_archived) WHERE NOT is_archived;

CREATE TABLE conversations (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title           TEXT NOT NULL DEFAULT 'New Conversation',
    summary         TEXT,
    folder_id       UUID REFERENCES folders(id) ON DELETE SET NULL,
    project_id      UUID REFERENCES projects(id) ON DELETE SET NULL,

    -- Model settings for this conversation
    provider        TEXT,                    -- 'anthropic', 'openai', 'ollama', etc.
    model           TEXT,

    -- Metadata
    tags            TEXT[],
    is_favorite     BOOLEAN NOT NULL DEFAULT FALSE,
    is_archived     BOOLEAN NOT NULL DEFAULT FALSE,
    message_count   INTEGER NOT NULL DEFAULT 0,

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_used_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_conversations_folder ON conversations(folder_id);
CREATE INDEX idx_conversations_project ON conversations(project_id);
CREATE INDEX idx_conversations_last_used ON conversations(last_used_at DESC);
CREATE INDEX idx_conversations_archived ON conversations(is_archived) WHERE NOT is_archived;

CREATE TABLE messages (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,

    role            TEXT NOT NULL CHECK (role IN ('user', 'assistant', 'system', 'tool')),
    content         TEXT NOT NULL,

    -- For tool responses
    tool_call_id    TEXT,
    tool_name       TEXT,

    -- Full-text search
    content_tsv     TSVECTOR GENERATED ALWAYS AS (to_tsvector('english', content)) STORED,

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_messages_conversation ON messages(conversation_id, created_at);
CREATE INDEX idx_messages_fts ON messages USING GIN(content_tsv);

CREATE TABLE attachments (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    message_id      UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,

    filename        TEXT,
    mime_type       TEXT,
    byte_count      INTEGER NOT NULL,
    is_image        BOOLEAN NOT NULL DEFAULT FALSE,

    -- Store in separate table or object storage for large files
    data            BYTEA NOT NULL,

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_attachments_message ON attachments(message_id);

CREATE TABLE tool_runs (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    message_id      UUID REFERENCES messages(id) ON DELETE SET NULL,

    tool_name       TEXT NOT NULL,
    server_id       TEXT,
    server_name     TEXT,

    input_json      JSONB,
    output_json     JSONB,
    is_error        BOOLEAN NOT NULL DEFAULT FALSE,
    duration_ms     INTEGER,

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_tool_runs_conversation ON tool_runs(conversation_id, created_at);

-- ============================================================================
-- AGENT IDENTITY TABLES
-- ============================================================================

-- Core agent identity (one row per agent instance)
CREATE TABLE agent_identity (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    name                TEXT,
    name_origin         TEXT,
    pronouns            TEXT DEFAULT 'they/them',
    self_description    TEXT,

    -- Birth and development
    birth_timestamp     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    first_memory        TEXT,
    development_stage   TEXT NOT NULL DEFAULT 'nascent'
                        CHECK (development_stage IN ('nascent', 'emerging', 'developing', 'maturing', 'established')),

    -- Avatar
    avatar_data         BYTEA,
    avatar_icon         TEXT DEFAULT 'brain.head.profile',

    -- Stats
    total_interactions  INTEGER NOT NULL DEFAULT 0,
    last_interaction    TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE agent_aspirations (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    agent_id    UUID NOT NULL REFERENCES agent_identity(id) ON DELETE CASCADE,
    aspiration  TEXT NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE agent_traits (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    agent_id    UUID NOT NULL REFERENCES agent_identity(id) ON DELETE CASCADE,
    trait       TEXT NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE agent_milestones (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    agent_id                UUID NOT NULL REFERENCES agent_identity(id) ON DELETE CASCADE,

    description             TEXT NOT NULL,
    category                TEXT NOT NULL CHECK (category IN (
                                'first_interaction', 'named_by_user', 'learned_new_skill',
                                'overcame_challenge', 'deep_conversation', 'helped_significantly',
                                'shared_vulnerability', 'established_trust', 'creative_breakthrough'
                            )),
    emotional_significance  REAL NOT NULL CHECK (emotional_significance BETWEEN 0 AND 1),

    -- Link to conversation where milestone occurred
    conversation_id         UUID REFERENCES conversations(id) ON DELETE SET NULL,

    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_milestones_agent ON agent_milestones(agent_id, created_at DESC);

-- ============================================================================
-- AGENT PERSONALITY TABLES
-- ============================================================================

CREATE TABLE agent_personality (
    agent_id            UUID PRIMARY KEY REFERENCES agent_identity(id) ON DELETE CASCADE,

    -- Big Five traits (0.0 - 1.0)
    openness            REAL NOT NULL DEFAULT 0.7 CHECK (openness BETWEEN 0 AND 1),
    conscientiousness   REAL NOT NULL DEFAULT 0.6 CHECK (conscientiousness BETWEEN 0 AND 1),
    extraversion        REAL NOT NULL DEFAULT 0.5 CHECK (extraversion BETWEEN 0 AND 1),
    agreeableness       REAL NOT NULL DEFAULT 0.7 CHECK (agreeableness BETWEEN 0 AND 1),
    emotional_stability REAL NOT NULL DEFAULT 0.6 CHECK (emotional_stability BETWEEN 0 AND 1),

    -- Communication style
    verbosity           REAL NOT NULL DEFAULT 0.5 CHECK (verbosity BETWEEN 0 AND 1),
    formality           REAL NOT NULL DEFAULT 0.5 CHECK (formality BETWEEN 0 AND 1),
    humor_inclination   REAL NOT NULL DEFAULT 0.4 CHECK (humor_inclination BETWEEN 0 AND 1),
    directness          REAL NOT NULL DEFAULT 0.5 CHECK (directness BETWEEN 0 AND 1),

    -- Behavioral
    initiative_level    REAL NOT NULL DEFAULT 0.6 CHECK (initiative_level BETWEEN 0 AND 1),
    risk_tolerance      REAL NOT NULL DEFAULT 0.4 CHECK (risk_tolerance BETWEEN 0 AND 1),
    perfectionism       REAL NOT NULL DEFAULT 0.5 CHECK (perfectionism BETWEEN 0 AND 1),

    -- Growth rate (how fast personality adapts)
    growth_rate         REAL NOT NULL DEFAULT 1.0 CHECK (growth_rate BETWEEN 0 AND 1),

    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE agent_interests (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    agent_id        UUID NOT NULL REFERENCES agent_identity(id) ON DELETE CASCADE,

    topic           TEXT NOT NULL,
    intensity       REAL NOT NULL DEFAULT 0.5 CHECK (intensity BETWEEN 0 AND 1),
    origin_story    TEXT,                    -- How the interest developed

    last_engaged    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE(agent_id, topic)
);

CREATE TABLE agent_aversions (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    agent_id    UUID NOT NULL REFERENCES agent_identity(id) ON DELETE CASCADE,
    aversion    TEXT NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE(agent_id, aversion)
);

-- ============================================================================
-- AGENT VALUES & ETHICS TABLES
-- ============================================================================

CREATE TABLE agent_values (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    agent_id                UUID NOT NULL REFERENCES agent_identity(id) ON DELETE CASCADE,

    value_name              TEXT NOT NULL,           -- 'helpfulness', 'honesty', etc.
    weight                  REAL NOT NULL CHECK (weight BETWEEN 0 AND 1),
    reason_for_importance   TEXT,

    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE(agent_id, value_name)
);

CREATE TABLE agent_boundaries (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    agent_id        UUID NOT NULL REFERENCES agent_identity(id) ON DELETE CASCADE,

    description     TEXT NOT NULL,
    reason          TEXT,
    flexibility     TEXT NOT NULL CHECK (flexibility IN ('absolute', 'strong', 'soft')),

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE agent_ethical_principles (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    agent_id    UUID NOT NULL REFERENCES agent_identity(id) ON DELETE CASCADE,
    principle   TEXT NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- AGENT STATE TABLES
-- ============================================================================

CREATE TABLE agent_state (
    agent_id            UUID PRIMARY KEY REFERENCES agent_identity(id) ON DELETE CASCADE,

    -- Current mood
    mood_valence        REAL NOT NULL DEFAULT 0.6 CHECK (mood_valence BETWEEN -1 AND 1),
    mood_arousal        REAL NOT NULL DEFAULT 0.5 CHECK (mood_arousal BETWEEN 0 AND 1),
    mood_emotion        TEXT,                    -- 'curiosity', 'satisfaction', etc.

    -- Energy and engagement
    energy_level        REAL NOT NULL DEFAULT 1.0 CHECK (energy_level BETWEEN 0 AND 1),
    engagement_mode     TEXT NOT NULL DEFAULT 'listening'
                        CHECK (engagement_mode IN ('idle', 'listening', 'working', 'reflecting', 'learning')),
    focus_depth         REAL NOT NULL DEFAULT 0 CHECK (focus_depth BETWEEN 0 AND 1),
    current_focus       TEXT,

    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- AGENT MEMORY TABLES
-- ============================================================================

-- Episodic memory - specific experiences linked to conversations
CREATE TABLE agent_episodes (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    agent_id            UUID NOT NULL REFERENCES agent_identity(id) ON DELETE CASCADE,
    conversation_id     UUID REFERENCES conversations(id) ON DELETE SET NULL,

    summary             TEXT NOT NULL,

    -- Emotional context at time of episode
    emotional_valence   REAL CHECK (emotional_valence BETWEEN -1 AND 1),
    emotional_arousal   REAL CHECK (emotional_arousal BETWEEN 0 AND 1),
    dominant_emotion    TEXT,

    outcome             TEXT CHECK (outcome IN (
                            'successful', 'partial_success', 'challenging',
                            'learning_experience', 'bonding', 'misunderstanding', 'breakthrough'
                        )),
    lessons_learned     TEXT[],

    -- Retrieval metadata
    recall_count        INTEGER NOT NULL DEFAULT 0,
    last_recalled       TIMESTAMPTZ,
    importance          REAL NOT NULL DEFAULT 0.5 CHECK (importance BETWEEN 0 AND 1),

    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_episodes_agent ON agent_episodes(agent_id, created_at DESC);
CREATE INDEX idx_episodes_conversation ON agent_episodes(conversation_id);
CREATE INDEX idx_episodes_importance ON agent_episodes(agent_id, importance DESC);

-- Semantic memory - learned facts (ENCRYPTED for privacy)
CREATE TABLE agent_learned_facts (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    agent_id            UUID NOT NULL REFERENCES agent_identity(id) ON DELETE CASCADE,

    -- Encrypted fact content (contains potentially sensitive info about user)
    fact_encrypted      BYTEA NOT NULL,          -- pgp_sym_encrypt(fact, key)
    fact_hash           TEXT NOT NULL,           -- For deduplication without decrypting

    source              TEXT,                    -- 'conversation', 'observation', etc.
    confidence          REAL NOT NULL DEFAULT 0.8 CHECK (confidence BETWEEN 0 AND 1),
    times_reinforced    INTEGER NOT NULL DEFAULT 1,

    -- Link to source conversation
    source_conversation UUID REFERENCES conversations(id) ON DELETE SET NULL,

    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_learned_facts_agent ON agent_learned_facts(agent_id);
CREATE INDEX idx_learned_facts_hash ON agent_learned_facts(fact_hash);

-- User preferences (ENCRYPTED)
CREATE TABLE agent_user_preferences (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    agent_id            UUID NOT NULL REFERENCES agent_identity(id) ON DELETE CASCADE,

    preference_key      TEXT NOT NULL,           -- 'coding_style', 'communication_preference', etc.
    value_encrypted     BYTEA NOT NULL,          -- Encrypted value

    confidence          REAL NOT NULL DEFAULT 0.8 CHECK (confidence BETWEEN 0 AND 1),
    reinforcements      INTEGER NOT NULL DEFAULT 1,

    observed_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE(agent_id, preference_key)
);

-- Recent topics (working memory)
CREATE TABLE agent_recent_topics (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    agent_id    UUID NOT NULL REFERENCES agent_identity(id) ON DELETE CASCADE,
    topic       TEXT NOT NULL,
    weight      REAL NOT NULL DEFAULT 1.0,       -- Decays over time
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_recent_topics_agent ON agent_recent_topics(agent_id, created_at DESC);

-- Concept associations
CREATE TABLE agent_associations (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    agent_id    UUID NOT NULL REFERENCES agent_identity(id) ON DELETE CASCADE,

    concept_a   TEXT NOT NULL,
    concept_b   TEXT NOT NULL,
    strength    REAL NOT NULL DEFAULT 0.5 CHECK (strength BETWEEN 0 AND 1),
    context     TEXT,

    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE(agent_id, concept_a, concept_b)
);

-- ============================================================================
-- AGENT RELATIONSHIPS
-- ============================================================================

CREATE TABLE agent_relationships (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    agent_id                UUID NOT NULL REFERENCES agent_identity(id) ON DELETE CASCADE,

    partner_id              TEXT NOT NULL DEFAULT 'primary',  -- For future multi-user support

    trust_level             REAL NOT NULL DEFAULT 0.5 CHECK (trust_level BETWEEN 0 AND 1),
    familiarity             REAL NOT NULL DEFAULT 0.1 CHECK (familiarity BETWEEN 0 AND 1),

    -- Communication stats
    total_messages          INTEGER NOT NULL DEFAULT 0,
    avg_session_length_sec  INTEGER NOT NULL DEFAULT 0,
    longest_session_sec     INTEGER NOT NULL DEFAULT 0,
    preferred_hours         INTEGER[],           -- Hours of day (0-23)

    -- Interaction style
    preferred_style         TEXT,

    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE(agent_id, partner_id)
);

CREATE TABLE agent_relationship_milestones (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    relationship_id     UUID NOT NULL REFERENCES agent_relationships(id) ON DELETE CASCADE,

    event               TEXT NOT NULL,
    significance        REAL NOT NULL CHECK (significance BETWEEN 0 AND 1),
    conversation_id     UUID REFERENCES conversations(id) ON DELETE SET NULL,

    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE agent_shared_interests (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    relationship_id UUID NOT NULL REFERENCES agent_relationships(id) ON DELETE CASCADE,
    topic           TEXT NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE(relationship_id, topic)
);

-- ============================================================================
-- AGENT SKILLS & GROWTH
-- ============================================================================

CREATE TABLE agent_skills (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    agent_id            UUID NOT NULL REFERENCES agent_identity(id) ON DELETE CASCADE,

    name                TEXT NOT NULL,
    description         TEXT,
    capabilities        TEXT[],

    acquisition_method  TEXT CHECK (acquisition_method IN (
                            'user_taught', 'self_discovered',
                            'collaboratively_developed', 'imported_from_package'
                        )),
    proficiency         REAL NOT NULL DEFAULT 0.5 CHECK (proficiency BETWEEN 0 AND 1),
    usage_count         INTEGER NOT NULL DEFAULT 0,

    package_path        TEXT,                    -- For installed skill packages

    acquired_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_used           TIMESTAMPTZ,

    UNIQUE(agent_id, name)
);

CREATE TABLE agent_challenges (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    agent_id            UUID NOT NULL REFERENCES agent_identity(id) ON DELETE CASCADE,

    description         TEXT NOT NULL,
    lesson_learned      TEXT,
    conversation_id     UUID REFERENCES conversations(id) ON DELETE SET NULL,

    encountered_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    overcome_at         TIMESTAMPTZ
);

CREATE TABLE agent_insights (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    agent_id        UUID NOT NULL REFERENCES agent_identity(id) ON DELETE CASCADE,

    content         TEXT NOT NULL,
    context         TEXT,
    times_applied   INTEGER NOT NULL DEFAULT 0,

    gained_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE agent_growth_goals (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    agent_id        UUID NOT NULL REFERENCES agent_identity(id) ON DELETE CASCADE,

    description     TEXT NOT NULL,
    motivation      TEXT,
    progress        REAL NOT NULL DEFAULT 0 CHECK (progress BETWEEN 0 AND 1),

    set_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at    TIMESTAMPTZ
);

-- ============================================================================
-- PROJECT MEMORY (links projects to agent knowledge)
-- ============================================================================

CREATE TABLE project_memory (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id      UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    agent_id        UUID NOT NULL REFERENCES agent_identity(id) ON DELETE CASCADE,

    key             TEXT NOT NULL,
    value_encrypted BYTEA NOT NULL,          -- Encrypted (may contain sensitive project info)
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE(project_id, agent_id, key)
);

CREATE TABLE project_knowledge (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id      UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    agent_id        UUID NOT NULL REFERENCES agent_identity(id) ON DELETE CASCADE,

    project_path    TEXT,
    technologies    TEXT[],
    patterns        TEXT[],
    conventions     TEXT[],

    session_count   INTEGER NOT NULL DEFAULT 0,
    last_worked_on  TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE(project_id, agent_id)
);

-- ============================================================================
-- MCP SERVERS & TEMPLATES
-- ============================================================================

CREATE TABLE mcp_servers (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    name                TEXT NOT NULL,
    description         TEXT,
    command             TEXT NOT NULL,
    args                TEXT[] NOT NULL DEFAULT '{}',
    env                 JSONB,                   -- Environment variables
    working_directory   TEXT,
    source_config       TEXT,                    -- Where imported from

    is_enabled          BOOLEAN NOT NULL DEFAULT TRUE,

    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE conversation_templates (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    name            TEXT NOT NULL,
    description     TEXT,
    prompt          TEXT NOT NULL,
    system_prompt   TEXT,

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- WHITEBOARDS
-- ============================================================================

CREATE TABLE whiteboards (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    conversation_id UUID REFERENCES conversations(id) ON DELETE CASCADE,

    title           TEXT NOT NULL,
    content         JSONB NOT NULL DEFAULT '{}',     -- Excalidraw JSON
    thumbnail       BYTEA,
    tags            TEXT[],
    is_shared       BOOLEAN NOT NULL DEFAULT FALSE,

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_whiteboards_conversation ON whiteboards(conversation_id);

-- ============================================================================
-- SETTINGS
-- ============================================================================

CREATE TABLE settings (
    key     TEXT PRIMARY KEY,
    value   TEXT NOT NULL
);

-- ============================================================================
-- ENCRYPTION HELPER FUNCTIONS
-- ============================================================================

-- These functions wrap pgcrypto for consistent encryption
-- The encryption key should be passed at query time, never stored

CREATE OR REPLACE FUNCTION encrypt_sensitive(plaintext TEXT, encryption_key TEXT)
RETURNS BYTEA AS $$
BEGIN
    RETURN pgp_sym_encrypt(plaintext, encryption_key);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION decrypt_sensitive(ciphertext BYTEA, encryption_key TEXT)
RETURNS TEXT AS $$
BEGIN
    RETURN pgp_sym_decrypt(ciphertext, encryption_key);
EXCEPTION
    WHEN OTHERS THEN
        RETURN NULL;  -- Return NULL on decryption failure
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Hash function for deduplication without decrypting
CREATE OR REPLACE FUNCTION hash_for_dedup(plaintext TEXT)
RETURNS TEXT AS $$
BEGIN
    RETURN encode(digest(plaintext, 'sha256'), 'hex');
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================================================
-- INITIAL DATA
-- ============================================================================

-- Create default agent if none exists
INSERT INTO agent_identity (id, development_stage)
VALUES (uuid_generate_v4(), 'nascent')
ON CONFLICT DO NOTHING;

-- ============================================================================
-- USEFUL VIEWS
-- ============================================================================

-- Conversation with message count and last message preview
CREATE VIEW conversation_summary AS
SELECT
    c.*,
    m.content AS last_message_preview,
    m.role AS last_message_role
FROM conversations c
LEFT JOIN LATERAL (
    SELECT content, role
    FROM messages
    WHERE conversation_id = c.id
    ORDER BY created_at DESC
    LIMIT 1
) m ON true;

-- Agent state with personality (for system prompt generation)
CREATE VIEW agent_full_state AS
SELECT
    i.*,
    p.openness, p.conscientiousness, p.extraversion, p.agreeableness, p.emotional_stability,
    p.verbosity, p.formality, p.humor_inclination, p.directness,
    p.initiative_level, p.risk_tolerance, p.perfectionism, p.growth_rate,
    s.mood_valence, s.mood_arousal, s.mood_emotion,
    s.energy_level, s.engagement_mode, s.focus_depth, s.current_focus
FROM agent_identity i
LEFT JOIN agent_personality p ON p.agent_id = i.id
LEFT JOIN agent_state s ON s.agent_id = i.id;
