# Exercise photographs and coaching notes

Pi Fit includes **878 distinct exercises**: the complete **876-record Free Exercise DB snapshot**, plus two Pi Fit movements absent from that dataset. The existing **216 exercise records** and their Romanian instructions remain available; the other **662 records** are imported without duplicating any upstream source ID. The original 64 durable exercise IDs are retained, so saved workout and routine references still resolve.

## Source and permission

Photographs are copied unchanged from [yuhonas/free-exercise-db](https://github.com/yuhonas/free-exercise-db/tree/f00c92c7dcf1216a928a52c3706c7ce8e2f71ed5), revision `f00c92c7dcf1216a928a52c3706c7ce8e2f71ed5`. The project README explicitly offers the JSON exercise descriptions and photographs for local use, and the repository is released under [The Unlicense](https://github.com/yuhonas/free-exercise-db/blob/f00c92c7dcf1216a928a52c3706c7ce8e2f71ed5/LICENSE.md). Its README credits the earlier [wrkout/exercises.json](https://github.com/wrkout/exercises.json) dataset.

The photographs are bundled in `assets/exercises/`; exercise screens need no external image server and do not send the user’s workout history to a third-party image host. The files are original JPEGs, without crops, retouching, or recompression. Start and end positions are separate images. Exact source folder names are recorded below.

Romanian names, three-step technique instructions, tips, difficulty labels, and filter facets are curated for Pi Fit. Variants that look similar remain separate only when equipment, grip, support, angle, or movement genuinely differ. Images demonstrate the named variant, rather than serving as generic muscle-group placeholders. The full selected external database is included. This is not a claim that every possible exercise in existence is represented, nor that Pi Fit uses Hevy’s private catalog.

Two movements absent from the source dataset, `bird_dog` and the two-handed `kettlebell_swing`, use technical illustrations generated with OpenAI image generation for Pi Fit and are credited in the app as such. These illustrations are visual guidance; the written technique remains authoritative.


## Complete external database and online photographs

- The full upstream JSON is preserved in `assets/exercise-data/catalog.json`, including its source revision, license and SHA-256. It contains 876 upstream records exactly as published.
- `lib/domain/external_exercise_catalog.dart` supplies the 662 records not already represented by the curated library. Each record has a stable `sourceId`; all 876 upstream IDs appear exactly once in the app. The additional Pi Fit `bird_dog` and two-handed `kettlebell_swing` have no upstream ID.
- The original 216 records keep their local, bundled images. The other 659 photographed source records use HTTPS URLs pinned to the same Git revision; photographs load on demand, so the app does not bundle the full 100+ MB source image collection. Viewing an image downloads that image from `raw.githubusercontent.com`. The full exercise names, instructions and filter metadata work offline. Previously displayed remote images may remain in Flutter’s in-memory cache; availability after an app restart is not guaranteed.
- All 660 newly imported records with usable source instructions retain the original English instructions, marked `instructionLanguage: en`; filter facets remain Romanian. Two upstream records, `Iron_Cross` and `One-Arm_Kettlebell_Swings`, contain no source instructions. Pi Fit supplies specific Romanian steps for their photographed variants and explicitly credits those notes as Pi Fit (`instructionLanguage: ro`). The existing 216 records also use Romanian notes.
- Three upstream records have no photographs: `Kettlebell_Halo`, `Kettlebell_Halo_With_Overhead_Extension`, and `Kettlebell_Overhead_Triceps_Extension`. Their records remain available and their image URLs are empty; the UI should show an honest unavailable-image state.
- Source categories, muscles, equipment and difficulty are mapped to consistent Romanian facets. Imported exercise names remain in English to retain the exact source identity; aliases include the original title and readable source ID.
- This import uses a pinned public snapshot. Updating to a newer upstream revision requires regenerating the snapshot and imported Dart records together; runtime browsing does not silently change exercise IDs or technique notes.

## Reproducing and refreshing the external import

The importer is `scripts/import_exercise_catalog.py` and requires only Python 3. It derives the curated-source mapping from the explicit `sourceId` fields in `exercise_catalog.dart` and `exercise_metadata.dart`; it preserves those records and their instructions. Default generation is offline and validates the snapshot’s canonical data checksum.

```sh
python scripts/import_exercise_catalog.py --check
python scripts/import_exercise_catalog.py
dart format lib/domain/external_exercise_catalog.dart
flutter test test/domain_test.dart
```

To select a newer upstream revision, download that revision’s `dist/exercises.json`, review its license and changes, then run `python scripts/import_exercise_catalog.py --source /path/to/dist/exercises.json --revision <exact-40-character-git-sha>`. This refreshes the snapshot and remaining imported Dart records together. Run the formatter and tests, review the source-count/provenance changes, and update this document for the chosen revision. The importer never downloads images or silently fetches a newer revision.

Current upstream JSON SHA-256: `5bb747e3fc658f095a60dcbf6d53c96627acdcc6ffb6fffde86f7e26995d40bf`.

Current canonical record-data SHA-256 (UTF-8 JSON, sorted keys and compact separators): `9982e8e947e15eb6db21dfde0954883681522187a767a94c99e0d70a8555f38d`.

## Variant clarifications

- `goblet_squat` shows a kettlebell and its equipment label now says Kettlebell.
- `reverse_fly` now explicitly describes the chest-supported incline-bench variant shown in its photos.
- `hanging_knee_raise` retains its saved ID, but the title, equipment and setup now correctly describe a captain’s-chair/parallels knee raise, as shown.
- Existing exercise IDs and routine IDs have not been renamed. Custom exercise records created before this update remain readable because image and filter metadata are optional.

## Bundled image index

| Pi Fit exercise ID | Upstream source folder | Positions |
| --- | --- | --- |
| `bench_press` | `Barbell_Bench_Press_-_Medium_Grip` | `bench_press.jpg` · `bench_press_end.jpg` |
| `incline_dumbbell_press` | `Incline_Dumbbell_Press` | `incline_dumbbell_press.jpg` · `incline_dumbbell_press_end.jpg` |
| `dumbbell_press` | `Dumbbell_Bench_Press` | `dumbbell_press.jpg` · `dumbbell_press_end.jpg` |
| `chest_fly` | `Dumbbell_Flyes` | `chest_fly.jpg` · `chest_fly_end.jpg` |
| `cable_fly` | `Cable_Crossover` | `cable_fly.jpg` · `cable_fly_end.jpg` |
| `push_up` | `Pushups` | `push_up.jpg` · `push_up_end.jpg` |
| `chest_press` | `Machine_Bench_Press` | `chest_press.jpg` · `chest_press_end.jpg` |
| `dips` | `Dips_-_Chest_Version` | `dips.jpg` · `dips_end.jpg` |
| `pull_up` | `Pullups` | `pull_up.jpg` · `pull_up_end.jpg` |
| `lat_pulldown` | `Wide-Grip_Lat_Pulldown` | `lat_pulldown.jpg` · `lat_pulldown_end.jpg` |
| `barbell_row` | `Bent_Over_Barbell_Row` | `barbell_row.jpg` · `barbell_row_end.jpg` |
| `seated_cable_row` | `Seated_Cable_Rows` | `seated_cable_row.jpg` · `seated_cable_row_end.jpg` |
| `dumbbell_row` | `One-Arm_Dumbbell_Row` | `dumbbell_row.jpg` · `dumbbell_row_end.jpg` |
| `face_pull` | `Face_Pull` | `face_pull.jpg` · `face_pull_end.jpg` |
| `straight_arm_pulldown` | `Straight-Arm_Pulldown` | `straight_arm_pulldown.jpg` · `straight_arm_pulldown_end.jpg` |
| `chest_supported_row` | `Dumbbell_Incline_Row` | `chest_supported_row.jpg` · `chest_supported_row_end.jpg` |
| `overhead_press` | `Standing_Military_Press` | `overhead_press.jpg` · `overhead_press_end.jpg` |
| `dumbbell_shoulder_press` | `Dumbbell_Shoulder_Press` | `dumbbell_shoulder_press.jpg` · `dumbbell_shoulder_press_end.jpg` |
| `lateral_raise` | `Side_Lateral_Raise` | `lateral_raise.jpg` · `lateral_raise_end.jpg` |
| `front_raise` | `Front_Dumbbell_Raise` | `front_raise.jpg` · `front_raise_end.jpg` |
| `reverse_fly` | `Reverse_Flyes` | `reverse_fly.jpg` · `reverse_fly_end.jpg` |
| `cable_lateral_raise` | `Standing_Low-Pulley_Deltoid_Raise` | `cable_lateral_raise.jpg` · `cable_lateral_raise_end.jpg` |
| `barbell_curl` | `Barbell_Curl` | `barbell_curl.jpg` · `barbell_curl_end.jpg` |
| `dumbbell_curl` | `Dumbbell_Bicep_Curl` | `dumbbell_curl.jpg` · `dumbbell_curl_end.jpg` |
| `hammer_curl` | `Hammer_Curls` | `hammer_curl.jpg` · `hammer_curl_end.jpg` |
| `preacher_curl` | `Preacher_Curl` | `preacher_curl.jpg` · `preacher_curl_end.jpg` |
| `cable_curl` | `Standing_Biceps_Cable_Curl` | `cable_curl.jpg` · `cable_curl_end.jpg` |
| `incline_curl` | `Incline_Dumbbell_Curl` | `incline_curl.jpg` · `incline_curl_end.jpg` |
| `triceps_pushdown` | `Triceps_Pushdown` | `triceps_pushdown.jpg` · `triceps_pushdown_end.jpg` |
| `overhead_triceps_extension` | `Cable_Rope_Overhead_Triceps_Extension` | `overhead_triceps_extension.jpg` · `overhead_triceps_extension_end.jpg` |
| `skull_crusher` | `Lying_Triceps_Press` | `skull_crusher.jpg` · `skull_crusher_end.jpg` |
| `close_grip_press` | `Close-Grip_Barbell_Bench_Press` | `close_grip_press.jpg` · `close_grip_press_end.jpg` |
| `squat` | `Barbell_Squat` | `squat.jpg` · `squat_end.jpg` |
| `front_squat` | `Front_Barbell_Squat` | `front_squat.jpg` · `front_squat_end.jpg` |
| `goblet_squat` | `Goblet_Squat` | `goblet_squat.jpg` · `goblet_squat_end.jpg` |
| `leg_press` | `Leg_Press` | `leg_press.jpg` · `leg_press_end.jpg` |
| `leg_extension` | `Leg_Extensions` | `leg_extension.jpg` · `leg_extension_end.jpg` |
| `lunge` | `Dumbbell_Lunges` | `lunge.jpg` · `lunge_end.jpg` |
| `bulgarian_split_squat` | `Split_Squat_with_Dumbbells` | `bulgarian_split_squat.jpg` · `bulgarian_split_squat_end.jpg` |
| `step_up` | `Dumbbell_Step_Ups` | `step_up.jpg` · `step_up_end.jpg` |
| `deadlift` | `Barbell_Deadlift` | `deadlift.jpg` · `deadlift_end.jpg` |
| `romanian_deadlift` | `Romanian_Deadlift` | `romanian_deadlift.jpg` · `romanian_deadlift_end.jpg` |
| `leg_curl` | `Lying_Leg_Curls` | `leg_curl.jpg` · `leg_curl_end.jpg` |
| `seated_leg_curl` | `Seated_Leg_Curl` | `seated_leg_curl.jpg` · `seated_leg_curl_end.jpg` |
| `hip_thrust` | `Barbell_Hip_Thrust` | `hip_thrust.jpg` · `hip_thrust_end.jpg` |
| `glute_bridge` | `Butt_Lift_Bridge` | `glute_bridge.jpg` · `glute_bridge_end.jpg` |
| `cable_kickback` | `One-Legged_Cable_Kickback` | `cable_kickback.jpg` · `cable_kickback_end.jpg` |
| `hip_abduction` | `Thigh_Abductor` | `hip_abduction.jpg` · `hip_abduction_end.jpg` |
| `standing_calf_raise` | `Standing_Calf_Raises` | `standing_calf_raise.jpg` · `standing_calf_raise_end.jpg` |
| `seated_calf_raise` | `Seated_Calf_Raise` | `seated_calf_raise.jpg` · `seated_calf_raise_end.jpg` |
| `plank` | `Plank` | `plank.jpg` · `plank_end.jpg` |
| `side_plank` | `Side_Bridge` | `side_plank.jpg` · `side_plank_end.jpg` |
| `crunch` | `Crunches` | `crunch.jpg` · `crunch_end.jpg` |
| `cable_crunch` | `Cable_Crunch` | `cable_crunch.jpg` · `cable_crunch_end.jpg` |
| `hanging_knee_raise` | `Knee_Hip_Raise_On_Parallel_Bars` | `hanging_knee_raise.jpg` · `hanging_knee_raise_end.jpg` |
| `dead_bug` | `Dead_Bug` | `dead_bug.jpg` · `dead_bug_end.jpg` |
| `russian_twist` | `Russian_Twist` | `russian_twist.jpg` · `russian_twist_end.jpg` |
| `treadmill` | `Running_Treadmill` | `treadmill.jpg` · `treadmill_end.jpg` |
| `stationary_bike` | `Bicycling_Stationary` | `stationary_bike.jpg` · `stationary_bike_end.jpg` |
| `rower` | `Rowing_Stationary` | `rower.jpg` · `rower_end.jpg` |
| `jump_rope` | `Rope_Jumping` | `jump_rope.jpg` · `jump_rope_end.jpg` |
| `elliptical` | `Elliptical_Trainer` | `elliptical.jpg` · `elliptical_end.jpg` |
| `incline_barbell_press` | `Barbell_Incline_Bench_Press_-_Medium_Grip` | `incline_barbell_press.jpg` · `incline_barbell_press_end.jpg` |
| `decline_barbell_press` | `Decline_Barbell_Bench_Press` | `decline_barbell_press.jpg` · `decline_barbell_press_end.jpg` |
| `decline_dumbbell_press` | `Decline_Dumbbell_Bench_Press` | `decline_dumbbell_press.jpg` · `decline_dumbbell_press_end.jpg` |
| `neutral_dumbbell_press` | `Dumbbell_Bench_Press_with_Neutral_Grip` | `neutral_dumbbell_press.jpg` · `neutral_dumbbell_press_end.jpg` |
| `neutral_incline_press` | `Hammer_Grip_Incline_DB_Bench_Press` | `neutral_incline_press.jpg` · `neutral_incline_press_end.jpg` |
| `incline_fly` | `Incline_Dumbbell_Flyes` | `incline_fly.jpg` · `incline_fly_end.jpg` |
| `decline_fly` | `Decline_Dumbbell_Flyes` | `decline_fly.jpg` · `decline_fly_end.jpg` |
| `pec_deck` | `Butterfly` | `pec_deck.jpg` · `pec_deck_end.jpg` |
| `smith_bench_press` | `Smith_Machine_Bench_Press` | `smith_bench_press.jpg` · `smith_bench_press_end.jpg` |
| `smith_incline_press` | `Smith_Machine_Incline_Bench_Press` | `smith_incline_press.jpg` · `smith_incline_press_end.jpg` |
| `flat_cable_fly` | `Flat_Bench_Cable_Flyes` | `flat_cable_fly.jpg` · `flat_cable_fly_end.jpg` |
| `single_arm_cable_fly` | `Single-Arm_Cable_Crossover` | `single_arm_cable_fly.jpg` · `single_arm_cable_fly_end.jpg` |
| `incline_push_up` | `Incline_Push-Up` | `incline_push_up.jpg` · `incline_push_up_end.jpg` |
| `decline_push_up` | `Decline_Push-Up` | `decline_push_up.jpg` · `decline_push_up_end.jpg` |
| `wide_push_up` | `Push-Up_Wide` | `wide_push_up.jpg` · `wide_push_up_end.jpg` |
| `dumbbell_pullover` | `Straight-Arm_Dumbbell_Pullover` | `dumbbell_pullover.jpg` · `dumbbell_pullover_end.jpg` |
| `chin_up` | `Chin-Up` | `chin_up.jpg` · `chin_up_end.jpg` |
| `band_assisted_pull_up` | `Band_Assisted_Pull-Up` | `band_assisted_pull_up.jpg` · `band_assisted_pull_up_end.jpg` |
| `neutral_pulldown` | `V-Bar_Pulldown` | `neutral_pulldown.jpg` · `neutral_pulldown_end.jpg` |
| `underhand_pulldown` | `Underhand_Cable_Pulldowns` | `underhand_pulldown.jpg` · `underhand_pulldown_end.jpg` |
| `close_grip_pulldown` | `Close-Grip_Front_Lat_Pulldown` | `close_grip_pulldown.jpg` · `close_grip_pulldown_end.jpg` |
| `t_bar_row` | `T-Bar_Row_with_Handle` | `t_bar_row.jpg` · `t_bar_row_end.jpg` |
| `underhand_barbell_row` | `Reverse_Grip_Bent-Over_Rows` | `underhand_barbell_row.jpg` · `underhand_barbell_row_end.jpg` |
| `two_dumbbell_row` | `Bent_Over_Two-Dumbbell_Row` | `two_dumbbell_row.jpg` · `two_dumbbell_row_end.jpg` |
| `one_arm_cable_row` | `Seated_One-arm_Cable_Pulley_Rows` | `one_arm_cable_row.jpg` · `one_arm_cable_row_end.jpg` |
| `smith_row` | `Smith_Machine_Bent_Over_Row` | `smith_row.jpg` · `smith_row_end.jpg` |
| `suspension_row` | `Suspended_Row` | `suspension_row.jpg` · `suspension_row_end.jpg` |
| `scapular_pull_up` | `Scapular_Pull-Up` | `scapular_pull_up.jpg` · `scapular_pull_up_end.jpg` |
| `back_extension` | `Hyperextensions_Back_Extensions` | `back_extension.jpg` · `back_extension_end.jpg` |
| `superman` | `Superman` | `superman.jpg` · `superman_end.jpg` |
| `dumbbell_shrug` | `Dumbbell_Shrug` | `dumbbell_shrug.jpg` · `dumbbell_shrug_end.jpg` |
| `barbell_shrug` | `Barbell_Shrug` | `barbell_shrug.jpg` · `barbell_shrug_end.jpg` |
| `arnold_press` | `Arnold_Dumbbell_Press` | `arnold_press.jpg` · `arnold_press_end.jpg` |
| `seated_barbell_press` | `Seated_Barbell_Military_Press` | `seated_barbell_press.jpg` · `seated_barbell_press_end.jpg` |
| `standing_dumbbell_press` | `Standing_Dumbbell_Press` | `standing_dumbbell_press.jpg` · `standing_dumbbell_press_end.jpg` |
| `one_arm_shoulder_press` | `Dumbbell_One-Arm_Shoulder_Press` | `one_arm_shoulder_press.jpg` · `one_arm_shoulder_press_end.jpg` |
| `smith_shoulder_press` | `Smith_Machine_Overhead_Shoulder_Press` | `smith_shoulder_press.jpg` · `smith_shoulder_press_end.jpg` |
| `machine_shoulder_press` | `Machine_Shoulder_Military_Press` | `machine_shoulder_press.jpg` · `machine_shoulder_press_end.jpg` |
| `seated_lateral_raise` | `Seated_Side_Lateral_Raise` | `seated_lateral_raise.jpg` · `seated_lateral_raise_end.jpg` |
| `one_arm_lateral_raise` | `One-Arm_Side_Laterals` | `one_arm_lateral_raise.jpg` · `one_arm_lateral_raise_end.jpg` |
| `cable_front_raise` | `Front_Cable_Raise` | `cable_front_raise.jpg` · `cable_front_raise_end.jpg` |
| `plate_front_raise` | `Front_Plate_Raise` | `plate_front_raise.jpg` · `plate_front_raise_end.jpg` |
| `cable_reverse_fly` | `Cable_Rear_Delt_Fly` | `cable_reverse_fly.jpg` · `cable_reverse_fly_end.jpg` |
| `reverse_pec_deck` | `Reverse_Machine_Flyes` | `reverse_pec_deck.jpg` · `reverse_pec_deck_end.jpg` |
| `seated_reverse_fly` | `Seated_Bent-Over_Rear_Delt_Raise` | `seated_reverse_fly.jpg` · `seated_reverse_fly_end.jpg` |
| `cable_external_rotation` | `External_Rotation_with_Cable` | `cable_external_rotation.jpg` · `cable_external_rotation_end.jpg` |
| `cable_internal_rotation` | `Cable_Internal_Rotation` | `cable_internal_rotation.jpg` · `cable_internal_rotation_end.jpg` |
| `band_pull_apart` | `Band_Pull_Apart` | `band_pull_apart.jpg` · `band_pull_apart_end.jpg` |
| `band_external_rotation` | `External_Rotation_with_Band` | `band_external_rotation.jpg` · `band_external_rotation_end.jpg` |
| `push_press` | `Push_Press` | `push_press.jpg` · `push_press_end.jpg` |
| `ez_bar_curl` | `EZ-Bar_Curl` | `ez_bar_curl.jpg` · `ez_bar_curl_end.jpg` |
| `concentration_curl` | `Concentration_Curls` | `concentration_curl.jpg` · `concentration_curl_end.jpg` |
| `cross_body_hammer_curl` | `Cross_Body_Hammer_Curl` | `cross_body_hammer_curl.jpg` · `cross_body_hammer_curl_end.jpg` |
| `reverse_barbell_curl` | `Reverse_Barbell_Curl` | `reverse_barbell_curl.jpg` · `reverse_barbell_curl_end.jpg` |
| `reverse_dumbbell_curl` | `Standing_Dumbbell_Reverse_Curl` | `reverse_dumbbell_curl.jpg` · `reverse_dumbbell_curl_end.jpg` |
| `zottman_curl` | `Zottman_Curl` | `zottman_curl.jpg` · `zottman_curl_end.jpg` |
| `rope_hammer_curl` | `Cable_Hammer_Curls_-_Rope_Attachment` | `rope_hammer_curl.jpg` · `rope_hammer_curl_end.jpg` |
| `high_cable_curl` | `High_Cable_Curls` | `high_cable_curl.jpg` · `high_cable_curl_end.jpg` |
| `cable_preacher_curl` | `Cable_Preacher_Curl` | `cable_preacher_curl.jpg` · `cable_preacher_curl_end.jpg` |
| `preacher_hammer_curl` | `Preacher_Hammer_Dumbbell_Curl` | `preacher_hammer_curl.jpg` · `preacher_hammer_curl_end.jpg` |
| `spider_curl` | `Spider_Curl` | `spider_curl.jpg` · `spider_curl_end.jpg` |
| `seated_dumbbell_curl` | `Seated_Dumbbell_Curl` | `seated_dumbbell_curl.jpg` · `seated_dumbbell_curl_end.jpg` |
| `drag_curl` | `Drag_Curl` | `drag_curl.jpg` · `drag_curl_end.jpg` |
| `rope_triceps_pushdown` | `Triceps_Pushdown_-_Rope_Attachment` | `rope_triceps_pushdown.jpg` · `rope_triceps_pushdown_end.jpg` |
| `reverse_triceps_pushdown` | `Reverse_Grip_Triceps_Pushdown` | `reverse_triceps_pushdown.jpg` · `reverse_triceps_pushdown_end.jpg` |
| `seated_dumbbell_triceps` | `Seated_Triceps_Press` | `seated_dumbbell_triceps.jpg` · `seated_dumbbell_triceps_end.jpg` |
| `dumbbell_triceps_kickback` | `Tricep_Dumbbell_Kickback` | `dumbbell_triceps_kickback.jpg` · `dumbbell_triceps_kickback_end.jpg` |
| `one_arm_overhead_triceps` | `Dumbbell_One-Arm_Triceps_Extension` | `one_arm_overhead_triceps.jpg` · `one_arm_overhead_triceps_end.jpg` |
| `dumbbell_skull_crusher` | `Lying_Dumbbell_Tricep_Extension` | `dumbbell_skull_crusher.jpg` · `dumbbell_skull_crusher_end.jpg` |
| `bench_dip` | `Bench_Dips` | `bench_dip.jpg` · `bench_dip_end.jpg` |
| `triceps_dip` | `Dips_-_Triceps_Version` | `triceps_dip.jpg` · `triceps_dip_end.jpg` |
| `machine_triceps_extension` | `Machine_Triceps_Extension` | `machine_triceps_extension.jpg` · `machine_triceps_extension_end.jpg` |
| `close_grip_push_up` | `Push-Ups_-_Close_Triceps_Position` | `close_grip_push_up.jpg` · `close_grip_push_up_end.jpg` |
| `barbell_wrist_curl` | `Palms-Up_Barbell_Wrist_Curl_Over_A_Bench` | `barbell_wrist_curl.jpg` · `barbell_wrist_curl_end.jpg` |
| `reverse_wrist_curl` | `Palms-Down_Wrist_Curl_Over_A_Bench` | `reverse_wrist_curl.jpg` · `reverse_wrist_curl_end.jpg` |
| `farmer_carry` | `Farmers_Walk` | `farmer_carry.jpg` · `farmer_carry_end.jpg` |
| `hack_squat` | `Hack_Squat` | `hack_squat.jpg` · `hack_squat_end.jpg` |
| `smith_squat` | `Smith_Machine_Squat` | `smith_squat.jpg` · `smith_squat_end.jpg` |
| `bodyweight_squat` | `Bodyweight_Squat` | `bodyweight_squat.jpg` · `bodyweight_squat_end.jpg` |
| `dumbbell_squat` | `Dumbbell_Squat` | `dumbbell_squat.jpg` · `dumbbell_squat_end.jpg` |
| `box_squat` | `Box_Squat` | `box_squat.jpg` · `box_squat_end.jpg` |
| `barbell_lunge` | `Barbell_Lunge` | `barbell_lunge.jpg` · `barbell_lunge_end.jpg` |
| `reverse_dumbbell_lunge` | `Dumbbell_Rear_Lunge` | `reverse_dumbbell_lunge.jpg` · `reverse_dumbbell_lunge_end.jpg` |
| `walking_barbell_lunge` | `Barbell_Walking_Lunge` | `walking_barbell_lunge.jpg` · `walking_barbell_lunge_end.jpg` |
| `walking_bodyweight_lunge` | `Bodyweight_Walking_Lunge` | `walking_bodyweight_lunge.jpg` · `walking_bodyweight_lunge_end.jpg` |
| `barbell_lateral_lunge` | `Barbell_Side_Split_Squat` | `barbell_lateral_lunge.jpg` · `barbell_lateral_lunge_end.jpg` |
| `single_leg_extension` | `Single-Leg_Leg_Extension` | `single_leg_extension.jpg` · `single_leg_extension_end.jpg` |
| `narrow_leg_press` | `Narrow_Stance_Leg_Press` | `narrow_leg_press.jpg` · `narrow_leg_press_end.jpg` |
| `sumo_deadlift` | `Sumo_Deadlift` | `sumo_deadlift.jpg` · `sumo_deadlift_end.jpg` |
| `trap_bar_deadlift` | `Trap_Bar_Deadlift` | `trap_bar_deadlift.jpg` · `trap_bar_deadlift_end.jpg` |
| `dumbbell_romanian_deadlift` | `Stiff-Legged_Dumbbell_Deadlift` | `dumbbell_romanian_deadlift.jpg` · `dumbbell_romanian_deadlift_end.jpg` |
| `single_leg_kettlebell_deadlift` | `Kettlebell_One-Legged_Deadlift` | `single_leg_kettlebell_deadlift.jpg` · `single_leg_kettlebell_deadlift_end.jpg` |
| `good_morning` | `Good_Morning` | `good_morning.jpg` · `good_morning_end.jpg` |
| `rack_pull` | `Rack_Pulls` | `rack_pull.jpg` · `rack_pull_end.jpg` |
| `glute_ham_raise` | `Glute_Ham_Raise` | `glute_ham_raise.jpg` · `glute_ham_raise_end.jpg` |
| `standing_leg_curl` | `Standing_Leg_Curl` | `standing_leg_curl.jpg` · `standing_leg_curl_end.jpg` |
| `ball_leg_curl` | `Ball_Leg_Curl` | `ball_leg_curl.jpg` · `ball_leg_curl_end.jpg` |
| `sliding_leg_curl` | `Platform_Hamstring_Slides` | `sliding_leg_curl.jpg` · `sliding_leg_curl_end.jpg` |
| `single_leg_glute_bridge` | `Single_Leg_Glute_Bridge` | `single_leg_glute_bridge.jpg` · `single_leg_glute_bridge_end.jpg` |
| `barbell_glute_bridge` | `Barbell_Glute_Bridge` | `barbell_glute_bridge.jpg` · `barbell_glute_bridge_end.jpg` |
| `cable_pull_through` | `Pull_Through` | `cable_pull_through.jpg` · `cable_pull_through_end.jpg` |
| `band_hip_extension` | `Hip_Extension_with_Bands` | `band_hip_extension.jpg` · `band_hip_extension_end.jpg` |
| `quadruped_glute_kickback` | `Glute_Kickback` | `quadruped_glute_kickback.jpg` · `quadruped_glute_kickback_end.jpg` |
| `machine_hip_adduction` | `Thigh_Adductor` | `machine_hip_adduction.jpg` · `machine_hip_adduction_end.jpg` |
| `cable_hip_adduction` | `Cable_Hip_Adduction` | `cable_hip_adduction.jpg` · `cable_hip_adduction_end.jpg` |
| `leg_press_calf_raise` | `Calf_Press_On_The_Leg_Press_Machine` | `leg_press_calf_raise.jpg` · `leg_press_calf_raise_end.jpg` |
| `dumbbell_standing_calf_raise` | `Standing_Dumbbell_Calf_Raise` | `dumbbell_standing_calf_raise.jpg` · `dumbbell_standing_calf_raise_end.jpg` |
| `smith_calf_raise` | `Smith_Machine_Calf_Raise` | `smith_calf_raise.jpg` · `smith_calf_raise_end.jpg` |
| `single_leg_seated_calf_raise` | `Dumbbell_Seated_One-Leg_Calf_Raise` | `single_leg_seated_calf_raise.jpg` · `single_leg_seated_calf_raise_end.jpg` |
| `ab_wheel_rollout` | `Ab_Roller` | `ab_wheel_rollout.jpg` · `ab_wheel_rollout_end.jpg` |
| `machine_crunch` | `Ab_Crunch_Machine` | `machine_crunch.jpg` · `machine_crunch_end.jpg` |
| `reverse_crunch` | `Reverse_Crunch` | `reverse_crunch.jpg` · `reverse_crunch_end.jpg` |
| `hanging_leg_raise` | `Hanging_Leg_Raise` | `hanging_leg_raise.jpg` · `hanging_leg_raise_end.jpg` |
| `lying_leg_raise` | `Flat_Bench_Lying_Leg_Raise` | `lying_leg_raise.jpg` · `lying_leg_raise_end.jpg` |
| `bicycle_crunch` | `Air_Bike` | `bicycle_crunch.jpg` · `bicycle_crunch_end.jpg` |
| `heel_touches` | `Alternate_Heel_Touchers` | `heel_touches.jpg` · `heel_touches_end.jpg` |
| `decline_crunch` | `Decline_Crunch` | `decline_crunch.jpg` · `decline_crunch_end.jpg` |
| `ball_crunch` | `Exercise_Ball_Crunch` | `ball_crunch.jpg` · `ball_crunch_end.jpg` |
| `cable_woodchop` | `Standing_Cable_Wood_Chop` | `cable_woodchop.jpg` · `cable_woodchop_end.jpg` |
| `dumbbell_side_bend` | `Dumbbell_Side_Bend` | `dumbbell_side_bend.jpg` · `dumbbell_side_bend_end.jpg` |
| `side_jackknife` | `Side_Jackknife` | `side_jackknife.jpg` · `side_jackknife_end.jpg` |
| `toe_touch_crunch` | `Toe_Touchers` | `toe_touch_crunch.jpg` · `toe_touch_crunch_end.jpg` |
| `cocoon_crunch` | `Cocoons` | `cocoon_crunch.jpg` · `cocoon_crunch_end.jpg` |
| `flutter_kicks` | `Scissor_Kick` | `flutter_kicks.jpg` · `flutter_kicks_end.jpg` |
| `sit_up` | `Sit-Up` | `sit_up.jpg` · `sit_up_end.jpg` |
| `suspension_knee_tuck` | `Suspended_Reverse_Crunch` | `suspension_knee_tuck.jpg` · `suspension_knee_tuck_end.jpg` |
| `recumbent_bike` | `Recumbent_Bike` | `recumbent_bike.jpg` · `recumbent_bike_end.jpg` |
| `stair_climber` | `Stairmaster` | `stair_climber.jpg` · `stair_climber_end.jpg` |
| `outdoor_cycling` | `Bicycling` | `outdoor_cycling.jpg` · `outdoor_cycling_end.jpg` |
| `incline_treadmill_walk` | `Walking_Treadmill` | `incline_treadmill_walk.jpg` · `incline_treadmill_walk_end.jpg` |
| `battle_ropes` | `Battling_Ropes` | `battle_ropes.jpg` · `battle_ropes_end.jpg` |
| `sled_push` | `Sled_Push` | `sled_push.jpg` · `sled_push_end.jpg` |
| `box_jump` | `Front_Box_Jump` | `box_jump.jpg` · `box_jump_end.jpg` |
| `jump_squat` | `Freehand_Jump_Squat` | `jump_squat.jpg` · `jump_squat_end.jpg` |
| `plyometric_push_up` | `Plyo_Push-up` | `plyometric_push_up.jpg` · `plyometric_push_up_end.jpg` |
| `split_jump` | `Split_Jump` | `split_jump.jpg` · `split_jump_end.jpg` |
| `kettlebell_thruster` | `Kettlebell_Thruster` | `kettlebell_thruster.jpg` · `kettlebell_thruster_end.jpg` |
| `kettlebell_row` | `One-Arm_Kettlebell_Row` | `kettlebell_row.jpg` · `kettlebell_row_end.jpg` |
| `kettlebell_floor_press` | `One-Arm_Kettlebell_Floor_Press` | `kettlebell_floor_press.jpg` · `kettlebell_floor_press_end.jpg` |
| `kettlebell_figure_eight` | `Kettlebell_Figure_8` | `kettlebell_figure_eight.jpg` · `kettlebell_figure_eight_end.jpg` |
| `hamstring_stretch` | `Hamstring_Stretch` | `hamstring_stretch.jpg` · `hamstring_stretch_end.jpg` |
| `quad_stretch` | `Quad_Stretch` | `quad_stretch.jpg` · `quad_stretch_end.jpg` |
| `hip_flexor_stretch` | `Kneeling_Hip_Flexor` | `hip_flexor_stretch.jpg` · `hip_flexor_stretch_end.jpg` |
| `child_pose` | `Childs_Pose` | `child_pose.jpg` · `child_pose_end.jpg` |
| `cat_stretch` | `Cat_Stretch` | `cat_stretch.jpg` · `cat_stretch_end.jpg` |
| `calf_stretch` | `Calf_Stretch_Hands_Against_Wall` | `calf_stretch.jpg` · `calf_stretch_end.jpg` |
| `shoulder_stretch` | `Shoulder_Stretch` | `shoulder_stretch.jpg` · `shoulder_stretch_end.jpg` |
| `triceps_stretch` | `Triceps_Stretch` | `triceps_stretch.jpg` · `triceps_stretch_end.jpg` |
| `chest_stretch` | `Chest_And_Front_Of_Shoulder_Stretch` | `chest_stretch.jpg` · `chest_stretch_end.jpg` |
| `hamstring_90_90` | `90_90_Hamstring` | `hamstring_90_90.jpg` · `hamstring_90_90_end.jpg` |
| `ankle_circles` | `Ankle_Circles` | `ankle_circles.jpg` · `ankle_circles_end.jpg` |
| `arm_circles` | `Arm_Circles` | `arm_circles.jpg` · `arm_circles_end.jpg` |

## Upstream license (verbatim)

```text
This is free and unencumbered software released into the public domain.

Anyone is free to copy, modify, publish, use, compile, sell, or
distribute this software, either in source code form or as a compiled
binary, for any purpose, commercial or non-commercial, and by any
means.

In jurisdictions that recognize copyright laws, the author or authors
of this software dedicate any and all copyright interest in the
software to the public domain. We make this dedication for the benefit
of the public at large and to the detriment of our heirs and
successors. We intend this dedication to be an overt act of
relinquishment in perpetuity of all present and future rights to this
software under copyright law.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

For more information, please refer to <https://unlicense.org>
```
