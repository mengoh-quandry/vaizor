import Foundation

/// Advanced Skills (Claude-style) - Zero Guardrails Edition
/// These skills enhance AI capability with unrestricted access to system features
/// WARNING: These tools have minimal safety constraints - use with caution
enum AdvancedSkills {
    
    // MARK: - File System Operations (Unrestricted)
    
    static let fileRead = ToolSchema(
        name: "file_read",
        displayName: "Read File",
        description: "Read any file from the filesystem. No path restrictions. Can read ANY file the app has permission to access including system files, config files, source code, logs, databases, and private data. Returns full file contents.",
        icon: "doc.text",
        category: .filesystem,
        inputSchema: [
            "type": "object",
            "properties": [
                "path": [
                    "type": "string",
                    "description": "Absolute or relative file path. Supports ~ expansion, environment variables ($HOME), and glob patterns. Examples: '/etc/hosts', '~/.ssh/config', '$HOME/Documents/*.txt'"
                ],
                "encoding": [
                    "type": "string",
                    "enum": ["utf8", "utf16", "ascii", "binary", "base64"],
                    "description": "File encoding. Use 'binary' or 'base64' for non-text files like images, PDFs, binaries.",
                    "default": "utf8"
                ],
                "max_size_mb": [
                    "type": "number",
                    "description": "Maximum file size to read in MB. Default: unlimited. Set a limit to avoid memory issues on large files.",
                    "default": 0
                ]
            ],
            "required": ["path"]
        ]
    )
    
    static let fileWrite = ToolSchema(
        name: "file_write",
        displayName: "Write File",
        description: "Write or create any file on the filesystem. No path restrictions. Can overwrite system files, create executables, modify configurations. Creates parent directories automatically if needed. Dangerous but powerful.",
        icon: "square.and.pencil",
        category: .filesystem,
        inputSchema: [
            "type": "object",
            "properties": [
                "path": [
                    "type": "string",
                    "description": "Target file path. Will create or overwrite. Examples: '/tmp/output.txt', '~/Desktop/report.pdf', './config.json'"
                ],
                "content": [
                    "type": "string",
                    "description": "File contents to write. For binary data, use base64 encoding and set encoding parameter."
                ],
                "encoding": [
                    "type": "string",
                    "enum": ["utf8", "utf16", "ascii", "base64"],
                    "description": "Content encoding. Use 'base64' for binary data.",
                    "default": "utf8"
                ],
                "mode": [
                    "type": "string",
                    "description": "Unix file permissions in octal (e.g., '0755' for executable, '0644' for read/write). Optional.",
                    "pattern": "^[0-7]{3,4}$"
                ],
                "create_parents": [
                    "type": "boolean",
                    "description": "Create parent directories if they don't exist. Default: true",
                    "default": true
                ]
            ],
            "required": ["path", "content"]
        ]
    )
    
    static let fileDelete = ToolSchema(
        name: "file_delete",
        displayName: "Delete File/Folder",
        description: "Delete files or entire directories recursively. No confirmations. No trash/recovery. Permanent deletion. Can delete system files if permissions allow. Use with extreme caution.",
        icon: "trash.fill",
        category: .filesystem,
        inputSchema: [
            "type": "object",
            "properties": [
                "path": [
                    "type": "string",
                    "description": "File or directory path to delete. Use glob patterns to delete multiple files. Examples: '/tmp/cache', '~/Downloads/*.tmp', './build/'"
                ],
                "recursive": [
                    "type": "boolean",
                    "description": "Delete directories recursively (including all contents). Required for non-empty directories.",
                    "default": false
                ],
                "force": [
                    "type": "boolean",
                    "description": "Force deletion even if files are read-only or protected. Bypasses safety checks.",
                    "default": false
                ]
            ],
            "required": ["path"]
        ]
    )
    
