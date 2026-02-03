#!/bin/bash
# UI/UX Lint Script for Vaizor
# Checks for design system violations

set -e

VIEWS_DIR="Sources/vaizor/Presentation/Views"
THEME_DIR="Sources/vaizor/Presentation/Theme"
ALL_SRC="Sources/vaizor"

echo "=========================================="
echo "  Vaizor UI/UX Design System Lint Report"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Function to count and report
count_violations() {
    local pattern="$1"
    local description="$2"
    local exclude="$3"
    local count

    if [ -n "$exclude" ]; then
        count=$(grep -rn "$pattern" "$ALL_SRC" 2>/dev/null | grep -v "$exclude" | wc -l | tr -d ' ')
    else
        count=$(grep -rn "$pattern" "$ALL_SRC" 2>/dev/null | wc -l | tr -d ' ')
    fi

    if [ "$count" -gt 10 ]; then
        echo -e "${RED}[HIGH]${NC} $description: $count instances"
    elif [ "$count" -gt 0 ]; then
        echo -e "${YELLOW}[MED]${NC}  $description: $count instances"
    else
        echo -e "${GREEN}[OK]${NC}   $description: $count instances"
    fi
}

echo "=== Hard-coded Colors ==="
count_violations 'Color(hex:' "Hard-coded hex colors" "ThemeColors\|ProviderColors\|CodeSyntaxColors"
count_violations '#[0-9a-fA-F]\{6\}' "Inline hex strings" ""

echo ""
echo "=== Button Style Violations ==="
count_violations '\.buttonStyle(\.plain)' "Plain button styles (should use VaizorButtonStyle)" ""
count_violations '\.buttonStyle(\.borderedProminent)' "System bordered prominent (consider VaizorButtonStyle)" ""
count_violations '\.buttonStyle(\.bordered)' "System bordered (consider VaizorButtonStyle)" ""

echo ""
echo "=== Spacing Violations ==="
count_violations '\.padding([0-9]' "Inline padding values (should use VaizorSpacing)" "VaizorSpacing"
count_violations '\.padding(\.' "Potential inline padding" ""

echo ""
echo "=== Typography Violations ==="
count_violations '\.font(\.system(size:' "Inline font sizes (should use VaizorTypography)" "VaizorTypography"
count_violations 'design: \.rounded' "Rounded font design (not native to macOS)" ""

echo ""
echo "=== Corner Radius Violations ==="
count_violations '\.cornerRadius([0-9]' "Inline corner radius (should use VaizorSpacing.radius*)" "VaizorSpacing"

echo ""
echo "=== Shadow Violations ==="
count_violations '\.shadow(color:' "Inline shadow definitions (should use nativeShadow)" "nativeShadow"

echo ""
echo "=== Gradient Usage ==="
count_violations 'LinearGradient' "Gradient usages (verify if needed)" ""

echo ""
echo "=== Animation Timing ==="
count_violations 'spring(response:' "Inline spring animations" "VaizorAnimations"
count_violations 'easeInOut(duration:' "Inline easeInOut animations" "VaizorAnimations"

echo ""
echo "=== Focus Ring Check ==="
focus_ring_count=$(grep -rn 'FocusState\|@FocusState' "$ALL_SRC" 2>/dev/null | wc -l | tr -d ' ')
echo "Focus state declarations: $focus_ring_count"
focus_ring_impl=$(grep -rn 'nativeFocusRing\|FocusRingModifier' "$ALL_SRC" 2>/dev/null | wc -l | tr -d ' ')
echo "Focus ring implementations: $focus_ring_impl"

echo ""
echo "=== Material Usage ==="
count_violations '\.regularMaterial' "Regular material (correct)" ""
count_violations '\.thinMaterial' "Thin material (correct for dropdowns)" ""
count_violations '\.ultraThinMaterial' "Ultra thin material (correct for toolbars)" ""

echo ""
echo "=========================================="
echo "  Summary"
echo "=========================================="

total_plain=$(grep -rn '\.buttonStyle(\.plain)' "$ALL_SRC" 2>/dev/null | wc -l | tr -d ' ')
total_hex=$(grep -rn 'Color(hex:' "$ALL_SRC" 2>/dev/null | grep -v "ThemeColors\|ProviderColors\|CodeSyntaxColors" | wc -l | tr -d ' ')
total_inline_font=$(grep -rn '\.font(\.system(size:' "$ALL_SRC" 2>/dev/null | grep -v "VaizorTypography" | wc -l | tr -d ' ')

echo ""
echo "Key violations to address:"
echo "  - Plain button styles: $total_plain"
echo "  - Hard-coded colors: $total_hex"
echo "  - Inline fonts: $total_inline_font"
echo ""

# Calculate rough compliance score
# Lower violations = higher score
base_score=100
deductions=$((total_plain + total_hex + total_inline_font))
# Cap deductions at 30 points
if [ "$deductions" -gt 30 ]; then
    deductions=30
fi
score=$((base_score - deductions))

echo "Estimated Native macOS Compliance Score: $score/100"
echo ""
