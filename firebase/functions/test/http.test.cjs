const test = require('node:test');
const assert = require('node:assert/strict');
const {EventEmitter} = require('node:events');
const {coach} = require('../lib/index.js');

async function request(overrides = {}) {
  const req = {
    method: 'POST', headers: {}, rawBody: Buffer.from('{}'),
    body: {message: 'Un plan de început?', context: ''},
    header(name) {return this.headers[name.toLowerCase()];},
    is(type) {return type === 'application/json';},
    ...overrides,
  };
  const res = new EventEmitter();
  res.headers = {};
  res.set = (name, value) => {res.headers[name] = value; return res;};
  res.status = (code) => {res.statusCode = code; return res;};
  res.json = res.send = (body) => {res.body = body; res.emit('finish'); return res;};
  await coach(req, res);
  return res;
}

test('missing authentication is rejected before contacting a provider', async () => {
  const response = await request();
  assert.equal(response.statusCode, 401);
  assert.equal(response.body.error, 'Authentication required');
  assert.equal(response.headers['Cache-Control'], 'no-store');
});

test('a web origin is denied unless explicitly allowlisted', async () => {
  const response = await request({headers: {origin: 'https://untrusted.example'}});
  assert.equal(response.statusCode, 403);
  assert.equal(response.headers['Access-Control-Allow-Origin'], undefined);
});

test('invalid and oversized input is rejected without calling Firebase Auth', async () => {
  assert.equal((await request({body: {message: '', context: ''}})).statusCode, 400);
  assert.equal((await request({rawBody: Buffer.alloc(65537)})).statusCode, 400);
});

test('only POST is accepted and preflight is handled', async () => {
  assert.equal((await request({method: 'GET'})).statusCode, 405);
  assert.equal((await request({method: 'OPTIONS'})).statusCode, 204);
});
