# 🎯 Feature Parity Game Plan

## Strategic Overview

**Goal:** Achieve feature parity with leading AI chat clients while maintaining our unique differentiators (Parallel Mode, MCP Integration, Split View).

**Timeline:** 6-8 weeks to reach core parity, then iterative improvements.

**Philosophy:** 
- Quick wins first (high impact, low effort)
- Core UX parity (what users expect)
- Organization features (power users)
- Polish & advanced features (differentiation)

---

## 📋 Phase 1: Quick Wins (Week 1) - **START HERE**

**Goal:** Fix the most obvious gaps that users notice immediately.

### 1.1 Copy Code Button ⏱️ 1-2 hours
**Priority:** 🔥 Critical
**Impact:** High - Every developer needs this
**Files:**
- `MessageBubbleView.swift` - Add copy button to code blocks
- Extract code from markdown code fences

**Implementation:**
- Detect code blocks in markdown rendering
- Add hover button on code blocks
- Copy to clipboard with language indicator

---

### 1.2 Proper Message Editing ⏱️ 3-4 hours
**Priority:** 🔥 Critical  
**Impact:** High - Users expect to fix typos
**Files:**
- `ChatView.swift` - Edit mode state
- `MessageBubbleView.swift` - Edit UI
- `ChatViewModel.swift` - Edit message logic

**Implementation:**
- Click edit → message becomes editable inline
- Save → regenerate response from edited message
- Cancel → revert changes
- Update `ConversationRepository` if needed

---

### 1.3 Archive UI ⏱️ 1-2 hours
**Priority:** High
**Impact:** Medium-High - Field exists, just needs UI
**Files:**
- `VaizorApp.swift` - Archive button in sidebar
- `ConversationRepository.swift` - Archive methods (if missing)
- Filter archived conversations

**Implementation:**
- Add archive/unarchive button to conversation list
- Filter toggle for archived conversations
- Use existing `is_archived` database field

---

### 1.4 Drag & Drop Files ⏱️ 3-4 hours
**Priority:** 🔥 Critical
**Impact:** High - Modern UX expectation
**Files:**
- `ChatView.swift` - Drop zone handler
- `ImageAttachmentView.swift` - Already exists
- File type detection

**Implementation:**
- Add `.onDrop` modifier to input area
- Support images, PDFs, text files
- Show preview before sending
- Handle multiple files

---

**Phase 1 Total: ~8-12 hours**

---

## 📋 Phase 2: Core UX Parity (Week 2)

**Goal:** Match standard features users expect from ChatGPT/Claude.

### 2.1 Per-Conversation Model Selection ⏱️ 2-3 hours
**Priority:** High
**Impact:** Medium-High - Different models per conversation
**Files:**
- `Conversation.swift` - Add `model` and `provider` fields
- `ConversationRepository.swift` - Migration + CRUD
- `ChatView.swift` - Model selector per conversation
- `ChatViewModel.swift` - Use conversation's model

**Implementation:**
- Add `selectedModel` and `selectedProvider` to `Conversation`
- Database migration
- UI in conversation header
- Default to global settings if not set

---

### 2.2 Message Timestamps (Full Date/Time) ⏱️ 1 hour
**Priority:** Medium
**Impact:** Medium - Better context
**Files:**
- `MessageBubbleView.swift` - Update timestamp display
- Format: "Jan 15, 2024 at 3:45 PM" or relative "2 hours ago"

**Implementation:**
- Replace `.time` style with custom formatter
- Show relative time with hover for absolute

---

### 2.3 Paste Images from Clipboard ⏱️ 2-3 hours
**Priority:** High
**Impact:** High - Common workflow
**Files:**
- `ChatView.swift` - Paste handler
- `NSPasteboard` image detection

**Implementation:**
- Monitor pasteboard for images
- Auto-attach on paste
- Show preview in input area

---

### 2.4 Multi-File Attachments ⏱️ 2-3 hours
**Priority:** Medium-High
**Impact:** Medium-High - Attach multiple files at once
**Files:**
- `ChatView.swift` - Multiple file handling
- `Message.swift` - Already supports attachments array
- UI for multiple attachment previews

**Implementation:**
- Allow selecting multiple files
- Show thumbnails/previews
- Send all in one message

---

**Phase 2 Total: ~7-10 hours**

---

## 📋 Phase 3: Organization Features (Week 3-4)

**Goal:** Help power users manage many conversations.

### 3.1 Folders/Categories ⏱️ 6-8 hours
**Priority:** High
**Impact:** High - Essential for organization
**Files:**
- `Conversation.swift` - Add `folderId` field
- `Folder.swift` - New model (id, name, parentId, color)
- `ConversationRepository.swift` - Folder CRUD + migration
- `VaizorApp.swift` - Folder sidebar UI
- `FolderManager.swift` - New service

