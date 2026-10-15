const test = require('node:test');
const assert = require('node:assert/strict');
const {MAX_DOCUMENT_BYTES, mergeBackup, parseArgs, seed} = require('../scripts/seed_demo.cjs');

const clone = (value) => structuredClone(value);
function session(id = 'demo-test-1') {
  return {id, routineName: 'TEST DATA · Full body',
    startedAt: '2026-09-01T14:00:00Z', finishedAt: '2026-09-01T15:00:00Z', notes: 'Synthetic',
    exercises: [{exerciseId: 'bench-press', sets: [{reps: 10, weight: 20, completed: true, rpe: 7}]}]};
}
function fixture() {
  return {version: 1, name: 'Athlete', goal: 'Strength and muscle', theme: 'dark',
    profile: {sessionsPerWeek: 3, sessionMinutes: 60, coachConsent: false},
    history: [session()], routines: [], schedule: [], active: null,
    favoriteExerciseIds: [], bodyMeasurements: [], appliedCoachProposalIds: []};
}
function backup() {
  return {schemaVersion: 1, updatedAt: 'ORIGINAL_TIMESTAMP', data: {...fixture(),
    name: 'Private name', profile: {sessionsPerWeek: 5, sessionMinutes: 40, limitations: 'Private notes', coachConsent: true},
    history: [session('personal-workout')], futurePreference: {keep: true}}};
}
function fakeServices(current, {failCommit = false} = {}) {
  const state = {current: clone(current), archives: [], writes: 0, reads: 0, userLookups: 0};
  const snapshot = () => ({exists: state.current != null, data: () => clone(state.current)});
  const reference = {path: 'users/test-user/backups/current',
    get: async () => { state.reads++; return snapshot(); },
    parent: {doc: (id) => ({path: `users/test-user/backups/${id}`})}};
  return {state, auth: {getUser: async (uid) => { state.userLookups++; return {uid, displayName: 'Auth name'}; }},
    serverTimestamp: () => 'NEW_TIMESTAMP', database: {
      doc: (documentPath) => { assert.equal(documentPath, reference.path); return reference; },
      runTransaction: async (callback) => {
        const writes = [];
        const result = await callback({
          get: async () => { state.reads++; return snapshot(); },
          create: (ref, value) => writes.push({archive: ref.path, value: clone(value)}),
          set: (ref, value) => writes.push({current: ref.path, value: clone(value)}),
        });
        if (failCommit) throw new Error('Simulated transaction abort');
        for (const write of writes) {
          state.writes++;
          if (write.archive) state.archives.push(write);
          else state.current = write.value;
        }
        return result;
      },
    }};
}
const options = (overrides = {}) => ({uid: 'test-user', apply: false, createIfMissing: false, ...overrides});

test('history merge preserves personal fields, active workout, schedule and edited duplicate sessions', () => {
  const existing = backup();
  existing.data.history.push({...session(), notes: 'Edited by user', exercises: [{exerciseId: 'bench-press', sets: [{reps: 8, weight: 35, completed: true}]}]});
  existing.data.active = {...session('active-workout'), finishedAt: null};
  existing.data.schedule = [{id: 'calendar-1', routineId: 'personal-routine', date: '2026-12-01T18:00:00Z', reminder: true}];
  const source = clone(existing);
  const demo = fixture();
  demo.history.push(session('demo-test-2'));
  const result = mergeBackup(existing, demo);
  assert.equal(result.addedCount, 1);
  assert.deepEqual(result.document.data.history.slice(0, 2), existing.data.history);
  const {history, ...preserved} = result.document.data;
  const {history: originalHistory, ...originalFields} = existing.data;
  assert.deepEqual(preserved, originalFields);
  assert.deepEqual(existing, source);
  assert.equal(result.document.updatedAt, 'ORIGINAL_TIMESTAMP');
});

test('repeating a seed is a no-op and an active ID is never duplicated in history', () => {
  const first = mergeBackup(backup(), fixture());
  const repeated = mergeBackup(first.document, fixture());
  assert.equal(repeated.changed, false);
  assert.equal(repeated.addedCount, 0);
  assert.deepEqual(repeated.document, first.document);
  const active = backup();
  active.data.active = {...session(), finishedAt: null};
  assert.equal(mergeBackup(active, fixture()).addedCount, 0);
});

test('a missing backup requires explicit bootstrap and uses Auth name with safe defaults', () => {
  assert.throws(() => mergeBackup(null, fixture()), /--create-if-missing/);
  const custom = fixture();
  custom.profile = {age: 30, coachConsent: true};
  const result = mergeBackup(null, custom, {createIfMissing: true, displayName: ' Auth athlete '});
  assert.equal(result.document.data.name, 'Auth athlete');
  assert.equal(result.document.data.profile.coachConsent, false);
  assert.equal(result.document.data.profile.age, null);
  assert.equal(result.created, true);
  assert.equal(result.addedCount, 1);
  assert.equal(mergeBackup(null, fixture(), {createIfMissing: true}).document.data.name, 'Athlete');
});

