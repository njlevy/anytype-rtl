/**
 * anytype-rtl: BiDi Injector (v2)
 *
 * For Anytype desktop (Electron) and published pages.
 * Sets dir="auto" on every text block so the browser's native
 * BiDi algorithm kicks in. The CSS uses :dir(rtl) to style them.
 *
 * This script is OPTIONAL — if you can add dir="auto" to blocks
 * in the HTML itself, you only need the CSS file.
 */

(function anytypeRTL() {
  'use strict';

  const CONFIG = {
    BLOCK_SELECTORS: [
      '.block.blockText',
      '.block.blockBookmark',
      '.block.blockLink',
      '.block.blockTable',
      '.block.blockTableOfContents',
    ],
    SKIP_SELECTORS: [
      '.block.blockText[class*="textCode"]',
    ],
    DEBOUNCE_MS: 100,
    DEBUG: false,
  };

  /**
   * Set dir="auto" on a block if it doesn't already have a dir attribute.
   * Code blocks get dir="ltr" forced.
   */
  function processBlock(block) {
    if (block.hasAttribute('dir')) return;

    // Code blocks: always LTR
    for (const sel of CONFIG.SKIP_SELECTORS) {
      if (block.matches(sel)) {
        block.setAttribute('dir', 'ltr');
        return;
      }
    }

    block.setAttribute('dir', 'auto');
  }

  function scanAll() {
    const selector = CONFIG.BLOCK_SELECTORS.join(', ');
    const blocks = document.querySelectorAll(selector);
    blocks.forEach(processBlock);

    // Also tag table cells
    document.querySelectorAll('.block.blockTable td, .block.blockTable th').forEach(cell => {
      if (!cell.hasAttribute('dir')) cell.setAttribute('dir', 'auto');
    });

    // Tag generic content in publish renderer
    document.querySelectorAll('.blocks p, .blocks li, .blocks h1, .blocks h2, .blocks h3, .blocks h4, .blocks td, .blocks th, .blocks blockquote').forEach(el => {
      if (!el.hasAttribute('dir') && !el.closest('[dir]')) {
        el.setAttribute('dir', 'auto');
      }
    });

    if (CONFIG.DEBUG) {
      const total = document.querySelectorAll('[dir]').length;
      console.log(`[anytype-rtl] Tagged ${total} elements with dir`);
    }
  }

  // MutationObserver for dynamic content
  let timer = null;
  function debouncedScan() {
    if (timer) clearTimeout(timer);
    timer = setTimeout(scanAll, CONFIG.DEBOUNCE_MS);
  }

  function startObserver() {
    const target = document.querySelector('.blocks') || document.body;
    new MutationObserver(mutations => {
      for (const m of mutations) {
        if ((m.type === 'childList' && m.addedNodes.length > 0) || m.type === 'characterData') {
          debouncedScan();
          return;
        }
      }
    }).observe(target, { childList: true, subtree: true, characterData: true });
  }

  const api = {
    scan: scanAll,
    configure(opts) { Object.assign(CONFIG, opts); },
    version: '2.0.0',
  };

  // Init
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => { scanAll(); startObserver(); });
  } else {
    scanAll();
    startObserver();
  }

  if (typeof window !== 'undefined') window.anytypeRTL = api;
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
})();
