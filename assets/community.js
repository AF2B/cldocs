/* CLDocs community contributions: list approved ones, let signed-in users submit.
 *
 * Everything user-supplied is written with textContent, never as HTML, and
 * every state-changing request carries the CSRF token handed out by /api/me.
 * Pure helpers are exported for Node tests.
 */
(function () {
  'use strict';

  var MAX_BODY_LENGTH = 4000;
  var MILLISECONDS_PER_SECOND = 1000;
  var KIND_EXAMPLE = 'example';
  var KIND_NOTE = 'note';
  var CSRF_HEADER = 'X-CSRF-Token';
  var JSON_TYPE = 'application/json';
  var STATUS_CREATED = 201;
  var TERMS_PATH = '/terms/';
  var LOGIN_PATH = '/login';

  var MESSAGES = {
    'unauthenticated': 'Sign in to contribute.',
    'forbidden': 'You are not allowed to do that.',
    'rate-limited': 'You are submitting too fast. Try again later.',
    'terms-not-accepted': 'You must accept the terms to contribute.',
    'body-empty': 'Write something first.',
    'body-too-long': 'That is too long (limit ' + MAX_BODY_LENGTH + ' characters).',
    'too-many-links': 'Too many links.',
    'body-control-characters': 'The text contains characters that are not allowed.',
    'unknown-symbol': 'That symbol is not documented here.'
  };
  var FALLBACK_MESSAGE = 'Something went wrong. Please try again.';
  var SUCCESS_MESSAGE = 'Thanks! A moderator will review it before it appears.';

  /** Return the user-facing sentence for an API error code. */
  function errorMessage(code) {
    return MESSAGES[code] || FALLBACK_MESSAGE;
  }

  /** Build the JSON body of a submission from the section dataset and form values. */
  function buildSubmission(dataset, kind, body, termsAccepted) {
    return {
      package: dataset.package,
      symbol: dataset.symbol,
      kind: kind === KIND_NOTE ? KIND_NOTE : KIND_EXAMPLE,
      body: body,
      terms: termsAccepted === true
    };
  }

  /** Format a Unix timestamp in seconds as an ISO date. */
  function formatDate(seconds) {
    return new Date(seconds * MILLISECONDS_PER_SECOND).toISOString().slice(0, 10);
  }

  if (typeof document === 'undefined') {
    module.exports = {
      errorMessage: errorMessage,
      buildSubmission: buildSubmission,
      formatDate: formatDate,
      MAX_BODY_LENGTH: MAX_BODY_LENGTH
    };
    return;
  }

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

  function getJson(url) {
    return fetch(url, { credentials: 'same-origin' }).then(function (response) {
      if (!response.ok) {
        throw new Error('status ' + response.status);
      }
      return response.json();
    });
  }

  function postJson(url, payload, csrf) {
    var headers = { 'Content-Type': JSON_TYPE };
    headers[CSRF_HEADER] = csrf;
    return fetch(url, {
      method: 'POST',
      credentials: 'same-origin',
      headers: headers,
      body: JSON.stringify(payload)
    }).then(function (response) {
      return response.json().then(function (data) {
        return { status: response.status, data: data };
      });
    });
  }

  function renderContribution(item, user, section, api) {
    var article = element('article', 'contribution');
    article.appendChild(element('p', 'label',
      item.kind + ' · ' + item.author + ' · ' + formatDate(item.created_at)));
    if (item.kind === KIND_EXAMPLE) {
      article.appendChild(element('pre', '', item.body));
    } else {
      article.appendChild(element('p', 'note', item.body));
    }
    if (user) {
      var flag = element('button', 'btn', 'Flag');
      flag.type = 'button';
      flag.addEventListener('click', function () {
        var reason = window.prompt('Why are you flagging this?');
        if (reason) {
          postJson(api + '/flags', { id: item.id, reason: reason }, user.csrf)
            .then(function () { flag.disabled = true; flag.textContent = 'Flagged'; });
        }
      });
      article.appendChild(flag);
    }
    return article;
  }

  function renderForm(user, section, api) {
    var form = element('form', 'contribute');
    var kind = element('select');
    kind.setAttribute('aria-label', 'Kind of contribution');
    [[KIND_EXAMPLE, 'Example'], [KIND_NOTE, 'Note']].forEach(function (pair) {
      var option = element('option', '', pair[1]);
      option.value = pair[0];
      kind.appendChild(option);
    });
    var text = element('textarea');
    text.maxLength = MAX_BODY_LENGTH;
    text.required = true;
    text.setAttribute('aria-label', 'Your example or note');
    text.placeholder = 'Code for an example, plain text for a note';
    var terms = element('label', 'terms');
    var box = element('input');
    box.type = 'checkbox';
    terms.appendChild(box);
    var termsText = element('span', '', 'I dedicate this to the public domain (CC0 1.0) and accept the ');
    var link = element('a', '', 'terms');
    link.href = TERMS_PATH;
    termsText.appendChild(link);
    terms.appendChild(termsText);
    var submit = element('button', 'btn', 'Submit for review');
    submit.type = 'submit';
    var status = element('p', 'form-status');
    status.setAttribute('role', 'status');
    form.appendChild(kind);
    form.appendChild(text);
    form.appendChild(terms);
    form.appendChild(submit);
    form.appendChild(status);
    form.addEventListener('submit', function (event) {
      event.preventDefault();
      status.className = 'form-status';
      postJson(api + '/contributions',
               buildSubmission(section.dataset, kind.value, text.value, box.checked),
               user.csrf)
        .then(function (result) {
          if (result.status === STATUS_CREATED) {
            text.value = '';
            status.textContent = SUCCESS_MESSAGE;
          } else {
            status.className = 'form-status form-error';
            status.textContent = errorMessage(result.data.error);
          }
        });
    });
    return form;
  }

  function renderSignIn() {
    var link = element('a', 'btn', 'Sign in with GitHub to contribute');
    link.href = LOGIN_PATH + '?next=' + encodeURIComponent(location.pathname);
    return link;
  }

  function init() {
    var section = document.getElementById('community');
    if (!section) {
      return;
    }
    var api = section.dataset.api;
    var query = '?package=' + encodeURIComponent(section.dataset.package) +
      '&symbol=' + encodeURIComponent(section.dataset.symbol);
    Promise.all([getJson(api + '/contributions' + query), getJson(api + '/me')])
      .then(function (results) {
        var list = document.getElementById('community-list');
        var holder = document.getElementById('community-form');
        var user = results[1].user;
        results[0].forEach(function (item) {
          list.appendChild(renderContribution(item, user, section, api));
        });
        if (results[0].length === 0) {
          list.appendChild(element('p', 'empty', 'No community contributions yet.'));
        }
        holder.appendChild(user ? renderForm(user, section, api) : renderSignIn());
        section.hidden = false;
      })
      .catch(function () { /* static hosting without the API: stay hidden */ });
  }

  init();
})();
