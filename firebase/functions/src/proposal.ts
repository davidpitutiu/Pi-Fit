import type {CoachInput} from "./validation";
type Obj = Record<string, unknown>;
export interface CoachOutput {reply: string; proposal: Obj | null}
interface Planning {intent: string; ids: Set<string>; target: string | null; revisions: Map<string, string>}
const obj = (v: unknown): v is Obj => !!v && typeof v === "object" && !Array.isArray(v);
const keys = (v: Obj, expected: string[]) => Object.keys(v).length === expected.length && expected.every((k) => k in v);
const str = (v: unknown, n: number, empty = false): v is string => typeof v === "string" && v.length <= n && (empty || !!v.trim());
const int = (v: unknown, a: number, b: number): v is number => typeof v === "number" && Number.isInteger(v) && v >= a && v <= b;
const nullable = (v: unknown) => v === null || str(v, 120);
const exerciseKeys = ["exerciseId", "sets", "reps", "weight"];
function exercise(v: unknown, ids: Set<string>): boolean {
  return obj(v) && keys(v, exerciseKeys) && str(v.exerciseId, 120) && ids.has(v.exerciseId) &&
    int(v.sets, 1, 8) && int(v.reps, 1, 50) && typeof v.weight === "number" &&
    Number.isFinite(v.weight) && v.weight >= 0 && v.weight <= 1000;
}
export function planningContext(context: string): Planning | null {
  let body: unknown;
  try {body = JSON.parse(context);} catch {return null;}
  if (!obj(body) || !obj(body.planning)) return null;
  const p = body.planning;
  if (!keys(p, ["intent", "catalog", "customRoutines", "targetRoutineId"]) ||
    !["create", "edit", "add", "replace"].includes(String(p.intent)) || !nullable(p.targetRoutineId) ||
    !Array.isArray(p.catalog) || p.catalog.length < 1 || p.catalog.length > 100 ||
    !Array.isArray(p.customRoutines) || p.customRoutines.length > 10) return null;
  const ids = new Set<string>();
  for (const item of p.catalog) {
    if (!obj(item) || !keys(item, ["id", "name", "muscle", "equipment"]) ||
      !str(item.id, 120) || !str(item.name, 160) || !str(item.muscle, 80) ||
      !str(item.equipment, 80) || ids.has(item.id)) return null;
    ids.add(item.id);
  }
  const revisions = new Map<string, string>();
  for (const item of p.customRoutines) {
    if (!obj(item) || !keys(item, ["id", "revision", "name", "exercises"]) ||
      !str(item.id, 120) || !str(item.revision, 120) || !str(item.name, 80) ||
      !Array.isArray(item.exercises) || item.exercises.length < 1 || item.exercises.length > 12 ||
      item.exercises.some((entry) => !exercise(entry, ids)) || revisions.has(item.id)) return null;
    revisions.set(item.id, item.revision);
  }
  const target = p.targetRoutineId as string | null;
  if ((target !== null && !revisions.has(target)) || (p.intent !== "create" && target === null)) return null;
  return {intent: String(p.intent), ids, target, revisions};
}
export function validateProposal(v: unknown, planning: Planning | null): v is Obj {
  if (!planning || !obj(v) || !keys(v, ["schemaVersion", "title", "summary", "routines", "schedule"]) ||
    v.schemaVersion !== 1 || !str(v.title, 100) || !str(v.summary, 1200) ||
    !Array.isArray(v.routines) || v.routines.length < 1 || v.routines.length > 7) return false;
  const targets = new Set<string>();
  for (const r of v.routines) {
    if (!obj(r) || !keys(r, ["targetRoutineId", "expectedRevision", "name", "subtitle", "estimatedMinutes", "exercises"]) ||
      !nullable(r.targetRoutineId) || !nullable(r.expectedRevision) || !str(r.name, 80) ||
      !str(r.subtitle, 240, true) || !int(r.estimatedMinutes, 15, 180) ||
      !Array.isArray(r.exercises) || r.exercises.length < 1 || r.exercises.length > 12) return false;
    if (r.targetRoutineId === null) {
      if (r.expectedRevision !== null || planning.intent !== "create") return false;
    } else {
      const id = r.targetRoutineId as string;
      if (id !== planning.target || targets.has(id) || planning.revisions.get(id) !== r.expectedRevision) return false;
      targets.add(id);
    }
    const seen = new Set<string>();
    for (const e of r.exercises) {
      if (!exercise(e, planning.ids)) return false;
      const id = (e as Obj).exerciseId as string;
      if (seen.has(id)) return false;
      seen.add(id);
    }
  }
  if (v.schedule !== null) {
    const s = v.schedule;
    if (!obj(s) || !keys(s, ["routineIndex", "weeks", "weekdays", "startDate", "hour", "minute", "reminder"]) ||
      !int(s.routineIndex, 0, v.routines.length - 1) || !int(s.weeks, 1, 12) || !int(s.hour, 0, 23) ||
      !int(s.minute, 0, 59) || typeof s.reminder !== "boolean" || !Array.isArray(s.weekdays) ||
      s.weekdays.length < 1 || s.weekdays.length > 7 || s.weekdays.some((day) => !int(day, 1, 7)) ||
      new Set(s.weekdays).size !== s.weekdays.length || !str(s.startDate, 10) || !/^\d{4}-\d{2}-\d{2}$/.test(s.startDate)) return false;
    const date = new Date(`${s.startDate}T00:00:00Z`);
    if (!Number.isFinite(date.valueOf()) || date.toISOString().slice(0, 10) !== s.startDate ||
      date.getUTCFullYear() < 2000 || date.getUTCFullYear() > 2100) return false;
  }
  return true;
}
export function parseCoachOutput(raw: string | null, input: CoachInput): CoachOutput | null {
  if (!raw || raw.length > 50000) return null;
  let data: unknown;
  try {data = JSON.parse(raw);} catch {return null;}
  if (!obj(data) || !keys(data, ["reply", "proposal"]) || !str(data.reply, 12000)) return null;
  if (data.proposal !== null && (/pain|hurt|injur|faint|dizz|calori|nutrition|diet|durer|doare|accident/i.test(input.message) ||
    !validateProposal(data.proposal, planningContext(input.context)))) return null;
  return {reply: data.reply.trim(), proposal: data.proposal as Obj | null};
}
const nullableString = {type: ["string", "null"]};
const exSchema = {type: "object", additionalProperties: false, required: exerciseKeys, properties: {
  exerciseId: {type: "string"}, sets: {type: "integer", minimum: 1, maximum: 8},
  reps: {type: "integer", minimum: 1, maximum: 50}, weight: {type: "number", minimum: 0, maximum: 1000},
}};
const scheduleSchema = {type: "object", additionalProperties: false,
  required: ["routineIndex", "weeks", "weekdays", "startDate", "hour", "minute", "reminder"], properties: {
    routineIndex: {type: "integer", minimum: 0, maximum: 6}, weeks: {type: "integer", minimum: 1, maximum: 12},
    weekdays: {type: "array", minItems: 1, maxItems: 7, items: {type: "integer", minimum: 1, maximum: 7}},
    startDate: {type: "string"}, hour: {type: "integer", minimum: 0, maximum: 23},
    minute: {type: "integer", minimum: 0, maximum: 59}, reminder: {type: "boolean"},
  }};
export const coachOutputSchema = {type: "object", additionalProperties: false, required: ["reply", "proposal"], properties: {
  reply: {type: "string"}, proposal: {anyOf: [{type: "null"}, {type: "object", additionalProperties: false,
    required: ["schemaVersion", "title", "summary", "routines", "schedule"], properties: {
      schemaVersion: {type: "integer", enum: [1]}, title: {type: "string"}, summary: {type: "string"},
      routines: {type: "array", minItems: 1, maxItems: 7, items: {type: "object", additionalProperties: false,
        required: ["targetRoutineId", "expectedRevision", "name", "subtitle", "estimatedMinutes", "exercises"], properties: {
          targetRoutineId: nullableString, expectedRevision: nullableString, name: {type: "string"}, subtitle: {type: "string"},
          estimatedMinutes: {type: "integer", minimum: 15, maximum: 180},
          exercises: {type: "array", minItems: 1, maxItems: 12, items: exSchema},
        }}}, schedule: {anyOf: [{type: "null"}, scheduleSchema]},
    }}]},
}};
