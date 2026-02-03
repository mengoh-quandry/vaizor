#!/bin/bash
# End-to-End UAT Test for Vaizor PostgreSQL Integration
# This script tests the complete PostgreSQL integration without launching the full UI

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test configuration
TEST_DB="vaizor_test"
TEST_HOST="localhost"
TEST_PORT="5432"
TEST_USER="marcus"
SCHEMA_FILE="/Users/marcus/.Projects/vaizor/docs/database-schema.sql"

# Counters
TESTS_PASSED=0
TESTS_FAILED=0

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

log_section() {
    echo ""
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}$1${NC}"
    echo -e "${YELLOW}========================================${NC}"
}

# Execute SQL and return result
run_sql() {
    psql -h "$TEST_HOST" -p "$TEST_PORT" -U "$TEST_USER" -d "$TEST_DB" -t -A -c "$1" 2>/dev/null
}

# Execute SQL expecting success
run_sql_expect_success() {
    if psql -h "$TEST_HOST" -p "$TEST_PORT" -U "$TEST_USER" -d "$TEST_DB" -c "$1" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

#######################################
# TEST SETUP
#######################################
log_section "TEST SETUP"

# Check PostgreSQL is running
log_info "Checking PostgreSQL connection..."
if pg_isready -h "$TEST_HOST" -p "$TEST_PORT" >/dev/null 2>&1; then
    log_success "PostgreSQL is running"
else
    log_fail "PostgreSQL is not running"
    echo "Please start PostgreSQL: brew services start postgresql@14"
    exit 1
fi

# Reset test database
log_info "Resetting test database..."
psql -h "$TEST_HOST" -p "$TEST_PORT" -U "$TEST_USER" -d postgres -c "DROP DATABASE IF EXISTS $TEST_DB;" >/dev/null 2>&1
psql -h "$TEST_HOST" -p "$TEST_PORT" -U "$TEST_USER" -d postgres -c "CREATE DATABASE $TEST_DB;" >/dev/null 2>&1
log_success "Test database created"

# Apply schema
log_info "Applying database schema..."
if psql -h "$TEST_HOST" -p "$TEST_PORT" -U "$TEST_USER" -d "$TEST_DB" -f "$SCHEMA_FILE" >/dev/null 2>&1; then
    log_success "Schema applied successfully"
else
    log_fail "Failed to apply schema"
    exit 1
fi

#######################################
# TEST 1: SCHEMA VERIFICATION
#######################################
log_section "TEST 1: SCHEMA VERIFICATION"

# Check core tables exist
EXPECTED_TABLES="conversations messages attachments folders conversation_templates projects project_memory tool_runs agent_identity"
for table in $EXPECTED_TABLES; do
    if run_sql "SELECT 1 FROM information_schema.tables WHERE table_name='$table';" | grep -q "1"; then
        log_success "Table '$table' exists"
    else
        log_fail "Table '$table' missing"
    fi
done

# Check pgcrypto extension
if run_sql "SELECT 1 FROM pg_extension WHERE extname='pgcrypto';" | grep -q "1"; then
    log_success "pgcrypto extension installed"
else
    log_fail "pgcrypto extension missing"
fi

#######################################
# TEST 2: CONVERSATION CRUD
#######################################
log_section "TEST 2: CONVERSATION CRUD"

# Create a conversation
CONV_ID="$(uuidgen)"
log_info "Creating conversation $CONV_ID..."
if run_sql_expect_success "INSERT INTO conversations (id, title, summary, message_count, is_favorite, is_archived, created_at, last_used_at) VALUES ('$CONV_ID', 'Test Conversation', 'A test conversation for E2E testing', 0, false, false, NOW(), NOW());"; then
    log_success "Created conversation"
else
    log_fail "Failed to create conversation"
fi

# Read conversation
TITLE=$(run_sql "SELECT title FROM conversations WHERE id='$CONV_ID';")
if [ "$TITLE" = "Test Conversation" ]; then
    log_success "Read conversation correctly"
else
    log_fail "Read conversation failed (got: $TITLE)"
fi

# Update conversation
if run_sql_expect_success "UPDATE conversations SET title='Updated Title', message_count=5 WHERE id='$CONV_ID';"; then
    log_success "Updated conversation"
else
    log_fail "Failed to update conversation"
fi

# Verify update
NEW_TITLE=$(run_sql "SELECT title FROM conversations WHERE id='$CONV_ID';")
MSG_COUNT=$(run_sql "SELECT message_count FROM conversations WHERE id='$CONV_ID';")
if [ "$NEW_TITLE" = "Updated Title" ] && [ "$MSG_COUNT" = "5" ]; then
    log_success "Verified conversation update"
else
    log_fail "Conversation update verification failed"
fi

#######################################
# TEST 3: MESSAGE CRUD
#######################################
log_section "TEST 3: MESSAGE CRUD"

# Create messages
MSG1_ID="$(uuidgen)"
MSG2_ID="$(uuidgen)"

log_info "Creating user message..."
if run_sql_expect_success "INSERT INTO messages (id, conversation_id, role, content, created_at) VALUES ('$MSG1_ID', '$CONV_ID', 'user', 'Hello, this is a test message!', NOW());"; then
    log_success "Created user message"
else
    log_fail "Failed to create user message"
fi

log_info "Creating assistant message..."
if run_sql_expect_success "INSERT INTO messages (id, conversation_id, role, content, created_at) VALUES ('$MSG2_ID', '$CONV_ID', 'assistant', 'Hello! How can I help you today?', NOW());"; then
    log_success "Created assistant message"
else
    log_fail "Failed to create assistant message"
fi

# Verify messages
MSG_COUNT=$(run_sql "SELECT COUNT(*) FROM messages WHERE conversation_id='$CONV_ID';")
if [ "$MSG_COUNT" = "2" ]; then
    log_success "Message count correct (2)"
else
    log_fail "Message count incorrect (expected 2, got $MSG_COUNT)"
fi

# Test message ordering
FIRST_MSG=$(run_sql "SELECT role FROM messages WHERE conversation_id='$CONV_ID' ORDER BY created_at ASC LIMIT 1;")
if [ "$FIRST_MSG" = "user" ]; then
    log_success "Message ordering correct"
else
    log_fail "Message ordering incorrect"
fi

#######################################
# TEST 4: FULL-TEXT SEARCH
#######################################
log_section "TEST 4: FULL-TEXT SEARCH"

# Insert searchable content
SEARCH_CONV_ID="$(uuidgen)"
SEARCH_MSG_ID="$(uuidgen)"
run_sql_expect_success "INSERT INTO conversations (id, title, created_at, last_used_at) VALUES ('$SEARCH_CONV_ID', 'Search Test', NOW(), NOW());"
run_sql_expect_success "INSERT INTO messages (id, conversation_id, role, content, created_at) VALUES ('$SEARCH_MSG_ID', '$SEARCH_CONV_ID', 'user', 'PostgreSQL is a powerful relational database', NOW());"

# Note: content_tsv is auto-generated, no need to update it manually

# Test search (compare lowercase UUIDs for consistency)
SEARCH_RESULT=$(run_sql "SELECT id FROM messages WHERE content_tsv @@ plainto_tsquery('english', 'PostgreSQL database');" 2>/dev/null | tr '[:upper:]' '[:lower:]')
SEARCH_MSG_ID_LOWER=$(echo "$SEARCH_MSG_ID" | tr '[:upper:]' '[:lower:]')
if [ "$SEARCH_RESULT" = "$SEARCH_MSG_ID_LOWER" ]; then
    log_success "Full-text search working"
else
    log_fail "Full-text search failed (expected: '$SEARCH_MSG_ID_LOWER', got: '$SEARCH_RESULT')"
fi

# Test search with ranking
RANK_RESULT=$(run_sql "SELECT ts_rank(content_tsv, plainto_tsquery('english', 'PostgreSQL')) as rank FROM messages WHERE id='$SEARCH_MSG_ID';" 2>/dev/null)
if [ -n "$RANK_RESULT" ]; then
    log_success "Search ranking working (rank: $RANK_RESULT)"
else
    log_fail "Search ranking failed"
fi

#######################################
# TEST 5: ATTACHMENTS
#######################################
log_section "TEST 5: ATTACHMENTS"

ATTACH_ID="$(uuidgen)"
# Create a small test attachment (hex-encoded "test data")
TEST_DATA_HEX="746573742064617461"

log_info "Creating attachment..."
if run_sql_expect_success "INSERT INTO attachments (id, message_id, filename, mime_type, byte_count, is_image, data, created_at) VALUES ('$ATTACH_ID', '$MSG1_ID', 'test.txt', 'text/plain', 9, false, '\\x$TEST_DATA_HEX'::bytea, NOW());"; then
    log_success "Created attachment"
else
    log_fail "Failed to create attachment"
fi

# Verify attachment
ATTACH_SIZE=$(run_sql "SELECT byte_count FROM attachments WHERE id='$ATTACH_ID';")
if [ "$ATTACH_SIZE" = "9" ]; then
    log_success "Attachment stored correctly"
else
    log_fail "Attachment size incorrect (expected 9, got $ATTACH_SIZE)"
fi

#######################################
# TEST 6: FOLDERS
#######################################
log_section "TEST 6: FOLDERS"

FOLDER_ID="$(uuidgen)"

log_info "Creating folder..."
if run_sql_expect_success "INSERT INTO folders (id, name, color, created_at) VALUES ('$FOLDER_ID', 'Test Folder', '#00976d', NOW());"; then
    log_success "Created folder"
else
    log_fail "Failed to create folder"
fi

# Assign conversation to folder
if run_sql_expect_success "UPDATE conversations SET folder_id='$FOLDER_ID' WHERE id='$CONV_ID';"; then
    log_success "Assigned conversation to folder"
else
    log_fail "Failed to assign conversation to folder"
fi

# Verify folder assignment
FOLDER_CONV=$(run_sql "SELECT COUNT(*) FROM conversations WHERE folder_id='$FOLDER_ID';")
if [ "$FOLDER_CONV" = "1" ]; then
    log_success "Folder assignment verified"
else
    log_fail "Folder assignment verification failed"
fi

#######################################
# TEST 7: TEMPLATES
#######################################
log_section "TEST 7: TEMPLATES"

TEMPLATE_ID="$(uuidgen)"

log_info "Creating template..."
if run_sql_expect_success "INSERT INTO conversation_templates (id, name, prompt, system_prompt, created_at) VALUES ('$TEMPLATE_ID', 'Code Review', 'Please review this code:', 'You are a senior code reviewer.', NOW());"; then
    log_success "Created template"
else
    log_fail "Failed to create template"
fi

# Verify template
TEMPLATE_NAME=$(run_sql "SELECT name FROM conversation_templates WHERE id='$TEMPLATE_ID';")
if [ "$TEMPLATE_NAME" = "Code Review" ]; then
    log_success "Template stored correctly"
else
    log_fail "Template storage failed"
fi

#######################################
# TEST 8: PROJECTS
#######################################
log_section "TEST 8: PROJECTS"

PROJECT_ID="$(uuidgen)"

log_info "Creating project..."
if run_sql_expect_success "INSERT INTO projects (id, name, description, created_at, updated_at) VALUES ('$PROJECT_ID', 'Test Project', 'A test project', NOW(), NOW());"; then
    log_success "Created project"
else
    log_fail "Failed to create project"
fi

# Link conversation to project (use search test conversation since main one may be deleted)
if run_sql_expect_success "UPDATE conversations SET project_id='$PROJECT_ID' WHERE id='$SEARCH_CONV_ID';"; then
    log_success "Linked conversation to project"
else
    log_fail "Failed to link conversation to project"
fi

#######################################
# TEST 9: AGENT IDENTITY
#######################################
log_section "TEST 9: AGENT IDENTITY"

AGENT_ID="$(uuidgen)"

log_info "Creating agent identity..."
if run_sql_expect_success "INSERT INTO agent_identity (id, name, development_stage, birth_timestamp, total_interactions, last_interaction, created_at, updated_at) VALUES ('$AGENT_ID', 'Vaizor', 'nascent', NOW(), 0, NOW(), NOW(), NOW());"; then
    log_success "Created agent identity"
else
    log_fail "Failed to create agent identity"
fi

# Verify agent
AGENT_NAME=$(run_sql "SELECT name FROM agent_identity WHERE id='$AGENT_ID';")
if [ "$AGENT_NAME" = "Vaizor" ]; then
    log_success "Agent identity stored correctly"
else
    log_fail "Agent identity storage failed (got: '$AGENT_NAME')"
fi

# Test agent personality (normalized table - agent_id is the primary key)
log_info "Creating agent personality..."
if run_sql_expect_success "INSERT INTO agent_personality (agent_id, openness, conscientiousness, extraversion, agreeableness, emotional_stability) VALUES ('$AGENT_ID', 0.7, 0.6, 0.5, 0.7, 0.6);"; then
    log_success "Created agent personality"
else
    log_fail "Failed to create agent personality"
fi

#######################################
# TEST 10: TOOL RUNS
#######################################
log_section "TEST 10: TOOL RUNS"

TOOL_RUN_ID="$(uuidgen)"

log_info "Recording tool run..."
if run_sql_expect_success "INSERT INTO tool_runs (id, conversation_id, message_id, tool_name, server_name, input_json, output_json, is_error, duration_ms, created_at) VALUES ('$TOOL_RUN_ID', '$CONV_ID', '$MSG2_ID', 'read_file', 'filesystem', '{\"path\": \"/test\"}', '{\"content\": \"test\"}', false, 150, NOW());"; then
    log_success "Recorded tool run"
else
    log_fail "Failed to record tool run"
fi

# Verify tool run
TOOL_DURATION=$(run_sql "SELECT duration_ms FROM tool_runs WHERE id='$TOOL_RUN_ID';")
if [ "$TOOL_DURATION" = "150" ]; then
    log_success "Tool run stored correctly"
else
    log_fail "Tool run storage failed"
fi

#######################################
# TEST 11: CASCADE DELETES
#######################################
log_section "TEST 11: CASCADE DELETES"

# Count before delete
MSG_BEFORE=$(run_sql "SELECT COUNT(*) FROM messages WHERE conversation_id='$CONV_ID';")
ATTACH_BEFORE=$(run_sql "SELECT COUNT(*) FROM attachments WHERE message_id='$MSG1_ID';")

log_info "Testing cascade delete on conversation..."
if run_sql_expect_success "DELETE FROM conversations WHERE id='$CONV_ID';"; then
    log_success "Deleted conversation"
else
    log_fail "Failed to delete conversation"
fi

# Verify cascades
MSG_AFTER=$(run_sql "SELECT COUNT(*) FROM messages WHERE conversation_id='$CONV_ID';")
if [ "$MSG_AFTER" = "0" ]; then
    log_success "Messages cascaded (was $MSG_BEFORE, now $MSG_AFTER)"
else
    log_fail "Messages not cascaded (still $MSG_AFTER)"
fi

ATTACH_AFTER=$(run_sql "SELECT COUNT(*) FROM attachments WHERE message_id='$MSG1_ID';")
if [ "$ATTACH_AFTER" = "0" ]; then
    log_success "Attachments cascaded (was $ATTACH_BEFORE, now $ATTACH_AFTER)"
else
    log_fail "Attachments not cascaded (still $ATTACH_AFTER)"
fi

#######################################
# TEST 12: PERFORMANCE BENCHMARK
#######################################
log_section "TEST 12: PERFORMANCE BENCHMARK"

log_info "Inserting 100 conversations..."
START_TIME=$(date +%s%N)
for i in $(seq 1 100); do
    run_sql_expect_success "INSERT INTO conversations (id, title, created_at, last_used_at) VALUES ('$(uuidgen)', 'Perf Test $i', NOW(), NOW());" || true
done
END_TIME=$(date +%s%N)
ELAPSED=$(( ($END_TIME - $START_TIME) / 1000000 ))
log_info "100 conversation inserts: ${ELAPSED}ms"

if [ $ELAPSED -lt 5000 ]; then
    log_success "Bulk insert performance acceptable (<5s)"
else
    log_fail "Bulk insert too slow (>${ELAPSED}ms)"
fi

log_info "Querying all conversations..."
START_TIME=$(date +%s%N)
CONV_COUNT=$(run_sql "SELECT COUNT(*) FROM conversations;")
END_TIME=$(date +%s%N)
ELAPSED=$(( ($END_TIME - $START_TIME) / 1000000 ))
log_info "Count query: ${ELAPSED}ms ($CONV_COUNT conversations)"

if [ $ELAPSED -lt 100 ]; then
    log_success "Query performance acceptable (<100ms)"
else
    log_fail "Query too slow (${ELAPSED}ms)"
fi

#######################################
# TEST SUMMARY
#######################################
log_section "TEST SUMMARY"

TOTAL=$((TESTS_PASSED + TESTS_FAILED))
echo ""
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
echo -e "Total Tests:  $TOTAL"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}   ALL TESTS PASSED! PostgreSQL OK     ${NC}"
    echo -e "${GREEN}========================================${NC}"
    exit 0
else
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}   SOME TESTS FAILED                   ${NC}"
    echo -e "${RED}========================================${NC}"
    exit 1
fi
