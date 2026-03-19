/**
 * anytype-rtl: Bookmarklet Loader
 *
 * Drag this to your bookmarks bar. Click it on any Anytype published page
 * to inject RTL support. Also works in Anytype desktop via DevTools console.
 *
 * To create the bookmarklet, minify this and prefix with javascript:
 */

javascript:void((function(){
  if(window.anytypeRTL){window.anytypeRTL.scan();return;}
  var base='https://cdn.jsdelivr.net/gh/YOUR_USERNAME/anytype-rtl@latest/src/';
  var css=document.createElement('link');
  css.rel='stylesheet';
  css.href=base+'rtl-styles.css';
  document.head.appendChild(css);
  var js=document.createElement('script');
  js.src=base+'rtl-detect.js';
  document.body.appendChild(js);
})());
