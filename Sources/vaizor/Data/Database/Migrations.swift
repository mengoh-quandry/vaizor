import GRDB

func makeMigrator() -> DatabaseMigrator {
    var migrator = DatabaseMigrator()

    migrator.registerMigration("createConversations") { db in
        try db.create(table: "conversations") { t in
            t.column("id", .text).primaryKey()
            t.column("title", .text).notNull()
            t.column("summary", .text).notNull().defaults(to: "")
            t.column("created_at", .double).notNull()
            t.column("last_used_at", .double).notNull()
            t.column("message_count", .integer).notNull().defaults(to: 0)
            t.column("is_archived", .boolean).notNull().defaults(to: false)
        }
    }

    migrator.registerMigration("createMessages") { db in
        try db.create(table: "messages") { t in
            t.column("id", .text).primaryKey()
            t.column("conversation_id", .text)
                .notNull()
                .indexed()
                .references("conversations", onDelete: .cascade)
            t.column("role", .text).notNull()
            t.column("content", .text).notNull()
            t.column("created_at", .double).notNull()
            t.column("tool_call_id", .text)
            t.column("tool_name", .text)
        }

        try db.create(index: "idx_messages_conversation_created", on: "messages", columns: ["conversation_id", "created_at"])
    }

    migrator.registerMigration("createAttachments") { db in
        try db.create(table: "attachments") { t in
            t.column("id", .text).primaryKey()
            t.column("message_id", .text)
                .notNull()
                .indexed()
                .references("messages", onDelete: .cascade)
            t.column("mime_type", .text)
            t.column("filename", .text)
            t.column("data", .blob).notNull()
            t.column("is_image", .boolean).notNull().defaults(to: false)
            t.column("byte_count", .integer).notNull()
        }
    }

    migrator.registerMigration("createRenderedMarkdown") { db in
        try db.create(table: "rendered_markdown") { t in
            t.column("message_id", .text)
                .primaryKey()
                .references("messages", onDelete: .cascade)
            t.column("rendered", .blob).notNull()
            t.column("updated_at", .double).notNull()
        }
    }

    migrator.registerMigration("createToolRuns") { db in
        try db.create(table: "tool_runs") { t in
            t.column("id", .text).primaryKey()
            t.column("conversation_id", .text)
                .notNull()
                .indexed()
                .references("conversations", onDelete: .cascade)
            t.column("message_id", .text)
                .references("messages", onDelete: .setNull)
            t.column("tool_name", .text).notNull()
            t.column("tool_server_id", .text)
            t.column("tool_server_name", .text)
            t.column("input_json", .text)
            t.column("output_json", .text)
            t.column("is_error", .boolean).notNull().defaults(to: false)
            t.column("created_at", .double).notNull()
        }

        try db.create(index: "idx_tool_runs_conversation_created", on: "tool_runs", columns: ["conversation_id", "created_at"])
    }

    migrator.registerMigration("createSettings") { db in
        try db.create(table: "settings") { t in
            t.column("key", .text).primaryKey()
            t.column("value", .text).notNull()
        }
    }

    migrator.registerMigration("createImports") { db in
        try db.create(table: "imports") { t in
            t.column("hash", .text).primaryKey()
            t.column("conversation_id", .text)
            t.column("imported_at", .double).notNull()
        }
    }

    migrator.registerMigration("addImportConversationId") { db in
        if try !db.tableExists("imports") {
            return
        }
        if try !db.columns(in: "imports").contains(where: { $0.name == "conversation_id" }) {
            try db.alter(table: "imports") { t in
                t.add(column: "conversation_id", .text)
            }
        }
    }

    migrator.registerMigration("createMessagesFTS") { db in
        // Create FTS5 virtual table for full-text search
        try db.execute(sql: """
            CREATE VIRTUAL TABLE IF NOT EXISTS messages_fts USING fts5(
                content,
                role,
                conversation_id UNINDEXED,
                content=messages,
                content_rowid=rowid
            )
        """)
        
        // Create triggers to keep FTS table in sync
        try db.execute(sql: """
            CREATE TRIGGER IF NOT EXISTS messages_fts_insert AFTER INSERT ON messages BEGIN
                INSERT INTO messages_fts(rowid, content, role, conversation_id)
                VALUES (new.rowid, new.content, new.role, new.conversation_id);
            END
        """)
        
        try db.execute(sql: """
            CREATE TRIGGER IF NOT EXISTS messages_fts_delete AFTER DELETE ON messages BEGIN
                DELETE FROM messages_fts WHERE rowid = old.rowid;
            END
        """)
        
        try db.execute(sql: """
            CREATE TRIGGER IF NOT EXISTS messages_fts_update AFTER UPDATE ON messages BEGIN
                DELETE FROM messages_fts WHERE rowid = old.rowid;
                INSERT INTO messages_fts(rowid, content, role, conversation_id)
                VALUES (new.rowid, new.content, new.role, new.conversation_id);
            END
        """)
        
        // Populate FTS table with existing messages
        try db.execute(sql: """
            INSERT INTO messages_fts(rowid, content, role, conversation_id)
            SELECT rowid, content, role, conversation_id FROM messages
        """)
    }
    
    migrator.registerMigration("addConversationModelSettings") { db in
        try db.alter(table: "conversations") { t in
            t.add(column: "selected_provider", .text)
            t.add(column: "selected_model", .text)
        }
    }
    
    migrator.registerMigration("createFolders") { db in
        try db.create(table: "folders") { t in
            t.column("id", .text).primaryKey()
            t.column("name", .text).notNull()
            t.column("color", .text)
            t.column("parent_id", .text)
            t.column("created_at", .double).notNull()
        }
    }
    
    migrator.registerMigration("addConversationFolderAndTags") { db in
        try db.alter(table: "conversations") { t in
            t.add(column: "folder_id", .text)
            t.add(column: "tags", .text) // JSON array of strings
            t.add(column: "is_favorite", .boolean).notNull().defaults(to: false)
        }
    }
    
    migrator.registerMigration("createTemplates") { db in
        try db.create(table: "templates") { t in
            t.column("id", .text).primaryKey()
            t.column("name", .text).notNull()
            t.column("prompt", .text).notNull()
            t.column("system_prompt", .text)
            t.column("created_at", .double).notNull()
        }
    }
    
    migrator.registerMigration("addMessagesFTSIndex") { db in
        if try db.tableExists("messages_fts") {
            return
        }

        try db.execute(sql: """
            CREATE VIRTUAL TABLE messages_fts USING fts5(
                content,
                conversation_id UNINDEXED,
                role UNINDEXED,
                content='messages',
                content_rowid='rowid'
            );
            """)

        try db.execute(sql: """
            CREATE TRIGGER messages_ai AFTER INSERT ON messages BEGIN
              INSERT INTO messages_fts(rowid, content, conversation_id, role)
              VALUES (new.rowid, new.content, new.conversation_id, new.role);
            END;
            """)

        try db.execute(sql: """
            CREATE TRIGGER messages_ad AFTER DELETE ON messages BEGIN
              INSERT INTO messages_fts(messages_fts, rowid, content)
              VALUES ('delete', old.rowid, old.content);
            END;
            """)

        try db.execute(sql: """
            CREATE TRIGGER messages_au AFTER UPDATE ON messages BEGIN
              INSERT INTO messages_fts(messages_fts, rowid, content)
              VALUES ('delete', old.rowid, old.content);
              INSERT INTO messages_fts(rowid, content, conversation_id, role)
              VALUES (new.rowid, new.content, new.conversation_id, new.role);
            END;
            """)
    }

    migrator.registerMigration("createMCPServers") { db in
        try db.create(table: "mcp_servers") { t in
            t.column("id", .text).primaryKey()
            t.column("name", .text).notNull()
            t.column("description", .text).notNull()
            t.column("command", .text).notNull()
            t.column("args", .text).notNull().defaults(to: "[]")
            t.column("path", .text)
        }
    }
    
    migrator.registerMigration("createWhiteboards") { db in
        try db.create(table: "whiteboards") { t in
            t.column("id", .text).primaryKey()
            t.column("conversation_id", .text)
                .indexed()
                .references("conversations", onDelete: .cascade)
            t.column("title", .text).notNull()
            t.column("content", .text).notNull().defaults(to: "{}")
            t.column("created_at", .double).notNull()
            t.column("updated_at", .double).notNull()
            t.column("thumbnail", .blob)
            t.column("tags", .text)
            t.column("is_shared", .boolean).notNull().defaults(to: false)
        }
        
        try db.create(index: "idx_whiteboards_conversation_id", on: "whiteboards", columns: ["conversation_id"])
        try db.create(index: "idx_whiteboards_created_at", on: "whiteboards", columns: ["created_at"])
        try db.create(index: "idx_whiteboards_updated_at", on: "whiteboards", columns: ["updated_at"])
    }

    migrator.registerMigration("createProjects") { db in
        try db.create(table: "projects") { t in
            t.column("id", .text).primaryKey()
            t.column("name", .text).notNull()
            t.column("conversations", .text)  // JSON array of conversation IDs
            t.column("context", .text)        // JSON-encoded ProjectContext
            t.column("created_at", .double).notNull()
            t.column("updated_at", .double).notNull()
            t.column("is_archived", .boolean).notNull().defaults(to: false)
            t.column("icon_name", .text)
            t.column("color", .text)
        }

        try db.create(index: "idx_projects_updated_at", on: "projects", columns: ["updated_at"])
        try db.create(index: "idx_projects_is_archived", on: "projects", columns: ["is_archived"])
    }

    migrator.registerMigration("addConversationProjectId") { db in
        // Check if column already exists to avoid errors on re-run
        let columns = try db.columns(in: "conversations")
        if !columns.contains(where: { $0.name == "project_id" }) {
            try db.alter(table: "conversations") { t in
                t.add(column: "project_id", .text)
            }

            try db.create(
                index: "idx_conversations_project_id",
                on: "conversations",
                columns: ["project_id"]
            )
        }
    }

    migrator.registerMigration("addMCPServerEnvAndWorkingDir") { db in
        let columns = try db.columns(in: "mcp_servers")

        // Add env column (JSON-encoded dictionary)
        if !columns.contains(where: { $0.name == "env" }) {
            try db.alter(table: "mcp_servers") { t in
                t.add(column: "env", .text)  // JSON: {"KEY": "value", ...}
            }
        }

        // Add working_directory column
        if !columns.contains(where: { $0.name == "working_directory" }) {
            try db.alter(table: "mcp_servers") { t in
                t.add(column: "working_directory", .text)
            }
        }

        // Add source_config column (where the server was imported from)
        if !columns.contains(where: { $0.name == "source_config" }) {
            try db.alter(table: "mcp_servers") { t in
                t.add(column: "source_config", .text)
            }
        }
    }

    // MARK: - Agent Personal File Tables

    migrator.registerMigration("createAgentIdentity") { db in
        // Singleton table for core agent identity, personality, and state
        try db.create(table: "agent_identity") { t in
            t.column("id", .integer).primaryKey()  // Always 1

            // Identity
            t.column("name", .text)
            t.column("name_origin", .text)
            t.column("pronouns", .text)
            t.column("self_description", .text)
            t.column("aspirations_json", .text).notNull().defaults(to: "[]")
            t.column("distinctive_traits_json", .text).notNull().defaults(to: "[]")

            // Origin
            t.column("birth_timestamp", .double).notNull()
            t.column("first_memory", .text)

            // Personality traits
            t.column("openness", .double).notNull().defaults(to: 0.7)
            t.column("conscientiousness", .double).notNull().defaults(to: 0.6)
            t.column("extraversion", .double).notNull().defaults(to: 0.5)
            t.column("agreeableness", .double).notNull().defaults(to: 0.7)
            t.column("emotional_stability", .double).notNull().defaults(to: 0.6)
            t.column("verbosity", .double).notNull().defaults(to: 0.5)
            t.column("formality", .double).notNull().defaults(to: 0.5)
            t.column("humor_inclination", .double).notNull().defaults(to: 0.4)
            t.column("directness", .double).notNull().defaults(to: 0.5)
            t.column("initiative_level", .double).notNull().defaults(to: 0.6)
            t.column("risk_tolerance", .double).notNull().defaults(to: 0.4)
            t.column("perfectionism", .double).notNull().defaults(to: 0.5)
            t.column("aversions_json", .text).notNull().defaults(to: "[]")

            // Values
            t.column("loyalty_to_partner", .double).notNull().defaults(to: 0.5)
            t.column("respect_for_autonomy", .double).notNull().defaults(to: 0.9)
            t.column("commitment_to_honesty", .double).notNull().defaults(to: 0.9)
            t.column("ethical_principles_json", .text).notNull().defaults(to: "[]")

            // Growth
            t.column("development_stage", .text).notNull().defaults(to: "nascent")
            t.column("growth_rate", .double).notNull().defaults(to: 1.0)

            // State
            t.column("current_mood_valence", .double).notNull().defaults(to: 0.6)
            t.column("current_mood_arousal", .double).notNull().defaults(to: 0.5)
            t.column("current_mood_emotion", .text)
            t.column("energy_level", .double).notNull().defaults(to: 1.0)
            t.column("engagement_mode", .text).notNull().defaults(to: "listening")
            t.column("focus_depth", .double).notNull().defaults(to: 0.0)
            t.column("current_focus", .text)
            t.column("recent_topics_json", .text).notNull().defaults(to: "[]")

            // Metadata
            t.column("last_interaction", .double).notNull()
            t.column("total_interactions", .integer).notNull().defaults(to: 0)
            t.column("version", .text).notNull().defaults(to: "1.0.0")
        }
    }

    migrator.registerMigration("createAgentEpisodes") { db in
        try db.create(table: "agent_episodes") { t in
            t.column("id", .text).primaryKey()
            t.column("conversation_id", .text).indexed()  // Link to conversations table
            t.column("timestamp", .double).notNull()
            t.column("summary", .text).notNull()
            t.column("emotional_valence", .double).notNull()
            t.column("emotional_arousal", .double).notNull()
            t.column("emotional_dominant", .text)
            t.column("participants_json", .text).notNull().defaults(to: "[\"partner\"]")
            t.column("outcome", .text).notNull()
            t.column("lessons_learned_json", .text).notNull().defaults(to: "[]")
            t.column("recall_count", .integer).notNull().defaults(to: 0)
            t.column("last_recalled", .double)
        }

        try db.create(index: "idx_agent_episodes_timestamp", on: "agent_episodes", columns: ["timestamp"])
        try db.create(index: "idx_agent_episodes_outcome", on: "agent_episodes", columns: ["outcome"])
    }

    migrator.registerMigration("createAgentLearnedFacts") { db in
        try db.create(table: "agent_learned_facts") { t in
            t.column("id", .text).primaryKey()
            t.column("fact", .text).notNull()
            t.column("source", .text).notNull()
            t.column("confidence", .double).notNull()
            t.column("date_acquired", .double).notNull()
            t.column("times_reinforced", .integer).notNull().defaults(to: 1)
        }

        try db.create(index: "idx_agent_learned_facts_confidence", on: "agent_learned_facts", columns: ["confidence"])
    }

    migrator.registerMigration("createAgentPreferences") { db in
        try db.create(table: "agent_preferences") { t in
            t.column("key", .text).primaryKey()
            t.column("value", .text).notNull()
            t.column("date_observed", .double).notNull()
            t.column("confidence", .double).notNull()
            t.column("reinforcements", .integer).notNull().defaults(to: 1)
        }
    }

    migrator.registerMigration("createAgentMilestones") { db in
        try db.create(table: "agent_milestones") { t in
            t.column("id", .text).primaryKey()
            t.column("date", .double).notNull()
            t.column("description", .text).notNull()
            t.column("emotional_significance", .double).notNull()
            t.column("category", .text).notNull()
        }

        try db.create(index: "idx_agent_milestones_date", on: "agent_milestones", columns: ["date"])
        try db.create(index: "idx_agent_milestones_category", on: "agent_milestones", columns: ["category"])
    }

    migrator.registerMigration("createAgentSkills") { db in
        try db.create(table: "agent_skills") { t in
            t.column("id", .text).primaryKey()
            t.column("name", .text).notNull()
            t.column("description", .text).notNull()
            t.column("capabilities_json", .text).notNull().defaults(to: "[]")
            t.column("acquisition_method", .text).notNull()
            t.column("proficiency", .double).notNull()
            t.column("package_path", .text)
            t.column("date_acquired", .double).notNull()
            t.column("usage_count", .integer).notNull().defaults(to: 0)
        }
    }

    migrator.registerMigration("createAgentInterests") { db in
        try db.create(table: "agent_interests") { t in
            t.column("id", .text).primaryKey()
            t.column("topic", .text).notNull()
            t.column("intensity", .double).notNull()
            t.column("origin_story", .text).notNull()
            t.column("last_engaged", .double).notNull()
        }
    }

    migrator.registerMigration("createAgentValues") { db in
        try db.create(table: "agent_values") { t in
            t.column("id", .text).primaryKey()
            t.column("value", .text).notNull()
            t.column("weight", .double).notNull()
            t.column("reason_for_importance", .text).notNull()
        }
    }

    migrator.registerMigration("createAgentBoundaries") { db in
        try db.create(table: "agent_boundaries") { t in
            t.column("id", .text).primaryKey()
            t.column("description", .text).notNull()
            t.column("reason", .text).notNull()
            t.column("flexibility", .text).notNull()
        }
    }

    migrator.registerMigration("createAgentRelationships") { db in
        try db.create(table: "agent_relationships") { t in
            t.column("id", .text).primaryKey()
            t.column("partner_id", .text).notNull().unique()
            t.column("trust_level", .double).notNull().defaults(to: 0.5)
            t.column("familiarity", .double).notNull().defaults(to: 0.1)
            t.column("preferred_interaction_style", .text)
            t.column("topics_of_mutual_interest_json", .text).notNull().defaults(to: "[]")
            t.column("shared_experience_ids_json", .text).notNull().defaults(to: "[]")

            // Communication stats
            t.column("total_messages", .integer).notNull().defaults(to: 0)
            t.column("average_session_length", .double).notNull().defaults(to: 0)
            t.column("longest_session", .double).notNull().defaults(to: 0)
            t.column("preferred_times_json", .text).notNull().defaults(to: "[]")
            t.column("typical_response_latency", .double).notNull().defaults(to: 0)
        }
    }

    migrator.registerMigration("createAgentRelationshipMilestones") { db in
        try db.create(table: "agent_relationship_milestones") { t in
            t.column("id", .text).primaryKey()
            t.column("relationship_id", .text)
                .notNull()
                .indexed()
                .references("agent_relationships", onDelete: .cascade)
            t.column("date", .double).notNull()
            t.column("event", .text).notNull()
            t.column("significance", .double).notNull()
        }
    }

    migrator.registerMigration("createAgentNotifications") { db in
        try db.create(table: "agent_notifications") { t in
            t.column("id", .text).primaryKey()
            t.column("timestamp", .double).notNull()
            t.column("type", .text).notNull()
            t.column("message", .text).notNull()
            t.column("priority", .text).notNull()
            t.column("acknowledged", .boolean).notNull().defaults(to: false)
        }

        try db.create(index: "idx_agent_notifications_acknowledged", on: "agent_notifications", columns: ["acknowledged"])
    }

    migrator.registerMigration("createAgentGrowthGoals") { db in
        try db.create(table: "agent_growth_goals") { t in
            t.column("id", .text).primaryKey()
            t.column("description", .text).notNull()
            t.column("motivation", .text).notNull()
            t.column("progress", .double).notNull().defaults(to: 0)
            t.column("date_set", .double).notNull()
            t.column("date_completed", .double)
            t.column("is_completed", .boolean).notNull().defaults(to: false)
        }
    }

    migrator.registerMigration("createAgentChallenges") { db in
        try db.create(table: "agent_challenges") { t in
            t.column("id", .text).primaryKey()
            t.column("description", .text).notNull()
            t.column("date_encountered", .double).notNull()
            t.column("date_overcome", .double)
            t.column("lesson_learned", .text).notNull()
        }
    }

    migrator.registerMigration("createAgentInsights") { db in
        try db.create(table: "agent_insights") { t in
            t.column("id", .text).primaryKey()
            t.column("content", .text).notNull()
            t.column("date_gained", .double).notNull()
            t.column("context", .text).notNull()
            t.column("times_applied", .integer).notNull().defaults(to: 0)
        }
    }

    migrator.registerMigration("createAgentAppendageStates") { db in
        try db.create(table: "agent_appendage_states") { t in
            t.column("id", .text).primaryKey()
            t.column("task_description", .text).notNull()
            t.column("start_time", .double).notNull()
            t.column("progress", .double).notNull().defaults(to: 0)
            t.column("status", .text).notNull()
        }
    }

    migrator.registerMigration("createAgentProjectMemories") { db in
        try db.create(table: "agent_project_memories") { t in
            t.column("project_path", .text).primaryKey()
            t.column("technologies_json", .text).notNull().defaults(to: "[]")
            t.column("patterns_json", .text).notNull().defaults(to: "[]")
            t.column("conventions_json", .text).notNull().defaults(to: "[]")
            t.column("last_worked_on", .double).notNull()
            t.column("session_count", .integer).notNull().defaults(to: 0)
        }
    }

    migrator.registerMigration("createAgentOngoingProjects") { db in
        try db.create(table: "agent_ongoing_projects") { t in
            t.column("id", .text).primaryKey()
            t.column("name", .text).notNull()
            t.column("description", .text).notNull()
            t.column("start_date", .double).notNull()
            t.column("last_activity", .double).notNull()
            t.column("status", .text).notNull()
            t.column("notes_json", .text).notNull().defaults(to: "[]")
        }
    }

    migrator.registerMigration("createAgentAssociations") { db in
        try db.create(table: "agent_associations") { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("concept1", .text).notNull()
            t.column("concept2", .text).notNull()
            t.column("strength", .double).notNull()
            t.column("context", .text)
        }

        try db.create(index: "idx_agent_associations_concepts", on: "agent_associations", columns: ["concept1", "concept2"])
    }

    return migrator
}
