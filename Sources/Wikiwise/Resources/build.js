// Wikiwise wiki compiler — runs in JavaScriptCore (no DOM, no fetch).
//
// Swift bridge functions:
//   readFile(path)      → String
//   writeFile(path, content)
//   copyFile(src, dst)  → Bool (binary-safe)
//   listDir(path)       → [String]
//   mkdirp(path)
//   fileExists(path)    → Bool
//   log(msg)
//
// Bundled assets (injected by Compiler.swift):
//   bundledCSS    — style.css content
//   bundledAppJS  — app.js content (client-side search/popovers/scrollspy)
//   bundledGraphJS — graph.js content (force-directed visualization)
//
// Entry point: compile(sourceDir, outputDir)

var md = markdownit({ html: true, linkify: true, typographer: true });

// ============================================================
//  KaTeX math plugin for markdown-it
//  Handles $...$ (inline) and $$...$$ (block) LaTeX math
// ============================================================

(function mathPlugin(md) {
  // --- Block rule: $$...$$ on its own lines ---
  function mathBlock(state, startLine, endLine, silent) {
    var startPos = state.bMarks[startLine] + state.tShift[startLine];
    var maxPos = state.eMarks[startLine];
    if (startPos + 2 > maxPos) return false;
    if (state.src.charCodeAt(startPos) !== 0x24 || state.src.charCodeAt(startPos + 1) !== 0x24) return false;

    // Opening $$ may have content after it on the same line (single-line block)
    var openContent = state.src.slice(startPos + 2, maxPos).trim();
    if (openContent && openContent.slice(-2) === '$$') {
      // Single-line: $$...$$ all on one line
      if (silent) return true;
      var tok = state.push('math_block', 'math', 0);
      tok.content = openContent.slice(0, -2).trim();
      tok.map = [startLine, startLine + 1];
      state.line = startLine + 1;
      return true;
    }

    // Multi-line: find closing $$
    var nextLine = startLine;
    for (;;) {
      nextLine++;
      if (nextLine >= endLine) return false;
      var lineStart = state.bMarks[nextLine] + state.tShift[nextLine];
      var lineMax = state.eMarks[nextLine];
      var lineText = state.src.slice(lineStart, lineMax).trim();
      if (lineText === '$$') break;
    }

    if (silent) return true;
    var tok = state.push('math_block', 'math', 0);
    tok.content = state.getLines(startLine + 1, nextLine, state.tShift[startLine], false).trim();
    if (openContent) tok.content = openContent + '\n' + tok.content;
    tok.map = [startLine, nextLine + 1];
    state.line = nextLine + 1;
    return true;
  }

  // --- Inline rule: $...$ ---
  function mathInline(state, silent) {
    if (state.src.charCodeAt(state.pos) !== 0x24) return false;

    // Skip if this is $$
    if (state.src.charCodeAt(state.pos + 1) === 0x24) return false;

    var start = state.pos + 1;
    // Find closing $ (not preceded by backslash, not followed by digit right after opening)
    var end = start;
    while (end < state.posMax) {
      if (state.src.charCodeAt(end) === 0x24 && state.src.charCodeAt(end - 1) !== 0x5C) break;
      end++;
    }
    if (end >= state.posMax) return false;
    var content = state.src.slice(start, end).trim();
    if (!content) return false;

    if (!silent) {
      var tok = state.push('math_inline', 'math', 0);
      tok.content = content;
    }
    state.pos = end + 1;
    return true;
  }

  function renderMath(content, displayMode) {
    if (typeof katex !== 'undefined') {
      try {
        return katex.renderToString(content, { throwOnError: false, displayMode: displayMode });
      } catch (e) {
        return '<span class="math-error">' + content + '</span>';
      }
    }
    // Fallback if KaTeX not loaded
    return displayMode
      ? '<div class="math-block">' + content + '</div>'
      : '<span class="math-inline">' + content + '</span>';
  }

  md.block.ruler.before('fence', 'math_block', mathBlock, { alt: ['paragraph', 'reference', 'blockquote', 'list'] });
  md.inline.ruler.before('escape', 'math_inline', mathInline);

  md.renderer.rules.math_block = function(tokens, idx) {
    return '<div class="katex-display">' + renderMath(tokens[idx].content, true) + '</div>\n';
  };
  md.renderer.rules.math_inline = function(tokens, idx) {
    return renderMath(tokens[idx].content, false);
  };
})(md);

// ============================================================
//  Constants
// ============================================================

var META_SLUGS = {
  home: true, index: true, log: true,
  whoami: true, 'our-skills': true, 'all-pages': true
};

var GRAPH_COLORS = {
  Meta:        '#9a8a77',
  Source:      '#c77a3c',
  Highlights:  '#8d6ba3',
  Concept:     '#4f8a6d',
  Discussion:  '#4a7ca6'
};

var FONT_LINKS =
  '<link rel="preconnect" href="https://fonts.googleapis.com">\n' +
  '<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>\n' +
  '<link href="https://fonts.googleapis.com/css2?family=Source+Serif+4:ital,opsz,wght@0,8..60,300..700;1,8..60,300..700&family=Inter:wght@400;500;600&family=JetBrains+Mono:wght@400&display=swap" rel="stylesheet">';

var wikiName = 'Wikiwise';

