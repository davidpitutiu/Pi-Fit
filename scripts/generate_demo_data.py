#!/usr/bin/env python3
"""Create clearly labelled, deterministic Pi Fit test history; never writes Firebase.

--as-of YYYY-MM-DD is an exclusive Europe/Bucharest midnight cutoff. The latest
36 Monday/Wednesday/Friday dates before it are used (about twelve weeks).
Existing same-ID records always win, including user-edited demo records. The
fixed pifit-demo-v1 namespace makes repeated merges idempotent even with another
cutoff date. Body measurements are opt-in and never change profile values.

Example:
  python scripts/generate_demo_data.py --as-of 2026-10-15 --output /tmp/pi-fit-demo.json
  python scripts/generate_demo_data.py --base backup.json --output merged.json
"""
from __future__ import annotations

import argparse
import copy
from datetime import date, datetime, time, timedelta
import json
from pathlib import Path
import re
import sys
from zoneinfo import ZoneInfo

BUCHAREST = ZoneInfo('Europe/Bucharest')
PREFIX = 'pifit-demo-v1'
TEST_NOTE = (
    'TEST DATA: synthetic demonstration workout generated for progress and export testing. '
    'These are not your personal training results. Demo record IDs start with pifit-demo-v1-.'
)

# (stable catalog ID, working sets, repetitions, initial external kg,
# load increase, exposures between increases). No bodyweight/duration ambiguity.
PUSH = (
    ('bench_press', 4, 8, 45.0, 2.5, 2),
    ('incline_dumbbell_press', 3, 10, 16.0, 2.0, 3),
    ('dumbbell_shoulder_press', 3, 10, 12.0, 2.0, 3),
    ('lateral_raise', 3, 12, 6.0, 1.0, 4),
    ('triceps_pushdown', 3, 12, 20.0, 2.5, 3),
)
PULL = (
    ('lat_pulldown', 4, 10, 35.0, 2.5, 2),
    ('seated_cable_row', 3, 10, 30.0, 2.5, 3),
    ('dumbbell_row', 3, 10, 18.0, 2.0, 3),
    ('dumbbell_curl', 3, 12, 8.0, 1.0, 3),
    ('hammer_curl', 3, 12, 8.0, 1.0, 4),
)
LEGS = (
    ('squat', 4, 8, 50.0, 2.5, 2),
    ('romanian_deadlift', 3, 10, 45.0, 2.5, 3),
    ('leg_press', 3, 10, 90.0, 5.0, 2),
    ('leg_curl', 3, 12, 25.0, 2.5, 3),
    ('standing_calf_raise', 3, 12, 35.0, 2.5, 3),
)
FULL_BODY = (
    ('squat', 3, 8, 50.0, 2.5, 2),
    ('bench_press', 3, 8, 45.0, 2.5, 2),
    ('lat_pulldown', 3, 10, 35.0, 2.5, 2),
    ('hip_thrust', 3, 10, 50.0, 5.0, 2),
    ('dumbbell_shoulder_press', 3, 10, 12.0, 2.0, 3),
)


def default_export() -> dict:
    return {
        'version': 1, 'name': 'Athlete', 'goal': 'Strength and muscle',
        'theme': 'dark',
        'profile': {
            'age': None, 'heightCm': None, 'weightKg': None,
            'experience': 'Beginner', 'sessionsPerWeek': 3, 'sessionMinutes': 60,
            'equipment': [], 'limitations': '', 'preferredDays': [1, 3, 5],
            'coachConsent': False,
        },
        'favoriteExerciseIds': [], 'bodyMeasurements': [],
        'appliedCoachProposalIds': [], 'routines': [], 'history': [],
        'schedule': [], 'active': None,
    }


def _parse_instant(value: str) -> datetime:
    parsed = datetime.fromisoformat(value.replace('Z', '+00:00'))
    return parsed.replace(tzinfo=BUCHAREST) if parsed.tzinfo is None else parsed


def _catalog_ids() -> set[str]:
    catalog = Path(__file__).resolve().parents[1] / 'lib/domain/external_exercise_catalog.dart'
    return set(re.findall(r"^\s*id:\s*'([^']+)'", catalog.read_text(encoding='utf-8'), re.MULTILINE))


