# anytype-rtl: Upstream Patch Guide

## Current State of RTL in Anytype

Anytype **already has partial RTL support** since v0.45.1. Here's exactly how it works:

### Desktop App (anytype-ts)

**Detection** — `src/ts/lib/util/string.ts:464`:
```ts
checkRtl(s: string): boolean {
  return /^[\u0591-\u05EA\u05F0-\u05F4\u0600-\u06FF]/.test(s);
}
```
Checks if the **first character** is Hebrew or Arabic. Simple but effective.

**Application** — `src/ts/component/block/text.tsx:54`:
```ts
const checkRtl = U.String.checkRtl(text) || fields.isRtlDetected;
```
When RTL is detected, it:
1. Sets `fields.isRtlDetected = true` on the block (persisted)
2. Calls `C.BlockListSetAlign(rootId, [id], I.BlockHAlign.Right)` — right-aligns the block
3. Adds class `isRtl` to the `.flex` container

**CSS** — `src/scss/common.scss:109`:
```css
.isRtl { direction: rtl; }
```

And `src/scss/block/text.scss:35`:
```css
.flex.isRtl {
  .markers {
    .marker { margin-right: 0px; margin-left: 6px; }
  }
}
```

### What's Missing

The desktop app's RTL support is **alignment + direction only**. It:
- ✅ Detects Hebrew/Arabic first character
- ✅ Right-aligns the block
- ✅ Sets `direction: rtl` via `.isRtl` class
- ✅ Flips marker margins

But it does NOT:
- ❌ Flip flex layout for markers (bullets/numbers appear on the wrong side)
- ❌ Mirror quote border (stays on the left)
- ❌ Mirror callout icon layout
- ❌ Mirror toggle arrow
- ❌ Flip nested block indentation
- ❌ Handle numbered list period placement (`.1` instead of `1.`)
- ❌ Apply any of this to published/shared pages

### Published Pages (anytype-publish-renderer)

The publish renderer has **zero RTL support**. The `block.templ` template doesn't pass any direction attribute, and `text.go` doesn't detect RTL content. Published pages are always LTR.

---

## Patches Needed

### Patch 1: Desktop App SCSS (`anytype-ts`)

File: `src/scss/block/text.scss`

Add after the existing `.flex.isRtl` block (line 39):

```scss
.flex.isRtl {
  .markers {
    .marker { margin-right: 0px; margin-left: 6px; }
  }

  /* === RTL enhancements === */

  /* Flip marker+text layout so markers appear on the right */
  flex-direction: row-reverse;

  /* Number markers: prevent period flip */
  .markers .marker.number > span {
    direction: ltr;
    unicode-bidi: bidi-override;
  }
}
```

File: `src/scss/block/text.scss` — Quote section:

```scss
/* Quote: flip border to right side in RTL */
.block.blockText.textQuote.isRtl {
  > .wrapContent > .selectionTarget > .dropTarget {
    > .additional > .line {
      left: auto;
      right: 11px;
    }
    > .flex {
      padding-left: 0;
      padding-right: 24px;
    }
  }
}
```

File: `src/scss/block/text.scss` — Callout:

```scss
/* Callout: icon+text already handled by flex-direction: row-reverse on .isRtl */
```

File: `src/scss/common.scss` — Add nested indent flip:

```scss
.isRtl { direction: rtl; }
/* Nested block indent flip for RTL */
.block:has(> .wrapContent .flex.isRtl) > .children {
  margin-left: 0;
  margin-right: 26px;
}
```

### Patch 2: Published Pages (`anytype-publish-renderer`)

File: `renderer/text.go` — Add RTL detection function:

```go
// checkRtl returns true if the first strong character is RTL (Hebrew/Arabic)
func checkRtl(s string) bool {
  for _, r := range s {
    // Hebrew: U+0591-U+05EA, U+05F0-U+05F4
    if r >= 0x0591 && r <= 0x05F4 {
      return true
    }
    // Arabic: U+0600-U+06FF
    if r >= 0x0600 && r <= 0x06FF {
      return true
    }
    // Latin: strong LTR
    if (r >= 'A' && r <= 'Z') || (r >= 'a' && r <= 'z') {
      return false
    }
  }
  return false
}
```

File: `renderer/block.go` — Add Dir field to BlockParams:

```go
type BlockParams struct {
  Id                 string
  BlockType          string
  Classes            []string
  ContentClasses     []string
  AdditionalClasses  []string
  Content            templ.Component
  Additional         templ.Component
  ChildrenIds        []string
  Width              string
  Dir                string  // "rtl" or "" (empty = default LTR)
}
```

File: `renderer/text.go` — In `makeTextBlockParams()`, after extracting text:

```go
if checkRtl(blockText.Text) {
  blockParams.Dir = "rtl"
  blockParams.Classes = append(blockParams.Classes, "isRtl")
}
```

File: `renderer/block.templ` — Add dir attribute to BlockTemplate:

```templ
<div
  id={ p.Id }
  class={ "block", "block" + p.BlockType, p.Classes }
  if p.Dir != "" {
    dir={ p.Dir }
  }
  if p.Width != "" {
    data-width={ p.Width }
  }
>
```

File: `src/scss/block/text.scss` (publish renderer) — Add RTL rules:

```scss
.block.blockText.isRtl {
  > .content > .flex {
    flex-direction: row-reverse;

    .markers .marker {
      margin-right: 0px;
      margin-left: 6px;
    }
    .markers .marker.number > span {
      direction: ltr;
      unicode-bidi: bidi-override;
    }
  }
}

.block.blockText.textQuote.isRtl {
  > .content { padding-left: 0; padding-right: 24px; }
  > .additional > .line { left: auto; right: 11px; }
}

.block.isRtl > .children {
  margin-left: 0;
  margin-right: 26px;
}
```

---

## Submission Plan

### Option A: Two PRs (Recommended)

1. **PR to `anyproto/anytype-ts`**: "Improve RTL support for lists, quotes, callouts, and nested blocks"
   - Touches only SCSS files
   - No logic changes needed (detection already works)
   - Low risk, easy to review

2. **PR to `anyproto/anytype-publish-renderer`**: "Add RTL support for published pages"
   - Go + SCSS + Templ changes
   - New RTL detection function
   - Dir attribute on block template
   - Matching CSS rules

### Option B: Feature Request + Patch

File an issue on `anyproto/anytype-ts` referencing the existing #757, attach the CSS patches, and link to this repo as a proof of concept.

### References

- Existing RTL issue: https://github.com/anyproto/anytype-ts/issues/757
- Community thread: https://community.anytype.io/t/add-rtl-support/2220
- Desktop app source: https://github.com/anyproto/anytype-ts
- Publish renderer: https://github.com/anyproto/anytype-publish-renderer
