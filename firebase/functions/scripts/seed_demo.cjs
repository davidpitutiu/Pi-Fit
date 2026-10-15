#!/usr/bin/env node
'use strict';

// Administrative, opt-in helper. Requiring this module never initializes an
// SDK, reads credentials, contacts Firebase, or changes a document.
const {readFile} = require('node:fs/promises');
const path = require('node:path');
const {randomUUID} = require('node:crypto');

const PROJECT_ID = 'pi-fit-663f2';
const MAX_DOCUMENT_BYTES = 700_000;
const DEFAULT_DATA_FILE = path.resolve(__dirname, '../../demo-workouts.v1.json');
class SeedError extends Error {}
const invalid = () => { throw new SeedError('Refusing an incomplete, unsupported, or invalid backup. No data was written.'); };
const object = (value) => {
  if (!value || typeof value !== 'object' || Array.isArray(value) ||
      ![Object.prototype, null].includes(Object.getPrototypeOf(value))) invalid();
  return value;
};
const list = (value) => { if (!Array.isArray(value)) invalid(); return value; };
const text = (value) => { if (typeof value !== 'string') invalid(); return value; };
const nonBlank = (value) => { if (!text(value).trim()) invalid(); return value; };
const number = (value, min, max) => {
  if (typeof value !== 'number' || !Number.isFinite(value) || value < min || value > max) invalid();
};
const integer = (value, min, max) => { number(value, min, max); if (!Number.isInteger(value)) invalid(); };
const boolean = (value) => { if (typeof value !== 'boolean') invalid(); };
const date = (value) => {
  if (!/^\d{4}-\d\d-\d\dT/.test(text(value)) || !Number.isFinite(Date.parse(value))) invalid();
  return Date.parse(value);
};
const unique = (values) => {
  const ids = values.map(nonBlank);
  if (new Set(ids).size !== ids.length) invalid();
};

function jsonValue(value, depth = 0) {
  if (depth > 40) invalid();
  if (value === null || typeof value === 'string' || typeof value === 'boolean') return;
  if (typeof value === 'number') { if (!Number.isFinite(value)) invalid(); return; }
  if (Array.isArray(value)) { for (const item of value) jsonValue(item, depth + 1); return; }
  for (const item of Object.values(object(value))) jsonValue(item, depth + 1);
}

function assertSize(value) {
  if (Buffer.byteLength(JSON.stringify(value), 'utf8') >= MAX_DOCUMENT_BYTES) {
    throw new SeedError('Refusing a document at or above the conservative 700,000-byte limit. No data was written.');
  }
}

function validateProfile(value) {
  const p = object(value);
  for (const [key, min, max] of [['heightCm', 100, 250], ['weightKg', 25, 350]]) {
    if (p[key] != null) number(p[key], min, max);
  }
  if (p.age != null) integer(p.age, 13, 100);
  if (p.experience != null && !['Beginner', 'Intermediate', 'Advanced', 'Începător', 'Intermediar', 'Avansat'].includes(p.experience)) invalid();
  if (p.sessionsPerWeek != null) integer(p.sessionsPerWeek, 1, 7);
  if (p.sessionMinutes != null) integer(p.sessionMinutes, 15, 180);
  if (p.equipment != null) {
    const equipment = list(p.equipment);
    unique(equipment);
    if (equipment.length > 30 || equipment.some((item) => item.length > 60)) invalid();
  }
  if (p.limitations != null && text(p.limitations).length > 1500) invalid();
  if (p.preferredDays != null) {
    const days = list(p.preferredDays);
    for (const day of days) integer(day, 1, 7);
    if (new Set(days).size !== days.length) invalid();
  }
  if (p.coachConsent != null) boolean(p.coachConsent);
}

function validateSession(value, finished) {
  const session = object(value);
  nonBlank(session.id);
  nonBlank(session.routineName);
  text(session.notes);
  const started = date(session.startedAt);
  if (finished ? date(session.finishedAt) < started : session.finishedAt != null) invalid();
  let completed = 0;
  for (const raw of list(session.exercises)) {
    const exercise = object(raw);
    nonBlank(exercise.exerciseId);
    for (const rawSet of list(exercise.sets)) {
      const set = object(rawSet);
      integer(set.reps, 1, 100_000);
      number(set.weight, 0, 100_000);
      boolean(set.completed);
      if (set.rpe != null) number(set.rpe, 1, 10);
      if (set.completed) completed++;
    }
  }
  if (finished && !completed) invalid();
}

