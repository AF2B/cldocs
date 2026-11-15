// Tests of the pure helpers and of the safety rules of assets/community.js.

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { test } from 'node:test';

const require = createRequire(import.meta.url);
const source = readFileSync(new URL('../assets/community.js', import.meta.url), 'utf8');
const { errorMessage, buildSubmission, formatDate, MAX_BODY_LENGTH } =
  require('../assets/community.js');

const FORBIDDEN_SINKS = [
  'innerHTML',
  'outerHTML',
  'insertAdjacentHTML',
  'document.write',
  'eval(',
  'new Function',
  'setTimeout("',
];

for (const sink of FORBIDDEN_SINKS) {
  test(`never uses the unsafe sink ${sink}`, () => {
    assert.ok(!source.includes(sink), `${sink} found in community.js`);
  });
}

test('every state-changing request sends the CSRF header', () => {
  assert.ok(source.includes("'X-CSRF-Token'"));
  assert.ok(source.includes("credentials: 'same-origin'"));
});

test('error codes map to sentences and unknown codes fall back', () => {
  assert.match(errorMessage('rate-limited'), /too fast/);
  assert.match(errorMessage('terms-not-accepted'), /terms/);
  assert.match(errorMessage('something-new'), /went wrong/);
  assert.match(errorMessage(undefined), /went wrong/);
});

test('submissions carry the symbol, a known kind and an explicit terms flag', () => {
  const dataset = { package: 'COMMON-LISP', symbol: 'CAR' };
  assert.deepEqual(buildSubmission(dataset, 'note', 'hello', true), {
    package: 'COMMON-LISP',
    symbol: 'CAR',
    kind: 'note',
    body: 'hello',
    terms: true,
  });
  assert.equal(buildSubmission(dataset, 'weird', 'x', true).kind, 'example');
  assert.equal(buildSubmission(dataset, 'note', 'x', 'yes').terms, false);
  assert.equal(buildSubmission(dataset, 'note', 'x', undefined).terms, false);
});

test('the body limit matches the server limit', () => {
  assert.equal(MAX_BODY_LENGTH, 4000);
});

test('dates are formatted from Unix seconds', () => {
  assert.equal(formatDate(0), '1970-01-01');
  assert.equal(formatDate(1763000000), '2025-11-13');
});
