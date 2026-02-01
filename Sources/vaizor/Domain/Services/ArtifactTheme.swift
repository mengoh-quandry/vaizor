import Foundation

/// Vaizor Design System - Premium artifact theming inspired by Apple, Stripe, Airbnb, Dropbox
struct ArtifactTheme {

    /// The complete CSS theme injected into all artifacts
    static let css: String = """
    /* ============================================
       VAIZOR DESIGN SYSTEM v2.0
       Inspired by Apple, Stripe, Airbnb, Dropbox
       ============================================ */

    :root {
        /* === COLOR SYSTEM === */

        /* Primary - Stripe-inspired gradient base */
        --v-primary: #635bff;
        --v-primary-light: #7a73ff;
        --v-primary-dark: #4b44c9;
        --v-primary-50: #f5f3ff;
        --v-primary-100: #ede9fe;
        --v-primary-200: #ddd6fe;
        --v-primary-300: #c4b5fd;
        --v-primary-400: #a78bfa;
        --v-primary-500: #8b5cf6;
        --v-primary-600: #7c3aed;
        --v-primary-700: #6d28d9;
        --v-primary-800: #5b21b6;
        --v-primary-900: #4c1d95;

        /* Accent - Vibrant cyan/teal */
        --v-accent: #00d4ff;
        --v-accent-light: #67e8f9;
        --v-accent-dark: #0891b2;

        /* Success - Fresh green */
        --v-success: #10b981;
        --v-success-light: #34d399;
        --v-success-dark: #059669;

        /* Warning - Warm amber */
        --v-warning: #f59e0b;
        --v-warning-light: #fbbf24;
        --v-warning-dark: #d97706;

        /* Error - Soft red */
        --v-error: #ef4444;
        --v-error-light: #f87171;
        --v-error-dark: #dc2626;

        /* Neutrals - Refined grays */
        --v-gray-50: #fafafa;
        --v-gray-100: #f4f4f5;
        --v-gray-200: #e4e4e7;
        --v-gray-300: #d4d4d8;
        --v-gray-400: #a1a1aa;
        --v-gray-500: #71717a;
        --v-gray-600: #52525b;
        --v-gray-700: #3f3f46;
        --v-gray-800: #27272a;
        --v-gray-900: #18181b;
        --v-gray-950: #09090b;

        /* === SEMANTIC TOKENS (Light Mode) === */
        --v-bg: #ffffff;
        --v-bg-secondary: #fafafa;
        --v-bg-tertiary: #f4f4f5;
        --v-bg-elevated: #ffffff;
        --v-bg-overlay: rgba(0, 0, 0, 0.5);

        --v-surface: #ffffff;
        --v-surface-secondary: #fafafa;
        --v-surface-hover: #f4f4f5;
        --v-surface-active: #e4e4e7;

        --v-border: #e4e4e7;
        --v-border-light: #f4f4f5;
        --v-border-focus: var(--v-primary);

        --v-text: #18181b;
        --v-text-secondary: #52525b;
        --v-text-tertiary: #a1a1aa;
        --v-text-inverse: #ffffff;
        --v-text-link: var(--v-primary);

        /* === GRADIENTS (Stripe-inspired) === */
        --v-gradient-primary: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        --v-gradient-accent: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
        --v-gradient-success: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%);
        --v-gradient-warm: linear-gradient(135deg, #fa709a 0%, #fee140 100%);
        --v-gradient-cool: linear-gradient(135deg, #a8edea 0%, #fed6e3 100%);
        --v-gradient-dark: linear-gradient(135deg, #434343 0%, #000000 100%);
        --v-gradient-mesh: radial-gradient(at 40% 20%, hsla(240,100%,74%,0.3) 0px, transparent 50%),
                          radial-gradient(at 80% 0%, hsla(189,100%,56%,0.3) 0px, transparent 50%),
                          radial-gradient(at 0% 50%, hsla(355,85%,63%,0.2) 0px, transparent 50%),
                          radial-gradient(at 80% 50%, hsla(340,100%,76%,0.2) 0px, transparent 50%),
                          radial-gradient(at 0% 100%, hsla(22,100%,77%,0.3) 0px, transparent 50%);

        /* === SHADOWS (Apple-inspired depth) === */
        --v-shadow-xs: 0 1px 2px rgba(0, 0, 0, 0.04);
        --v-shadow-sm: 0 1px 3px rgba(0, 0, 0, 0.06), 0 1px 2px rgba(0, 0, 0, 0.04);
        --v-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.07), 0 2px 4px -1px rgba(0, 0, 0, 0.04);
        --v-shadow-md: 0 10px 15px -3px rgba(0, 0, 0, 0.08), 0 4px 6px -2px rgba(0, 0, 0, 0.04);
        --v-shadow-lg: 0 20px 25px -5px rgba(0, 0, 0, 0.08), 0 10px 10px -5px rgba(0, 0, 0, 0.03);
        --v-shadow-xl: 0 25px 50px -12px rgba(0, 0, 0, 0.15);
        --v-shadow-inner: inset 0 2px 4px 0 rgba(0, 0, 0, 0.04);
        --v-shadow-glow: 0 0 40px -10px var(--v-primary);
        --v-shadow-glow-accent: 0 0 40px -10px var(--v-accent);

        /* === TYPOGRAPHY === */
        --v-font-sans: -apple-system, BlinkMacSystemFont, 'SF Pro Display', 'Segoe UI', Roboto, 'Helvetica Neue', sans-serif;
        --v-font-mono: 'SF Mono', 'Fira Code', 'JetBrains Mono', Consolas, monospace;
        --v-font-display: -apple-system, BlinkMacSystemFont, 'SF Pro Display', 'Segoe UI', Roboto, sans-serif;

        /* Font sizes - Apple-inspired scale */
        --v-text-xs: 0.75rem;
        --v-text-sm: 0.875rem;
        --v-text-base: 1rem;
        --v-text-lg: 1.125rem;
        --v-text-xl: 1.25rem;
        --v-text-2xl: 1.5rem;
        --v-text-3xl: 1.875rem;
        --v-text-4xl: 2.25rem;
        --v-text-5xl: 3rem;
        --v-text-6xl: 3.75rem;
        --v-text-7xl: 4.5rem;

        /* Line heights */
        --v-leading-none: 1;
        --v-leading-tight: 1.15;
        --v-leading-snug: 1.3;
        --v-leading-normal: 1.5;
        --v-leading-relaxed: 1.625;
        --v-leading-loose: 2;

        /* Letter spacing */
        --v-tracking-tighter: -0.04em;
        --v-tracking-tight: -0.02em;
        --v-tracking-normal: 0;
        --v-tracking-wide: 0.02em;
        --v-tracking-wider: 0.04em;

        /* === SPACING === */
        --v-space-px: 1px;
        --v-space-0: 0;
        --v-space-1: 0.25rem;
        --v-space-2: 0.5rem;
        --v-space-3: 0.75rem;
        --v-space-4: 1rem;
        --v-space-5: 1.25rem;
        --v-space-6: 1.5rem;
        --v-space-8: 2rem;
        --v-space-10: 2.5rem;
        --v-space-12: 3rem;
        --v-space-16: 4rem;
        --v-space-20: 5rem;
        --v-space-24: 6rem;
        --v-space-32: 8rem;

        /* === BORDER RADIUS === */
        --v-radius-none: 0;
        --v-radius-sm: 0.25rem;
        --v-radius: 0.5rem;
        --v-radius-md: 0.75rem;
        --v-radius-lg: 1rem;
        --v-radius-xl: 1.25rem;
        --v-radius-2xl: 1.5rem;
        --v-radius-3xl: 2rem;
        --v-radius-full: 9999px;

        /* === TRANSITIONS === */
        --v-ease-out: cubic-bezier(0.22, 1, 0.36, 1);
        --v-ease-in-out: cubic-bezier(0.65, 0, 0.35, 1);
        --v-ease-spring: cubic-bezier(0.175, 0.885, 0.32, 1.275);
        --v-duration-fast: 150ms;
        --v-duration: 200ms;
        --v-duration-slow: 300ms;
        --v-duration-slower: 500ms;
    }

    /* === DARK MODE === */
    @media (prefers-color-scheme: dark) {
        :root {
            --v-bg: #09090b;
            --v-bg-secondary: #18181b;
            --v-bg-tertiary: #27272a;
            --v-bg-elevated: #27272a;

            --v-surface: #18181b;
            --v-surface-secondary: #27272a;
            --v-surface-hover: #3f3f46;
            --v-surface-active: #52525b;

            --v-border: #3f3f46;
            --v-border-light: #27272a;

            --v-text: #fafafa;
            --v-text-secondary: #a1a1aa;
            --v-text-tertiary: #71717a;

            --v-shadow-xs: 0 1px 2px rgba(0, 0, 0, 0.2);
            --v-shadow-sm: 0 1px 3px rgba(0, 0, 0, 0.3), 0 1px 2px rgba(0, 0, 0, 0.2);
            --v-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.3), 0 2px 4px -1px rgba(0, 0, 0, 0.2);
            --v-shadow-md: 0 10px 15px -3px rgba(0, 0, 0, 0.4), 0 4px 6px -2px rgba(0, 0, 0, 0.2);
            --v-shadow-lg: 0 20px 25px -5px rgba(0, 0, 0, 0.4), 0 10px 10px -5px rgba(0, 0, 0, 0.2);
            --v-shadow-xl: 0 25px 50px -12px rgba(0, 0, 0, 0.5);
        }
    }

    /* ============================================
       BASE STYLES
       ============================================ */

    *, *::before, *::after {
        box-sizing: border-box;
        margin: 0;
        padding: 0;
    }

    html {
        font-size: 16px;
        -webkit-font-smoothing: antialiased;
        -moz-osx-font-smoothing: grayscale;
        text-rendering: optimizeLegibility;
    }

    body {
        font-family: var(--v-font-sans);
        font-size: var(--v-text-base);
        line-height: var(--v-leading-normal);
        color: var(--v-text);
        background: var(--v-bg);
        min-height: 100vh;
    }

    /* ============================================
       TYPOGRAPHY
       ============================================ */

    /* Display headings - Apple style */
    .v-display-xl {
        font-size: var(--v-text-7xl);
        font-weight: 700;
        letter-spacing: var(--v-tracking-tighter);
        line-height: var(--v-leading-none);
    }

    .v-display-lg {
        font-size: var(--v-text-6xl);
        font-weight: 700;
        letter-spacing: var(--v-tracking-tighter);
        line-height: var(--v-leading-tight);
    }

    .v-display {
        font-size: var(--v-text-5xl);
        font-weight: 600;
        letter-spacing: var(--v-tracking-tight);
        line-height: var(--v-leading-tight);
    }

    h1, .v-h1 {
        font-size: var(--v-text-4xl);
        font-weight: 600;
        letter-spacing: var(--v-tracking-tight);
        line-height: var(--v-leading-tight);
        color: var(--v-text);
    }

    h2, .v-h2 {
        font-size: var(--v-text-3xl);
        font-weight: 600;
        letter-spacing: var(--v-tracking-tight);
        line-height: var(--v-leading-snug);
        color: var(--v-text);
    }

    h3, .v-h3 {
        font-size: var(--v-text-2xl);
        font-weight: 600;
        line-height: var(--v-leading-snug);
        color: var(--v-text);
    }

    h4, .v-h4 {
        font-size: var(--v-text-xl);
        font-weight: 600;
        line-height: var(--v-leading-snug);
        color: var(--v-text);
    }

    h5, .v-h5 {
        font-size: var(--v-text-lg);
        font-weight: 600;
        line-height: var(--v-leading-normal);
        color: var(--v-text);
    }

    h6, .v-h6 {
        font-size: var(--v-text-sm);
        font-weight: 600;
        text-transform: uppercase;
        letter-spacing: var(--v-tracking-wider);
        color: var(--v-text-secondary);
    }

    p, .v-body {
        font-size: var(--v-text-base);
        line-height: var(--v-leading-relaxed);
        color: var(--v-text-secondary);
    }

    .v-body-lg {
        font-size: var(--v-text-lg);
        line-height: var(--v-leading-relaxed);
        color: var(--v-text-secondary);
    }

    .v-body-sm {
        font-size: var(--v-text-sm);
        line-height: var(--v-leading-relaxed);
        color: var(--v-text-secondary);
    }

    .v-caption {
        font-size: var(--v-text-xs);
        line-height: var(--v-leading-normal);
        color: var(--v-text-tertiary);
    }

    .v-overline {
        font-size: var(--v-text-xs);
        font-weight: 600;
        text-transform: uppercase;
        letter-spacing: var(--v-tracking-wider);
        color: var(--v-text-tertiary);
    }

    /* Text utilities */
    .v-text-gradient {
        background: var(--v-gradient-primary);
        -webkit-background-clip: text;
        -webkit-text-fill-color: transparent;
        background-clip: text;
    }

    .v-text-balance {
        text-wrap: balance;
    }

    /* ============================================
       LAYOUT
       ============================================ */

    .v-container {
        width: 100%;
        max-width: 1200px;
        margin: 0 auto;
        padding: 0 var(--v-space-6);
    }

    .v-container-sm { max-width: 640px; }
    .v-container-md { max-width: 768px; }
    .v-container-lg { max-width: 1024px; }
    .v-container-xl { max-width: 1280px; }
    .v-container-full { max-width: none; }

    .v-section {
        padding: var(--v-space-20) 0;
    }

    .v-section-sm { padding: var(--v-space-12) 0; }
    .v-section-lg { padding: var(--v-space-32) 0; }

    /* Flexbox */
    .v-flex { display: flex; }
    .v-inline-flex { display: inline-flex; }
    .v-flex-col { flex-direction: column; }
    .v-flex-row { flex-direction: row; }
    .v-flex-wrap { flex-wrap: wrap; }
    .v-items-start { align-items: flex-start; }
    .v-items-center { align-items: center; }
    .v-items-end { align-items: flex-end; }
    .v-items-stretch { align-items: stretch; }
    .v-justify-start { justify-content: flex-start; }
    .v-justify-center { justify-content: center; }
    .v-justify-end { justify-content: flex-end; }
    .v-justify-between { justify-content: space-between; }
    .v-justify-around { justify-content: space-around; }
    .v-flex-1 { flex: 1 1 0%; }
    .v-flex-auto { flex: 1 1 auto; }
    .v-flex-none { flex: none; }

    /* Stack (vertical) */
    .v-stack {
        display: flex;
        flex-direction: column;
    }
    .v-stack-xs { gap: var(--v-space-1); }
    .v-stack-sm { gap: var(--v-space-2); }
    .v-stack { gap: var(--v-space-4); }
    .v-stack-md { gap: var(--v-space-6); }
    .v-stack-lg { gap: var(--v-space-8); }
    .v-stack-xl { gap: var(--v-space-12); }

    /* Row (horizontal) */
    .v-row {
        display: flex;
        flex-direction: row;
        align-items: center;
    }
    .v-row-xs { gap: var(--v-space-1); }
    .v-row-sm { gap: var(--v-space-2); }
    .v-row { gap: var(--v-space-4); }
    .v-row-md { gap: var(--v-space-6); }
    .v-row-lg { gap: var(--v-space-8); }

    /* Grid */
    .v-grid {
        display: grid;
        gap: var(--v-space-6);
    }
    .v-grid-cols-1 { grid-template-columns: repeat(1, minmax(0, 1fr)); }
    .v-grid-cols-2 { grid-template-columns: repeat(2, minmax(0, 1fr)); }
    .v-grid-cols-3 { grid-template-columns: repeat(3, minmax(0, 1fr)); }
    .v-grid-cols-4 { grid-template-columns: repeat(4, minmax(0, 1fr)); }
    .v-grid-cols-auto { grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); }

    /* Center */
    .v-center {
        display: flex;
        align-items: center;
        justify-content: center;
    }

    /* ============================================
       CARDS - Airbnb/Stripe inspired
       ============================================ */

    .v-card {
        background: var(--v-surface);
        border-radius: var(--v-radius-xl);
        border: 1px solid var(--v-border);
        overflow: hidden;
        transition: all var(--v-duration) var(--v-ease-out);
    }

    .v-card-elevated {
        background: var(--v-surface);
        border-radius: var(--v-radius-xl);
        border: none;
        box-shadow: var(--v-shadow-md);
    }

    .v-card-interactive {
        cursor: pointer;
    }

    .v-card-interactive:hover {
        transform: translateY(-4px);
        box-shadow: var(--v-shadow-xl);
        border-color: transparent;
    }

    .v-card-glass {
        background: rgba(255, 255, 255, 0.8);
        backdrop-filter: blur(20px) saturate(180%);
        -webkit-backdrop-filter: blur(20px) saturate(180%);
        border: 1px solid rgba(255, 255, 255, 0.3);
    }

    @media (prefers-color-scheme: dark) {
        .v-card-glass {
            background: rgba(24, 24, 27, 0.8);
            border: 1px solid rgba(255, 255, 255, 0.1);
        }
    }

    .v-card-gradient {
        background: var(--v-gradient-mesh);
        background-color: var(--v-surface);
    }

    .v-card-padding {
        padding: var(--v-space-6);
    }

    .v-card-padding-sm { padding: var(--v-space-4); }
    .v-card-padding-lg { padding: var(--v-space-8); }

    /* Card sections */
    .v-card-header {
        padding: var(--v-space-6);
        border-bottom: 1px solid var(--v-border-light);
    }

    .v-card-body {
        padding: var(--v-space-6);
    }

    .v-card-footer {
        padding: var(--v-space-4) var(--v-space-6);
        background: var(--v-bg-secondary);
        border-top: 1px solid var(--v-border-light);
    }

    /* Card media */
    .v-card-media {
        position: relative;
        overflow: hidden;
        aspect-ratio: 16 / 9;
    }

    .v-card-media img {
        width: 100%;
        height: 100%;
        object-fit: cover;
        transition: transform var(--v-duration-slow) var(--v-ease-out);
    }

    .v-card-interactive:hover .v-card-media img {
        transform: scale(1.05);
    }

    /* ============================================
       BUTTONS - Stripe/Apple inspired
       ============================================ */

    .v-btn {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        gap: var(--v-space-2);
        padding: var(--v-space-3) var(--v-space-5);
        font-family: var(--v-font-sans);
        font-size: var(--v-text-sm);
        font-weight: 500;
        line-height: 1;
        border-radius: var(--v-radius-lg);
        border: none;
        cursor: pointer;
        transition: all var(--v-duration) var(--v-ease-out);
        text-decoration: none;
        white-space: nowrap;
        user-select: none;
    }

    .v-btn:disabled {
        opacity: 0.5;
        cursor: not-allowed;
        transform: none !important;
    }

    /* Primary - Gradient with glow */
    .v-btn-primary {
        background: var(--v-gradient-primary);
        color: white;
        box-shadow: var(--v-shadow), 0 4px 14px -4px rgba(102, 126, 234, 0.5);
    }

    .v-btn-primary:hover:not(:disabled) {
        transform: translateY(-2px);
        box-shadow: var(--v-shadow-md), 0 8px 20px -4px rgba(102, 126, 234, 0.6);
    }

    .v-btn-primary:active:not(:disabled) {
        transform: translateY(0);
    }

    /* Secondary */
    .v-btn-secondary {
        background: var(--v-surface);
        color: var(--v-text);
        border: 1px solid var(--v-border);
        box-shadow: var(--v-shadow-xs);
    }

    .v-btn-secondary:hover:not(:disabled) {
        background: var(--v-surface-hover);
        border-color: var(--v-border);
        transform: translateY(-1px);
        box-shadow: var(--v-shadow-sm);
    }

    /* Ghost */
    .v-btn-ghost {
        background: transparent;
        color: var(--v-text-secondary);
    }

    .v-btn-ghost:hover:not(:disabled) {
        background: var(--v-surface-hover);
        color: var(--v-text);
    }

    /* Outline */
    .v-btn-outline {
        background: transparent;
        color: var(--v-primary);
        border: 1px solid var(--v-primary);
    }

    .v-btn-outline:hover:not(:disabled) {
        background: var(--v-primary);
        color: white;
    }

    /* Danger */
    .v-btn-danger {
        background: var(--v-error);
        color: white;
    }

    .v-btn-danger:hover:not(:disabled) {
        background: var(--v-error-dark);
        transform: translateY(-1px);
    }

    /* Sizes */
    .v-btn-xs {
        padding: var(--v-space-1) var(--v-space-2);
        font-size: var(--v-text-xs);
        border-radius: var(--v-radius);
    }

    .v-btn-sm {
        padding: var(--v-space-2) var(--v-space-4);
        font-size: var(--v-text-sm);
    }

    .v-btn-lg {
        padding: var(--v-space-4) var(--v-space-8);
        font-size: var(--v-text-base);
        border-radius: var(--v-radius-xl);
    }

    .v-btn-xl {
        padding: var(--v-space-5) var(--v-space-10);
        font-size: var(--v-text-lg);
        border-radius: var(--v-radius-2xl);
    }

    /* Icon button */
    .v-btn-icon {
        padding: var(--v-space-3);
        aspect-ratio: 1;
    }

    .v-btn-icon-sm { padding: var(--v-space-2); }
    .v-btn-icon-lg { padding: var(--v-space-4); }

    /* Full width */
    .v-btn-full {
        width: 100%;
    }

    /* Button group */
    .v-btn-group {
        display: inline-flex;
    }

    .v-btn-group .v-btn {
        border-radius: 0;
    }

    .v-btn-group .v-btn:first-child {
        border-radius: var(--v-radius-lg) 0 0 var(--v-radius-lg);
    }

    .v-btn-group .v-btn:last-child {
        border-radius: 0 var(--v-radius-lg) var(--v-radius-lg) 0;
    }

    /* ============================================
       INPUTS - Modern form controls
       ============================================ */

    .v-input {
        width: 100%;
        padding: var(--v-space-3) var(--v-space-4);
        font-family: var(--v-font-sans);
        font-size: var(--v-text-base);
        line-height: var(--v-leading-normal);
        color: var(--v-text);
        background: var(--v-surface);
        border: 1px solid var(--v-border);
        border-radius: var(--v-radius-lg);
        outline: none;
        transition: all var(--v-duration) var(--v-ease-out);
    }

    .v-input:hover {
        border-color: var(--v-gray-400);
    }

    .v-input:focus {
        border-color: var(--v-primary);
        box-shadow: 0 0 0 3px rgba(99, 91, 255, 0.15);
    }

    .v-input::placeholder {
        color: var(--v-text-tertiary);
    }

    .v-input-sm {
        padding: var(--v-space-2) var(--v-space-3);
        font-size: var(--v-text-sm);
    }

    .v-input-lg {
        padding: var(--v-space-4) var(--v-space-5);
        font-size: var(--v-text-lg);
    }

    .v-input-error {
        border-color: var(--v-error);
    }

    .v-input-error:focus {
        box-shadow: 0 0 0 3px rgba(239, 68, 68, 0.15);
    }

    /* Search input with icon */
    .v-search-wrapper {
        position: relative;
    }

    .v-search-wrapper .v-search-icon {
        position: absolute;
        left: var(--v-space-4);
        top: 50%;
        transform: translateY(-50%);
        color: var(--v-text-tertiary);
        pointer-events: none;
    }

    .v-search-wrapper .v-input {
        padding-left: var(--v-space-12);
    }

    /* Select */
    .v-select {
        appearance: none;
        background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='20' height='20' viewBox='0 0 24 24' fill='none' stroke='%2371717a' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpath d='m6 9 6 6 6-6'/%3E%3C/svg%3E");
        background-repeat: no-repeat;
        background-position: right var(--v-space-3) center;
        padding-right: var(--v-space-12);
    }

    /* Label */
    .v-label {
        display: block;
        margin-bottom: var(--v-space-2);
        font-size: var(--v-text-sm);
        font-weight: 500;
        color: var(--v-text);
    }

    /* Helper text */
    .v-helper {
        margin-top: var(--v-space-2);
        font-size: var(--v-text-sm);
        color: var(--v-text-tertiary);
    }

    .v-helper-error {
        color: var(--v-error);
    }

    /* ============================================
       BADGES & CHIPS
       ============================================ */

    .v-badge {
        display: inline-flex;
        align-items: center;
        gap: var(--v-space-1);
        padding: var(--v-space-1) var(--v-space-3);
        font-size: var(--v-text-xs);
        font-weight: 500;
        line-height: 1.4;
        border-radius: var(--v-radius-full);
        background: var(--v-bg-tertiary);
        color: var(--v-text-secondary);
    }

    .v-badge-primary {
        background: var(--v-primary-100);
        color: var(--v-primary-700);
    }

    @media (prefers-color-scheme: dark) {
        .v-badge-primary {
            background: rgba(99, 91, 255, 0.2);
            color: var(--v-primary-light);
        }
    }

    .v-badge-success {
        background: rgba(16, 185, 129, 0.15);
        color: var(--v-success);
    }

    .v-badge-warning {
        background: rgba(245, 158, 11, 0.15);
        color: var(--v-warning-dark);
    }

    .v-badge-error {
        background: rgba(239, 68, 68, 0.15);
        color: var(--v-error);
    }

    .v-badge-outline {
        background: transparent;
        border: 1px solid currentColor;
    }

    /* Chip (interactive badge) */
    .v-chip {
        display: inline-flex;
        align-items: center;
        gap: var(--v-space-2);
        padding: var(--v-space-2) var(--v-space-4);
        font-size: var(--v-text-sm);
        font-weight: 500;
        border-radius: var(--v-radius-full);
        background: var(--v-surface-secondary);
        color: var(--v-text);
        border: 1px solid var(--v-border);
        cursor: pointer;
        transition: all var(--v-duration) var(--v-ease-out);
    }

    .v-chip:hover {
        background: var(--v-surface-hover);
    }

    .v-chip-selected {
        background: var(--v-primary);
        color: white;
        border-color: var(--v-primary);
    }

    /* ============================================
       STATS & METRICS - Dashboard style
       ============================================ */

    .v-stat {
        display: flex;
        flex-direction: column;
        gap: var(--v-space-1);
    }

    .v-stat-value {
        font-size: var(--v-text-4xl);
        font-weight: 700;
        letter-spacing: var(--v-tracking-tight);
        line-height: 1;
        color: var(--v-text);
    }

    .v-stat-value-lg {
        font-size: var(--v-text-5xl);
    }

    .v-stat-value-sm {
        font-size: var(--v-text-2xl);
    }

    .v-stat-label {
        font-size: var(--v-text-sm);
        color: var(--v-text-tertiary);
    }

    .v-stat-change {
        display: inline-flex;
        align-items: center;
        gap: var(--v-space-1);
        font-size: var(--v-text-sm);
        font-weight: 500;
    }

    .v-stat-up {
        color: var(--v-success);
    }

    .v-stat-down {
        color: var(--v-error);
    }

    /* Stat card */
    .v-stat-card {
        padding: var(--v-space-6);
        background: var(--v-surface);
        border-radius: var(--v-radius-xl);
        border: 1px solid var(--v-border);
    }

    .v-stat-card-gradient {
        background: var(--v-gradient-primary);
        border: none;
        color: white;
    }

    .v-stat-card-gradient .v-stat-value,
    .v-stat-card-gradient .v-stat-label {
        color: white;
    }

    .v-stat-card-gradient .v-stat-label {
        opacity: 0.8;
    }

    /* ============================================
       AVATARS
       ============================================ */

    .v-avatar {
        display: flex;
        align-items: center;
        justify-content: center;
        width: 40px;
        height: 40px;
        border-radius: var(--v-radius-full);
        background: var(--v-gradient-primary);
        color: white;
        font-weight: 600;
        font-size: var(--v-text-sm);
        overflow: hidden;
        flex-shrink: 0;
    }

    .v-avatar img {
        width: 100%;
        height: 100%;
        object-fit: cover;
    }

    .v-avatar-xs { width: 24px; height: 24px; font-size: var(--v-text-xs); }
    .v-avatar-sm { width: 32px; height: 32px; font-size: var(--v-text-xs); }
    .v-avatar-lg { width: 56px; height: 56px; font-size: var(--v-text-lg); }
    .v-avatar-xl { width: 80px; height: 80px; font-size: var(--v-text-2xl); }

    /* Avatar group */
    .v-avatar-group {
        display: flex;
    }

    .v-avatar-group .v-avatar {
        border: 2px solid var(--v-bg);
        margin-left: -8px;
    }

    .v-avatar-group .v-avatar:first-child {
        margin-left: 0;
    }

    /* ============================================
       PROGRESS & LOADING
       ============================================ */

    .v-progress {
        width: 100%;
        height: 8px;
        background: var(--v-bg-tertiary);
        border-radius: var(--v-radius-full);
        overflow: hidden;
    }

    .v-progress-bar {
        height: 100%;
        background: var(--v-gradient-primary);
        border-radius: var(--v-radius-full);
        transition: width var(--v-duration-slow) var(--v-ease-out);
    }

    .v-progress-sm { height: 4px; }
    .v-progress-lg { height: 12px; }

    /* Spinner */
    .v-spinner {
        width: 24px;
        height: 24px;
        border: 2px solid var(--v-border);
        border-top-color: var(--v-primary);
        border-radius: 50%;
        animation: v-spin 0.8s linear infinite;
    }

    .v-spinner-sm { width: 16px; height: 16px; }
    .v-spinner-lg { width: 40px; height: 40px; border-width: 3px; }

    @keyframes v-spin {
        to { transform: rotate(360deg); }
    }

    /* Skeleton */
    .v-skeleton {
        background: linear-gradient(90deg, var(--v-bg-tertiary) 25%, var(--v-bg-secondary) 50%, var(--v-bg-tertiary) 75%);
        background-size: 200% 100%;
        animation: v-shimmer 1.5s ease-in-out infinite;
        border-radius: var(--v-radius);
    }

    @keyframes v-shimmer {
        0% { background-position: 200% 0; }
        100% { background-position: -200% 0; }
    }

    .v-skeleton-text {
        height: 1em;
        margin-bottom: var(--v-space-2);
    }

    .v-skeleton-circle {
        border-radius: var(--v-radius-full);
    }

    /* ============================================
       TABLES
       ============================================ */

    .v-table-wrapper {
        overflow-x: auto;
        border-radius: var(--v-radius-xl);
        border: 1px solid var(--v-border);
    }

    .v-table {
        width: 100%;
        border-collapse: collapse;
        font-size: var(--v-text-sm);
    }

    .v-table th {
        padding: var(--v-space-4);
        text-align: left;
        font-weight: 600;
        color: var(--v-text-secondary);
        background: var(--v-bg-secondary);
        border-bottom: 1px solid var(--v-border);
    }

    .v-table td {
        padding: var(--v-space-4);
        border-bottom: 1px solid var(--v-border-light);
        color: var(--v-text);
    }

    .v-table tbody tr:last-child td {
        border-bottom: none;
    }

    .v-table tbody tr:hover {
        background: var(--v-surface-hover);
    }

    /* ============================================
       ALERTS & NOTICES
       ============================================ */

    .v-alert {
        display: flex;
        align-items: flex-start;
        gap: var(--v-space-3);
        padding: var(--v-space-4);
        border-radius: var(--v-radius-lg);
        font-size: var(--v-text-sm);
    }

    .v-alert-info {
        background: rgba(99, 91, 255, 0.1);
        border: 1px solid rgba(99, 91, 255, 0.2);
        color: var(--v-primary);
    }

    .v-alert-success {
        background: rgba(16, 185, 129, 0.1);
        border: 1px solid rgba(16, 185, 129, 0.2);
        color: var(--v-success);
    }

    .v-alert-warning {
        background: rgba(245, 158, 11, 0.1);
        border: 1px solid rgba(245, 158, 11, 0.2);
        color: var(--v-warning-dark);
    }

    .v-alert-error {
        background: rgba(239, 68, 68, 0.1);
        border: 1px solid rgba(239, 68, 68, 0.2);
        color: var(--v-error);
    }

    /* ============================================
       DIVIDERS
       ============================================ */

    .v-divider {
        border: none;
        height: 1px;
        background: var(--v-border);
        margin: var(--v-space-6) 0;
    }

    .v-divider-light {
        background: var(--v-border-light);
    }

    .v-divider-vertical {
        width: 1px;
        height: auto;
        align-self: stretch;
        background: var(--v-border);
        margin: 0 var(--v-space-4);
    }

    /* ============================================
       TOOLTIPS
       ============================================ */

    .v-tooltip {
        position: relative;
    }

    .v-tooltip::after {
        content: attr(data-tooltip);
        position: absolute;
        bottom: 100%;
        left: 50%;
        transform: translateX(-50%) translateY(-4px);
        padding: var(--v-space-2) var(--v-space-3);
        font-size: var(--v-text-xs);
        font-weight: 500;
        color: white;
        background: var(--v-gray-900);
        border-radius: var(--v-radius);
        white-space: nowrap;
        opacity: 0;
        visibility: hidden;
        transition: all var(--v-duration-fast) var(--v-ease-out);
        z-index: 50;
    }

    .v-tooltip:hover::after {
        opacity: 1;
        visibility: visible;
        transform: translateX(-50%) translateY(-8px);
    }

    /* ============================================
       ANIMATIONS
       ============================================ */

    .v-animate-fade-in {
        animation: v-fade-in var(--v-duration-slow) var(--v-ease-out);
    }

    @keyframes v-fade-in {
        from { opacity: 0; }
        to { opacity: 1; }
    }

    .v-animate-slide-up {
        animation: v-slide-up var(--v-duration-slow) var(--v-ease-out);
    }

    @keyframes v-slide-up {
        from { opacity: 0; transform: translateY(20px); }
        to { opacity: 1; transform: translateY(0); }
    }

    .v-animate-slide-down {
        animation: v-slide-down var(--v-duration-slow) var(--v-ease-out);
    }

    @keyframes v-slide-down {
        from { opacity: 0; transform: translateY(-20px); }
        to { opacity: 1; transform: translateY(0); }
    }

    .v-animate-scale {
        animation: v-scale var(--v-duration) var(--v-ease-spring);
    }

    @keyframes v-scale {
        from { opacity: 0; transform: scale(0.9); }
        to { opacity: 1; transform: scale(1); }
    }

    .v-animate-bounce {
        animation: v-bounce 0.5s var(--v-ease-spring);
    }

    @keyframes v-bounce {
        0%, 100% { transform: translateY(0); }
        50% { transform: translateY(-10px); }
    }

    /* Stagger children */
    .v-stagger > * {
        animation: v-slide-up var(--v-duration-slow) var(--v-ease-out) backwards;
    }

    .v-stagger > *:nth-child(1) { animation-delay: 0ms; }
    .v-stagger > *:nth-child(2) { animation-delay: 60ms; }
    .v-stagger > *:nth-child(3) { animation-delay: 120ms; }
    .v-stagger > *:nth-child(4) { animation-delay: 180ms; }
    .v-stagger > *:nth-child(5) { animation-delay: 240ms; }
    .v-stagger > *:nth-child(6) { animation-delay: 300ms; }
    .v-stagger > *:nth-child(7) { animation-delay: 360ms; }
    .v-stagger > *:nth-child(8) { animation-delay: 420ms; }

    /* Hover effects */
    .v-hover-lift {
        transition: transform var(--v-duration) var(--v-ease-out);
    }

    .v-hover-lift:hover {
        transform: translateY(-4px);
    }

    .v-hover-glow {
        transition: box-shadow var(--v-duration) var(--v-ease-out);
    }

    .v-hover-glow:hover {
        box-shadow: var(--v-shadow-glow);
    }

    /* ============================================
       UTILITIES
       ============================================ */

    /* Spacing */
    .v-p-0 { padding: 0; }
    .v-p-1 { padding: var(--v-space-1); }
    .v-p-2 { padding: var(--v-space-2); }
    .v-p-3 { padding: var(--v-space-3); }
    .v-p-4 { padding: var(--v-space-4); }
    .v-p-6 { padding: var(--v-space-6); }
    .v-p-8 { padding: var(--v-space-8); }

    .v-m-0 { margin: 0; }
    .v-m-auto { margin: auto; }
    .v-mt-4 { margin-top: var(--v-space-4); }
    .v-mt-6 { margin-top: var(--v-space-6); }
    .v-mt-8 { margin-top: var(--v-space-8); }
    .v-mb-4 { margin-bottom: var(--v-space-4); }
    .v-mb-6 { margin-bottom: var(--v-space-6); }
    .v-mb-8 { margin-bottom: var(--v-space-8); }

    /* Text */
    .v-text-left { text-align: left; }
    .v-text-center { text-align: center; }
    .v-text-right { text-align: right; }

    .v-font-normal { font-weight: 400; }
    .v-font-medium { font-weight: 500; }
    .v-font-semibold { font-weight: 600; }
    .v-font-bold { font-weight: 700; }

    .v-text-primary { color: var(--v-primary); }
    .v-text-secondary { color: var(--v-text-secondary); }
    .v-text-tertiary { color: var(--v-text-tertiary); }
    .v-text-success { color: var(--v-success); }
    .v-text-warning { color: var(--v-warning); }
    .v-text-error { color: var(--v-error); }

    /* Backgrounds */
    .v-bg-primary { background: var(--v-primary); }
    .v-bg-gradient { background: var(--v-gradient-primary); }
    .v-bg-gradient-mesh { background: var(--v-gradient-mesh); }
    .v-bg-surface { background: var(--v-surface); }
    .v-bg-secondary { background: var(--v-bg-secondary); }

    /* Borders */
    .v-border { border: 1px solid var(--v-border); }
    .v-border-none { border: none; }
    .v-rounded { border-radius: var(--v-radius); }
    .v-rounded-lg { border-radius: var(--v-radius-lg); }
    .v-rounded-xl { border-radius: var(--v-radius-xl); }
    .v-rounded-2xl { border-radius: var(--v-radius-2xl); }
    .v-rounded-full { border-radius: var(--v-radius-full); }

    /* Shadows */
    .v-shadow { box-shadow: var(--v-shadow); }
    .v-shadow-md { box-shadow: var(--v-shadow-md); }
    .v-shadow-lg { box-shadow: var(--v-shadow-lg); }
    .v-shadow-xl { box-shadow: var(--v-shadow-xl); }
    .v-shadow-none { box-shadow: none; }

    /* Overflow */
    .v-overflow-hidden { overflow: hidden; }
    .v-overflow-auto { overflow: auto; }

    /* Position */
    .v-relative { position: relative; }
    .v-absolute { position: absolute; }
    .v-fixed { position: fixed; }
    .v-sticky { position: sticky; }

    /* Display */
    .v-hidden { display: none; }
    .v-block { display: block; }
    .v-inline-block { display: inline-block; }

    /* Width/Height */
    .v-w-full { width: 100%; }
    .v-h-full { height: 100%; }
    .v-min-h-screen { min-height: 100vh; }

    /* Cursor */
    .v-cursor-pointer { cursor: pointer; }

    /* ============================================
       SPECIAL COMPONENTS
       ============================================ */

    /* Hero section */
    .v-hero {
        position: relative;
        padding: var(--v-space-24) 0;
        text-align: center;
        overflow: hidden;
    }

    .v-hero-gradient {
        background: var(--v-gradient-mesh);
        background-color: var(--v-bg);
    }

    /* Feature grid */
    .v-features {
        display: grid;
        gap: var(--v-space-8);
        grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
    }

    .v-feature {
        text-align: center;
        padding: var(--v-space-6);
    }

    .v-feature-icon {
        width: 48px;
        height: 48px;
        margin: 0 auto var(--v-space-4);
        display: flex;
        align-items: center;
        justify-content: center;
        background: var(--v-gradient-primary);
        border-radius: var(--v-radius-lg);
        color: white;
    }

    /* Pricing card */
    .v-pricing {
        padding: var(--v-space-8);
        background: var(--v-surface);
        border-radius: var(--v-radius-2xl);
        border: 1px solid var(--v-border);
        text-align: center;
    }

    .v-pricing-featured {
        background: var(--v-gradient-primary);
        border: none;
        color: white;
        transform: scale(1.05);
        box-shadow: var(--v-shadow-xl);
    }

    .v-pricing-price {
        font-size: var(--v-text-5xl);
        font-weight: 700;
        letter-spacing: var(--v-tracking-tight);
    }

    /* Testimonial */
    .v-testimonial {
        padding: var(--v-space-8);
        background: var(--v-surface);
        border-radius: var(--v-radius-2xl);
        border: 1px solid var(--v-border);
    }

    .v-testimonial-content {
        font-size: var(--v-text-lg);
        line-height: var(--v-leading-relaxed);
        color: var(--v-text);
        margin-bottom: var(--v-space-6);
    }

    /* ============================================
       CHART STYLES (Recharts)
       ============================================ */

    .recharts-wrapper {
        font-family: var(--v-font-sans) !important;
    }

    .recharts-text {
        fill: var(--v-text-tertiary) !important;
        font-size: 12px !important;
    }

    .recharts-cartesian-grid line {
        stroke: var(--v-border-light) !important;
    }

    .recharts-tooltip-wrapper .recharts-default-tooltip {
        background: var(--v-surface) !important;
        border: 1px solid var(--v-border) !important;
        border-radius: var(--v-radius-lg) !important;
        box-shadow: var(--v-shadow-lg) !important;
        padding: var(--v-space-3) var(--v-space-4) !important;
    }

    /* ============================================
       LOADING STATES
       ============================================ */

    .loading {
        display: flex;
        flex-direction: column;
        align-items: center;
        justify-content: center;
        min-height: 200px;
        gap: var(--v-space-4);
        color: var(--v-text-tertiary);
    }

    .loading-spinner {
        width: 32px;
        height: 32px;
        border: 3px solid var(--v-border);
        border-top-color: var(--v-primary);
        border-radius: 50%;
        animation: v-spin 0.8s linear infinite;
    }

    .error {
        padding: var(--v-space-6);
        background: rgba(239, 68, 68, 0.1);
        border: 1px solid rgba(239, 68, 68, 0.2);
        border-radius: var(--v-radius-lg);
        color: var(--v-error);
        font-size: var(--v-text-sm);
    }

    #root {
        min-height: 100px;
    }
    """

    /// Tailwind config that extends with Vaizor theme
    static let tailwindConfig: String = """
    tailwind.config = {
        darkMode: 'media',
        theme: {
            extend: {
                colors: {
                    primary: {
                        DEFAULT: '#635bff',
                        50: '#f5f3ff',
                        100: '#ede9fe',
                        200: '#ddd6fe',
                        300: '#c4b5fd',
                        400: '#a78bfa',
                        500: '#8b5cf6',
                        600: '#7c3aed',
                        700: '#6d28d9',
                        800: '#5b21b6',
                        900: '#4c1d95',
                    },
                    accent: '#00d4ff',
                },
                fontFamily: {
                    sans: ['-apple-system', 'BlinkMacSystemFont', 'SF Pro Display', 'Segoe UI', 'Roboto', 'sans-serif'],
                    mono: ['SF Mono', 'Fira Code', 'JetBrains Mono', 'Consolas', 'monospace'],
                },
                borderRadius: {
                    DEFAULT: '0.5rem',
                    'xl': '1rem',
                    '2xl': '1.5rem',
                },
                boxShadow: {
                    'glow': '0 0 40px -10px rgba(99, 91, 255, 0.5)',
                },
            },
        },
    }
    """
}
