import copy
from datetime import date, datetime, timedelta
import json
from pathlib import Path
import tempfile
import unittest

import generate_demo_data as demo


class DemoDataTests(unittest.TestCase):
    as_of = date(2026, 10, 15)

    def test_history_has_realistic_completed_values_windows_and_catalog_ids(self):
        payload, summary = demo.build_fixture(as_of=self.as_of)
        self.assertEqual(summary['demoWorkouts'], 36)
        self.assertEqual(summary['demoActiveDays'], 36)
        self.assertEqual(summary['demoCompletedSets'], 572)
        self.assertEqual(summary['demoExercises'], 16)
        self.assertEqual(summary['demoWorkoutsIn7DaysBeforeCutoff'], 3)
        self.assertEqual(summary['demoWorkoutsIn28DaysBeforeCutoff'], 12)
        cutoff = datetime.combine(self.as_of, datetime.min.time(), tzinfo=demo.BUCHAREST)
        self.assertTrue(all(demo._parse_instant(s['finishedAt']) < cutoff for s in payload['history']))
        self.assertEqual(payload['profile']['weightKg'], None)
        self.assertEqual(payload['bodyMeasurements'], [])
        self.assertTrue(all('TEST DATA' in s['notes'] and 'TEST DATA' in s['routineName']
                            for s in payload['history']))

    def test_merge_is_idempotent_preserves_profile_active_and_user_edited_demo_rows(self):
        base, _ = demo.build_fixture(as_of=self.as_of)
        base['name'] = 'Existing name'
        base['goal'] = 'General fitness'
        base['profile'].update({'weightKg': 95, 'heightCm': 185, 'coachConsent': True})
        base['active'] = {'id': 'preserve-active', 'unrecognizedFutureField': [1, 2]}
        base['favoriteExerciseIds'] = ['squat']
        base['routines'] = [{'id': 'preserve-routine'}]
        base['schedule'] = [{'id': 'preserve-calendar'}]
        base['additionalFutureKey'] = {'preserve': True}
        edited = base['history'][0]
        edited['notes'] = 'User edited a demo row. Keep my changes.'
        edited['exercises'][0]['sets'][0]['weight'] = 123.5
        before = copy.deepcopy(base)
        merged, summary = demo.build_fixture(as_of=self.as_of, base=base)
        self.assertEqual(summary['addedWorkouts'], 0)
        self.assertEqual(merged, before)
        self.assertEqual(base, before, 'The supplied object must not be mutated.')
        for key in ('name', 'goal', 'profile', 'active', 'favoriteExerciseIds', 'routines', 'schedule'):
            self.assertEqual(merged[key], before[key])

    def test_missing_demo_rows_append_once_without_replacing_current_history(self):
        fixture, _ = demo.build_fixture(as_of=self.as_of)
        base = demo.default_export()
        personal = copy.deepcopy(fixture['history'][0])
        personal['id'] = 'personal-history'
        personal['notes'] = 'My real workout'
        base['history'] = [personal, fixture['history'][1]]
        merged, summary = demo.build_fixture(as_of=self.as_of, base=base)
        self.assertEqual(summary['addedWorkouts'], 35)
        self.assertEqual(len(merged['history']), 37)
        self.assertEqual(next(s for s in merged['history'] if s['id'] == 'personal-history'), personal)
        rerun, stats = demo.build_fixture(as_of=self.as_of, base=merged)
        self.assertEqual(rerun, merged)
        self.assertEqual(stats['addedWorkouts'], 0)

    def test_optional_body_history_is_labelled_idempotent_and_does_not_change_profile(self):
        base = demo.default_export()
        base['profile'].update({'weightKg': 95, 'heightCm': 185})
        merged, summary = demo.build_fixture(as_of=self.as_of, base=base, include_body_measurements=True)
        self.assertEqual(summary['addedBodyMeasurements'], 7)
        self.assertEqual(merged['profile'], base['profile'])
        self.assertEqual(len(merged['bodyMeasurements']), 7)
        self.assertTrue(all('TEST DATA' in value['sourceName'] for value in merged['bodyMeasurements']))
        self.assertTrue(all(value['source'] == 'manual' for value in merged['bodyMeasurements']))
        repeated, stats = demo.build_fixture(as_of=self.as_of, base=merged, include_body_measurements=True)
        self.assertEqual(repeated, merged)
        self.assertEqual(stats['addedBodyMeasurements'], 0)

    def test_dates_use_actual_bucharest_dst_offsets_and_no_future_cutoff(self):
        history = demo.generate_history(date(2026, 4, 1))
        offsets = {demo._parse_instant(value['startedAt']).utcoffset() for value in history}
        self.assertEqual(offsets, {timedelta(hours=2), timedelta(hours=3)})
        future = datetime.now(demo.BUCHAREST).date() + timedelta(days=1)
        with self.assertRaises(ValueError):
            demo.build_fixture(as_of=future)

    def test_invalid_base_does_not_replace_existing_output(self):
        with tempfile.TemporaryDirectory() as folder:
            output = Path(folder) / 'result.json'
            output.write_text('keep original', encoding='utf-8')
            base = Path(folder) / 'bad.json'
            base.write_text(json.dumps({'version': 99}), encoding='utf-8')
            result = demo.main(['--base', str(base), '--output', str(output), '--as-of', self.as_of.isoformat()])
            self.assertEqual(result, 1)
            self.assertEqual(output.read_text(encoding='utf-8'), 'keep original')


if __name__ == '__main__':
    unittest.main()
