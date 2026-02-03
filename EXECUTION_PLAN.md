# Execution Plan: Phase 1 Cleanup → Phase 2 Kickoff

## Overview
Complete remaining Phase 1 optimizations, then begin Phase 2 high-impact features.

---

## Phase 1 Cleanup (2-4 hours)

### Task 1.1: Integrate MarkdownRenderService ⏱️ 30-60 min
**Priority:** High (completes Phase 1)  
**Impact:** Smooth scrolling, no UI blocking during markdown rendering

**Steps:**
1. Update `MessageBubbleView` to use async markdown rendering
2. Add `@State` for rendered markdown view
3. Load markdown via `MarkdownRenderService.render()` on appear
4. Show loading placeholder while rendering
5. Cache rendered views per message ID

**Files to modify:**
- `Sources/vaizor/Presentation/Views/MessageBubbleView.swift`
- `Sources/vaizor/Domain/Services/MarkdownRenderService.swift` (may need adjustments)

**Testing:**
- Scroll through long conversation with markdown
- Verify no UI stutter
- Check memory usage doesn't grow unbounded

---

### Task 1.2: Add Keyset Pagination ⏱️ 2-3 hours
**Priority:** High (essential for long conversations)  
**Impact:** 10-100x faster message loading for large conversations

**Steps:**
1. Add pagination support to `ConversationRepository`:
   - `loadMessages(conversationId:after:limit:)` method
   - Use `created_at, id` for keyset pagination
   - Return `(messages: [Message], hasMore: Bool, lastCursor: (Date, UUID)?)`

2. Update `ChatViewModel`:
   - Add `@Published var isLoadingMore: Bool`
   - Add `@Published var hasMoreMessages: Bool`
   - Modify `loadMessages()` to load initial chunk (50-100 messages)
   - Add `loadMoreMessages()` method

3. Update `ChatView`:
   - Detect scroll position near top
   - Trigger `loadMoreMessages()` when scrolling up
   - Show loading indicator when fetching more

4. Update virtualization:
   - Adjust `visibleMessageRange` to account for pagination
   - Handle messages loaded out of order

**Files to modify:**
- `Sources/vaizor/Data/Repositories/ConversationRepository.swift`
- `Sources/vaizor/Presentation/ViewModels/ChatViewModel.swift`
- `Sources/vaizor/Presentation/Views/ChatView.swift`

**Database changes:**
- Add index on `(conversation_id, created_at, id)` if not exists

**Testing:**
- Load conversation with 1000+ messages
- Verify initial load is fast (<100ms)
- Scroll up, verify more messages load
- Test with conversations of various sizes

---

## Phase 2: High-Impact Features (Week 1-2)

### Task 2.1: Full-Text Search (FTS5) ⏱️ 4-6 hours
**Priority:** High  
**Impact:** Instant search across all conversations

**Steps:**
1. Create FTS5 virtual table migration:
   - `messages_fts` table with `content`, `role`, `conversation_id`
   - Triggers to keep FTS table in sync

2. Add search methods to `ConversationRepository`:
   - `searchMessages(query: String, conversationId: UUID?) -> [Message]`
   - Support scoped (per conversation) and global search

3. Build search UI:
   - Add search bar to sidebar
   - Show search results with context
   - Highlight matching text

**Files to create/modify:**
- `Sources/vaizor/Data/Database/Migrations/AddFTS5Search.swift`
- `Sources/vaizor/Data/Repositories/ConversationRepository.swift`
- `Sources/vaizor/Presentation/Views/SearchView.swift` (new)
- `Sources/vaizor/Presentation/Views/ChatSidebarView.swift`

**Testing:**
- Search across multiple conversations
- Verify search is fast (<50ms for 10k messages)
- Test special characters, quotes, etc.

---

### Task 2.2: Parallel Model Execution MVP ⏱️ 6-8 hours
**Priority:** High (Major Differentiator)  
**Impact:** Compare multiple models side-by-side

**Steps:**
1. Create `ParallelModelExecutor`:
   - Send same prompt to multiple models simultaneously
   - Collect responses as they arrive
   - Handle errors gracefully

