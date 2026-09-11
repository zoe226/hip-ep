/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

/*
 * Progressive enhancement only: every feature below is additive. With
 * JavaScript disabled the site still renders, navigates, and reads correctly —
 * the sidebar, pager, and content are all server-rendered by Jekyll. That
 * matters because one acceptance criterion for these docs is that an agent or
 * a plain text-mode browser can follow Get Started end to end.
 */
(function () {
  'use strict';

  var THEME_KEY = 'hipep-theme';
  var root = document.documentElement;

  /* ---------------------------------------------------------------- theme */

  function initTheme() {
    var button = document.querySelector('[data-theme-toggle]');
    if (!button) return;

    button.addEventListener('click', function () {
      var next = root.getAttribute('data-theme') === 'light' ? 'dark' : 'light';
      root.setAttribute('data-theme', next);
      try {
        localStorage.setItem(THEME_KEY, next);
      } catch (e) {
        /* Private mode: the toggle still works, it just will not persist. */
      }
    });
  }

  /* ------------------------------------------------------------ mobile nav */

  function initMobileNav() {
    var button = document.querySelector('[data-nav-toggle]');
    var menu = document.querySelector('[data-nav-mobile]');
    if (!button || !menu) return;

    button.addEventListener('click', function () {
      var open = menu.hasAttribute('hidden');
      if (open) {
        menu.removeAttribute('hidden');
      } else {
        menu.setAttribute('hidden', '');
      }
      button.setAttribute('aria-expanded', String(open));
    });
  }

  /* --------------------------------------------------------- copy buttons */

  function initCodeCopy() {
    var blocks = document.querySelectorAll('.docs-content div.highlight, .prose div.highlight');

    Array.prototype.forEach.call(blocks, function (block) {
      var pre = block.querySelector('pre');
      if (!pre) return;

      var button = document.createElement('button');
      button.type = 'button';
      button.className = 'code-copy';
      button.textContent = 'Copy';
      button.setAttribute('aria-label', 'Copy code to clipboard');

      button.addEventListener('click', function () {
        var text = pre.innerText.replace(/\n$/, '');
        var done = function (ok) {
          button.textContent = ok ? 'Copied' : 'Failed';
          button.classList.toggle('is-done', ok);
          setTimeout(function () {
            button.textContent = 'Copy';
            button.classList.remove('is-done');
          }, 1600);
        };

        if (navigator.clipboard && navigator.clipboard.writeText) {
          navigator.clipboard.writeText(text).then(function () { done(true); },
            function () { done(false); });
        } else {
          done(false);
        }
      });

      block.appendChild(button);
    });
  }

  /* ------------------------------------------------------------------ toc */

  function slugify(text) {
    return text.toLowerCase().trim()
      .replace(/[^\w一-鿿\- ]+/g, '')
      .replace(/\s+/g, '-')
      .replace(/-+/g, '-');
  }

  function initToc() {
    var content = document.querySelector('.docs-content');
    var panel = document.querySelector('[data-docs-toc]');
    var list = document.querySelector('[data-docs-toc-list]');
    if (!content || !panel || !list) return;

    var headings = content.querySelectorAll('h2, h3');
    var links = [];
    var seen = {};

    Array.prototype.forEach.call(headings, function (heading) {
      var text = heading.textContent.trim();
      if (!text) return;

      if (!heading.id) {
        // kramdown already assigns ids; this only covers headings emitted by
        // raw HTML in a page, and must not collide with an existing one.
        var base = slugify(text) || 'section';
        var id = base;
        var n = 1;
        while (seen[id] || document.getElementById(id)) {
          id = base + '-' + n;
          n += 1;
        }
        heading.id = id;
      }
      seen[heading.id] = true;

      // A hover anchor makes every heading directly linkable, which is what
      // lets us cite a specific step of a walkthrough in an issue or a PR.
      var anchor = document.createElement('a');
      anchor.className = 'anchor-link';
      anchor.href = '#' + heading.id;
      anchor.setAttribute('aria-label', 'Link to this section');
      anchor.textContent = '#';
      heading.appendChild(anchor);

      var link = document.createElement('a');
      link.href = '#' + heading.id;
      link.textContent = text;
      link.setAttribute('data-level', heading.tagName === 'H3' ? '3' : '2');
      list.appendChild(link);
      links.push(link);
    });

    if (!links.length) return;
    panel.removeAttribute('hidden');

    if (!('IntersectionObserver' in window)) return;

    // Track which headings are on screen and light up the topmost one. A plain
    // scroll handler recomputing offsets was noticeably janky on long pages.
    var visible = {};
    var observer = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        visible[entry.target.id] = entry.isIntersecting;
      });

      var activeId = null;
      Array.prototype.some.call(headings, function (heading) {
        if (visible[heading.id]) { activeId = heading.id; return true; }
        return false;
      });

      links.forEach(function (link) {
        link.classList.toggle('is-active',
          activeId !== null && link.getAttribute('href') === '#' + activeId);
      });
    }, { rootMargin: '-80px 0px -70% 0px', threshold: 0 });

    Array.prototype.forEach.call(headings, function (h) { observer.observe(h); });
  }

  /* --------------------------------------------------------------- search */

  function escapeHtml(text) {
    return text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  }

  function tokenize(raw) {
    return raw.toLowerCase().split(/\s+/).filter(function (t) { return t.length > 0; });
  }

  function countOccurrences(haystack, needle) {
    var n = 0;
    var at = haystack.indexOf(needle);
    while (at >= 0) { n += 1; at = haystack.indexOf(needle, at + needle.length); }
    return n;
  }

  // The snippet must show the reader *why* a page matched, so it is cut from
  // the body around the first hit. Falling back to the description -- which
  // every docs page has -- would show text that need not contain the query at
  // all, which is why this takes the whole page rather than a pre-chosen string.
  function snippetFor(page, terms, phrase) {
    var content = page.content || '';
    var lower = content.toLowerCase();
    var at = -1;
    var len = 0;

    if (phrase.indexOf(' ') >= 0) { at = lower.indexOf(phrase); len = phrase.length; }
    for (var i = 0; at < 0 && i < terms.length; i += 1) {
      at = lower.indexOf(terms[i]);
      len = terms[i].length;
    }

    if (at < 0) {
      var fallback = page.description || content;
      return escapeHtml(fallback.slice(0, 140)) + (fallback.length > 140 ? '…' : '');
    }

    var start = Math.max(0, at - 60);
    var end = Math.min(content.length, at + len + 90);
    var rel = at - start;
    var window_ = content.slice(start, end);
    // Split on the known offset rather than string-replacing the match: the
    // match text can legitimately occur earlier in the window.
    var html = escapeHtml(window_.slice(0, rel))
      + '<mark>' + escapeHtml(window_.substr(rel, len)) + '</mark>'
      + escapeHtml(window_.slice(rel + len));
    return (start > 0 ? '…' : '') + html + (end < content.length ? '…' : '');
  }

  function initSearch() {
    var input = document.querySelector('[data-docs-search-input]');
    var results = document.querySelector('[data-docs-search-results]');
    if (!input || !results) return;

    var index = null;
    var loading = false;
    var pending = null;

    function load() {
      if (index || loading) return;
      loading = true;
      // baseurl-aware: the site is served from /hip-ep/ on the fork and from
      // the repo root or a custom domain later, so the URL must not be hardcoded.
      var base = root.getAttribute('data-baseurl') || '';
      fetch(base + '/search.json')
        .then(function (r) { return r.json(); })
        .then(function (data) {
          index = data;
          loading = false;
          if (pending !== null) { run(pending); pending = null; }
        })
        .catch(function () {
          loading = false;
          results.innerHTML = '<p class="docs-search__empty">Search index unavailable.</p>';
          results.classList.add('is-open');
        });
    }

    function run(rawQuery) {
      var query = rawQuery.trim().toLowerCase();
      if (query.length < 2) { close(); return; }
      if (!index) { pending = rawQuery; load(); return; }

      // Every term must appear somewhere, so "cpu fallback" matches a page that
      // says both words apart rather than requiring that exact string. Ranking
      // is by where and how often, so a page that merely mentions a word once
      // does not tie with the page that is about it.
      var terms = tokenize(query);
      var hits = [];
      index.forEach(function (page) {
        var title = (page.title || '').toLowerCase();
        var body = ((page.description || '') + ' ' + (page.content || '')).toLowerCase();
        var score = 0;

        for (var i = 0; i < terms.length; i += 1) {
          var inTitle = title.indexOf(terms[i]) >= 0;
          var n = countOccurrences(body, terms[i]);
          if (!inTitle && n === 0) return;
          if (inTitle) score += 20;
          // Capped: a long page repeating a common word must not outrank a
          // short page that is actually about it.
          score += Math.min(n, 8);
        }

        // Contiguous phrase is far stronger evidence than the same words apart.
        if (terms.length > 1) {
          if (title.indexOf(query) >= 0) score += 40;
          else if (body.indexOf(query) >= 0) score += 15;
        }

        hits.push({ page: page, score: score });
      });

      hits.sort(function (a, b) { return b.score - a.score; });
      hits = hits.slice(0, 8);

      if (!hits.length) {
        results.innerHTML = '<p class="docs-search__empty">No matches for “'
          + escapeHtml(rawQuery.trim()) + '”.</p>';
        results.classList.add('is-open');
        return;
      }

      results.innerHTML = hits.map(function (hit) {
        var page = hit.page;
        return '<a class="docs-search__result" href="' + page.url + '">'
          + '<span class="docs-search__result-title">' + escapeHtml(page.title || 'Untitled') + '</span>'
          + '<span class="docs-search__result-snippet">' + snippetFor(page, terms, query) + '</span>'
          + '</a>';
      }).join('');
      results.classList.add('is-open');
    }

    function close() {
      results.classList.remove('is-open');
      results.innerHTML = '';
    }

    function highlighted() {
      return results.querySelector('.is-highlighted');
    }

    function move(step) {
      var items = results.querySelectorAll('.docs-search__result');
      if (!items.length) return;
      var current = highlighted();
      var i = current ? Array.prototype.indexOf.call(items, current) : -1;
      var next = (i + step + items.length + 1) % (items.length + 1) - 1;
      if (current) current.classList.remove('is-highlighted');
      if (next >= 0) items[next].classList.add('is-highlighted');
    }

    input.addEventListener('focus', load);
    input.addEventListener('input', function () { run(input.value); });

    input.addEventListener('keydown', function (event) {
      if (event.key === 'Escape') { close(); input.blur(); }
      else if (event.key === 'ArrowDown') { event.preventDefault(); move(1); }
      else if (event.key === 'ArrowUp') { event.preventDefault(); move(-1); }
      else if (event.key === 'Enter') {
        var target = highlighted() || results.querySelector('.docs-search__result');
        if (target) { event.preventDefault(); window.location.href = target.href; }
      }
    });

    document.addEventListener('click', function (event) {
      if (!results.contains(event.target) && event.target !== input) close();
    });

    // "/" is the near-universal docs-search shortcut; skip it while the user is
    // already typing somewhere else.
    document.addEventListener('keydown', function (event) {
      var tag = (event.target.tagName || '').toLowerCase();
      if (event.key === '/' && tag !== 'input' && tag !== 'textarea' && !event.target.isContentEditable) {
        event.preventDefault();
        input.focus();
      }
    });
  }

  /* --------------------------------------------------------------- tables */

  function initTableScroll() {
    // Benchmark tables are wide by nature; wrapping them keeps a phone-width
    // viewport from getting a horizontal scrollbar on the whole page.
    var tables = document.querySelectorAll('.docs-content table, .prose table');
    Array.prototype.forEach.call(tables, function (table) {
      if (table.parentNode.classList.contains('table-scroll')) return;
      var wrap = document.createElement('div');
      wrap.className = 'table-scroll';
      table.parentNode.insertBefore(wrap, table);
      wrap.appendChild(table);
    });
  }

  /* ------------------------------------------------------------ hero deck */

  function initDeck() {
    // The markup ships every slide visible and the controls hidden, so the
    // no-JS rendering is a readable stack of features rather than a dead
    // widget. Only once we are sure we can drive it do we collapse it to one
    // slide and reveal the controls.
    var deck = document.querySelector('[data-deck]');
    if (!deck) return;

    var slides = deck.querySelectorAll('[data-deck-slide]');
    var controls = deck.querySelector('[data-deck-controls]');
    var dotHost = deck.querySelector('[data-deck-dots]');
    if (slides.length < 2 || !controls || !dotHost) return;

    var index = 0;
    var dots = [];
    var timer = null;

    function show(next) {
      index = (next + slides.length) % slides.length;
      Array.prototype.forEach.call(slides, function (slide, i) {
        slide.hidden = i !== index;
      });
      dots.forEach(function (dot, i) {
        dot.setAttribute('aria-current', i === index ? 'true' : 'false');
      });
    }

    Array.prototype.forEach.call(slides, function (slide, i) {
      var dot = document.createElement('button');
      dot.type = 'button';
      dot.className = 'deck__dot';
      dot.setAttribute('aria-label', 'Feature ' + (i + 1) + ' of ' + slides.length);
      dot.addEventListener('click', function () {
        stop();
        show(i);
      });
      dotHost.appendChild(dot);
      dots.push(dot);
    });

    deck.querySelector('[data-deck-prev]').addEventListener('click', function () {
      stop();
      show(index - 1);
    });
    deck.querySelector('[data-deck-next]').addEventListener('click', function () {
      stop();
      show(index + 1);
    });

    function stop() {
      if (timer === null) return;
      window.clearInterval(timer);
      timer = null;
    }

    // Auto-advance is a hint that there is more than one panel, so it stops for
    // good the moment someone steers the deck themselves — and never starts if
    // the reader has asked for reduced motion, or is reading a slide.
    var still = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)');
    if (!(still && still.matches)) {
      timer = window.setInterval(function () {
        show(index + 1);
      }, 7000);
      deck.addEventListener('mouseenter', stop);
      deck.addEventListener('focusin', stop);
    }

    deck.classList.add('is-ready');
    controls.hidden = false;
    show(0);
  }

  /* ----------------------------------------------------------------- boot */

  function boot() {
    initTheme();
    initMobileNav();
    initCodeCopy();
    initToc();
    initSearch();
    initTableScroll();
    initDeck();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', boot);
  } else {
    boot();
  }
})();