function initWikiName(sourceDir) {
  var claudePath = sourceDir + '/CLAUDE.md';
  if (fileExists(claudePath)) {
    var content = readFile(claudePath);
    var match = content.match(/^#\s+(.+?)(?:\s*[-\u2014]\s*schema)?$/m);
    if (match) {
      wikiName = match[1].trim();
    }
  }
}

function buildMasthead() {
  var displayName = wikiName.replace(/[-_]/g, ' ');
  var words = displayName.split(/\s+/);
  var letter = words[0].charAt(0).toUpperCase();

  var wordsHtml = '';
  if (words.length === 1) {
    wordsHtml = '      <span class="masthead-mark-word-primary">' + escapeHtml(words[0]) + '</span>\n';
  } else {
    wordsHtml = '      <span class="masthead-mark-word-primary">' + escapeHtml(words[0]) + '</span>\n' +
      '      <span class="masthead-mark-word-secondary">' + escapeHtml(words.slice(1).join(' ')) + '</span>\n';
  }

  return '<header class="masthead">\n' +
    '  <a class="masthead-mark" href="home.html">\n' +
    '    <span class="masthead-mark-letter">' + escapeHtml(letter) + '</span>\n' +
    '    <span class="masthead-mark-words">\n' +
    wordsHtml +
    '    </span>\n' +
    '  </a>\n' +
    '  <div class="masthead-search">\n' +
    '    <input id="search-input" type="search" placeholder="Search ' + escapeHtml(wikiName) + '\u2026" autocomplete="off">\n' +
    '    <div id="search-results"></div>\n' +
    '  </div>\n' +
    '</header>';
}

var NAV_HTML =
  '<nav class="rail-nav"><h4>Navigate</h4><ul>' +
  '<li><a href="home.html">Home</a></li>' +
  '<li><a href="index.html">Catalog</a></li>' +
  '<li><a href="map-3d.html">Map</a></li>' +
  '<li><a href="log.html">Recent changes</a></li>' +
  '</ul></nav>';

// ============================================================
//  Entry point
// ============================================================

function compile(sourceDir, outputDir) {
  mkdirp(outputDir);
  initWikiName(sourceDir);

  var markdownFiles = findMarkdownFiles(sourceDir, outputDir);
  var knownSlugs = buildSlugSet(markdownFiles);
  var css = typeof bundledCSS !== 'undefined' ? bundledCSS : '';

  // Load compile cache for incremental builds
  var cachePath = outputDir + '/.compile-cache.json';
  var cache = loadCompileCache(cachePath);

  // Pass 1: parse every page, skipping md.render() for unchanged files
  var parseResult = parseAllPages(markdownFiles, knownSlugs, cache);
  var pages = parseResult.pages;
  var cacheHits = parseResult.cacheHits;

  // Build the backlinks map (inverted link index)
  var backlinkMap = buildBacklinkMap(pages);

  // Build data indexes for client-side features (search, previews)
  var searchEntries = buildSearchEntries(pages);
  var previews = buildPreviewIndex(pages);
  // Pass 2: assemble final HTML for each page
  renderAllPages(pages, backlinkMap, css, outputDir);

  // Write data files (shared across all pages via <script src>)
  writeFile(outputDir + '/search.json', JSON.stringify(searchEntries));
  writeFile(outputDir + '/previews.json', JSON.stringify(previews));
  writeFile(outputDir + '/search.json.js',
    'var __searchIndex=' + JSON.stringify(searchEntries) +
    ';var __previewData=' + JSON.stringify(previews) + ';');

  // Generate graph + map visualizations
  writeGraph(pages, css, outputDir);
  compileMap(sourceDir, outputDir);

  // Copy static assets to output
  writeFile(outputDir + '/style.css', css);
  if (typeof bundledAppJS !== 'undefined') {
    writeFile(outputDir + '/app.js', bundledAppJS);
  }
  if (typeof bundledKatexCSS !== 'undefined') {
    writeFile(outputDir + '/katex.min.css', bundledKatexCSS);
  }
  copyKatexFonts(sourceDir, outputDir);
  copyAssets(sourceDir, outputDir);

  // Persist cache for next run
  saveCompileCache(cachePath, pages, markdownFiles);

  log('Compiled ' + markdownFiles.length + ' files (' + cacheHits + ' cached, ' +
      (markdownFiles.length - cacheHits) + ' rendered) \u2192 ' + outputDir);
  return markdownFiles.length;
}

// ============================================================
//  Progressive rendering: lightweight scan + JIT page compile
// ============================================================

// Shared state for progressive mode — populated by scanPages(),
// consumed by compilePage() and compileNextBatch().
var _progressive = null;

// Extract [[wikilinks]] from raw markdown without rendering.
function extractOutgoingLinks(source, knownSlugs, currentSlug) {
  var links = [];
  var seen = {};
  var re = /\[\[([^\]|]+)(?:\|[^\]]+)?\]\]/g;
  var match;
  while ((match = re.exec(source)) !== null) {
    var slug = match[1].trim().toLowerCase().replace(/ /g, '-');
    if (knownSlugs[slug] && slug !== currentSlug && !seen[slug]) {
      links.push(slug);
      seen[slug] = true;
    }
  }
  return links;
}