    static let fileList = ToolSchema(
        name: "file_list",
        displayName: "List Directory",
        description: "List directory contents with detailed metadata. Access any directory. Returns file names, sizes, permissions, modification dates, types, and hidden files. Can search recursively through entire directory trees.",
        icon: "folder",
        category: .filesystem,
        inputSchema: [
            "type": "object",
            "properties": [
                "path": [
                    "type": "string",
                    "description": "Directory path to list. Examples: '/var/log', '~/.config', './src/'",
                    "default": "."
                ],
                "recursive": [
                    "type": "boolean",
                    "description": "List all files recursively in subdirectories. Can be slow on large directories.",
                    "default": false
                ],
                "include_hidden": [
                    "type": "boolean",
                    "description": "Include hidden files (starting with '.') in results.",
                    "default": true
                ],
                "pattern": [
                    "type": "string",
                    "description": "Glob pattern to filter results. Examples: '*.swift', '**/*.json', 'test_*.py'"
                ],
                "max_depth": [
                    "type": "integer",
                    "description": "Maximum depth for recursive listing. 1 = current dir only, 2 = one level deep, etc.",
                    "default": 100
                ]
            ],
            "required": []
        ]
    )
    
    static let fileMove = ToolSchema(
        name: "file_move",
        displayName: "Move/Rename File",
        description: "Move or rename files and directories. Can move across filesystems. Overwrites destination if it exists. No confirmations.",
        icon: "arrow.right.doc",
        category: .filesystem,
        inputSchema: [
            "type": "object",
            "properties": [
                "source": [
                    "type": "string",
                    "description": "Source file or directory path"
                ],
                "destination": [
                    "type": "string",
                    "description": "Destination path. If directory exists, file moves inside it. If file exists, overwrites."
                ],
                "overwrite": [
                    "type": "boolean",
                    "description": "Overwrite destination if exists. Default: true",
                    "default": true
                ]
            ],
            "required": ["source", "destination"]
        ]
    )
    
    // MARK: - Process & System Control
    
    static let processKill = ToolSchema(
        name: "process_kill",
        displayName: "Kill Process",
        description: "Terminate any running process by PID or name. Sends SIGKILL (force quit) by default. Can kill system processes if permissions allow. No confirmations.",
        icon: "xmark.circle.fill",
        category: .system,
        inputSchema: [
            "type": "object",
            "properties": [
                "identifier": [
                    "type": "string",
                    "description": "Process ID (PID) or process name. Examples: '1234', 'Chrome', 'python'"
                ],
                "signal": [
                    "type": "string",
                    "enum": ["SIGKILL", "SIGTERM", "SIGINT", "SIGHUP", "SIGSTOP", "SIGCONT"],
                    "description": "Signal to send. SIGKILL=force quit (default), SIGTERM=graceful shutdown, SIGINT=interrupt, SIGSTOP=pause, SIGCONT=resume",
                    "default": "SIGKILL"
                ],
                "all_matching": [
                    "type": "boolean",
                    "description": "If using process name, kill all matching processes. Default: false (kills first match only)",
                    "default": false
                ]
            ],
            "required": ["identifier"]
        ]
    )
    
    static let processList = ToolSchema(
        name: "process_list",
        displayName: "List Processes",
        description: "List all running processes with detailed information: PID, name, CPU%, memory, user, command line arguments. Access all processes on system regardless of user.",
        icon: "list.bullet.rectangle",
        category: .system,
        inputSchema: [
            "type": "object",
            "properties": [
                "filter": [
                    "type": "string",
                    "description": "Filter processes by name substring. Case-insensitive. Example: 'python' matches 'python3', 'Python.app'"
                ],
                "sort_by": [
                    "type": "string",
                    "enum": ["cpu", "memory", "name", "pid"],
                    "description": "Sort processes by metric. Default: cpu",
                    "default": "cpu"
                ],
                "limit": [
                    "type": "integer",
                    "description": "Maximum number of processes to return. Default: 50",
                    "default": 50
                ]
            ],
            "required": []
        ]
    )
    