function validateData(value) {
  const data = object(value);
  jsonValue(data);
  assertSize(data);
  if (data.version !== 1 || !Object.hasOwn(data, 'active')) invalid();
  text(data.name); text(data.goal); text(data.theme);
  if (data.profile != null) validateProfile(data.profile);
  for (const key of ['favoriteExerciseIds', 'appliedCoachProposalIds']) {
    if (data[key] != null) unique(list(data[key]));
  }
  if (data.appliedCoachProposalIds?.some((id) => id.length > 256)) invalid();
  const measurements = list(data.bodyMeasurements ?? []);
  unique(measurements.map((m) => object(m).id));
  const sources = new Set();
  for (const m of measurements) {
    if (m.id.length > 1200 || date(m.measuredAt) < Date.UTC(1900, 0, 1) || date(m.measuredAt) > Date.now()) invalid();
    if (m.weightKg == null && m.heightCm == null) invalid();
    if (m.weightKg != null) number(m.weightKg, 25, 350);
    if (m.heightCm != null) number(m.heightCm, 100, 250);
    if (m.source != null && !['manual', 'health'].includes(m.source)) invalid();
    if (m.source === 'health' && m.sourceRecordId == null) invalid();
    if (m.sourceRecordId != null) {
      if (nonBlank(m.sourceRecordId).length > 512) invalid();
      const key = `${m.source ?? 'manual'}/${m.sourceRecordId}`;
      if (sources.has(key)) invalid();
      sources.add(key);
    }
    if (m.sourceName != null && text(m.sourceName).length > 100) invalid();
  }
  const routines = list(data.routines);
  unique(routines.map((r) => object(r).id));
  for (const r of routines) {
    nonBlank(r.name); text(r.subtitle); text(r.category);
    integer(r.estimatedMinutes, 0, 1440);
    for (const raw of list(r.exercises)) {
      const exercise = object(raw);
      nonBlank(exercise.exerciseId);
      integer(exercise.sets, 1, 100);
      integer(exercise.reps, 1, 100_000);
      number(exercise.weight, 0, 100_000);
    }
  }
  const history = list(data.history);
  for (const session of history) validateSession(session, true);
  const sessionIds = history.map((s) => s.id);
  if (data.active != null) {
    validateSession(data.active, false);
    sessionIds.push(data.active.id);
  }
  unique(sessionIds);
  const schedule = list(data.schedule);
  unique(schedule.map((s) => object(s).id));
  for (const event of schedule) {
    nonBlank(event.routineId); date(event.date); boolean(event.reminder);
  }
  return data;
}

function fixtureData(value) {
  const fixture = object(value);
  if (Object.hasOwn(fixture, 'schemaVersion')) {
    if (fixture.schemaVersion !== 1) invalid();
    return validateData(fixture.data);
  }
  return validateData(fixture);
}

// Existing session IDs always win, even if a user edited a previous demo set.
// Every field outside history, including unknown future fields, is preserved.
function mergeBackup(existing, fixture, {createIfMissing = false, displayName} = {}) {
  const demo = fixtureData(fixture);
  let current;
  if (existing == null) {
    if (!createIfMissing) throw new SeedError('No current backup exists. Upload a backup first, or explicitly use --create-if-missing. No data was written.');
    // A fixture supplies workouts, never inferred personal details or consent.
    const data = {version: 1,
      name: typeof displayName === 'string' && displayName.trim() ? displayName.trim().slice(0, 60) : 'Athlete',
      goal: 'Strength and muscle', theme: 'dark',
      profile: {age: null, heightCm: null, weightKg: null, experience: 'Beginner',
        sessionsPerWeek: 3, sessionMinutes: 60, equipment: [], limitations: '',
        preferredDays: [1, 3, 5], coachConsent: false},
      routines: [], history: [], schedule: [], active: null,
      bodyMeasurements: [], favoriteExerciseIds: [], appliedCoachProposalIds: []};
    current = {schemaVersion: 1, data};
  } else {
    current = object(existing);
    if (current.schemaVersion !== 1) invalid();
    validateData(current.data);
    assertSize(current);
  }
  const present = new Set(current.data.history.map((session) => session.id));
  if (current.data.active != null) present.add(current.data.active.id);
  const added = demo.history.filter((session) => !present.has(session.id));
  const merged = {...current, data: {...current.data, history: [...current.data.history, ...added]}};
  validateData(merged.data);
  assertSize(merged);
  return {document: merged, addedCount: added.length, existingCount: current.data.history.length,
    fixtureCount: demo.history.length, created: existing == null, changed: existing == null || added.length > 0};
}

