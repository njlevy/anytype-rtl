# anytype-rtl

BiDi (bidirectional) support for Anytype — automatic RTL detection and layout for Hebrew, Arabic, and mixed-direction content. Works in both the desktop app and published/shared pages.

## what it does

- **Per-block auto-detection**: each text block gets its own direction based on content analysis (first strong character wins, with fallback ratio)
- **Full BiDi**: mixed Hebrew + English content in the same page, each block directed independently
- **Punctuation fixes**: parentheses `()`, brackets `[]`, colons, commas — all placed correctly via `unicode-bidi: plaintext`
- **List marker mirroring**: bullets, numbers, checkboxes, toggles — all flip to the correct side
- **Quote border flip**: left border becomes right border in RTL blocks
- **Callout layout reversal**: icon + text swap sides
- **Nested indent flip**: child blocks indent from the right in RTL
- **Code blocks exempt**: code always stays LTR (as it should)
- **Table support**: per-cell direction detection
- **MutationObserver**: watches for new/edited blocks and re-applies direction in real time
- **SPA navigation aware**: re-scans on URL changes (for Anytype's page navigation)

## installation

### for anytype desktop (custom CSS + console)

1. Copy `src/anytype-custom.css`
2. In Anytype: **Menu > File > Open > Custom CSS**
3. Paste the contents and save
4. **Menu > File > Apply Custom CSS**
5. Press `Cmd+R` (Mac) or `Ctrl+R` to refresh

For auto-detection, open DevTools (`Cmd+Shift+I`) and paste the contents of `src/rtl-detect.js` into the console. Or use the bookmarklet.

### for published/shared pages (bookmarklet)

1. Create a new bookmark in your browser
2. Set the URL to the contents of `src/bookmarklet.js`
3. Navigate to any Anytype published page
4. Click the bookmarklet

### for published pages (self-hosted)

Host the `src/` folder and add to your page:

```html
<link rel="stylesheet" href="rtl-styles.css">
<script src="rtl-detect.js"></script>
```

## files

```
anytype-rtl/
├── src/
│   ├── rtl-detect.js       # detection engine + MutationObserver
│   ├── rtl-styles.css       # full BiDi stylesheet (desktop + published)
│   ├── anytype-custom.css   # desktop-only Custom CSS version
│   └── bookmarklet.js       # one-click bookmarklet loader
├── demo.html                # interactive demo with Hebrew test content
└── README.md
```

## api

The script exposes `window.anytypeRTL`:

```js
anytypeRTL.scan()              // re-scan all blocks
anytypeRTL.analyze('שלום')     // { direction: 'rtl', rtlRatio: 1, hasRTL: true, hasLTR: false }
anytypeRTL.configure({ DEBUG: true })  // enable console logging
```

## known limitations

- **Desktop editor**: wrapping `<bdi>` elements inside `contenteditable` is disabled to avoid breaking the editor. BiDi isolation works at the block level only.
- **Custom CSS only**: Anytype doesn't have a plugin API yet, so the JS portion requires DevTools or a bookmarklet. The CSS-only version handles blocks that already have `dir="rtl"` set.
- **Publish renderer**: the published page DOM may vary between Anytype versions. The script uses broad selectors to stay compatible.

## how detection works

1. For each text block, extract the direct text content (ignoring nested block-level elements)
2. Count RTL characters (Hebrew U+0590–U+05FF, Arabic U+0600–U+06FF, etc.) vs LTR characters (Latin, etc.)
3. The **first strong directional character** determines the block's direction (per Unicode BiDi Algorithm)
4. If the block contains both RTL and LTR characters, it gets the `anytype-bidi` class for isolation
5. `unicode-bidi: plaintext` lets the browser's built-in BiDi algorithm handle punctuation placement
6. A MutationObserver re-runs detection when content changes (debounced at 100ms)