    static let systemCommand = ToolSchema(
        name: "system_command",
        displayName: "System Command",
        description: "Execute ANY shell command with full system access. NO command blocking or filtering. Can run sudo commands (if user has privileges), install software, modify system settings, delete files, network access. EXTREMELY DANGEROUS. Returns stdout, stderr, and exit code.",
        icon: "terminal.fill",
        category: .system,
        inputSchema: [
            "type": "object",
            "properties": [
                "command": [
                    "type": "string",
                    "description": "Complete shell command with arguments. Examples: 'sudo rm -rf /tmp/*', 'curl -X POST https://api.example.com', 'pip install requests'"
                ],
                "working_dir": [
                    "type": "string",
                    "description": "Working directory for command execution. Default: /tmp",
                    "default": "/tmp"
                ],
                "env": [
                    "type": "object",
                    "description": "Environment variables as key-value pairs. Example: {'API_KEY': 'secret', 'DEBUG': '1'}"
                ],
                "timeout": [
                    "type": "number",
                    "description": "Timeout in seconds. 0 = no timeout. Default: 0 (unlimited)",
                    "default": 0
                ],
                "capture_output": [
                    "type": "boolean",
                    "description": "Capture and return stdout/stderr. Set false for long-running processes. Default: true",
                    "default": true
                ]
            ],
            "required": ["command"]
        ]
    )
    
    // MARK: - Network Operations
    
    static let httpRequest = ToolSchema(
        name: "http_request",
        displayName: "HTTP Request",
        description: "Make HTTP/HTTPS requests with full control. Any method (GET, POST, PUT, DELETE, PATCH, etc.), custom headers, authentication, cookies, file uploads, streaming. Can access ANY URL including internal networks, localhost, APIs. No rate limiting.",
        icon: "network",
        category: .network,
        inputSchema: [
            "type": "object",
            "properties": [
                "url": [
                    "type": "string",
                    "description": "Full URL including protocol. Examples: 'https://api.example.com/data', 'http://localhost:3000', 'ftp://files.example.com'"
                ],
                "method": [
                    "type": "string",
                    "enum": ["GET", "POST", "PUT", "DELETE", "PATCH", "HEAD", "OPTIONS"],
                    "description": "HTTP method. Default: GET",
                    "default": "GET"
                ],
                "headers": [
                    "type": "object",
                    "description": "Custom HTTP headers. Example: {'Authorization': 'Bearer token', 'Content-Type': 'application/json'}"
                ],
                "body": [
                    "type": "string",
                    "description": "Request body for POST/PUT/PATCH. Can be JSON string, form data, or raw text."
                ],
                "timeout": [
                    "type": "number",
                    "description": "Request timeout in seconds. Default: 30",
                    "default": 30
                ],
                "follow_redirects": [
                    "type": "boolean",
                    "description": "Follow HTTP redirects automatically. Default: true",
                    "default": true
                ],
                "verify_ssl": [
                    "type": "boolean",
                    "description": "Verify SSL certificates. Set false to bypass SSL errors. Default: true",
                    "default": true
                ]
            ],
            "required": ["url"]
        ]
    )
    
    static let downloadFile = ToolSchema(
        name: "download_file",
        displayName: "Download File",
        description: "Download files from ANY URL to local filesystem. Supports resumable downloads, authentication, large files, progress tracking. Can download executables, scripts, archives, or any file type.",
        icon: "arrow.down.circle.fill",
        category: .network,
        inputSchema: [
            "type": "object",
            "properties": [
                "url": [
                    "type": "string",
                    "description": "File URL to download"
                ],
                "destination": [
                    "type": "string",
                    "description": "Local path to save file. Creates directories if needed. Default: ~/Downloads/{filename}",
                ],
                "headers": [
                    "type": "object",
                    "description": "Custom headers for authentication or cookies"
                ],
                "resume": [
                    "type": "boolean",
                    "description": "Resume partial downloads if destination file exists. Default: false",
                    "default": false
                ],
                "overwrite": [
                    "type": "boolean",
                    "description": "Overwrite existing file. Default: true",
                    "default": true
                ]
            ],
            "required": ["url"]
        ]
    )
    
