// Tests of the client-side ranking against the real generated index.
// Run by the Lisp suite: CLDOCS_INDEX=<site>/assets/search-index.json node --test tests/

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { test } from 'node:test';

const require = createRequire(import.meta.url);
const { rank } = require('../assets/search.js');

const indexPath = process.env.CLDOCS_INDEX;
assert.ok(indexPath, 'CLDOCS_INDEX must point to search-index.json');
const index = JSON.parse(readFileSync(indexPath, 'utf8'));

const NAME = 0;
const PATH = 3;
const names = (query, limit) => rank(index, query, limit).map((row) => row[NAME]);

const FIRST_RESULT_CASES = [
  ['car', 'car'],
  ['cdr', 'cdr'],
  ['mapcar', 'mapcar'],
  ['mapc', 'mapc'],
  ['defun', 'defun'],
  ['format', 'format'],
  ['loop', 'loop'],
  ['setf', 'setf'],
  ['nth', 'nth'],
  ['1+', '1+'],
  ['string=', 'string='],
  ['gethash', 'gethash'],
  ['print-base', '*print-base*'],
  ['*print-base*', '*print-base*'],
  ['with-open-file', 'with-open-file'],
  ['MAPCAR', 'mapcar'],
  ['  car  ', 'car'],
];

for (const [query, expected] of FIRST_RESULT_CASES) {
  test(`"${query}" ranks ${expected} first`, () => {
    assert.equal(names(query)[0], expected);
  });
}

test('prefix queries return related symbols', () => {
  const found = names('hash', 50);
  for (const expected of ['make-hash-table', 'hash-table-count', 'sxhash']) {
    assert.ok(found.includes(expected), `${expected} missing from ${found}`);
  }
});

test('prefix matches outrank substring matches', () => {
  const found = names('string', 50);
  const firstContains = found.findIndex((name) => !name.startsWith('string'));
  const lastPrefix = found.map((name) => name.startsWith('string')).lastIndexOf(true);
  assert.ok(firstContains === -1 || lastPrefix < firstContains);
});

test('multi-word queries must match every word', () => {
  const SUMMARY = 4;
  const rows = rank(index, 'hash table', 50);
  assert.ok(rows.length > 0);
  for (const row of rows) {
    const text = `${row[NAME]} ${row[SUMMARY]}`.toLowerCase();
    assert.ok(text.includes('hash') && text.includes('table'), row[NAME]);
  }
  assert.ok(rows.map((row) => row[NAME]).includes('make-hash-table'));
});

test('empty and whitespace queries return nothing', () => {
  assert.deepEqual(rank(index, ''), []);
  assert.deepEqual(rank(index, '   '), []);
  assert.deepEqual(rank(index, undefined), []);
});

test('nonsense queries return nothing', () => {
  assert.deepEqual(rank(index, 'zzzzqqqq'), []);
});

test('limit is respected and defaults to twenty', () => {
  assert.equal(rank(index, 'a', 5).length, 5);
  assert.ok(rank(index, 'a').length <= 20);
});

test('results link to existing symbol paths', () => {
  const [row] = rank(index, 'car');
  assert.equal(row[PATH], 'sym/common-lisp/car/');
});

test('special characters in queries never throw', () => {
  for (const query of ['(', ')', '\\', '[', '.*', '+', '*', '?', '"']) {
    assert.doesNotThrow(() => rank(index, query));
  }
});
