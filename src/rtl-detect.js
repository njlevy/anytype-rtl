/**
 * anytype-rtl: Document-level RTL detector (v4)
 *
 * Strategy: if the page title is Hebrew/Arabic, treat the
 * entire document as RTL. Sets dir="rtl" on every text block.
 * Individual blocks can still override to LTR (e.g., code).
 *
 * Paste in DevTools (Cmd+Option+I) after loading a page.
 * Pair with anytype-custom.css.
 */

(function anytypeRTL() {
  'use strict';

  const RTL_CHARS = /[\u0591-\u05F4\u0600-\u06FF\u0700-\u074F\u0780-\u07BF\u08A0-\u08FF\uFB1D-\uFDFF\uFE70-\uFEFF]/;
  const LTR_CHARS = /[A-Za-z\u00C0-\u02AF\u0370-\u03FF\u0400-\u04FF]/;

  function firstStrongDir(text) {
    for (const ch of text) {
      if (RTL_CHARS.test(ch)) return 'rtl';
      if (LTR_CHARS.test(ch)) return 'ltr';
    }
    return null;
  }

  function getPageTitle() {
    // Anytype desktop: title is in #value inside the first editable block,
    // or in .block.blockFeatured, or the first header
    const titleEl = document.querySelector('.block.blockText.textTitle #value')
      || document.querySelector('.block.blockText.textTitle .editableWrap')
      || document.querySelector('#value');
    return titleEl ? titleEl.textContent.trim() : '';
  }

  function applyDocumentRTL() {
    const title = getPageTitle();
    const dir = firstStrongDir(title);

    if (dir !== 'rtl') {
      console.log('[anytype-rtl] Title is not RTL, skipping. Title: "' + title.substring(0, 40) + '"');
      return;
    }

    console.log('[anytype-rtl] Hebrew title detected → applying RTL to all blocks');

    // Set dir="rtl" on every text block
    document.querySelectorAll('.block.blockText').forEach(block => {
      // Skip code blocks
      if (block.classList.contains('textCode')) {
        block.setAttribute('dir', 'ltr');
        return;
      }
      block.setAttribute('dir', 'rtl');
    });

    // Table cells too
    document.querySelectorAll('.block.blockTable td, .block.blockTable th').forEach(cell => {
      cell.setAttribute('dir', 'rtl');
    });
  }

  // MutationObserver: re-apply when blocks are added/changed
  let timer = null;
  function debouncedApply() {
    if (timer) clearTimeout(timer);
    timer = setTimeout(applyDocumentRTL, 200);
  }

  function startObserver() {
    const target = document.querySelector('.blocks') || document.body;
    new MutationObserver(mutations => {
      for (const m of mutations) {
        if (m.type === 'attributes' && m.attributeName === 'dir') continue;
        if ((m.type === 'childList' && m.addedNodes.length > 0) || m.type === 'characterData') {
          debouncedApply();
          return;
        }
      }
    }).observe(target, { childList: true, subtree: true, characterData: true, attributes: true });
  }

  // Watch for page navigation (SPA)
  let lastUrl = location.href;
  setInterval(() => {
    if (location.href !== lastUrl) {
      lastUrl = location.href;
      setTimeout(applyDocumentRTL, 500);
    }
  }, 500);

  // API
  window.anytypeRTL = {
    apply: applyDocumentRTL,
    detect: firstStrongDir,
    getTitle: getPageTitle,
    version: '4.0.0',
  };

  // Run
  applyDocumentRTL();
  startObserver();
  console.log('[anytype-rtl] v4 loaded. Use anytypeRTL.apply() to re-scan.');
})();