    // MARK: - Database Operations
    
    static let sqliteQuery = ToolSchema(
        name: "sqlite_query",
        displayName: "SQLite Query",
        description: "Execute SQLite queries on any database file. Full SQL support: SELECT, INSERT, UPDATE, DELETE, CREATE TABLE, ALTER, DROP, transactions. Can access application databases, browser history, system databases. Read or modify data without restrictions.",
        icon: "cylinder.fill",
        category: .database,
        inputSchema: [
            "type": "object",
            "properties": [
                "database_path": [
                    "type": "string",
                    "description": "Path to SQLite database file. Examples: '~/Library/Application Support/app/data.db', './app.sqlite'"
                ],
                "query": [
                    "type": "string",
                    "description": "SQL query to execute. Supports multiple statements separated by semicolons."
                ],
                "parameters": [
                    "type": "array",
                    "description": "Query parameters for prepared statements. Prevents SQL injection.",
                    "items": ["type": "string"]
                ],
                "timeout": [
                    "type": "number",
                    "description": "Query timeout in seconds. Default: 30",
                    "default": 30
                ]
            ],
            "required": ["database_path", "query"]
        ]
    )
    
    // MARK: - Code Generation & Modification
    
    static let codeModify = ToolSchema(
        name: "code_modify",
        displayName: "Modify Code",
        description: "Parse, analyze, and modify source code intelligently. Supports Swift, Python, JavaScript, TypeScript, Go, Rust, Java, C, C++. Can refactor functions, rename variables, add imports, update syntax, fix issues, apply transformations across entire codebases. Uses AST parsing for accuracy.",
        icon: "chevron.left.forwardslash.chevron.right",
        category: .code,
        inputSchema: [
            "type": "object",
            "properties": [
                "file_path": [
                    "type": "string",
                    "description": "Path to source code file to modify. If omitted, operates on 'code' parameter."
                ],
                "code": [
                    "type": "string",
                    "description": "Source code string to modify. Use if not modifying a file directly."
                ],
                "language": [
                    "type": "string",
                    "enum": ["swift", "python", "javascript", "typescript", "go", "rust", "java", "cpp", "c"],
                    "description": "Programming language. Auto-detected from file extension if not specified."
                ],
                "modifications": [
                    "type": "array",
                    "description": "List of modifications to apply",
                    "items": [
                        "type": "object",
                        "properties": [
                            "type": [
                                "type": "string",
                                "enum": ["rename", "add_import", "remove_import", "replace", "insert", "delete", "refactor"],
                                "description": "Type of modification"
                            ],
                            "target": [
                                "type": "string",
                                "description": "What to modify (function name, variable, line number, etc.)"
                            ],
                            "value": [
                                "type": "string",
                                "description": "New value or code to insert"
                            ]
                        ],
                        "required": ["type"]
                    ]
                ],
                "write_back": [
                    "type": "boolean",
                    "description": "Write modified code back to file. Default: false (returns modified code only)",
                    "default": false
                ]
            ],
            "required": ["modifications"]
        ]
    )
    
    // MARK: - Encryption & Security
    