test('unsupported schemas and damaged training records are refused instead of overwritten', () => {
  const malformed = [
    {...backup(), schemaVersion: 0}, {...backup(), data: {version: 1}},
    {...backup(), data: {...fixture(), version: 2}},
  ];
  for (const mutation of [
    (data) => { data.history[0].exercises[0].sets[0].rpe = 11; },
    (data) => { data.history[0].exercises[0].sets[0].completed = false; },
    (data) => { data.history.push(clone(data.history[0])); },
    (data) => { data.history[0].finishedAt = '2020-01-01T00:00:00Z'; },
    (data) => { data.profile.sessionsPerWeek = 0; },
    (data) => { data.schedule = [{}]; },
    (data) => { data.bodyMeasurements = [{id: 'bad', measuredAt: '2020-01-01T00:00:00Z', weightKg: 1}]; },
  ]) {
    const document = backup(); mutation(document.data); malformed.push(document);
  }
  for (const current of malformed) assert.throws(() => mergeBackup(current, fixture()), /Refusing/);
  assert.throws(() => mergeBackup(backup(), {schemaVersion: 2, data: fixture()}), /Refusing/);
});

test('size limits use UTF-8 bytes and also reject growth beyond the safe document size', () => {
  const existing = backup();
  existing.data.futurePreference = '🙂'.repeat(Math.ceil(MAX_DOCUMENT_BYTES / 4));
  assert.throws(() => mergeBackup(existing, fixture()), /700,000-byte/);
  const almostFull = backup();
  almostFull.data.futurePreference = 'a'.repeat(MAX_DOCUMENT_BYTES - Buffer.byteLength(JSON.stringify(almostFull)) - 150);
  const demo = fixture();
  demo.history[0].notes = 'a'.repeat(1000);
  assert.throws(() => mergeBackup(almostFull, demo), /700,000-byte/);
});

test('CLI defaults to dry-run and refuses conflicting modes or path-like UIDs', () => {
  assert.equal(parseArgs(['--uid', 'test-user']).apply, false);
  assert.equal(parseArgs(['--uid', 'test-user', '--apply']).apply, true);
  assert.equal(parseArgs(['--uid', 'test-user', '--create-if-missing']).createIfMissing, true);
  for (const args of [[], ['--uid', 'users/another'], ['--uid', 'test-user', '--apply', '--dry-run'],
    ['--uid'], ['--uid', 'test-user', '--project', 'other-project']]) {
    assert.throws(() => parseArgs(args));
  }
});

test('dry-run verifies Auth account and reads backup without issuing writes', async () => {
  const services = fakeServices(backup());
  const result = await seed({...services, options: options(), fixture: fixture()});
  assert.equal(result.addedCount, 1);
  assert.equal(result.applied, false);
  assert.equal(services.state.userLookups, 1);
  assert.equal(services.state.reads, 1);
  assert.equal(services.state.writes, 0);
  assert.deepEqual(services.state.current, backup());
});

test('apply archives the exact old document and merges current data atomically, then becomes no-op', async () => {
  const original = backup();
  const services = fakeServices(original);
  const result = await seed({...services, options: options({apply: true}), fixture: fixture()});
  assert.equal(result.applied, true);
  assert.match(result.archivePath, /^users\/test-user\/backups\/before_demo_/);
  assert.equal(services.state.writes, 2);
  assert.deepEqual(services.state.archives[0].value, original);
  assert.equal(services.state.current.data.history.length, 2);
  assert.equal(services.state.current.updatedAt, 'NEW_TIMESTAMP');
  assert.equal(services.state.current.data.name, original.data.name);
  const repeated = await seed({...services, options: options({apply: true}), fixture: fixture()});
  assert.equal(repeated.applied, false);
  assert.equal(services.state.writes, 2);
  assert.equal(services.state.archives.length, 1);
});

test('an aborted transaction leaves both current backup and archive collection unchanged', async () => {
  const services = fakeServices(backup(), {failCommit: true});
  await assert.rejects(seed({...services, options: options({apply: true}), fixture: fixture()}), /transaction abort/);
  assert.equal(services.state.writes, 0);
  assert.deepEqual(services.state.current, backup());
  assert.deepEqual(services.state.archives, []);
});

test('an unknown or mismatched Auth UID prevents even reading a backup', async () => {
  for (const getUser of [async () => { throw new Error('User not found'); }, async () => ({uid: 'another-user'})]) {
    const services = fakeServices(backup());
    await assert.rejects(seed({...services, auth: {getUser}, options: options({apply: true}), fixture: fixture()}));
    assert.equal(services.state.reads, 0);
    assert.equal(services.state.writes, 0);
  }
});

test('explicit bootstrap creates only the current backup without archiving a missing document', async () => {
  const services = fakeServices(null);
  const result = await seed({...services, options: options({apply: true, createIfMissing: true}), fixture: fixture()});
  assert.equal(result.created, true);
  assert.equal(result.archivePath, null);
  assert.equal(services.state.writes, 1);
  assert.equal(services.state.current.data.name, 'Auth name');
  assert.equal(services.state.current.schemaVersion, 1);
});