**Implementation:**
- Database schema: `folders` table
- Nested folder support (optional)
- Drag & drop conversations to folders
- Folder colors/icons
- "Uncategorized" default folder

---

### 3.2 Tags/Labels ⏱️ 4-5 hours
**Priority:** Medium-High
**Impact:** Medium-High - Flexible organization
**Files:**
- `Conversation.swift` - Add `tags: [String]` field
- `ConversationRepository.swift` - Tag queries + migration
- `VaizorApp.swift` - Tag UI (sidebar filter, tag chips)
- Tag autocomplete

**Implementation:**
- JSON array in database (or junction table)
- Tag input with autocomplete
- Filter by tags
- Tag colors

---

### 3.3 Favorites/Starred ⏱️ 1-2 hours
**Priority:** Medium
**Impact:** Medium - Quick access
**Files:**
- `Conversation.swift` - Add `isFavorite: Bool` field
- `ConversationRepository.swift` - Migration
- `VaizorApp.swift` - Star button + filter

**Implementation:**
- Boolean field in database
- Star icon in conversation list
- "Favorites" filter section

---

### 3.4 Conversation Templates ⏱️ 3-4 hours
**Priority:** Medium
**Impact:** Medium - Reusable prompts
**Files:**
- `ConversationTemplate.swift` - New model
- `TemplateRepository.swift` - New repository
- `ChatView.swift` - Template picker
- `SlashCommandView.swift` - Template commands

**Implementation:**
- Templates table (name, prompt, systemPrompt)
- Save current conversation as template
- Load template into new conversation
- Template library UI

---

**Phase 3 Total: ~14-19 hours**

---

## 📋 Phase 4: Polish & Rendering (Week 5-6)

**Goal:** Improve visual polish and content rendering.

### 4.1 Dark/Light Mode Toggle ⏱️ 2-3 hours
**Priority:** Medium
**Impact:** Medium - User preference
**Files:**
- `VaizorApp.swift` - Theme state
- `ComprehensiveSettingsView.swift` - Theme selector
- Color scheme updates

**Implementation:**
- `@AppStorage` for theme preference
- System theme detection
- Custom color sets for dark/light

---

### 4.2 Collapsible Long Messages ⏱️ 2-3 hours
**Priority:** Medium
**Impact:** Medium - Better readability
**Files:**
- `MessageBubbleView.swift` - Collapse logic
- "Show more" / "Show less" buttons

**Implementation:**
- Character limit (e.g., 2000 chars)
- Expand/collapse animation
- Smooth transitions

---

### 4.3 Enhanced Code Block Styling ⏱️ 3-4 hours
**Priority:** Medium
**Impact:** Medium - Developer UX
**Files:**
- `MessageBubbleView.swift` - Code block rendering
- Syntax highlighting (if not already done)
- Language detection

**Implementation:**
- Better code block backgrounds
- Language badges
- Line numbers (optional)
- Improved copy button styling

---

### 4.4 Link Previews ⏱️ 4-5 hours
**Priority:** Low-Medium
**Impact:** Medium - Rich content
**Files:**
- `LinkPreviewView.swift` - New component
- URL metadata fetching
- Cache previews

**Implementation:**
- Detect URLs in messages
- Fetch Open Graph metadata
- Show preview cards
- Cache to avoid repeated fetches

---

### 4.5 Table Rendering Improvements ⏱️ 2-3 hours
**Priority:** Low-Medium
**Impact:** Low-Medium - Better markdown tables
**Files:**
- `MessageBubbleView.swift` - Table styling
- MarkdownUI table customization

**Implementation:**
- Better table borders
- Alternating row colors
- Responsive tables

---

**Phase 4 Total: ~13-18 hours**

---

## 📋 Phase 5: Advanced Features (Week 7+)

**Goal:** Power user features and differentiation.

### 5.1 Custom Instructions (Global System Prompts) ⏱️ 3-4 hours
**Priority:** Medium
**Impact:** Medium-High - Power user feature
**Files:**
- `DependencyContainer.swift` - Store custom instructions
- `ComprehensiveSettingsView.swift` - Instructions editor
- `LLMConfiguration.swift` - Apply instructions

**Implementation:**
- `@AppStorage` for instructions
- Text editor in settings
- Apply to all conversations (or per-conversation override)

---

### 5.2 Token Counter & Cost Estimation ⏱️ 4-5 hours
**Priority:** Medium
**Impact:** Medium - Usage tracking
**Files:**
- `TokenCounter.swift` - New service
- `ChatView.swift` - Display tokens/cost
- Provider-specific token counting

**Implementation:**
- Use `tiktoken` or similar
- Count input/output tokens
- Calculate cost per provider
- Show in message footer or sidebar

---

### 5.3 Message Threading/Replies ⏱️ 6-8 hours
**Priority:** Low-Medium
**Impact:** Medium - Better context
**Files:**
- `Message.swift` - Add `replyToId: UUID?` field
- `MessageBubbleView.swift` - Thread UI
- `ConversationRepository.swift` - Migration

