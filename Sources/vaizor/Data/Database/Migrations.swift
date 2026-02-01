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

    return migrator
}
