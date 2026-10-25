const assert = require('node:assert/strict');
const test = require('node:test');
const { csvCell } = require('../public/site/admin-csv');

test('CSV cells neutralize spreadsheet formulas after whitespace and control characters', () => {
  for (const value of ['=1+1', '+1', '-1', '@SUM(1,1)', ' =1+1', '\t=1+1', '\r@SUM(1,1)', '\n-1']) {
    assert.match(csvCell(value), /^"'/, value);
  }
  assert.equal(csvCell('一般文字'), '"一般文字"');
  assert.equal(csvCell('有"引號'), '"有""引號"');
});
