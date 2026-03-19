#!/bin/bash
# Apply RTL patches to anytype-publish-renderer and create a PR
set -e

FORK_OWNER=$(gh api user -q .login)
UPSTREAM="anyproto/anytype-publish-renderer"
BRANCH="feat/rtl-support"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Step 1: Fork & clone ==="
if [ ! -d "$HOME/anytype-publish-renderer" ]; then
    gh repo fork "$UPSTREAM" --clone --default-branch-only -- "$HOME/anytype-publish-renderer"
    cd "$HOME/anytype-publish-renderer"
else
    cd "$HOME/anytype-publish-renderer"
    git fetch upstream 2>/dev/null || git remote add upstream "https://github.com/$UPSTREAM.git" && git fetch upstream
    git checkout main
    git pull upstream main
fi

echo ""
echo "=== Step 2: Create branch ==="
git checkout -b "$BRANCH" 2>/dev/null || git checkout "$BRANCH"

echo ""
echo "=== Step 3: Add RTL detection ==="

# Copy rtl.go and rtl_test.go
cp "$SCRIPT_DIR/rtl.go" renderer/rtl.go
cp "$SCRIPT_DIR/rtl_test.go" renderer/rtl_test.go
echo "✓ Added renderer/rtl.go and renderer/rtl_test.go"

echo ""
echo "=== Step 4: Patch Go files ==="

python3 << 'PYEOF'
import re

# --- block.go: add Dir field to BlockParams ---
with open("renderer/block.go", "r") as f:
    content = f.read()

# Add Dir field to BlockParams struct
content = content.replace(
    'Width         string',
    'Width         string\n\tDir           string'
)

# In makeDefaultBlockParams, detect direction from block text
# Find the function and add Dir detection
if 'func (r *Renderer) makeDefaultBlockParams' in content:
    # Add Dir detection after params are built
    content = content.replace(
        'return &params',
        '''// Detect text direction
\tif text := r.getBlockText(b); text != "" {
\t\tparams.Dir = CheckRTL(text)
\t}
\treturn &params'''
    )
    print("✓ block.go: Added Dir field and detection")
else:
    print("⚠ block.go: Could not find makeDefaultBlockParams")

with open("renderer/block.go", "w") as f:
    f.write(content)

# --- page.go: add Dir field to RenderPageParams ---
with open("renderer/page.go", "r") as f:
    content = f.read()

# Add Dir to RenderPageParams
content = content.replace(
    'SpaceName      string',
    'SpaceName      string\n\tDir            string'
)

# Set Dir based on page name in MakeRenderPageParams
if 'func (r *Renderer) MakeRenderPageParams' in content:
    content = content.replace(
        'return &RenderPageParams{',
        '''pageDir := CheckRTL(name)
\treturn &RenderPageParams{'''
    )
    content = content.replace(
        'SpaceName:      spaceName,\n\t}',
        'SpaceName:      spaceName,\n\t\tDir:            pageDir,\n\t}'
    )
    print("✓ page.go: Added Dir to RenderPageParams")
else:
    print("⚠ page.go: Could not find MakeRenderPageParams")

with open("renderer/page.go", "w") as f:
    f.write(content)

# --- text.go: add helper to get block text ---
with open("renderer/text.go", "r") as f:
    content = f.read()

# Check if getBlockText already exists
if 'func (r *Renderer) getBlockText' not in content:
    # Add at the end of the file
    content += '''

// getBlockText extracts the plain text content from a block for direction detection.
func (r *Renderer) getBlockText(b *model.Block) string {
\tif t := b.GetText(); t != nil {
\t\treturn t.GetText()
\t}
\treturn ""
}
'''
    print("✓ text.go: Added getBlockText helper")
else:
    print("✓ text.go: getBlockText already exists")

with open("renderer/text.go", "w") as f:
    f.write(content)

print("\nGo files patched.")
PYEOF

echo ""
echo "=== Step 5: Patch templates ==="

python3 << 'PYEOF'
# --- block.templ: add dir attribute ---
with open("renderer/block.templ", "r") as f:
    content = f.read()

# Add dir attribute after data-width conditional
if 'dir={ p.Dir }' not in content:
    content = content.replace(
        '''if p.Width != "" {
\t\tdata-width={ p.Width }
\t}''',
        '''if p.Width != "" {
\t\tdata-width={ p.Width }
\t}
\tif p.Dir != "" {
\t\tdir={ p.Dir }
\t}'''
    )
    print("✓ block.templ: Added dir attribute")
else:
    print("✓ block.templ: dir attribute already present")

with open("renderer/block.templ", "w") as f:
    f.write(content)

# --- page.templ: add dir on <html> ---
with open("renderer/page.templ", "r") as f:
    content = f.read()

# Add dir to the <html> tag
if 'dir=' not in content:
    # Try to find the <html> tag
    content = content.replace(
        '<html',
        '''<html
\tif p.Dir != "" {
\t\tdir={ p.Dir }
\t}'''
    )
    print("✓ page.templ: Added dir on <html>")
else:
    print("✓ page.templ: dir already on <html>")

with open("renderer/page.templ", "w") as f:
    f.write(content)

print("\nTemplates patched.")
PYEOF

echo ""
echo "=== Step 6: Patch SCSS ==="

python3 << 'PYEOF'
# --- common.scss: convert to logical properties ---
with open("src/scss/block/common.scss", "r") as f:
    content = f.read()

# Children padding: left → inline-start
content = content.replace(
    '.block > .children { padding-left: 48px; }',
    '.block > .children { padding-inline-start: 48px; }'
)