2. Update `ChatViewModel`:
   - Add `@Published var parallelResponses: [UUID: String]`
   - Add `@Published var selectedModels: Set<LLMProvider>`
   - Modify `sendMessage()` to support parallel mode

3. Build comparison UI:
   - Model selector (checkboxes)
   - Side-by-side response view
   - Response comparison metrics (latency, tokens)

**Files to create/modify:**
- `Sources/vaizor/Domain/Services/ParallelModelExecutor.swift` (new)
- `Sources/vaizor/Presentation/ViewModels/ChatViewModel.swift`
- `Sources/vaizor/Presentation/Views/ModelComparisonView.swift` (new)
- `Sources/vaizor/Presentation/Views/ChatView.swift`

**Testing:**
- Compare 2-3 models simultaneously
- Verify responses arrive independently
- Test error handling (one model fails)

---

## Optional Enhancements (Can be done in parallel)

### Task 3.1: Message Rendering Cache in SQLite ⏱️ 3-4 hours
**Priority:** Medium  
**Impact:** Faster message display after app restart

**Steps:**
1. Add `rendered_markdown` column to `messages` table
2. Store rendered markdown blob when message is created/updated
3. Load cached render on message display
4. Invalidate cache on message edit

**Files to modify:**
- `Sources/vaizor/Data/Database/Migrations/AddRenderedMarkdownCache.swift`
- `Sources/vaizor/Data/Database/Records/MessageRecord.swift`
- `Sources/vaizor/Domain/Services/MarkdownRenderService.swift`
- `Sources/vaizor/Data/Repositories/ConversationRepository.swift`

---

### Task 3.2: Improve Virtualization ⏱️ 2-3 hours
**Priority:** Medium  
**Impact:** Better scroll performance

**Steps:**
1. Implement proper scroll position tracking
2. Calculate visible range based on scroll offset
3. Preload messages above/below viewport more intelligently

**Files to modify:**
- `Sources/vaizor/Presentation/Views/ChatView.swift`

---

## Timeline Estimate

### Week 1: Phase 1 Cleanup
- **Day 1:** Task 1.1 (MarkdownRenderService integration)
- **Day 2-3:** Task 1.2 (Keyset pagination)

### Week 2: Phase 2 Core Features
- **Day 1-2:** Task 2.1 (FTS5 Search)
- **Day 3-4:** Task 2.2 (Parallel Model Execution)

### Week 3+: Optional Enhancements
- Can be done in parallel with other Phase 2 features

---

## Risk Assessment

### Low Risk ✅
- MarkdownRenderService integration (straightforward)
- Keyset pagination (well-understood pattern)

### Medium Risk ⚠️
- FTS5 setup (migration complexity)
- Parallel model execution (concurrency management)

### Mitigation
- Test migrations on sample data first
- Use proper error handling for parallel execution
- Add comprehensive logging

---

## Success Criteria

### Phase 1 Cleanup
- ✅ Markdown renders smoothly (no UI blocking)
- ✅ Conversations with 1000+ messages load in <100ms
- ✅ Scrolling is smooth with pagination

### Phase 2 Features
- ✅ Search returns results in <50ms
- ✅ Can compare 2-3 models simultaneously
- ✅ All features work reliably

---

## Dependencies

### Required Before Starting
- ✅ SQLite migration complete (done)
- ✅ GRDB infrastructure in place (done)
- ✅ Export/Import working (done)

### Nice to Have
- MarkdownRenderService integration (will do in Task 1.1)
- Keyset pagination (will do in Task 1.2)

---

## Approval Checklist

- [ ] Phase 1 cleanup tasks approved
- [ ] Phase 2 feature priorities confirmed
- [ ] Timeline acceptable
- [ ] Risk level acceptable
- [ ] Ready to proceed

---

## Next Steps After Approval

1. Start with Task 1.1 (MarkdownRenderService)
2. Complete Task 1.2 (Keyset pagination)
3. Begin Task 2.1 (FTS5 Search)
4. Implement Task 2.2 (Parallel Model Execution)

**Estimated Total Time:** 12-18 hours for core plan