// Detect whether source has an infobox (YAML frontmatter or **Key:** format).
function hasSourceInfobox(source) {
  if (/^---\n/.test(source)) return true;
  var lines = source.split('\n');
  var cursor = 0;
  if (cursor < lines.length && /^#\s/.test(lines[cursor])) cursor++;
  while (cursor < lines.length && lines[cursor].trim() === '') cursor++;
  if (cursor < lines.length && /^!\[/.test(lines[cursor].trim())) cursor++;
  while (cursor < lines.length && lines[cursor].trim() === '') cursor++;
  return cursor < lines.length && /^\*\*[^*]+:\*\*/.test(lines[cursor].trim());
}

// Lightweight scan: read every .md file but only extract metadata via
// regex — no md.render(), no HTML assembly. Builds everything needed
// for the sidebar, search, graph, and backlinks. Returns page count.
function scanPages(sourceDir, outputDir) {
  mkdirp(outputDir);
  initWikiName(sourceDir);

  var markdownFiles = findMarkdownFiles(sourceDir, outputDir);
  var knownSlugs = buildSlugSet(markdownFiles);
  var css = typeof bundledCSS !== 'undefined' ? bundledCSS : '';

  var pages = {};
  var filePathBySlug = {};

  markdownFiles.forEach(function(filePath) {
    var slug = slugFromPath(filePath);
    var source = readFile(filePath);
    var title = extractTitle(source) || slug;
    var outgoingLinks = extractOutgoingLinks(source, knownSlugs, slug);
    var infobox = hasSourceInfobox(source);

    pages[slug] = {
      title: title,
      outgoingLinks: outgoingLinks,
      hasInfobox: infobox,
      plainText: markdownToPlainText(source),
      richText: markdownToRichText(source),
      mtime: fileMtime(filePath),
      // html is NOT populated yet — deferred to compilePage()
      html: null
    };
    filePathBySlug[slug] = filePath;
  });

  var backlinkMap = buildBacklinkMap(pages);

  // Build data indexes for client-side features (search, previews)
  var searchEntries = buildSearchEntries(pages);
  var previews = buildPreviewIndex(pages);
  // Write data files (shared across all pages via <script src>)
  writeFile(outputDir + '/search.json', JSON.stringify(searchEntries));
  writeFile(outputDir + '/previews.json', JSON.stringify(previews));
  writeFile(outputDir + '/search.json.js',
    'var __searchIndex=' + JSON.stringify(searchEntries) +
    ';var __previewData=' + JSON.stringify(previews) + ';');
  writeGraph(pages, css, outputDir);
  compileMap(sourceDir, outputDir);

  // Copy static assets
  writeFile(outputDir + '/style.css', css);
  if (typeof bundledAppJS !== 'undefined') {
    writeFile(outputDir + '/app.js', bundledAppJS);
  }
  // Copy KaTeX CSS and fonts for math rendering
  if (typeof bundledKatexCSS !== 'undefined') {
    writeFile(outputDir + '/katex.min.css', bundledKatexCSS);
  }
  copyKatexFonts(sourceDir, outputDir);
  copyAssets(sourceDir, outputDir);

  // Build queue of slugs not yet compiled
  var pending = [];
  for (var slug in pages) pending.push(slug);

  _progressive = {
    pages: pages,
    filePathBySlug: filePathBySlug,
    backlinkMap: backlinkMap,
    knownSlugs: knownSlugs,
    css: css,
    outputDir: outputDir,
    pending: pending,
    
  };

  // Save cache (html will be null for un-rendered pages — that's fine,
  // compilePage() updates it and saveProgressiveCache() persists later).
  var cachePath = outputDir + '/.compile-cache.json';
  saveCompileCache(cachePath, pages, markdownFiles);

  var uniqueCount = Object.keys(pages).length;
  log('Scanned ' + markdownFiles.length + ' files \u2192 ' + uniqueCount + ' unique pages (metadata only)');
  return uniqueCount;
}

// Full-render a single page: md.render() + wikilink resolution + HTML
// assembly. Called on demand when the user navigates, or by the
// background drip. Returns true if compiled, false if slug not found.
function compilePage(slug) {
  if (!_progressive) return false;
  var state = _progressive;
  var page = state.pages[slug];
  if (!page) return false;

  // Already rendered?
  var htmlPath = state.outputDir + '/' + slug + '.html';
  if (page.html !== null && fileExists(htmlPath)) return true;

  // Full render
  var filePath = state.filePathBySlug[slug];
  var source = readFile(filePath);
  var rendered = renderPageBody(source, state.knownSlugs, slug);

  page.html = rendered.html;
  page.subtitle = rendered.subtitle;

  // Assemble final page
  var backlinksHtml = renderBacklinks(state.backlinkMap[slug] || [], state.pages);
  var tocResult = buildTableOfContents(page.html);
  var articleBody = (tocResult.htmlWithIds || page.html) + backlinksHtml;

  var html = buildPageHtml({
    body: articleBody,
    title: page.title,
    subtitle: page.subtitle,
    css: state.css,
    tocHtml: tocResult.tocHtml,
    slug: slug,
    
  });

  writeFile(htmlPath, html);
  return true;
}

// Ad-hoc compile: render any markdown file to HTML, even if it wasn't
// part of the original scan (e.g. raw/ files). Uses the same styling
// but no backlinks or search data.
function compileAdhoc(filePath, outputPath) {
  var source = readFile(filePath);
  if (!source) return false;

  var slug = filePath.split('/').pop().replace(/\.md$/i, '').toLowerCase().replace(/ /g, '-');
  var knownSlugs = _progressive ? _progressive.knownSlugs : {};
  var rendered = renderPageBody(source, knownSlugs, slug);
  var css = _progressive ? _progressive.css : (typeof bundledCSS !== 'undefined' ? bundledCSS : '');
  var tocResult = buildTableOfContents(rendered.html);
  var articleBody = tocResult.htmlWithIds || rendered.html;

  var html = buildPageHtml({
    body: articleBody,
    title: rendered.title,
    subtitle: rendered.subtitle || '',
    css: css,
    tocHtml: tocResult.tocHtml,
    slug: slug,
    
  });

  writeFile(outputPath, html);
  return true;
}

// Compile up to `batchSize` pages from the pending queue. Returns the
// number of pages remaining. Called repeatedly from Swift on a timer.
function compileNextBatch(batchSize) {
  if (!_progressive) return 0;
  var count = Math.min(batchSize, _progressive.pending.length);
  for (var i = 0; i < count; i++) {
    var slug = _progressive.pending.pop();
    if (slug) compilePage(slug);
  }
  return _progressive.pending.length;
}

// Copy KaTeX font files to the output directory so katex.min.css can
// reference them via the fonts/ relative path.
function copyKatexFonts(sourceDir, outputDir) {
  if (typeof copyFile === 'undefined') return;
  if (typeof bundledKatexFontsDir === 'undefined') return;
  var fontsDir = bundledKatexFontsDir;
  if (!fileExists(fontsDir)) return;
  var outFonts = outputDir + '/fonts';
  mkdirp(outFonts);
  var entries = listDir(fontsDir);
  for (var i = 0; i < entries.length; i++) {
    var src = fontsDir + '/' + entries[i];
    var dst = outFonts + '/' + entries[i];
    var srcMtime = fileMtime(src);
    var dstMtime = fileMtime(dst);
    if (dstMtime >= srcMtime && srcMtime > 0) continue;
    copyFile(src, dst);
  }
}

// Copy wiki/assets/ → site/out/assets/ (binary-safe via copyFile bridge).
// Recurses into subdirectories; skips files whose mtime hasn't changed.
function copyAssets(sourceDir, outputDir) {
  if (typeof copyFile === 'undefined') return;
  var assetsDir = sourceDir + '/wiki/assets';
  if (!fileExists(assetsDir)) return;
  var outAssets = outputDir + '/assets';
  var copied = 0;

  function copyDir(srcDir, dstDir) {
    var entries = listDir(srcDir);
    for (var i = 0; i < entries.length; i++) {
      var src = srcDir + '/' + entries[i];
      var dst = dstDir + '/' + entries[i];
      // Recurse into subdirectories (listDir returns non-empty for dirs)
      var children = listDir(src);
      if (children.length > 0) {
        copyDir(src, dst);
        continue;
      }
      // Skip if destination is up to date
      var srcMtime = fileMtime(src);
      var dstMtime = fileMtime(dst);
      if (dstMtime >= srcMtime && srcMtime > 0) continue;
      mkdirp(dstDir);
      if (copyFile(src, dst)) copied++;
    }
  }

  copyDir(assetsDir, outAssets);
  if (copied) log('Copied ' + copied + ' asset(s) to ' + outAssets);
}

// Re-read CSS from disk and update the progressive state. Called when
// the file watcher detects a style change.
function reloadCSS(sourceDir) {
  if (!_progressive) return;
  var cssPath = sourceDir + '/site/style.css';
  var css;
  if (fileExists(cssPath)) {
    css = readFile(cssPath);
  } else {
    css = typeof bundledCSS !== 'undefined' ? bundledCSS : '';
  }
  _progressive.css = css;
  writeFile(_progressive.outputDir + '/style.css', css);
}

// Mark all pages as un-rendered so they get recompiled (with fresh CSS
// or after a structural change). Repopulates the pending queue.
function invalidateAll() {
  if (!_progressive) return 0;
  _progressive.pending = [];
  for (var slug in _progressive.pages) {
    _progressive.pages[slug].html = null;
    _progressive.pending.push(slug);
  }
  return _progressive.pending.length;
}

// Invalidate a single page's cached HTML so it gets recompiled.
function invalidatePage(slug) {
  if (!_progressive || !_progressive.pages[slug]) return false;
  _progressive.pages[slug].html = null;
  if (_progressive.pending.indexOf(slug) === -1) {
    _progressive.pending.push(slug);
  }
  return true;
}

// Re-scan the source directory, rebuilding metadata, backlinks, search
// index, etc. Used when files are added or deleted.
function rescan(sourceDir, outputDir) {
  scanPages(sourceDir, outputDir);
}

// ============================================================
//  Pass 1: Parse all pages
// ============================================================

function parseAllPages(markdownFiles, knownSlugs, cache) {
  var pages = {};
  var cacheHits = 0;

  markdownFiles.forEach(function(filePath) {
    var pageSlug = slugFromPath(filePath);
    var mtime = fileMtime(filePath);

    // Reuse cached parse result if the source file hasn't changed
    var cached = cache[pageSlug];
    if (cached && cached.mtime === mtime) {
      pages[pageSlug] = cached;
      cacheHits++;
      return;
    }

    // File is new or modified — full parse + render
    var source = readFile(filePath);
    var rendered = renderPageBody(source, knownSlugs, pageSlug);

    pages[pageSlug] = {
      title: rendered.title,
      html: rendered.html,
      subtitle: rendered.subtitle,
      hasInfobox: rendered.hasInfobox,
      outgoingLinks: rendered.outgoingLinks,
      plainText: markdownToPlainText(source),
      richText: markdownToRichText(source),
      mtime: mtime
    };
  });

  return { pages: pages, cacheHits: cacheHits };
}

// ============================================================
//  Pass 2: Render final HTML pages
// ============================================================

function renderAllPages(pages, backlinkMap, css, outputDir) {
  for (var pageSlug in pages) {
    var page = pages[pageSlug];
    var backlinksHtml = renderBacklinks(backlinkMap[pageSlug] || [], pages);
    var tocResult = buildTableOfContents(page.html);
    var articleBody = (tocResult.htmlWithIds || page.html) + backlinksHtml;

    var html = buildPageHtml({
      body: articleBody,
      title: page.title,
      subtitle: page.subtitle || '',
      css: css,
      tocHtml: tocResult.tocHtml,
      slug: pageSlug,
      
    });

    writeFile(outputDir + '/' + pageSlug + '.html', html);
  }
}

// ============================================================
//  Backlink map
// ============================================================

function buildBacklinkMap(pages) {
  var backlinks = {};
  for (var sourceSlug in pages) {
    var outgoing = pages[sourceSlug].outgoingLinks;
    for (var i = 0; i < outgoing.length; i++) {
      var targetSlug = outgoing[i];
      if (!backlinks[targetSlug]) backlinks[targetSlug] = [];
      backlinks[targetSlug].push(sourceSlug);
    }
  }
  return backlinks;
}

function renderBacklinks(backlinkSlugs, pages) {
  if (!backlinkSlugs.length) return '';
  backlinkSlugs.sort();
  var listItems = backlinkSlugs.map(function(linkSlug) {
    var label = (pages[linkSlug] && pages[linkSlug].title) || linkSlug;
    return '<li><a class="wikilink" href="' + encodeURI(linkSlug) + '.html">' + escapeHtml(label) + '</a></li>';
  }).join('');
  return '<section class="backlinks-main"><h2>What links here</h2><ul>' + listItems + '</ul></section>';
}

// ============================================================
//  Data file generation
// ============================================================

function buildSearchEntries(pages) {
  var entries = [];
  for (var pageSlug in pages) {
    var page = pages[pageSlug];
    entries.push({
      slug: pageSlug,
      href: pageSlug + '.html',
      title: page.title,
      text: (page.plainText || '').substring(0, 1500)
    });
  }
  return entries;
}

function buildPreviewIndex(pages) {
  var previews = {};
  for (var pageSlug in pages) {
    var page = pages[pageSlug];
    previews[pageSlug] = {
      title: page.title,
      lead: (page.plainText || '').substring(0, 600),
      rich: page.richText || '',
      href: pageSlug + '.html',
      type: classifyPage(pageSlug, page.hasInfobox)
    };
  }
  return previews;
}

// ============================================================
//  Graph generation
// ============================================================

// Reference pages excluded from graph/map — they are scaffold docs, not wiki content.
var GRAPH_EXCLUDED_SLUGS = { 'llm-wiki': true, 'agents': true };

function writeGraph(pages, css, outputDir) {
  var nodes = [];
  var nodeExists = {};
  var degree = {};

  for (var pageSlug in pages) {
    if (GRAPH_EXCLUDED_SLUGS[pageSlug]) continue;
    var pt = pages[pageSlug].plainText || '';
    var wordCount = pt ? pt.split(/\s+/).length : 0;
    nodes.push({
      id: pageSlug,
      label: pages[pageSlug].title,
      type: classifyPage(pageSlug, pages[pageSlug].hasInfobox),
      href: pageSlug + '.html',
      words: wordCount
    });
    nodeExists[pageSlug] = true;
    degree[pageSlug] = 0;
  }

  var links = [];
  for (var pageSlug in pages) {
    var outgoing = pages[pageSlug].outgoingLinks;
    for (var i = 0; i < outgoing.length; i++) {
      var targetSlug = outgoing[i];
      if (targetSlug !== pageSlug && nodeExists[targetSlug]) {
        links.push({ source: pageSlug, target: targetSlug });
        degree[pageSlug] = (degree[pageSlug] || 0) + 1;
        degree[targetSlug] = (degree[targetSlug] || 0) + 1;
      }
    }
  }

  for (var i = 0; i < nodes.length; i++) {
    nodes[i].val = 1 + (degree[nodes[i].id] || 0);
  }

  var graphData = { nodes: nodes, links: links };
  writeFile(outputDir + '/graph.json', JSON.stringify(graphData));
  writeFile(outputDir + '/graph.html', buildGraphHtml(css, graphData));
  return graphData;
}

function classifyPage(pageSlug, hasInfobox) {
  if (META_SLUGS[pageSlug]) return 'Meta';
  if (!hasInfobox) return 'Concept';
  if (/_highlights$/.test(pageSlug)) return 'Highlights';
  if (/^slack[-_]/.test(pageSlug)) return 'Discussion';
  return 'Source';
}

// ============================================================
//  HTML templates
// ============================================================

function buildPageHtml(options) {
  var railHtml = '<aside class="rail">\n' + NAV_HTML + '\n' +
    (options.tocHtml || '') + '\n</aside>';

  return [
    '<!doctype html>',
    '<html lang="en">',
    '<head>',
    '<meta charset="utf-8">',
    '<meta name="viewport" content="width=device-width,initial-scale=1">',
    '<title>' + escapeHtml(options.title) + ' \u2014 ' + escapeHtml(wikiName) + '</title>',
    FONT_LINKS,
    '<link rel="stylesheet" href="katex.min.css">',
    '<link rel="stylesheet" href="style.css">',
    '</head>',
    '<body class="page-' + escapeHtml(options.slug) + '">',
    buildMasthead(),
    '<div class="layout">',
    railHtml,
    '<div class="article-wrap">',
    '<div class="article">',
    '<div class="article-head">',
    '  <h1 class="article-title">' + escapeHtml(options.title) + '</h1>',
    (options.subtitle || ''),
    '</div>',
    '<div class="article-body">',
    options.body,
    '</div>',
    '</div>',
    '</div>',
    '</div>',
    '<script src="search.json.js"><\/script>',
    '<script src="app.js"><\/script>',
    '</body>',
    '</html>'
  ].join('\n');
}

function buildGraphHtml(css, graphData) {
  var graphJS = typeof bundledGraphJS !== 'undefined' ? bundledGraphJS : '';

  return [
    '<!doctype html>',
    '<html lang="en">',
    '<head>',
    '<meta charset="utf-8">',
    '<meta name="viewport" content="width=device-width,initial-scale=1">',
    '<title>Graph \u2014 ' + escapeHtml(wikiName) + '</title>',
    FONT_LINKS,
    '<link rel="stylesheet" href="style.css">',
    '<style>' + graphPageCSS() + '</style>',
    '</head>',
    '<body class="page-graph">',
    '<div class="map-nav-toggle" style="position:absolute;top:16px;left:50%;transform:translateX(-50%);z-index:10;display:flex;border:1px solid var(--rule);border-radius:4px;overflow:hidden;background:var(--surface);font-family:var(--sans);">',
    '  <a href="map.html" style="padding:6px 14px;font-size:0.72rem;font-weight:500;letter-spacing:0.08em;text-transform:uppercase;color:var(--muted);text-decoration:none;border:none;border-right:1px solid var(--rule);">Map</a>',
    '  <a href="map-3d.html" style="padding:6px 14px;font-size:0.72rem;font-weight:500;letter-spacing:0.08em;text-transform:uppercase;color:var(--muted);text-decoration:none;border:none;border-right:1px solid var(--rule);">3D</a>',
    '  <a href="graph.html" style="padding:6px 14px;font-size:0.72rem;font-weight:500;letter-spacing:0.08em;text-transform:uppercase;text-decoration:none;border:none;background:var(--ink);color:var(--bg);">Classic</a>',
    '</div>',
    '<div class="graph-layout" id="graph-layout">',
    '  <div class="graph-root">',
    '    <div id="graph-canvas"></div>',
    '    <div class="graph-panel graph-stats" id="graph-stats"></div>',
    '    <div class="graph-panel graph-legend">',
    '      <h4>Categories</h4>',
    '      <ul id="legend-items"></ul>',
    '    </div>',
    '    <div class="graph-panel graph-help">scroll to zoom \u00b7 drag to pan \u00b7 click a node to preview \u00b7 shift-click to open</div>',
    '  </div>',
    '  <aside class="side-pane" id="side-pane">',
    '    <header class="side-pane-head">',
    '      <span class="side-title" id="side-title"></span>',
    '      <div class="side-actions">',
    '        <button id="side-open" title="Open in full page">Open \u2197</button>',
    '        <button id="side-close" class="close-btn" title="Close (Esc)">\u00d7</button>',
    '      </div>',
    '    </header>',
    '    <iframe id="side-frame" title="Page preview"></iframe>',
    '  </aside>',
    '</div>',
    '<script src="https://unpkg.com/d3@7/dist/d3.min.js"><\/script>',
    '<script src="https://unpkg.com/force-graph@1.49.0/dist/force-graph.min.js"><\/script>',
    '<script src="app.js"><\/script>',
    '<script>',
    'var GRAPH_COLORS = ' + safeJsonForScript(GRAPH_COLORS) + ';',
    'var GRAPH_DATA = ' + safeJsonForScript(graphData) + ';',
    '<\/script>',
    '<script>' + graphJS + '<\/script>',
    '</body>',
    '</html>'
  ].join('\n');
}

function graphPageCSS() {
  return [
    'body.page-graph { overflow: hidden; }',
    '.graph-layout { position: fixed; top: 0; left: 0; width: 100vw; height: 100vh; display: flex; background: var(--bg); }',
    '.graph-root { position: relative; flex: 1 1 auto; min-width: 0; height: 100%; background: var(--bg); }',
    '#graph-canvas { width: 100%; height: 100%; position: relative; }',
    '.side-pane { flex: 0 0 0; width: 0; overflow: hidden; background: var(--surface); border-left: 1px solid var(--rule); display: flex; flex-direction: column; transition: flex-basis 0.32s cubic-bezier(.25,.8,.35,1), width 0.32s cubic-bezier(.25,.8,.35,1); }',
    '.graph-layout.open .side-pane { flex: 0 0 52%; width: 52%; }',
    '.side-pane-head { flex: 0 0 auto; height: 42px; display: flex; align-items: center; justify-content: space-between; padding: 0 8px 0 16px; border-bottom: 1px solid var(--rule); font-family: var(--sans); font-size: 0.78rem; color: var(--muted); }',
    '.side-pane-head .side-title { text-transform: uppercase; letter-spacing: 0.12em; font-weight: 600; font-size: 0.62rem; }',
    '.side-pane-head .side-actions { display: flex; gap: 4px; }',
    '.side-pane-head button { background: none; border: 0; cursor: pointer; color: var(--muted); padding: 6px 10px; border-radius: 4px; font-family: var(--sans); font-size: 0.82rem; line-height: 1; transition: background 0.12s ease, color 0.12s ease; }',
    '.side-pane-head button:hover { background: var(--rule-soft); color: var(--ink); }',
    '.side-pane-head .close-btn { font-size: 1.2rem; padding: 4px 10px; }',
    '.side-pane iframe { flex: 1 1 auto; width: 100%; border: 0; background: var(--bg); }',
    '.graph-panel { position: absolute; background: var(--surface); border: 1px solid var(--rule); border-radius: 4px; box-shadow: 0 8px 24px rgba(40, 30, 20, 0.08); font-family: var(--sans); font-size: 0.8rem; color: var(--ink); }',
    '.graph-legend { top: 18px; right: 18px; padding: 12px 14px; min-width: 180px; }',
    '.graph-legend h4 { margin: 0 0 8px; font-size: 0.62rem; text-transform: uppercase; letter-spacing: 0.12em; color: var(--muted); font-weight: 600; }',
    '.graph-legend ul { list-style: none; padding: 0; margin: 0; }',
    '.graph-legend li { display: flex; align-items: center; gap: 8px; margin: 4px 0; cursor: pointer; user-select: none; }',
    '.graph-legend li.dimmed { opacity: 0.35; }',
    '.graph-legend .dot { width: 10px; height: 10px; border-radius: 50%; display: inline-block; flex: 0 0 auto; }',
    '.graph-legend .count { margin-left: auto; color: var(--muted); font-variant-numeric: tabular-nums; }',
    '.graph-help { bottom: 18px; left: 18px; padding: 8px 12px; color: var(--muted); font-size: 0.72rem; }',
    '.graph-stats { top: 18px; left: 18px; padding: 8px 12px; color: var(--muted); font-size: 0.72rem; font-variant-numeric: tabular-nums; }',
    '.graph-stats strong { color: var(--ink); font-weight: 600; }'
  ].join('\n');
}

// ============================================================
//  Markdown transforms (pre-render)
// ============================================================

function transformCallouts(markdownText) {
  return markdownText.replace(
    /^(> \[!(\w+)\][ \t]*(.*)\n(?:>.*\n?)*)/gm,
    function(block, _, calloutType, headerText) {
      var lines = block.split('\n');
      var bodyLines = [];
      for (var i = 1; i < lines.length; i++) {
        var stripped = lines[i].replace(/^>\s?/, '');
        if (stripped || i < lines.length - 1) bodyLines.push(stripped);
      }
      var bodyHtml = md.render(bodyLines.join('\n'));
      var title = headerText.trim() || calloutType.charAt(0).toUpperCase() + calloutType.slice(1);
      return '<aside class="callout callout-' + calloutType.toLowerCase() + '">' +
        '<span class="callout-title">' + escapeHtml(title) + '</span>' +
        bodyHtml + '</aside>\n';
    }
  );
}

// ============================================================
//  HTML post-processing (post-render)
// ============================================================

function resolveWikilinks(html, knownSlugs, currentPageSlug) {
  var outgoingLinks = [];
  var seen = {};

  var processed = html.replace(
    /\[\[([^\]|]+)(?:\|([^\]]+))?\]\]/g,
    function(_, rawTarget, displayText) {
      var targetSlug = rawTarget.trim().toLowerCase().replace(/ /g, '-');
      var label = displayText || rawTarget.trim();
      var exists = knownSlugs[targetSlug];
      var cssClass = exists ? 'wikilink' : 'wikilink missing';

      if (exists && targetSlug !== currentPageSlug && !seen[targetSlug]) {
        outgoingLinks.push(targetSlug);
        seen[targetSlug] = true;
      }

      return '<a class="' + cssClass + '" data-slug="' + escapeHtml(targetSlug) +
        '" href="' + encodeURI(targetSlug) + '.html">' + escapeHtml(label) + '</a>';
    }
  );

  return { html: processed, outgoingLinks: outgoingLinks };
}

