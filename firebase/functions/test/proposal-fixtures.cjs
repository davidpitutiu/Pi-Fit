const ex = {exerciseId: 'push_up', sets: 2, reps: 10, weight: 0};
function context(intent = 'create') {
  return JSON.stringify({profile: {sessionsPerWeek: 3}, planning: {intent,
    catalog: [{id: 'push_up', name: 'Push-up', muscle: 'Chest', equipment: 'Bodyweight'}],
    customRoutines: intent === 'create' ? [] : [{id: 'my-routine', revision: 'revision-1', name: 'My routine', exercises: [ex]}],
    targetRoutineId: intent === 'create' ? null : 'my-routine'}});
}
function proposal() { return {schemaVersion: 1, title: '3-day program', summary: 'Review loads before applying.',
  routines: [{targetRoutineId: null, expectedRevision: null, name: 'Full body A', subtitle: 'Leave two reps in reserve.', estimatedMinutes: 30, exercises: [{...ex}]}], schedule: null}; }

module.exports = {ex, context, proposal};
