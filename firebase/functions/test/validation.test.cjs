const test = require('node:test');
const assert = require('node:assert/strict');
const {validateInput, extractReply, checkLimit} = require('../lib/validation.js');

test('validates the request boundary before invoking the provider', () => {
  assert.deepEqual(validateInput({message: '  Plan? ', context: ''}), {
    message: 'Plan?', context: '',
  });
  for (const body of [null, [], {message: 'x'}, {message: '', context: ''},
    {message: 'x'.repeat(3001), context: ''},
    {message: 'x', context: 'x'.repeat(12001)},
    {message: 'x', context: '', model: 'unauthorized'}]) {
    assert.equal(validateInput(body), null);
  }
});

test('rejects the eleventh request in a minute and resets windows', () => {
  const now = 100_000_000;
  const limited = {minuteStart: now - 1000, dayStart: now - 1000,
    minuteCount: 10, dayCount: 10};
  assert.equal(checkLimit(limited, now).allowed, false);
  const reset = checkLimit(limited, now + 60_000);
  assert.equal(reset.allowed, true);
  assert.equal(reset.next.minuteCount, 1);
  assert.equal(reset.next.dayCount, 11);
  assert.equal(checkLimit({...limited, minuteCount: 0, dayCount: 100}, now).allowed, false);
  assert.equal(checkLimit(limited, now + 86_400_000).next.dayCount, 1);
});

test('extracts output text without accepting tool output as a reply', () => {
  assert.equal(extractReply({output: [{content: [{type: 'output_text', text: 'Salut!'}]}]}), 'Salut!');
  assert.equal(extractReply({output: [{type: 'function_call', arguments: 'secret'}]}), null);
  assert.equal(extractReply(null), null);
});