function addNewTabToExternalLinks(html) {
  return html.replace(
    /<a\s+((?:(?!class="wikilink)[^>])*)href="(https?:\/\/[^"]*)"([^>]*)>/g,
    function(match, before, url, after) {
      if (match.indexOf('target=') !== -1) return match;
      return '<a ' + before + 'href="' + url + '"' + after + ' target="_blank" rel="noopener">';
    }
  );
}

function buildTableOfContents(html) {
  var headings = [];
  var idCounts = {};

  var htmlWithIds = html.replace(
    /<(h[23])([^>]*)>([\s\S]*?)<\/\1>/gi,
    function(_, tag, attrs, innerHTML) {
      var text = innerHTML.replace(/<[^>]+>/g, '').trim();
      var id = text.toLowerCase().replace(/[^\w\s-]/g, '').replace(/\s+/g, '-');

      if (idCounts[id] !== undefined) {
        idCounts[id]++;
        id = id + '-' + idCounts[id];
      } else {
        idCounts[id] = 0;
      }

      var level = tag.toLowerCase() === 'h2' ? 2 : 3;
      headings.push({ level: level, text: text, id: id });
      return '<' + tag + attrs + ' id="' + id + '">' + innerHTML + '</' + tag + '>';
    }
  );

  if (headings.length < 2) return { tocHtml: '', htmlWithIds: htmlWithIds };

  var tocListItems = '';
  var inSublist = false;

  for (var i = 0; i < headings.length; i++) {
    var heading = headings[i];
    if (heading.level === 3 && !inSublist) { tocListItems += '<ul>'; inSublist = true; }
    if (heading.level === 2 && inSublist) { tocListItems += '</ul>'; inSublist = false; }
    tocListItems += '<li><a href="#' + heading.id + '">' + escapeHtml(heading.text) + '</a></li>';
  }
  if (inSublist) tocListItems += '</ul>';

  var tocHtml = '<section class="toc-block"><h4>Contents</h4>' +
    '<div class="toc"><ul>' + tocListItems + '</ul></div></section>';

  return { tocHtml: tocHtml, htmlWithIds: htmlWithIds };
}

// ============================================================
//  Source-page infobox extraction
// ============================================================

function extractSourceInfobox(body) {
  var lines = body.split('\n');
  var metadataLines = [];
  var avatarLine = '';
  var cursor = 0;

  // Skip leading blanks
  while (cursor < lines.length && lines[cursor].trim() === '') cursor++;

  // Optional avatar image (e.g. profile pic)
  if (cursor < lines.length && /^!\[/.test(lines[cursor].trim())) {
    avatarLine = lines[cursor].trim();
    cursor++;
    while (cursor < lines.length && lines[cursor].trim() === '') cursor++;
  }

  // Collect **Key:** value lines
  while (cursor < lines.length && /^\*\*[^*]+:\*\*/.test(lines[cursor].trim())) {
    metadataLines.push(lines[cursor].trim());
    cursor++;
  }

  if (metadataLines.length === 0) {
    return { tableHtml: '', remainingBody: body };
  }

  // Skip trailing blanks and optional --- divider
  while (cursor < lines.length && lines[cursor].trim() === '') cursor++;
  if (cursor < lines.length && /^---+$/.test(lines[cursor].trim())) cursor++;
  while (cursor < lines.length && lines[cursor].trim() === '') cursor++;

  // Build infobox table rows
  var tableRows = metadataLines.map(function(line) {
    var match = line.match(/^\*\*([^*]+):\*\*\s*(.*)/);
    if (!match) return '';
    return buildInfoboxRow(match[1], match[2]);
  }).join('');

  var tableHtml = '<table class="infobox"><caption>Source</caption>' + tableRows + '</table>';

  var remainingBody = lines.slice(cursor).join('\n');
  if (avatarLine) remainingBody = avatarLine + '\n\n' + remainingBody;

  return { tableHtml: tableHtml, remainingBody: remainingBody };
}

// ============================================================
//  Utilities
// ============================================================

function findMarkdownFiles(dir, outputDir) {
  var results = [];
  var entries = listDir(dir);
  for (var i = 0; i < entries.length; i++) {
    var entry = entries[i];
    var entryPath = dir + '/' + entry;
    if (entryPath === outputDir || entry.charAt(0) === '.' || entry === 'raw') continue;
    if (/\.md$/i.test(entry)) {
      results.push(entryPath);
    } else if (!/\./.test(entry)) {
      try { results = results.concat(findMarkdownFiles(entryPath, outputDir)); }
      catch (e) {}
    }
  }
  return results;
}

function buildSlugSet(filePaths) {
  var slugs = {};
  filePaths.forEach(function(fp) { slugs[slugFromPath(fp)] = true; });
  return slugs;
}

function slugFromPath(filePath) {
  var filename = filePath.split('/').pop();
  return filename.replace(/\.md$/i, '').toLowerCase().replace(/ /g, '-');
}

function extractTitle(source) {
  var match = source.match(/^#\s+(.+)/m);
  return match ? match[1].trim() : null;
}

// Shared render pipeline: parse frontmatter, render markdown, resolve
// wikilinks, assemble infobox. Used by both compilePage and parseAllPages.
function renderPageBody(source, knownSlugs, slug) {
  var parsed = parseFrontmatter(source);
  var title = extractTitle(parsed.body) || (parsed.fm && parsed.fm.title) || slug;
  var body = stripLeadingH1(parsed.body);

  var fmInfoboxHtml = renderFrontmatterInfobox(parsed.fm);
  var subtitle = renderSubtitle(parsed.fm);

  // Only scan for legacy **Key:** infobox if no YAML frontmatter
  if (!fmInfoboxHtml) {
    var infobox = extractSourceInfobox(body);
    body = infobox.remainingBody;
  }
  body = transformCallouts(body);

  var renderedHtml = md.render(body);
  var linkResult = resolveWikilinks(renderedHtml, knownSlugs, slug);
  renderedHtml = addNewTabToExternalLinks(linkResult.html);

  if (fmInfoboxHtml) {
    renderedHtml = fmInfoboxHtml + renderedHtml;
  } else if (infobox && infobox.tableHtml) {
    renderedHtml = infobox.tableHtml + renderedHtml;
  }

  return {
    html: renderedHtml,
    title: title,
    subtitle: subtitle,
    hasInfobox: !!(parsed.fm || fmInfoboxHtml || (infobox && infobox.tableHtml)),
    outgoingLinks: linkResult.outgoingLinks
  };
}

// Parse YAML frontmatter (---\nkey: value\n---) into an object.
// Returns { fm: {key: value, ...}, body: remaining text }.
function parseFrontmatter(source) {
  var match = source.match(/^---\n([\s\S]*?)\n---\n*/);
  if (!match) return { fm: null, body: source };
  var fm = {};
  match[1].split('\n').forEach(function(line) {
    var idx = line.indexOf(':');
    if (idx === -1) return;
    var key = line.slice(0, idx).trim();
    var val = line.slice(idx + 1).trim();
    if (key) fm[key] = val;
  });
  return { fm: fm, body: source.slice(match[0].length) };
}

// Render a subtitle line from frontmatter: "type · author · date"
function renderSubtitle(fm) {
  if (!fm) return '';
  var bits = ['type', 'author', 'date'].reduce(function(acc, key) {
    if (fm[key]) acc.push(escapeHtml(fm[key]));
    return acc;
  }, []);
  if (bits.length === 0) return '';
  return '<div class="article-subtitle">' + bits.join(' \u00b7 ') + '</div>';
}

// Build a single infobox row, auto-linking URLs.
function buildInfoboxRow(key, value) {
  var cellHtml;
  if (/^https?:\/\//.test(value)) {
    cellHtml = '<a href="' + escapeHtml(value) + '" class="extlink" target="_blank" rel="noopener">' +
      escapeHtml(value) + '</a>';
  } else {
    cellHtml = escapeHtml(value);
  }
  return '<tr><th>' + escapeHtml(key) + '</th><td>' + cellHtml + '</td></tr>';
}

// Render a floating infobox table from frontmatter fields.
// Skips fields already shown in the subtitle.
function renderFrontmatterInfobox(fm) {
  if (!fm) return '';
  var skipKeys = { title: true, type: true, author: true, date: true };
  var rows = Object.keys(fm)
    .filter(function(k) { return !skipKeys[k]; })
    .map(function(k) { return buildInfoboxRow(k, fm[k]); })
    .join('');
  if (!rows) return '';
  return '<table class="infobox"><caption>Source</caption>' + rows + '</table>';
}

function stripLeadingH1(source) {
  return source.replace(/^#\s+.*\n?\n?/, '');
}

function markdownToPlainText(source) {
  var text = source;
  text = text.replace(/^---[\s\S]*?---\n*/m, '');             // YAML frontmatter
  text = text.replace(/\[\[([^\]|]+)\|([^\]]+)\]\]/g, '$2');  // [[target|display]] → display
  text = text.replace(/\[\[([^\]]+)\]\]/g, '$1');              // [[target]] → target
  text = text.replace(/^#{1,6}\s+/gm, '');                    // headings
  text = text.replace(/!\[[^\]]*\]\([^)]*\)/g, '');            // images
  text = text.replace(/\[([^\]]+)\]\([^)]*\)/g, '$1');         // links → text
  text = text.replace(/(\*\*|__)(.*?)\1/g, '$2');              // bold
  text = text.replace(/(\*|_)(.*?)\1/g, '$2');                 // italic
  text = text.replace(/`[^`]+`/g, '');                         // inline code
  text = text.replace(/^>\s?/gm, '');                          // blockquote markers
  text = text.replace(/^[-*+]\s+/gm, '');                     // unordered list markers
  text = text.replace(/^\d+\.\s+/gm, '');                     // ordered list markers
  text = text.replace(/\n{2,}/g, ' ').replace(/\s+/g, ' ').trim();
  return text;
}

// Preserves bold, italic, headers, wikilinks — strips everything else.
// Used by the editorial map canvas for rich text rendering.
function markdownToRichText(source) {
  var text = source;
  text = text.replace(/^---[\s\S]*?---\n*/m, '');                 // YAML frontmatter
  text = text.replace(/```[\s\S]*?```/g, '');                     // fenced code
  text = text.replace(/!\[[^\]]*\]\([^)]*\)/g, '');               // images
  text = text.replace(/^>\s*\[![^\]]*\][+-]?\s*/gm, '');          // callout markers
  text = text.replace(/^>\s?/gm, '');                             // blockquote markers
  text = text.replace(/^[-*+]\s+/gm, '');                         // list markers
  text = text.replace(/\[\[([^\]|]+?)(?:\|[^\]]+)?\]\]/g,         // [[slug]] → {{slug}}
    function(_, slug) { return '{{' + slug.trim() + '}}'; });
  text = text.replace(/\[([^\]]+)\]\([^)]*\)/g, '$1');            // [text](url) → text
  text = text.replace(/`([^`]+)`/g, '$1');                        // inline code → plain
  text = text.replace(/^#{2,6}\s+(.+)$/gm,                       // ## Heading → ##Heading
    function(_, heading) { return '##' + heading; });
  text = text.replace(/^#\s+.+$/gm, '');                          // strip H1
  text = text.replace(/^(##[^\n]+)\n(?!\n)/gm, '$1\n\n');         // ensure blank after headers
  text = text.replace(/\n{3,}/g, '\n\n');                         // collapse 3+ newlines
  var paragraphs = text.split('\n\n').map(function(paragraph) {
    return paragraph.replace(/\s+/g, ' ').trim();
  }).filter(function(paragraph) { return paragraph; });
  return paragraphs.join('\n\n');
}

// ============================================================
//  Map: grid layout + HTML generation (lazy, called via compileMap)
// ============================================================

var MAP_CATEGORY_MAP = {
  Discussion: 'question', Concept: 'concept', Entity: 'entity',
  Meta: 'special', Source: 'source', Highlights: 'highlights'
};

var MAP_SPECIAL_SLUGS = { whoami: true, log: true };

function classifyForMap(pageSlug, graphType) {
  if (MAP_SPECIAL_SLUGS[pageSlug]) return 'special';
  return MAP_CATEGORY_MAP[graphType] || 'source';
}

function truncateLabel(label, maxLength) {
  maxLength = maxLength || 16;
  if (label.length <= maxLength) return label;
  var cutoff = maxLength - 1;
  var lastSpace = label.lastIndexOf(' ', cutoff);
  if (lastSpace >= maxLength / 2) return label.substring(0, lastSpace) + '\u2026';
  return label.substring(0, cutoff) + '~';
}

function assignGridPositions(graphNodes, graphLinks) {
  // Build adjacency (skip meta/special pages)
  var adjacency = {};
  var nodeTypes = {};

  graphNodes.forEach(function(node) {
    var category = classifyForMap(node.id, node.type);
    nodeTypes[node.id] = category;
    if (!MAP_SPECIAL_SLUGS[node.id]) {
      adjacency[node.id] = [];
    }
  });

  graphLinks.forEach(function(link) {
    var source = typeof link.source === 'object' ? link.source.id : link.source;
    var target = typeof link.target === 'object' ? link.target.id : link.target;
    if (adjacency[source] && adjacency[target]) {
      adjacency[source].push(target);
      adjacency[target].push(source);
    }
  });

  var placed = {};
  var occupied = {};
  var cells = [];

  function isOccupied(row, col) { return occupied[row + ',' + col]; }
  function markOccupied(row, col) { occupied[row + ',' + col] = true; }

  function findNearestSlot(targetRow, preferredCol) {
    for (var radius = 0; radius < 50; radius++) {
      for (var dr = -radius; dr <= radius; dr++) {
        for (var dc = -radius; dc <= radius; dc++) {
          if (!isOccupied(targetRow + dr, preferredCol + dc)) {
            return [targetRow + dr, preferredCol + dc];
          }
        }
      }
    }
    return [targetRow, preferredCol + 50];
  }

  function placeNode(slug, row, col) {
    placed[slug] = [row, col];
    markOccupied(row, col);
    var node = graphNodes.filter(function(n) { return n.id === slug; })[0];
    cells.push({
      id: slug,
      label: truncateLabel(node ? node.label : slug),
      category: nodeTypes[slug] || 'source',
      row: row,
      col: col,
      href: slug + '.html',
      val: node ? (node.val || 1) : 1,
      words: node ? (node.words || 0) : 0
    });
  }

  // Tier 1: Place questions (discussions) in row 0
  var questions = Object.keys(adjacency)
    .filter(function(slug) { return nodeTypes[slug] === 'question'; })
    .sort(function(a, b) { return (adjacency[b] || []).length - (adjacency[a] || []).length; });

  var questionCol = 0;
  questions.forEach(function(slug) {
    placeNode(slug, 0, questionCol);
    questionCol++;
  });

  // Tier 2: Place concepts/entities/special near their connected questions
  var corridorSlugs = Object.keys(adjacency)
    .filter(function(slug) {
      return !placed[slug] && (nodeTypes[slug] === 'concept' || nodeTypes[slug] === 'entity' || nodeTypes[slug] === 'special');
    })
    .sort(function(a, b) { return (adjacency[b] || []).length - (adjacency[a] || []).length; });

  corridorSlugs.forEach(function(slug) {
    var neighbors = (adjacency[slug] || []).filter(function(n) { return placed[n]; });
    var targetRow, avgCol;

    if (neighbors.length) {
      var avgRow = neighbors.reduce(function(sum, n) { return sum + placed[n][0]; }, 0) / neighbors.length;
      avgCol = neighbors.reduce(function(sum, n) { return sum + placed[n][1]; }, 0) / neighbors.length;
      targetRow = Math.round(avgRow) + (nodeTypes[slug] === 'entity' ? 1 : -1);
    } else {
      targetRow = 2;
      avgCol = Object.keys(placed).length % (questionCol || 1);
    }

    var slot = findNearestSlot(targetRow, Math.round(avgCol));
    placeNode(slug, slot[0], slot[1]);
  });

  // Tier 3: Place sources/highlights further out
  var sourceSlugs = Object.keys(adjacency)
    .filter(function(slug) {
      return !placed[slug] && (nodeTypes[slug] === 'source' || nodeTypes[slug] === 'highlights');
    })
    .sort(function(a, b) { return (adjacency[b] || []).length - (adjacency[a] || []).length; });

  sourceSlugs.forEach(function(slug) {
    var neighbors = (adjacency[slug] || []).filter(function(n) { return placed[n]; });
    var targetRow, avgCol;

    if (neighbors.length) {
      var avgRow = neighbors.reduce(function(sum, n) { return sum + placed[n][0]; }, 0) / neighbors.length;
      avgCol = neighbors.reduce(function(sum, n) { return sum + placed[n][1]; }, 0) / neighbors.length;
      targetRow = avgRow <= 0 ? Math.round(avgRow) - 2 : Math.round(avgRow) + 1;
    } else {
      targetRow = -3;
      avgCol = 0;
    }

    var slot = findNearestSlot(targetRow, Math.round(avgCol));
    placeNode(slug, slot[0], slot[1]);
  });

  // Normalize to 0-based coordinates
  if (cells.length) {
    var minRow = cells.reduce(function(min, c) { return Math.min(min, c.row); }, Infinity);
    var minCol = cells.reduce(function(min, c) { return Math.min(min, c.col); }, Infinity);
    cells.forEach(function(cell) { cell.row -= minRow; cell.col -= minCol; });
  }

  return cells;
}

// Called lazily — generates map.json + map.html from existing graph.json + previews.json
function compileMap(sourceDir, outputDir) {
  var graphJsonPath = outputDir + '/graph.json';
  var previewsJsonPath = outputDir + '/previews.json';

  if (!fileExists(graphJsonPath) || !fileExists(previewsJsonPath)) {
    log('Map skipped — graph.json or previews.json not found. Run compile() first.');
    return;
  }

  var graphData = JSON.parse(readFile(graphJsonPath));
  var previews = JSON.parse(readFile(previewsJsonPath));
  var cells = assignGridPositions(graphData.nodes, graphData.links);

  // Build edge list (only between placed nodes)
  var placedIds = {};
  cells.forEach(function(cell) { placedIds[cell.id] = true; });

  var edges = graphData.links
    .filter(function(link) {
      var source = typeof link.source === 'object' ? link.source.id : link.source;
      var target = typeof link.target === 'object' ? link.target.id : link.target;
      return placedIds[source] && placedIds[target];
    })
    .map(function(link) {
      return {
        source: typeof link.source === 'object' ? link.source.id : link.source,
        target: typeof link.target === 'object' ? link.target.id : link.target
      };
    });

  var stats = { total: cells.length };
  cells.forEach(function(cell) {
    stats[cell.category] = (stats[cell.category] || 0) + 1;
  });

  var mapData = { nodes: cells, edges: edges, stats: stats };
  writeFile(outputDir + '/map.json', JSON.stringify(mapData));

  // Inject data into map.html template
  var mapTemplate = (typeof bundledMapHTML !== 'undefined') ? bundledMapHTML : null;
  if (!mapTemplate) {
    var mapTemplatePath = sourceDir + '/site/map.html';
    if (fileExists(mapTemplatePath)) {
      mapTemplate = readFile(mapTemplatePath);
    }
  }
  if (mapTemplate) {
    var mapHtml = mapTemplate
      .replace('__MAP_DATA_PLACEHOLDER__', safeJsonForScript(mapData))
      .replace('__PREVIEWS_DATA_PLACEHOLDER__', safeJsonForScript(previews))
      .replace('__GRAPH_DATA_PLACEHOLDER__', safeJsonForScript(graphData));
    writeFile(outputDir + '/map.html', mapHtml);
  }

  // Inject data into map-3d.html template
  var map3dTemplate = (typeof bundledMap3dHTML !== 'undefined') ? bundledMap3dHTML : null;
  if (!map3dTemplate) {
    var map3dTemplatePath = sourceDir + '/site/map-3d.html';
    if (fileExists(map3dTemplatePath)) {
      map3dTemplate = readFile(map3dTemplatePath);
    }
  }
  if (map3dTemplate) {
    var map3dHtml = map3dTemplate
      .replace('__MAP_DATA_PLACEHOLDER__', safeJsonForScript(mapData))
      .replace('__PREVIEWS_DATA_PLACEHOLDER__', safeJsonForScript(previews));
    writeFile(outputDir + '/map-3d.html', map3dHtml);
  }

  log('Map compiled: ' + cells.length + ' nodes, ' + edges.length + ' edges');
}

// ============================================================
//  Compile cache for incremental builds
// ============================================================

function loadCompileCache(cachePath) {
  if (!fileExists(cachePath)) return {};
  try { return JSON.parse(readFile(cachePath)); }
  catch (e) { return {}; }
}

function saveCompileCache(cachePath, pages, markdownFiles) {
  var activeSlugs = buildSlugSet(markdownFiles);
  var cache = {};

  for (var pageSlug in pages) {
    if (!activeSlugs[pageSlug]) continue;
    var page = pages[pageSlug];
    cache[pageSlug] = {
      title: page.title,
      html: page.html,
      hasInfobox: page.hasInfobox,
      outgoingLinks: page.outgoingLinks,
      plainText: page.plainText,
      richText: page.richText,
      mtime: page.mtime
    };
  }

  writeFile(cachePath, JSON.stringify(cache));
}

function escapeHtml(str) {
  return str
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

// JSON.stringify does not escape </script>, which allows premature tag
// closure when embedding JSON inside a <script> block. This helper
// escapes </ to <\/ so the HTML parser cannot see a closing tag.
function safeJsonForScript(value) {
  return JSON.stringify(value).replace(/<\//g, '<\\/');
}