def generate_history(as_of: date) -> list[dict]:
    dates = [as_of - timedelta(days=offset) for offset in range(1, 91)
             if (as_of - timedelta(days=offset)).weekday() in (0, 2, 4)][:36]
    if len(dates) != 36:
        raise ValueError('The selected window must contain 36 training dates.')
    dates.sort()
    exposures: dict[str, int] = {}
    history = []
    for index, day in enumerate(dates):
        name, exercises = (('Push day', PUSH), ('Pull day', PULL), ('Leg day', LEGS))[index % 3]
        if (index + 1) % 9 == 0:
            name, exercises = 'Full body', FULL_BODY
        started = datetime.combine(day, time(18, (index % 3) * 15), tzinfo=BUCHAREST)
        duration = 44 + (index * 7) % 24
        entries = []
        for exercise_id, count, base_reps, initial, increment, every in exercises:
            exposure = exposures.get(exercise_id, 0)
            load = initial + (exposure // every) * increment
            sets = []
            for set_index in range(count):
                backoff = 2.5 if count == 4 and set_index >= 2 else 0.0
                sets.append({
                    'reps': base_reps + ((index + set_index) % 3) - 1,
                    'weight': round(max(1.0, load - backoff), 2),
                    'completed': True,
                    'rpe': round(6.5 + (exposure % 3) * 0.5 + set_index * 0.5, 1),
                })
            entries.append({'exerciseId': exercise_id, 'sets': sets})
            exposures[exercise_id] = exposure + 1
        history.append({
            'id': f'{PREFIX}-workout-{index + 1:02d}',
            'routineName': f'TEST DATA · {name}',
            'startedAt': started.isoformat(),
            'finishedAt': (started + timedelta(minutes=duration)).isoformat(),
            'exercises': entries, 'notes': TEST_NOTE,
        })
    return history


def generate_body_measurements(as_of: date) -> list[dict]:
    records = []
    for index in range(7):
        day = as_of - timedelta(days=85 - index * 14)
        records.append({
            'id': f'{PREFIX}-body-{index + 1:02d}',
            'measuredAt': datetime.combine(day, time(7, 30), tzinfo=BUCHAREST).isoformat(),
            'weightKg': round(82.4 - index * 0.2, 1),
            'heightCm': 180.0 if index == 0 else None,
            'source': 'manual',
            'sourceRecordId': f'{PREFIX}-body-{index + 1:02d}',
            'sourceName': 'TEST DATA · synthetic body measurement',
        })
    return records


def validate_generated(history: list[dict], as_of: date) -> dict:
    cutoff = datetime.combine(as_of, time.min, tzinfo=BUCHAREST)
    start = cutoff - timedelta(days=90)
    catalog_ids = _catalog_ids()
    ids = set()
    completed_sets = 0
    volume = 0.0
    exercise_ids = set()
    dates = set()
    for session in history:
        if not session['id'].startswith(f'{PREFIX}-workout-') or session['id'] in ids:
            raise ValueError('Generated workout IDs must be unique demo IDs.')
        ids.add(session['id'])
        began, finished = _parse_instant(session['startedAt']), _parse_instant(session['finishedAt'])
        if not start <= began < finished < cutoff:
            raise ValueError('A generated workout lies outside the past 90 days.')
        if not timedelta(minutes=30) <= finished - began <= timedelta(minutes=90):
            raise ValueError('A generated workout duration is invalid.')
        if 'TEST DATA' not in session['notes'] or 'TEST DATA' not in session['routineName']:
            raise ValueError('Synthetic workouts must be visibly labelled TEST DATA.')
        dates.add(began.astimezone(BUCHAREST).date())
        for exercise in session['exercises']:
            exercise_id = exercise['exerciseId']
            if exercise_id not in catalog_ids:
                raise ValueError(f'Unknown catalog exercise: {exercise_id}')
            exercise_ids.add(exercise_id)
            for value in exercise['sets']:
                if not (value['completed'] is True and 1 <= value['reps'] <= 50
                        and 0 < value['weight'] <= 250 and 1 <= value['rpe'] <= 10):
                    raise ValueError('A generated set is not a valid completed strength set.')
                completed_sets += 1
                volume += value['reps'] * value['weight']
    if len(history) != 36 or len(dates) != 36:
        raise ValueError('The demo must contain 36 distinct completed training days.')
    def period_count(days: int) -> int:
        boundary = as_of - timedelta(days=days)
        return sum(day >= boundary for day in dates)
    return {
        'demoWorkouts': len(history), 'demoActiveDays': len(dates),
        'demoCompletedSets': completed_sets, 'demoVolumeKgReps': round(volume, 2),
        'demoExercises': len(exercise_ids),
        'demoWorkoutsIn7DaysBeforeCutoff': period_count(7),
        'demoWorkoutsIn28DaysBeforeCutoff': period_count(28),
        'firstDemoWorkout': min(dates).isoformat(),
        'lastDemoWorkout': max(dates).isoformat(),
    }


def _validate_base(base: dict) -> None:
    if not isinstance(base, dict) or base.get('version') != 1:
        raise ValueError('The base must be a plain AppStore export with version 1.')
    for key in ('name', 'goal', 'theme'):
        if not isinstance(base.get(key), str):
            raise ValueError(f'The base {key} must be a string.')
    for key in ('history', 'routines', 'schedule'):
        if not isinstance(base.get(key), list):
            raise ValueError(f'The base {key} must be a list.')
    for key in ('history', 'bodyMeasurements'):
        records = base.get(key, [])
        if not isinstance(records, list):
            raise ValueError(f'The base {key} must be a list.')
        ids = [record.get('id') for record in records if isinstance(record, dict)]
        if len(ids) != len(records) or any(not isinstance(value, str) or not value for value in ids):
            raise ValueError(f'The base {key} has invalid record IDs.')
        if len(set(ids)) != len(ids):
            raise ValueError(f'The base {key} contains duplicate record IDs; no output was changed.')
    if 'active' not in base:
        raise ValueError('The base export must include active, even when it is null.')


def build_fixture(*, as_of: date, base: dict | None = None,
                  include_body_measurements: bool = False) -> tuple[dict, dict]:
    if as_of > datetime.now(BUCHAREST).date():
        raise ValueError('--as-of cannot be a future date in Europe/Bucharest.')
    if as_of.year < 2000:
        raise ValueError('--as-of must be a date from the year 2000 onward.')
    result = default_export() if base is None else copy.deepcopy(base)
    _validate_base(result)
    demo = generate_history(as_of)
    summary = validate_generated(demo, as_of)
    existing_ids = {session['id'] for session in result['history']}
    additions = [session for session in demo if session['id'] not in existing_ids]
    result['history'] = sorted(result['history'] + additions,
                               key=lambda entry: _parse_instant(entry['startedAt']), reverse=True)
    body_added = 0
    if include_body_measurements:
        # Never infer or replace the user's current profile values from test data.
        existing = result.get('bodyMeasurements', [])
        ids = {record['id'] for record in existing}
        source_ids = {(record.get('source'), record.get('sourceRecordId'))
                      for record in existing if record.get('sourceRecordId') is not None}
        body_additions = [record for record in generate_body_measurements(as_of)
                          if record['id'] not in ids
                          and (record['source'], record['sourceRecordId']) not in source_ids]
        result['bodyMeasurements'] = sorted(existing + body_additions,
            key=lambda entry: _parse_instant(entry['measuredAt']), reverse=True)
        body_added = len(body_additions)
    summary.update({'addedWorkouts': len(additions), 'addedBodyMeasurements': body_added,
                    'resultWorkoutCount': len(result['history']),
                    'asOfExclusive': as_of.isoformat(), 'timezone': 'Europe/Bucharest'})
    return result, summary


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--base', type=Path, help='Existing plain AppStore export JSON to merge without replacing data.')
    parser.add_argument('--output', required=True, type=Path, help='Destination JSON file; no cloud writes are performed.')
    parser.add_argument('--as-of', type=date.fromisoformat, default=datetime.now(BUCHAREST).date(), metavar='YYYY-MM-DD')
    parser.add_argument('--include-body-measurements', action='store_true', help='Explicitly add seven labelled synthetic measurements; preserves profile values.')
    args = parser.parse_args(argv)
    try:
        base = None if args.base is None else json.loads(args.base.read_text(encoding='utf-8'))
        payload, summary = build_fixture(as_of=args.as_of, base=base,
                                        include_body_measurements=args.include_body_measurements)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        temporary = args.output.with_name(args.output.name + '.tmp')
        temporary.write_text(json.dumps(payload, ensure_ascii=False, indent=2, allow_nan=False) + '\n', encoding='utf-8')
        temporary.replace(args.output)
        # Summary only: never print the supplied profile, notes, or account data.
        print(json.dumps(summary, ensure_ascii=False, sort_keys=True))
        return 0
    except (OSError, ValueError, TypeError, KeyError) as error:
        print(f'Demo generation failed: {error}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
