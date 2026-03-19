# anytype-rtl

BiDi (bidirectional) support for Anytype — automatic RTL detection and layout for Hebrew, Arabic, and mixed-direction content. Works in both the desktop app and published/shared pages.

## what it does

- **Per-block auto-detection**: each text block gets its own direction based on first strong character
- **Full BiDi**: mixed Hebrew + English content in the same page, each block directed independently
- **Punctuation fixes**: parentheses `()`, brackets `[]`, colons, commas — all placed correctly
- **List marker mirroring**: bullets, numbers, checkboxes, toggles — all flip to the correct side
- **Numbered list period fix**: prevents `.1` instead of `1.` via `unicode-bidi: bidi-override`
- **Quote border flip**: left border becomes right border in RTL blocks
- **Callout layout reversal**: icon + text swap sides
- **Toggle arrow mirror**: collapsed arrow points left in RTL (matching reading direction)
- **Nested indent flip**: child blocks indent from the right in RTL
- **Code blocks exempt**: code always stays LTR (as it should)
- **Table support**: right-aligned cells in RTL tables

## quick start: custom CSS (no code)

Anytype already detects RTL content and applies the `.isRtl` class. The built-in CSS just needs a few more rules:

1. Copy `src/anytype-custom.css`
2. In Anytype: **Menu > File > Apply Custom CSS**
3. Paste the contents and save
4. Press `Cmd+R` (Mac) or `Ctrl+R` to refresh

That's it — numbered lists, toggles, and callouts will work correctly in RTL.

## upstream patches

The `patches/` directory contains ready-to-apply patches for Anytype's source code:

### Desktop app (anytype-ts)

**`patches/apply-and-pr.sh`** — automated script that:
1. Forks & clones `anyproto/anytype-ts`
2. Creates a `fix/rtl-enhancements` branch
3. Applies SCSS patches to `text.scss` and `common.scss`
4. Shows the diff for review
5. Commits and creates a PR

Run it:
```bash
cd patches
./apply-and-pr.sh
```

Requires: `gh` CLI authenticated with GitHub.

**What the patches change** (2 files, ~16 lines):

`src/scss/block/text.scss`:
- Inside `.flex.isRtl`: add `unicode-bidi: bidi-override` on `.marker.markerNumbered > span` to fix period placement
- After callout block: add `.align2` override to flip children padding

`src/scss/block/common.scss`:
- After toggle rotation rule: add `scaleX(-1)` on `.markerToggle` when block has `align2` + `.isRtl`

### Published pages (anytype-publish-renderer)

See `UPSTREAM.md` for the full patch guide. The publish renderer needs:
- RTL detection function in Go
- `Dir` field on `BlockParams`
- `dir` attribute in `block.templ`
- Matching SCSS rules

## files

```
anytype-rtl/
├── src/
│   ├── rtl-detect.js         # detection engine + MutationObserver
│   ├── rtl-styles.css         # full BiDi stylesheet (desktop + published)
│   ├── anytype-custom.css     # desktop-only Custom CSS (works with built-in detection)
│   └── bookmarklet.js         # one-click bookmarklet loader
├── patches/
│   ├── apply-and-pr.sh        # automated fork + patch + PR script
│   └── anytype-ts-rtl.patch   # raw patch file
├── demo.html                  # interactive demo with Hebrew test content
├── UPSTREAM.md                # detailed patch guide for both repos
└── README.md
```

## api

The optional JS script exposes `window.anytypeRTL`:

```js
anytypeRTL.scan()              // re-scan all blocks
anytypeRTL.analyze('שלום')     // { direction: 'rtl', rtlRatio: 1, hasRTL: true, hasLTR: false }
anytypeRTL.configure({ DEBUG: true })  // enable console logging
```

## how it works

Anytype's desktop app already has RTL infrastructure:
- `U.String.checkRtl()` detects Hebrew/Arabic first characters
- Sets `fields.isRtlDetected` on the block (persisted)
- Adds `.isRtl` class to the `.flex` container
- Sets `direction: rtl` via CSS
- Sets `align2` class → `flex-direction: row-reverse` on the block

The SCSS just needs a few more rules to handle numbered list periods, toggle arrows, and callout padding. That's what this project provides.

## references

- Existing RTL issue: https://github.com/anyproto/anytype-ts/issues/757
- Community thread: https://community.anytype.io/t/add-rtl-support/2220
- Desktop app source: https://github.com/anyproto/anytype-ts
- Publish renderer: https://github.com/anyproto/anytype-publish-renderer