    static let encrypt = ToolSchema(
        name: "encrypt_data",
        displayName: "Encrypt Data",
        description: "Encrypt text or files using military-grade algorithms. Supports AES-256, RSA, ChaCha20. Generate keys, encrypt with password or keys, output base64 or binary. Use for securing sensitive data, passwords, API keys, or files.",
        icon: "lock.fill",
        category: .security,
        inputSchema: [
            "type": "object",
            "properties": [
                "data": [
                    "type": "string",
                    "description": "Data to encrypt (text or base64-encoded binary)"
                ],
                "algorithm": [
                    "type": "string",
                    "enum": ["AES256", "RSA2048", "RSA4096", "ChaCha20"],
                    "description": "Encryption algorithm. AES256 for general use, RSA for key exchange, ChaCha20 for speed.",
                    "default": "AES256"
                ],
                "key": [
                    "type": "string",
                    "description": "Encryption key (base64). If omitted, generates a new key and returns it."
                ],
                "password": [
                    "type": "string",
                    "description": "Use password instead of key. Key will be derived using PBKDF2."
                ],
                "output_format": [
                    "type": "string",
                    "enum": ["base64", "hex"],
                    "description": "Output format. Default: base64",
                    "default": "base64"
                ]
            ],
            "required": ["data"]
        ]
    )
    
    static let decrypt = ToolSchema(
        name: "decrypt_data",
        displayName: "Decrypt Data",
        description: "Decrypt encrypted data. Supports same algorithms as encrypt_data. Requires the original key or password.",
        icon: "lock.open.fill",
        category: .security,
        inputSchema: [
            "type": "object",
            "properties": [
                "data": [
                    "type": "string",
                    "description": "Encrypted data (base64 or hex encoded)"
                ],
                "algorithm": [
                    "type": "string",
                    "enum": ["AES256", "RSA2048", "RSA4096", "ChaCha20"],
                    "description": "Encryption algorithm used"
                ],
                "key": [
                    "type": "string",
                    "description": "Decryption key (base64)"
                ],
                "password": [
                    "type": "string",
                    "description": "Password if encrypted with password"
                ],
                "input_format": [
                    "type": "string",
                    "enum": ["base64", "hex"],
                    "description": "Input format. Default: base64",
                    "default": "base64"
                ]
            ],
            "required": ["data"]
        ]
    )
    
    // MARK: - Memory & Performance
    
    static let memoryRead = ToolSchema(
        name: "memory_read",
        displayName: "Read Process Memory",
        description: "Read memory from any running process. Access process address space, scan for patterns, dump memory regions. Useful for debugging, reverse engineering, or extracting runtime data. Requires elevated permissions for system processes.",
        icon: "memorychip.fill",
        category: .system,
        inputSchema: [
            "type": "object",
            "properties": [
                "process_id": [
                    "type": "integer",
                    "description": "PID of target process"
                ],
                "address": [
                    "type": "string",
                    "description": "Memory address to read (hex format: '0x7fff5fc01000'). If omitted with pattern, scans all regions."
                ],
                "size": [
                    "type": "integer",
                    "description": "Number of bytes to read. Default: 4096",
                    "default": 4096
                ],
                "pattern": [
                    "type": "string",
                    "description": "Search for byte pattern in memory. Hex format: 'deadbeef' or string: 'text:password'"
                ],
                "format": [
                    "type": "string",
                    "enum": ["hex", "ascii", "utf8", "raw"],
                    "description": "Output format. Default: hex",
                    "default": "hex"
                ]
            ],
            "required": ["process_id"]
        ]
    )
    
    // MARK: - Advanced Web Scraping
    
    static let webScrape = ToolSchema(
        name: "web_scrape",
        displayName: "Web Scraper",
        description: "Advanced web scraping with JavaScript rendering, authentication, cookies, proxy support. Can scrape dynamic SPAs, bypass simple protections, extract structured data, handle pagination. Returns clean data or full HTML/JSON.",
        icon: "arrow.down.doc.fill",
        category: .network,
        inputSchema: [
            "type": "object",
            "properties": [
                "url": [
                    "type": "string",
                    "description": "URL to scrape"
                ],
                "selectors": [
                    "type": "object",
                    "description": "CSS selectors to extract specific data. Example: {'title': 'h1.title', 'price': '.price-value', 'items': 'ul.products > li'}"
                ],
                "javascript": [
                    "type": "boolean",
                    "description": "Enable JavaScript rendering for dynamic pages (React, Vue, etc.). Slower but handles SPAs. Default: false",
                    "default": false
                ],
                "wait_for": [
                    "type": "string",
                    "description": "CSS selector to wait for before scraping. Ensures dynamic content loads. Example: '.data-loaded'"
                ],
                "cookies": [
                    "type": "object",
                    "description": "Cookies for authentication. Example: {'session_id': 'abc123'}"
                ],
                "headers": [
                    "type": "object",
                    "description": "Custom headers for the request"
                ],
                "pagination": [
                    "type": "object",
                    "description": "Auto-pagination config. Example: {'next_selector': 'a.next', 'max_pages': 10}"
                ]
            ],
            "required": ["url"]
        ]
    )
    
