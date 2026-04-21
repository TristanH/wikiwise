// Wikiwise graph visualization — force-directed with D3 + force-graph.
// Injected variables: GRAPH_DATA (inline JSON), GRAPH_COLORS (color map)
(function () {
  var COLORS = GRAPH_COLORS;

  // ---- Color utilities ----
  function hexToRgb(hex) {
    var digits = hex.replace('#', '');
    return {
      r: parseInt(digits.slice(0, 2), 16),
      g: parseInt(digits.slice(2, 4), 16),
      b: parseInt(digits.slice(4, 6), 16)
    };
  }

  var rgbByType = {};
  for (var colorKey in COLORS) rgbByType[colorKey] = hexToRgb(COLORS[colorKey]);

  function rgba(type, alpha) {
    var rgb = rgbByType[type] || { r: 150, g: 150, b: 150 };
    return 'rgba(' + rgb.r + ',' + rgb.g + ',' + rgb.b + ',' + alpha + ')';
  }

  function nodeRadius(node) {
    return 3 + Math.log(1 + (node.val || 1)) * 2.6;
  }

  // ---- Initialize graph ----
  var data = GRAPH_DATA;
  var allNodes = data.nodes.map(function(node) { return Object.assign({}, node); });
  var allLinks = data.links.map(function(link) { return Object.assign({}, link); });

  // Build neighbor index for hover highlighting
  var neighborSets = new Map();
  allNodes.forEach(function(node) { neighborSets.set(node.id, new Set()); });
  allLinks.forEach(function(link) {
    neighborSets.get(link.source).add(link.target);
    neighborSets.get(link.target).add(link.source);
  });

  var canvasEl = document.getElementById('graph-canvas');
  var hoveredNodeId = null;
  var bgColor = (getComputedStyle(document.documentElement)
    .getPropertyValue('--bg') || '#fbfaf5').trim();

  function isNeighborOf(nodeA, nodeB) {
    if (nodeA === nodeB) return true;
    var set = neighborSets.get(nodeA);
    return set ? set.has(nodeB) : false;
  }

  // ---- Render graph ----
  var graph = ForceGraph()(canvasEl)
    .graphData({ nodes: allNodes, links: allLinks })
    .backgroundColor(bgColor)
    .nodeRelSize(1)
    .nodeVal(function(node) { return Math.pow(nodeRadius(node), 2); })
    .nodeLabel(function() { return ''; })
    .autoPauseRedraw(false)
    .linkColor(function(link) {
      var sourceId = typeof link.source === 'object' ? link.source.id : link.source;
      var targetId = typeof link.target === 'object' ? link.target.id : link.target;
      if (!hoveredNodeId) return 'rgba(120, 105, 85, 0.13)';
      if (sourceId === hoveredNodeId || targetId === hoveredNodeId) return 'rgba(80, 65, 50, 0.55)';
      return 'rgba(120, 105, 85, 0.04)';
    })
    .linkWidth(function(link) {
      var sourceId = typeof link.source === 'object' ? link.source.id : link.source;
      var targetId = typeof link.target === 'object' ? link.target.id : link.target;
      return (hoveredNodeId && (sourceId === hoveredNodeId || targetId === hoveredNodeId)) ? 1.4 : 0.5;
    })
    .onNodeHover(function(node) {
      hoveredNodeId = node ? node.id : null;
      canvasEl.style.cursor = node ? 'pointer' : '';
    })
    .onNodeClick(function(node, event) {
      if (event && event.shiftKey) { window.location = node.href; return; }
      openSidePane(node);
    })
    .onBackgroundClick(function() { hoveredNodeId = null; })
    .nodeCanvasObjectMode(function() { return 'replace'; })
    .nodeCanvasObject(renderNode);

  function renderNode(node, ctx, scale) {
    if (!Number.isFinite(node.x) || !Number.isFinite(node.y)) return;

    var radius = nodeRadius(node);
    var isFocused = !hoveredNodeId || isNeighborOf(hoveredNodeId, node.id);
    var baseAlpha = isFocused ? 0.92 : 0.14;

    // Outer halo glow
    var haloRadius = radius * (isFocused && hoveredNodeId === node.id ? 3.2 : 2.1);
    var haloGrad = ctx.createRadialGradient(node.x, node.y, radius * 0.6, node.x, node.y, haloRadius);
    haloGrad.addColorStop(0, rgba(node.type, isFocused ? 0.28 : 0.04));
    haloGrad.addColorStop(1, rgba(node.type, 0));
    ctx.beginPath();
    ctx.arc(node.x, node.y, haloRadius, 0, 2 * Math.PI);
    ctx.fillStyle = haloGrad;
    ctx.fill();

    // Node body with radial gradient
    var bodyGrad = ctx.createRadialGradient(
      node.x - radius * 0.35, node.y - radius * 0.35, radius * 0.1,
      node.x, node.y, radius
    );
    bodyGrad.addColorStop(0, rgba(node.type, Math.min(1, baseAlpha + 0.06)));
    bodyGrad.addColorStop(1, rgba(node.type, baseAlpha));
    ctx.beginPath();
    ctx.arc(node.x, node.y, radius, 0, 2 * Math.PI);
    ctx.fillStyle = bodyGrad;
    ctx.fill();

    // Hairline stroke
    ctx.lineWidth = 0.8 / scale;
    ctx.strokeStyle = rgba(node.type, isFocused ? 0.65 : 0.12);
    ctx.stroke();

    // Label visibility: show neighbors when hovering, all labels at high zoom
    var isHovered = node.id === hoveredNodeId;
    var isNeighborOfHovered = hoveredNodeId && neighborSets.get(hoveredNodeId).has(node.id);
    var showLabel = hoveredNodeId ? (isHovered || isNeighborOfHovered) : (scale >= 1.3);
    if (!showLabel) return;

    var fontSize = Math.max(3, (isHovered ? 12 : 10) / scale);
    ctx.font = (isHovered ? '600 ' : '') + fontSize + 'px Inter, sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'top';

    // White outline for readability
    ctx.lineWidth = (isHovered ? 3.2 : 2.4) / scale;
    ctx.strokeStyle = 'rgba(251, 250, 245, 0.9)';
    ctx.strokeText(node.label, node.x, node.y + radius + 2);

    ctx.fillStyle = isHovered ? 'rgba(26, 22, 18, 1)'
      : (isNeighborOfHovered ? 'rgba(26, 22, 18, 0.92)' : 'rgba(26, 22, 18, 0.75)');
    ctx.fillText(node.label, node.x, node.y + radius + 2);
  }

  // Clear hover when mouse leaves canvas
  canvasEl.addEventListener('mouseleave', function() {
    hoveredNodeId = null;
    canvasEl.style.cursor = '';
  });

  // ---- Force tuning ----
  graph.d3Force('charge').strength(-420).distanceMax(520);
  graph.d3Force('link')
    .distance(function(link) {
      var sourceVal = (link.source && link.source.val) || 1;
      var targetVal = (link.target && link.target.val) || 1;
      return 60 + Math.max(sourceVal, targetVal) * 0.35;
    })
    .strength(0.35);
  graph.d3Force('collide', d3.forceCollide()
    .radius(function(node) { return nodeRadius(node) + 6; })
    .strength(1).iterations(3));
  graph.d3Force('x', d3.forceX(0).strength(0.04));
  graph.d3Force('y', d3.forceY(0).strength(0.04));
  graph.cooldownTicks(250).d3AlphaDecay(0.02).warmupTicks(20);

  // ---- Legend with category filtering ----
  var legendEl = document.getElementById('legend-items');
  var activeCategories = {};
  for (var categoryName in COLORS) activeCategories[categoryName] = true;

  var categoryCounts = {};
  allNodes.forEach(function(node) { categoryCounts[node.type] = (categoryCounts[node.type] || 0) + 1; });

  function applyFilter() {
    var visibleIds = {};
    allNodes.forEach(function(node) { if (activeCategories[node.type]) visibleIds[node.id] = true; });
    graph.graphData({
      nodes: allNodes.filter(function(node) { return visibleIds[node.id]; }),
      links: data.links
        .filter(function(link) { return visibleIds[link.source] && visibleIds[link.target]; })
        .map(function(link) { return Object.assign({}, link); })
    });
  }

  Object.keys(COLORS).forEach(function(type) {
    if (!categoryCounts[type]) return;
    var li = document.createElement('li');
    li.innerHTML =
      '<span class="dot" style="background:' + COLORS[type] + '"></span>' +
      '<span>' + type + '</span>' +
      '<span class="count">' + categoryCounts[type] + '</span>';
    li.addEventListener('click', function() {
      if (activeCategories[type]) delete activeCategories[type];
      else activeCategories[type] = true;
      li.classList.toggle('dimmed', !activeCategories[type]);
      applyFilter();
    });
    legendEl.appendChild(li);
  });

  document.getElementById('graph-stats').innerHTML =
    '<strong>' + allNodes.length + '</strong> pages \u00b7 ' +
    '<strong>' + allLinks.length + '</strong> links';

  // ---- Responsive sizing ----
  var graphRootEl = document.querySelector('.graph-root');
  var graphLayoutEl = document.getElementById('graph-layout');
  var mastheadEl = document.querySelector('.masthead');

  function syncLayoutOffset() {
    var mastheadHeight = mastheadEl ? mastheadEl.getBoundingClientRect().height : 61;
    graphLayoutEl.style.top = mastheadHeight + 'px';
    graphLayoutEl.style.height = 'calc(100vh - ' + mastheadHeight + 'px)';
  }

  function resizeCanvas() {
    syncLayoutOffset();
    var width = graphRootEl.clientWidth;
    var height = graphRootEl.clientHeight;
    if (width > 0 && height > 0) graph.width(width).height(height);
  }

  syncLayoutOffset();
  resizeCanvas();

  if (window.ResizeObserver) {
    new ResizeObserver(resizeCanvas).observe(graphRootEl);
  } else {
    window.addEventListener('resize', resizeCanvas);
  }
  document.addEventListener('visibilitychange', function() {
    if (document.visibilityState === 'visible') resizeCanvas();
  });

  // ---- Side pane (article preview on node click) ----
  var layoutEl = document.getElementById('graph-layout');
  var sideFrame = document.getElementById('side-frame');
  var sideTitleEl = document.getElementById('side-title');
  var currentPreviewHref = null;

  var PREVIEW_CSS = [
    '.masthead, .rail, .toc-block, .backlinks-main, .article-foot { display: none !important }',
    '.layout { display: block !important; padding: 0 !important; margin: 0 !important; max-width: none !important }',
    '.article { max-width: none !important; width: auto !important; padding: 1.4rem 2rem 3rem !important; margin: 0 !important }',
    '.article-head { margin-top: 0 !important }',
    '.article-title { margin-top: 0 !important }',
    'body { padding: 0 !important; margin: 0 !important; background: var(--bg) !important }',
    'html { overflow-x: hidden }'
  ].join('\n');

  function applyPreviewStyles() {
    try {
      var doc = sideFrame.contentDocument;
      if (!doc) return;
      var styleEl = doc.getElementById('wikiwise-preview-style');
      if (!styleEl) {
        styleEl = doc.createElement('style');
        styleEl.id = 'wikiwise-preview-style';
        doc.head.appendChild(styleEl);
      }
      styleEl.textContent = PREVIEW_CSS;
    } catch (_) {}
  }

  sideFrame.addEventListener('load', applyPreviewStyles);

  function openSidePane(node) {
    currentPreviewHref = node.href;
    sideTitleEl.textContent = node.type;
    sideFrame.src = node.href;
    layoutEl.classList.add('open');
    graph.d3ReheatSimulation();
  }

  function closeSidePane() {
    layoutEl.classList.remove('open');
    currentPreviewHref = null;
    setTimeout(function() {
      if (!layoutEl.classList.contains('open')) sideFrame.src = 'about:blank';
    }, 350);
    graph.d3ReheatSimulation();
  }

  document.getElementById('side-close').addEventListener('click', closeSidePane);
  document.getElementById('side-open').addEventListener('click', function() {
    if (currentPreviewHref) window.location = currentPreviewHref;
  });
  document.addEventListener('keydown', function(event) {
    if (event.key === 'Escape' && layoutEl.classList.contains('open')) closeSidePane();
  });
})();
