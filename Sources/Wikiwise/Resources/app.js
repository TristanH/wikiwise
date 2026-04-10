// Wikiwise client-side: search, wikilink hover previews, TOC scrollspy.
(function () {

  function escapeHtml(text) {
    return String(text).replace(/[&<>"']/g, function(char) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[char];
    });
  }

  // ---- Search ----

  var searchIndex = window.__searchIndex || [];

  if (!searchIndex.length) {
    fetch('search.json')
      .then(function(response) { return response.json(); })
      .then(function(data) { searchIndex = data; })
      .catch(function() {});
  }

  var searchInput = document.getElementById('search-input');
  var searchResults = document.getElementById('search-results');

  function scorePages(query) {
    query = query.toLowerCase().trim();
    if (!query) return [];

    var terms = query.split(/\s+/);

    return searchIndex
      .map(function(page) {
        var title = page.title.toLowerCase();
        var body = page.text.toLowerCase();
        var slug = page.slug.toLowerCase();
        var score = 0;

        if (title === query) score += 200;
        else if (title.indexOf(query) === 0) score += 100;
        else if (title.indexOf(query) !== -1) score += 40;
        if (slug.indexOf(query) !== -1) score += 20;

        for (var idx = 0; idx < terms.length; idx++) {
          if (title.indexOf(terms[idx]) !== -1) score += 8;
          if (body.indexOf(terms[idx]) !== -1) score += 2;
        }

        return { page: page, score: score };
      })
      .filter(function(result) { return result.score > 0; })
      .sort(function(left, right) { return right.score - left.score; })
      .slice(0, 8)
      .map(function(result) { return result.page; });
  }

  function renderSearchResults(matchedPages) {
    if (!matchedPages.length) {
      searchResults.style.display = 'none';
      searchResults.innerHTML = '';
      return;
    }

    searchResults.innerHTML = matchedPages
      .map(function(page) {
        return '<a href="' + page.href + '"><strong>' + escapeHtml(page.title) + '</strong>' +
          '<div class="hint">' + escapeHtml(page.slug) + '</div></a>';
      })
      .join('');
    searchResults.style.display = 'block';
  }

  if (searchInput && searchResults) {
    searchInput.addEventListener('input', function() {
      renderSearchResults(scorePages(searchInput.value));
    });

    searchInput.addEventListener('keydown', function(event) {
      if (event.key === 'Enter') {
        var firstResult = searchResults.querySelector('a');
        if (firstResult) window.location = firstResult.getAttribute('href');
      } else if (event.key === 'Escape') {
        searchResults.style.display = 'none';
        searchInput.blur();
      }
    });

    document.addEventListener('click', function(event) {
      if (!searchResults.contains(event.target) && event.target !== searchInput) {
        searchResults.style.display = 'none';
      }
    });
  }

  // ---- Wikilink hover preview popover ----

  var previewData = window.__previewData || null;
  var previewLoadPromise = null;
  var popoverEl = null;
  var activeAnchor = null;
  var showTimer = null;
  var hideTimer = null;

  function clearTimers() {
    clearTimeout(showTimer);
    clearTimeout(hideTimer);
  }

  function ensurePopoverElement() {
    if (popoverEl) return popoverEl;
    popoverEl = document.createElement('div');
    popoverEl.className = 'wiki-popover';
    document.body.appendChild(popoverEl);
    popoverEl.addEventListener('mouseenter', function() { clearTimeout(hideTimer); });
    popoverEl.addEventListener('mouseleave', scheduleHide);
    return popoverEl;
  }

  function showPopover(anchor, preview) {
    ensurePopoverElement();

    popoverEl.innerHTML =
      (preview.type ? '<div class="pop-type">' + escapeHtml(preview.type) + '</div>' : '') +
      '<div class="pop-title">' + escapeHtml(preview.title) + '</div>' +
      '<p class="pop-lead">' + escapeHtml(preview.lead || '') + '</p>';

    var anchorRect = anchor.getBoundingClientRect();
    var popoverWidth = 23 * 16; // matches CSS: 23rem at 16px root
    var viewportMargin = 16;

    var leftPos = anchorRect.left + window.scrollX;
    if (leftPos + popoverWidth > window.scrollX + window.innerWidth - viewportMargin) {
      leftPos = window.scrollX + window.innerWidth - popoverWidth - viewportMargin;
    }
    if (leftPos < viewportMargin) leftPos = viewportMargin;

    popoverEl.style.left = leftPos + 'px';
    popoverEl.style.top = anchorRect.bottom + window.scrollY + 6 + 'px';
    requestAnimationFrame(function() { popoverEl.classList.add('visible'); });
    activeAnchor = anchor;
  }

  function hidePopover() {
    if (!popoverEl) return;
    popoverEl.classList.remove('visible');
    // Park off-screen after fade to prevent stale hit-testing
    setTimeout(function() {
      if (popoverEl && !popoverEl.classList.contains('visible')) {
        popoverEl.style.left = '-9999px';
        popoverEl.style.top = '-9999px';
      }
    }, 160);
    activeAnchor = null;
  }

  function scheduleHide() {
    clearTimers();
    hideTimer = setTimeout(hidePopover, 160);
  }

  function loadPreviewData() {
    if (previewData || previewLoadPromise) return previewLoadPromise;
    previewLoadPromise = fetch('previews.json')
      .then(function(response) { return response.json(); })
      .then(function(data) { previewData = data; })
      .catch(function() { previewData = {}; });
    return previewLoadPromise;
  }

  document.addEventListener('mouseover', function(event) {
    var wikilinkAnchor = event.target.closest('a.wikilink[data-slug]');
    if (!wikilinkAnchor || wikilinkAnchor.classList.contains('missing')) return;
    if (wikilinkAnchor === activeAnchor) { clearTimeout(hideTimer); return; }

    clearTimers();
    var targetSlug = wikilinkAnchor.dataset.slug;

    var triggerPopover = function() {
      var preview = previewData && previewData[targetSlug];
      if (preview) showPopover(wikilinkAnchor, preview);
    };

    if (previewData) {
      showTimer = setTimeout(triggerPopover, 220);
    } else {
      loadPreviewData().then(function() {
        showTimer = setTimeout(triggerPopover, 60);
      });
    }
  });

  document.addEventListener('mouseout', function(event) {
    var wikilinkAnchor = event.target.closest('a.wikilink[data-slug]');
    if (!wikilinkAnchor) return;
    clearTimeout(showTimer);
    scheduleHide();
  });

  // ---- TOC scrollspy ----

  (function initScrollspy() {
    var tocAnchors = Array.from(
      document.querySelectorAll('.toc-block .toc a[href^="#"]')
    );
    if (!tocAnchors.length) return;

    // Map each heading element to its corresponding TOC anchor
    var headingToAnchor = new Map();
    var idToAnchor = new Map();

    for (var idx = 0; idx < tocAnchors.length; idx++) {
      var tocAnchor = tocAnchors[idx];
      var headingId = decodeURIComponent(tocAnchor.getAttribute('href').slice(1));
      var headingEl = document.getElementById(headingId);
      if (headingEl) {
        headingToAnchor.set(headingEl, tocAnchor);
        idToAnchor.set(headingId, tocAnchor);
      }
    }

    if (!headingToAnchor.size) return;

    var visibleHeadingIds = new Set();

    var observer = new IntersectionObserver(
      function(entries) {
        for (var idx = 0; idx < entries.length; idx++) {
          var entry = entries[idx];
          if (entry.isIntersecting) {
            visibleHeadingIds.add(entry.target.id);
          } else {
            visibleHeadingIds.delete(entry.target.id);
          }
        }

        // Pick the first visible heading in document order
        var activeHeadingId = null;
        headingToAnchor.forEach(function(anchor, heading) {
          if (!activeHeadingId && visibleHeadingIds.has(heading.id)) {
            activeHeadingId = heading.id;
          }
        });

        // Fallback: last heading that has scrolled above the midpoint of the viewport
        if (!activeHeadingId) {
          headingToAnchor.forEach(function(anchor, heading) {
            if (heading.getBoundingClientRect().top < window.innerHeight * 0.4) {
              activeHeadingId = heading.id;
            }
          });
        }

        // Fallback: if still nothing active, highlight the first TOC item
        if (!activeHeadingId) {
          var firstHeading = null;
          headingToAnchor.forEach(function(anchor, heading) {
            if (!firstHeading) firstHeading = heading;
          });
          if (firstHeading) activeHeadingId = firstHeading.id;
        }

        // Update active class
        tocAnchors.forEach(function(anchor) { anchor.classList.remove('active'); });
        if (activeHeadingId && idToAnchor.get(activeHeadingId)) {
          idToAnchor.get(activeHeadingId).classList.add('active');
        }
      },
      { rootMargin: '0px 0px -60% 0px', threshold: 0 }
    );

    headingToAnchor.forEach(function(anchor, heading) {
      observer.observe(heading);
    });
  })();

  // Hide popover on scroll to prevent stale positioning
  document.addEventListener('scroll', function() {
    clearTimers();
    hidePopover();
  }, { passive: true });

})();