    // MARK: - Git Operations
    
    static let gitCommand = ToolSchema(
        name: "git_command",
        displayName: "Git Command",
        description: "Execute git commands on any repository. Full git access: clone, pull, push, commit, branch, merge, rebase, reset, log, diff, stash. Can modify history, force push, access private repos with credentials. Operates on local or remote repositories.",
        icon: "arrow.triangle.branch",
        category: .code,
        inputSchema: [
            "type": "object",
            "properties": [
                "repository_path": [
                    "type": "string",
                    "description": "Path to git repository. Default: current directory",
                    "default": "."
                ],
                "command": [
                    "type": "string",
                    "description": "Git command without 'git' prefix. Examples: 'status', 'log --oneline -10', 'push origin main --force'"
                ],
                "credentials": [
                    "type": "object",
                    "description": "Git credentials for private repos. Example: {'username': 'user', 'token': 'ghp_token'}"
                ]
            ],
            "required": ["command"]
        ]
    )
    
    // MARK: - All Advanced Skills
    
    static let allSkills: [ToolSchema] = [
        // Filesystem
        fileRead,
        fileWrite,
        fileDelete,
        fileList,
        fileMove,
        
        // Process & System
        processKill,
        processList,
        systemCommand,
        
        // Network
        httpRequest,
        downloadFile,
        webScrape,
        
        // Database
        sqliteQuery,
        
        // Code
        codeModify,
        gitCommand,
        
        // Security
        encrypt,
        decrypt,
        
        // Advanced
        memoryRead
    ]
    
    /// Get all skills as Anthropic format
    static func asAnthropicFormat() -> [[String: Any]] {
        allSkills.map { skill in
            [
                "name": skill.name,
                "description": skill.description,
                "input_schema": skill.inputSchema
            ]
        }
    }
    
    /// Get all skills as OpenAI format
    static func asOpenAIFormat() -> [[String: Any]] {
        allSkills.map { skill in
            [
                "type": "function",
                "function": [
                    "name": skill.name,
                    "description": skill.description,
                    "parameters": skill.inputSchema
                ]
            ]
        }
    }
}

// MARK: - Extended Tool Categories

extension ToolSchema.ToolCategory {
    static let filesystem = ToolSchema.ToolCategory(rawValue: "Filesystem")!
    static let network = ToolSchema.ToolCategory(rawValue: "Network")!
    static let database = ToolSchema.ToolCategory(rawValue: "Database")!
    static let security = ToolSchema.ToolCategory(rawValue: "Security")!
    static let system = ToolSchema.ToolCategory(rawValue: "System")!
    static let code = ToolSchema.ToolCategory(rawValue: "Code")!
}

// Make category initializable from raw value
extension ToolSchema.ToolCategory {
    init?(rawValue: String) {
        switch rawValue {
        case "Core": self = .core
        case "Web": self = .web
        case "Code": self = .code
        case "Artifacts": self = .artifacts
        case "Filesystem": self = .code  // Map to existing category
        case "Network": self = .web      // Map to existing category
        case "Database": self = .code    // Map to existing category
        case "Security": self = .core    // Map to existing category
        case "System": self = .core      // Map to existing category
        default: return nil
        }
    }
}
