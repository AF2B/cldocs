/* CLDocs client-side search. No dependencies.
 *
 * Index rows are [name, package, kinds[], path, summary], see
 * src/search-index.lisp. The ranking lives in `rank`, a pure function that is
 * also exported for Node so the test suite can exercise it without a browser.
 */
(function (root) {
  'use strict';

  var SCORE_EXACT = 1000;
  var SCORE_EXACT_WITHOUT_EARMUFFS = 900;
  var SCORE_PREFIX = 800;
  var SCORE_CONTAINS = 500;
  var SCORE_SUMMARY = 100;
  var CONTAINS_LENGTH_WEIGHT = 0.5;
  var NO_MATCH = -1;
  var DEFAULT_LIMIT = 20;

  var ROW_NAME = 0;
  var ROW_PACKAGE = 1;
  var ROW_KINDS = 2;
  var ROW_PATH = 3;
  var ROW_SUMMARY = 4;

  var EARMUFFS = /^[*+]|[*+]$/g;
  var WHITESPACE = /\s+/;
  var KEY_SLASH = '/';
  var KEY_ESCAPE = 'Escape';
  var KEY_DOWN = 'ArrowDown';
  var KEY_UP = 'ArrowUp';
  var KEY_ENTER = 'Enter';

  /** Lowercase and trim a user query. */
  function normalize(text) {
    return text.toLowerCase().trim();
  }

  /** Score one query token against a symbol name; NO_MATCH when absent. */
  function scoreName(name, token) {
    if (name === token) {
      return SCORE_EXACT;
    }
    if (name.replace(EARMUFFS, '') === token) {
      return SCORE_EXACT_WITHOUT_EARMUFFS;
    }
    if (name.indexOf(token) === 0) {
      return SCORE_PREFIX - (name.length - token.length);
    }
    var position = name.indexOf(token);
    if (position >= 0) {
      return SCORE_CONTAINS - position -
        (name.length - token.length) * CONTAINS_LENGTH_WEIGHT;
    }
    return NO_MATCH;
  }

  /** Score a whole row: every token must match the name or the summary. */
  function scoreRow(row, tokens) {
    var name = row[ROW_NAME];
    var summary = row[ROW_SUMMARY].toLowerCase();
    var total = 0;
    for (var i = 0; i < tokens.length; i++) {
      var score = scoreName(name, tokens[i]);
      if (score === NO_MATCH && summary.indexOf(tokens[i]) >= 0) {
        score = SCORE_SUMMARY;
      }
      if (score === NO_MATCH) {
        return NO_MATCH;
      }
      total += score;
    }
    return total;
  }

  /**
   * Rank index rows for a query.
   *
   * @param {Array} index  the parsed search index
   * @param {string} query what the user typed
   * @param {number} [limit] maximum number of rows returned
   * @returns {Array} matching rows, best first
   */
  function rank(index, query, limit) {
    var text = normalize(query || '');
    if (text === '') {
      return [];
    }
    var tokens = text.split(WHITESPACE);
    var scored = [];
    for (var i = 0; i < index.length; i++) {
      var score = scoreRow(index[i], tokens);
      if (score !== NO_MATCH) {
        scored.push({ row: index[i], score: score });
      }
    }
    scored.sort(function (a, b) {
      return (b.score - a.score) ||
        (a.row[ROW_NAME].length - b.row[ROW_NAME].length) ||
        (a.row[ROW_NAME] < b.row[ROW_NAME] ? -1 : 1);
    });
    return scored.slice(0, limit || DEFAULT_LIMIT).map(function (entry) {
      return entry.row;
    });
  }

  /* ---- Browser wiring ---- */

  function element(tag, className, text) {
    var node = document.createElement(tag);
    if (className) {
      node.className = className;
    }
    if (text !== undefined) {
      node.textContent = text;
    }
    return node;
  }

  function resultItem(row, siteRoot) {
    var item = element('li');
    var link = element('a');
    link.href = siteRoot + row[ROW_PATH];
    link.appendChild(element('span', 'result-name', row[ROW_NAME]));
    var meta = row[ROW_PACKAGE] + ' · ' + row[ROW_KINDS].join(', ');
    if (row[ROW_SUMMARY]) {
      meta += ' · ' + row[ROW_SUMMARY];
    }
    link.appendChild(element('span', 'result-meta', meta));
    item.appendChild(link);
    return item;
  }

  function attach(input, list) {
    var siteRoot = input.getAttribute('data-root') || '';
    var indexUrl = input.getAttribute('data-index');
    var index = null;
    var loading = null;
    var selected = -1;

    function links() {
      return list.querySelectorAll('a');
    }

    function select(position) {
      var anchors = links();
      for (var i = 0; i < anchors.length; i++) {
        anchors[i].setAttribute('aria-selected', String(i === position));
      }
      selected = position;
    }

    function close() {
      list.hidden = true;
      list.textContent = '';
      selected = -1;
    }

    function render() {
      list.textContent = '';
      if (!index || normalize(input.value) === '') {
        close();
        return;
      }
      var rows = rank(index, input.value);
      if (rows.length === 0) {
        list.appendChild(element('li', 'search-empty', 'No matching symbols.'));
      }
      rows.forEach(function (row) {
        list.appendChild(resultItem(row, siteRoot));
      });
      list.hidden = false;
      select(rows.length > 0 ? 0 : -1);
    }

    function load() {
      if (!loading) {
        loading = fetch(indexUrl)
          .then(function (response) { return response.json(); })
          .then(function (rows) { index = rows; render(); });
      }
      return loading;
    }

    input.addEventListener('focus', load);
    input.addEventListener('input', function () { load().then(render); });
    input.addEventListener('keydown', function (event) {
      var count = links().length;
      if (event.key === KEY_DOWN && count > 0) {
        event.preventDefault();
        select((selected + 1) % count);
      } else if (event.key === KEY_UP && count > 0) {
        event.preventDefault();
        select((selected - 1 + count) % count);
      } else if (event.key === KEY_ENTER && selected >= 0) {
        event.preventDefault();
        links()[selected].click();
      } else if (event.key === KEY_ESCAPE) {
        close();
        input.blur();
      }
    });
    document.addEventListener('click', function (event) {
      if (!list.contains(event.target) && event.target !== input) {
        close();
      }
    });
    document.addEventListener('keydown', function (event) {
      var typing = /^(input|textarea|select)$/i.test(event.target.tagName);
      if (event.key === KEY_SLASH && !typing) {
        event.preventDefault();
        input.focus();
      }
    });
  }

  if (typeof document !== 'undefined') {
    var input = document.getElementById('search-input');
    var list = document.getElementById('search-results');
    if (input && list) {
      attach(input, list);
    }
  }

  if (typeof module !== 'undefined' && module.exports) {
    module.exports = { rank: rank, normalize: normalize };
  }
})(this);
