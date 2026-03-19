#!/bin/bash
# Apply RTL patches to anytype-ts and create a PR
# Run from anywhere — script handles cloning and setup
set -e

FORK_OWNER=$(gh api user -q .login)
UPSTREAM="anyproto/anytype-ts"
BRANCH="fix/rtl-enhancements"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Step 1: Fork & clone ==="
if [ ! -d "$HOME/anytype-ts" ]; then
    gh repo fork "$UPSTREAM" --clone --default-branch-only -- "$HOME/anytype-ts"
    cd "$HOME/anytype-ts"
else
    cd "$HOME/anytype-ts"
    git fetch upstream 2>/dev/null || git remote add upstream "https://github.com/$UPSTREAM.git" && git fetch upstream
    git checkout main
    git pull upstream main
fi

echo ""
echo "=== Step 2: Create branch ==="
git checkout -b "$BRANCH" 2>/dev/null || git checkout "$BRANCH"

echo ""
echo "=== Step 3: Apply patches ==="

# --- text.scss: add numbered marker bidi-override + callout RTL ---
# Find the existing .flex.isRtl block and expand it
TEXTSCSS="src/scss/block/text.scss"

# Insert after the closing of .marker margin rule (line with "margin-left: 6px")
# We add the numbered marker fix inside .flex.isRtl
sed -i '/\.flex\.isRtl {/{
  # We need to find the closing brace of this block and add before it
}' "$TEXTSCSS"

# More reliable: use python for the multi-line insert
python3 << 'PYEOF'
import re

with open("src/scss/block/text.scss", "r") as f:
    content = f.read()

# 1. Expand .flex.isRtl block: add numbered marker fix
old_rtl_block = """\t\t.flex.isRtl {
\t\t\t.markers {
\t\t\t\t.marker { margin-right: 0px; margin-left: 6px; }
\t\t\t}
\t\t}"""

new_rtl_block = """\t\t.flex.isRtl {
\t\t\t.markers {
\t\t\t\t.marker { margin-right: 0px; margin-left: 6px; }
\t\t\t}

\t\t\t/* Numbered markers: keep digit+period in LTR order to prevent ".1" instead of "1." */
\t\t\t.markers .marker.markerNumbered > span {
\t\t\t\tdirection: ltr;
\t\t\t\tunicode-bidi: bidi-override;
\t\t\t}
\t\t}"""

content = content.replace(old_rtl_block, new_rtl_block)

# 2. Add callout RTL children padding fix after the existing callout .children rule
old_callout_children = """\t\t\t> .children { padding-right: 16px; }
\t\t}
\t}"""

new_callout_children = """\t\t\t> .children { padding-right: 16px; }
\t\t}
\t}
\t/* Callout RTL: flip children padding */
\t.block.blockText.textCallout.align2 > .wrapContent > .children { padding-left: 16px; padding-right: 0px; }"""

content = content.replace(old_callout_children, new_callout_children)

with open("src/scss/block/text.scss", "w") as f:
    f.write(content)

print("✓ text.scss patched")
PYEOF

# --- common.scss: add toggle arrow mirror for RTL ---
python3 << 'PYEOF'
with open("src/scss/block/common.scss", "r") as f:
    content = f.read()

old_toggle = "\t.block.isToggled > .wrapContent > .selectionTarget > .dropTarget > .flex > .markers > .markerToggle { transform: rotateZ(90deg); }"

new_toggle = """\t.block.isToggled > .wrapContent > .selectionTarget > .dropTarget > .flex > .markers > .markerToggle { transform: rotateZ(90deg); }

\t/* RTL: mirror toggle arrow so collapsed state points left instead of right */
\t.block.align2 > .wrapContent > .selectionTarget > .dropTarget > .flex.isRtl > .markers > .markerToggle {
\t\ttransform: scaleX(-1);
\t}
\t.block.align2.isToggled > .wrapContent > .selectionTarget > .dropTarget > .flex.isRtl > .markers > .markerToggle {
\t\ttransform: scaleX(-1) rotateZ(90deg);
\t}"""

content = content.replace(old_toggle, new_toggle)

with open("src/scss/block/common.scss", "w") as f:
    f.write(content)

print("✓ common.scss patched")
PYEOF

echo ""
echo "=== Step 4: Verify changes ==="
git diff --stat
echo ""
git diff

echo ""
read -p "Look good? Press Enter to commit and create PR, or Ctrl+C to abort..."

echo ""
echo "=== Step 5: Commit ==="
git add src/scss/block/text.scss src/scss/block/common.scss
git commit -m "$(cat <<'EOF'
fix: improve RTL support for numbered lists, toggles, and callouts

Enhances the existing RTL infrastructure with three targeted CSS fixes:

1. Numbered list markers: Apply unicode-bidi: bidi-override to keep
   digit+period in correct LTR order (prevents ".1" instead of "1.")
2. Toggle arrows: Mirror collapsed arrow direction for RTL blocks
   so it points left (matching reading direction)
3. Callout blocks: Flip children padding for RTL-aligned callouts

No logic changes — detection and isRtl class assignment already work
correctly. These are purely CSS refinements.

Ref: #757
EOF
)"

echo ""
echo "=== Step 6: Push & create PR ==="
git push -u origin "$BRANCH"

gh pr create \
    --repo "$UPSTREAM" \
    --title "fix: improve RTL support for numbered lists, toggles, and callouts" \
    --body "$(cat <<'EOF'
## Summary

Enhances the existing RTL infrastructure with three targeted CSS fixes. No logic changes — detection and `isRtl` class assignment already work correctly.

### Changes

**1. Numbered list period placement** (`text.scss`)
The BiDi algorithm treats the period in numbered markers as a neutral character, causing it to appear before the digit (`.1` instead of `1.`). Fix: apply `direction: ltr; unicode-bidi: bidi-override` on `.marker.markerNumbered > span` inside `.flex.isRtl`.

**2. Toggle arrow mirroring** (`common.scss`)
The collapsed toggle arrow (▶) points right, which is backwards for RTL content. Fix: apply `scaleX(-1)` on the marker when the block has `align2` (RTL alignment) and `.flex.isRtl`.

**3. Callout children padding** (`text.scss`)
Callout blocks have `padding-right: 16px` on `.children`, which is correct for LTR but wrong for RTL. Fix: add an `align2` override that swaps the padding to the left side.

### Testing

- Create a text block starting with Hebrew (e.g., `שלום`)
- Verify numbered lists show `1.` not `.1`
- Verify toggle arrows point left when collapsed
- Verify callout child blocks indent from the right side

### Context

- Ref: #757
- Proof of concept: https://github.com/njlevy/anytype-rtl
- Only touches SCSS files — minimal surface area, easy to review
EOF
)"

echo ""
echo "✅ Done! PR created."
EOF