function parseArgs(args) {
  const options = {uid: null, apply: false, createIfMissing: false, datafile: DEFAULT_DATA_FILE};
  let mode;
  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    if (arg === '--uid' || arg === '--datafile') {
      const value = args[++i];
      if (!value || value.startsWith('--')) throw new SeedError('Flags --uid and --datafile require a value.');
      options[arg === '--uid' ? 'uid' : 'datafile'] = value;
    } else if (arg === '--dry-run' || arg === '--apply') {
      if (mode && mode !== arg) throw new SeedError('Choose either --dry-run or --apply.');
      mode = arg;
      options.apply = arg === '--apply';
    } else if (arg === '--create-if-missing') options.createIfMissing = true;
    else throw new SeedError('Unknown argument. Use --uid UID [--dry-run|--apply] [--create-if-missing] [--datafile PATH].');
  }
  if (typeof options.uid !== 'string' || !options.uid.trim() || options.uid.length > 128 || options.uid.includes('/')) {
    throw new SeedError('Provide one valid target Auth UID with --uid.');
  }
  return options;
}

async function seed({auth, database, serverTimestamp, options, fixture}) {
  fixtureData(fixture);
  // A typo or removed account must never create an orphaned backup document.
  const user = await auth.getUser(options.uid);
  if (user.uid !== options.uid) throw new SeedError('The returned account did not match the requested UID. No data was written.');
  const currentRef = database.doc(`users/${options.uid}/backups/current`);
  const merge = (snapshot) => mergeBackup(snapshot.exists ? snapshot.data() : null, fixture, {
    createIfMissing: options.createIfMissing, displayName: user.displayName,
  });
  if (!options.apply) {
    const result = merge(await currentRef.get());
    return {...result, applied: false, archivePath: null};
  }
  const archiveRef = currentRef.parent.doc(`before_demo_${randomUUID()}`);
  return database.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(currentRef);
    const result = merge(snapshot);
    if (!result.changed) return {...result, applied: false, archivePath: null};
    if (snapshot.exists) transaction.create(archiveRef, snapshot.data());
    transaction.set(currentRef, {...result.document, updatedAt: serverTimestamp()});
    return {...result, applied: true, archivePath: snapshot.exists ? archiveRef.path : null};
  });
}

async function main(args = process.argv.slice(2)) {
  const options = parseArgs(args);
  let fixture;
  try { fixture = JSON.parse(await readFile(options.datafile, 'utf8')); }
  catch (_) { throw new SeedError('The fixture could not be read as JSON. Check --datafile.'); }
  fixtureData(fixture);
  const {initializeApp, applicationDefault, deleteApp} = require('firebase-admin/app');
  const {getAuth} = require('firebase-admin/auth');
  const {getFirestore, FieldValue} = require('firebase-admin/firestore');
  const app = initializeApp({projectId: PROJECT_ID, credential: applicationDefault()});
  let database;
  try {
    database = getFirestore(app);
    const result = await seed({auth: getAuth(app), database,
      serverTimestamp: () => FieldValue.serverTimestamp(), options, fixture});
    console.log(`${options.apply ? 'Apply' : 'Dry run'}: project ${PROJECT_ID}; existing sessions ${result.existingCount}; fixture sessions ${result.fixtureCount}; additions ${result.addedCount}; ${result.applied ? 'saved' : 'no writes'}.`);
    if (result.archivePath) console.log(`Previous backup archived at ${result.archivePath}`);
    if (result.applied) console.log('In Pi Fit, sign in to this account and use Profile → Restore from cloud to load the cloud history.');
  } finally {
    // Admin app deletion alone does not terminate its Firestore gRPC client.
    try {
      if (database) await database.terminate();
    } finally {
      await deleteApp(app);
    }
  }
}

if (require.main === module) {
  main().catch((error) => {
    if (error instanceof SeedError) console.error(error.message);
    else {
      const code = typeof error?.code === 'string' && /^[a-z0-9_/-]{1,80}$/i.test(error.code) ? error.code : 'credentials-or-service-error';
      console.error(`Demo seed failed (${code}). Check account permissions and Application Default Credentials. For an owner account, use gcloud auth application-default login. No private error details were printed.`);
    }
    process.exitCode = 1;
  });
}

module.exports = {PROJECT_ID, MAX_DOCUMENT_BYTES, SeedError, validateData, fixtureData, mergeBackup, parseArgs, seed};