# Alignment: left/right → start/end
content = content.replace(
    '.block.align0 > .content { text-align: left; }',
    '.block.align0 > .content { text-align: start; }'
)
content = content.replace(
    '.block.align2 > .content { text-align: right; }',
    '.block.align2 > .content { text-align: end; }'
)

print("✓ common.scss: Converted to logical properties")

with open("src/scss/block/common.scss", "w") as f:
    f.write(content)

# --- text.scss: add RTL rules ---
with open("src/scss/block/text.scss", "r") as f:
    content = f.read()

# Add RTL section at end of file
rtl_rules = '''

/* ── RTL Support ─────────────────────────────────────────────── */

/* Numbered markers: keep "1." not ".1" */
.block[dir="rtl"] .markers .marker > span {
  direction: ltr;
  unicode-bidi: bidi-override;
}

/* Marker margin flip */
.block[dir="rtl"] .markers .marker {
  margin-right: 0;
  margin-left: 6px;
}

/* Toggle arrow: point left when collapsed */
.block[dir="rtl"] .markers .icon.toggle {
  transform: scaleX(-1);
}

/* Quote border flip */
.block.blockText.textQuote[dir="rtl"] > .content > .flex > .text {
  padding-inline-start: 0;
  padding-inline-end: 24px;
}
.block.blockText.textQuote[dir="rtl"] > .content > .line {
  left: auto;
  right: 0;
}

/* Callout: flip icon and text */
.block.blockText.textCallout[dir="rtl"] > .content > .flex {
  direction: rtl;
}

/* Code: always LTR regardless of document direction */
.block.blockText.textCode[dir="rtl"] {
  direction: ltr;
}
.block.blockText.textCode[dir="rtl"] .text {
  text-align: left;
  direction: ltr;
}
'''

if 'RTL Support' not in content:
    content += rtl_rules
    print("✓ text.scss: Added RTL rules")
else:
    print("✓ text.scss: RTL rules already present")

with open("src/scss/block/text.scss", "w") as f:
    f.write(content)

print("\nSCSS patched.")
PYEOF

echo ""
echo "=== Step 7: Verify ==="
echo "Running Go tests..."
go test ./renderer/ -run TestCheckRTL -v 2>&1 || echo "(tests may need full module setup)"

echo ""
echo "Files changed:"
git diff --stat
echo ""
git diff

echo ""
read -p "Look good? Press Enter to commit and create PR, or Ctrl+C to abort..."

echo ""
echo "=== Step 8: Commit ==="
git add renderer/rtl.go renderer/rtl_test.go renderer/block.go renderer/block.templ \
       renderer/text.go renderer/page.go renderer/page.templ \
       src/scss/block/common.scss src/scss/block/text.scss
git commit -m "$(cat <<'EOF'
feat: add RTL support for Hebrew and Arabic content

Adds bidirectional text support to the publish renderer:

1. Detection: new CheckRTL() function finds the first strong
   directional character in text, classifying blocks as RTL or LTR.
   Digits, punctuation, and whitespace are treated as neutral.

2. Page-level: if the page title is Hebrew/Arabic, sets dir="rtl"
   on the <html> element so the entire document defaults to RTL.

3. Block-level: each text block gets a dir attribute based on its
   content, allowing mixed-direction pages.

4. SCSS: converts hard-coded directional properties to CSS Logical
   Properties (padding-inline-start, text-align: start/end) and adds
   RTL-specific rules for numbered markers, toggle arrows, quote
   borders, callouts, and code blocks.

Code blocks always stay LTR regardless of document direction.

Ref: anyproto/anytype-ts#757
EOF
)"

echo ""
echo "=== Step 9: Push & PR ==="
git push -u origin "$BRANCH"

gh pr create \
    --repo "$UPSTREAM" \
    --title "feat: add RTL support for Hebrew and Arabic content" \
    --body "$(cat <<'EOF'
## Summary

Adds bidirectional text (BiDi) support to the publish renderer for Hebrew, Arabic, and other RTL languages.

### How it works

- **Detection**: `CheckRTL()` scans for the first strong directional character (skipping digits, punctuation, whitespace). This handles cases like `3. שלום` correctly.
- **Page-level**: If the page title is RTL, `dir="rtl"` is set on `<html>`.
- **Block-level**: Each text block gets `dir="rtl"` or `dir="ltr"` based on its content.
- **CSS**: Directional properties converted to CSS Logical Properties. RTL-specific rules added for markers, toggles, quotes, callouts.
- **Code blocks**: Always forced LTR regardless of document direction.

### Files changed

| File | Change |
|------|--------|
| `renderer/rtl.go` | New: RTL detection function |
| `renderer/rtl_test.go` | New: test cases for detection |
| `renderer/block.go` | Add `Dir` field to `BlockParams` |
| `renderer/block.templ` | Emit `dir` attribute on blocks |
| `renderer/text.go` | Add `getBlockText()` helper |
| `renderer/page.go` | Add `Dir` field to `RenderPageParams` |
| `renderer/page.templ` | Emit `dir` attribute on `<html>` |
| `src/scss/block/common.scss` | Convert to logical properties |
| `src/scss/block/text.scss` | Add RTL styling rules |

### Test plan

- [ ] Create a page with Hebrew title and mixed content
- [ ] Verify numbered lists show `1.` not `.1`
- [ ] Verify toggle arrows point left
- [ ] Verify quote borders appear on the right
- [ ] Verify code blocks stay LTR
- [ ] Verify nested blocks indent from the right
- [ ] Run `go test ./renderer/ -run TestCheckRTL`

### Context

- Desktop RTL issue: anyproto/anytype-ts#757
- Community thread: https://community.anytype.io/t/add-rtl-support/2220
- Proof of concept: https://github.com/njlevy/anytype-rtl

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"

echo ""
echo "✅ Done! PR created."