**Implementation:**
- Reply button on messages
- Show thread indentation
- Collapse/expand threads

---

### 5.4 Pin Messages ⏱️ 2-3 hours
**Priority:** Low-Medium
**Impact:** Low-Medium - Mark important messages
**Files:**
- `Message.swift` - Add `isPinned: Bool` field
- `ConversationRepository.swift` - Migration
- `ChatView.swift` - Pin UI + pinned section

**Implementation:**
- Pin icon in message actions
- Show pinned messages at top
- Visual indicator

---

**Phase 5 Total: ~15-20 hours**

---

## 🎯 Implementation Strategy

### Week-by-Week Breakdown

**Week 1: Quick Wins**
- ✅ Copy code button
- ✅ Proper message editing
- ✅ Archive UI
- ✅ Drag & drop files

**Week 2: Core UX**
- ✅ Per-conversation model
- ✅ Message timestamps
- ✅ Paste images
- ✅ Multi-file attachments

**Week 3-4: Organization**
- ✅ Folders
- ✅ Tags
- ✅ Favorites
- ✅ Templates

**Week 5-6: Polish**
- ✅ Dark/Light mode
- ✅ Collapsible messages
- ✅ Code styling
- ✅ Link previews

**Week 7+: Advanced**
- ✅ Custom instructions
- ✅ Token counter
- ✅ Threading
- ✅ Pin messages

---

## 🔧 Technical Considerations

### Database Migrations
- All new fields need migrations
- Use GRDB migration system
- Test migrations on existing databases

### Backward Compatibility
- Default values for new fields
- Graceful degradation if features unavailable
- Migration rollback support

### Performance
- Index new database fields (folders, tags)
- Cache expensive operations (link previews, token counting)
- Lazy load where possible

### Testing
- Unit tests for new repositories
- UI tests for critical flows
- Manual testing checklist per feature

---

## 📊 Success Metrics

### Phase 1 (Quick Wins)
- ✅ Copy code button works on all code blocks
- ✅ Edit message regenerates response
- ✅ Archive button visible and functional
- ✅ Drag & drop accepts images/files

### Phase 2 (Core UX)
- ✅ Conversations can have different models
- ✅ Timestamps show full date/time
- ✅ Paste images works from clipboard
- ✅ Multiple files attachable

### Phase 3 (Organization)
- ✅ Folders created and conversations organized
- ✅ Tags filter conversations
- ✅ Favorites section works
- ✅ Templates save and load

### Phase 4 (Polish)
- ✅ Theme switching works
- ✅ Long messages collapse
- ✅ Code blocks styled better
- ✅ Links show previews

---

## 🚀 Quick Start Checklist

### Before Starting Phase 1:
- [ ] Review current codebase structure
- [ ] Set up development branch
- [ ] Review `FEATURE_PARITY_ANALYSIS.md`
- [ ] Identify any blockers

### Phase 1.1 - Copy Code Button:
- [ ] Read `MessageBubbleView.swift`
- [ ] Understand markdown rendering
- [ ] Add copy button to code blocks
- [ ] Test with various code languages
- [ ] Verify clipboard copy works

### Phase 1.2 - Message Editing:
- [ ] Review current edit implementation
- [ ] Design inline edit UI
- [ ] Implement edit state management
- [ ] Add regenerate on save
- [ ] Test edit flow end-to-end

---

## 💡 Notes & Considerations

### What We're NOT Doing (Yet)
- Voice input (low priority, placeholder exists)
- LaTeX/Math rendering (specialized use case)
- Run code (security concerns)
- Collaboration features (not core to MVP)
- API access (future consideration)

### What We're Keeping Unique
- ✅ Parallel model execution
- ✅ MCP server integration
- ✅ Split view conversations
- ✅ Prompt enhancement
- ✅ Local-first (Ollama)

### Risk Mitigation
- **Database migrations:** Test thoroughly, backup first
- **Breaking changes:** Version migrations, defaults
- **Performance:** Profile before/after each phase
- **User experience:** Test with real workflows

---

## 🎬 Next Steps

1. **Review this plan** - Confirm priorities and timeline
2. **Start Phase 1.1** - Copy code button (quickest win)
3. **Iterate** - Get feedback after each phase
4. **Adjust** - Pivot based on user needs

---

## 📝 Estimated Total Time

- **Phase 1:** 8-12 hours
- **Phase 2:** 7-10 hours  
- **Phase 3:** 14-19 hours
- **Phase 4:** 13-18 hours
- **Phase 5:** 15-20 hours

**Total: ~57-79 hours** (roughly 2-3 weeks of focused development)

---

**Ready to start?** Let's begin with Phase 1.1 - Copy Code Button! 🚀
