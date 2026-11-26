(function () {
  var s = document.currentScript, src = s ? s.src : "", name = "og-map-3676a2267626";
  function go() {
    var f = document.querySelectorAll('iframe[data-rr-map="' + name + '"]');
    for (var i = 0; i < f.length; i++) {
      if (!src || src.indexOf("data:") === 0) {
        f[i].srcdoc = "<p style=\"font:15px system-ui,sans-serif;padding:1em\">This map is a folder beside the page: render the document with <code>self_contained: false</code> (pkgdown and Quarto keep the folders).</p>";
      } else {
        f[i].src = src.replace(/og-locate[.]js([?#].*)?$/, "index.html");
      }
    }
  }
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", go); else go();
})();
