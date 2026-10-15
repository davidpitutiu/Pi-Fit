const test = require('node:test');
const assert = require('node:assert/strict');
const {planningContext, validateProposal, parseCoachOutput, coachOutputSchema} = require('../lib/proposal.js');
const {ex, context, proposal} = require('./proposal-fixtures.cjs');
function input(ctx = context()) {return {message: 'Create a 3-day workout program', context: ctx, history: []};}

test('valid structured programs are previews with known exercise IDs', () => {
  const raw = proposal();
  assert.equal(validateProposal(raw, planningContext(context())), true);
  assert.deepEqual(parseCoachOutput(JSON.stringify({reply: 'Review this plan.', proposal: raw}), input()), {reply: 'Review this plan.', proposal: raw});
  assert.equal(coachOutputSchema.additionalProperties, false);
  assert.deepEqual(coachOutputSchema.required, ['reply', 'proposal']);
});

test('unknown IDs, duplicate exercises, unsafe loads and action-shaped extras are rejected', () => {
  for (const mutate of [
    p => p.routines[0].exercises[0].exerciseId = 'invented-exercise',
    p => p.routines[0].exercises.push({...ex}),
    p => p.routines[0].exercises[0].weight = 1001,
    p => p.routines[0].exercises[0].sets = 99,
    p => p.routines[0].exercises[0].reps = 0,
    p => p.executeImmediately = true,
  ]) {
    const raw = proposal(); mutate(raw);
    assert.equal(validateProposal(raw, planningContext(context())), false);
  }
});

test('editing requires the exact selected custom routine and revision', () => {
  const raw = proposal();
  raw.routines[0].targetRoutineId = 'my-routine';
  raw.routines[0].expectedRevision = 'revision-1';
  assert.equal(validateProposal(raw, planningContext(context('edit'))), true);
  raw.routines[0].expectedRevision = 'stale-revision';
  assert.equal(validateProposal(raw, planningContext(context('edit'))), false);
  raw.routines[0].expectedRevision = 'revision-1';
  raw.routines[0].targetRoutineId = 'built-in-template';
  assert.equal(validateProposal(raw, planningContext(context('edit'))), false);
  assert.equal(validateProposal(proposal(), planningContext(context('edit'))), false);
});

test('schedule previews validate dates, weekday uniqueness and routine index', () => {
  const raw = proposal();
  raw.schedule = {routineIndex: 0, weeks: 4, weekdays: [1,3,5], startDate: '2026-11-02', hour: 18, minute: 30, reminder: false};
  assert.equal(validateProposal(raw, planningContext(context())), true);
  for (const patch of [{startDate: '2026-02-30'}, {weekdays: [1,1]}, {routineIndex: 1}, {weeks: 13}, {hour: 24}]) {
    assert.equal(validateProposal({...raw, schedule: {...raw.schedule, ...patch}}, planningContext(context())), false);
  }
});

test('general Q&A and pain or nutrition requests cannot return a program action', () => {
  assert.deepEqual(parseCoachOutput(JSON.stringify({reply: 'Rest between sets.', proposal: null}), input('')), {reply: 'Rest between sets.', proposal: null});
  assert.equal(parseCoachOutput(JSON.stringify({reply: 'A plan', proposal: proposal()}), input('')), null);
  assert.equal(parseCoachOutput(JSON.stringify({reply: 'A plan', proposal: proposal()}), {...input(), message: 'Create a workout despite chest pain'}), null);
  assert.equal(parseCoachOutput('not JSON', input()), null);
});
