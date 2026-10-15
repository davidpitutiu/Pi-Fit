# Exercise catalog and icons

Pi Fit includes all **876 records** from the open [Free Exercise DB](https://github.com/yuhonas/free-exercise-db), pinned at commit `f00c92c7dcf1216a928a52c3706c7ce8e2f71ed5`, plus original Bird Dog and Two-Hand Kettlebell Swing entries. The upstream database is distributed under the **Unlicense**; its snapshot/provenance are retained in `assets/exercise-data/catalog.json`.

The app displays English names, metadata and instructions. Original English source instructions are preserved verbatim when available. Five source records have no instructions (Iron Cross, One-Arm Kettlebell Swings, Push Press, Side Bridge and Side Jackknife); these receive original Pi Fit notes, as do the two original entries. Difficulty is the catalog's training level, distinct from a user's subjective 1–10 effort rating.

`assets/exercise-data/legacy-ids.json` preserves all 216 curated identifiers and their old search names. Existing workout histories, favorites and routine references keep working. Imported IDs remain deterministic. Romanian names remain search aliases, while the interface/catalog display English. No historical user text is machine-translated or replaced.

## Rendering

Exercises, routine cards, workout headers and details use a consistent Material icon system (`lib/ui/exercise_icon.dart` and `exercise_image.dart`). Icons are selected from the actual exercise's equipment and training category, including free weights, cable, machine, bodyweight, core, mobility and cardio. They follow the light/dark/lime theme and use Flutter's bundled Material Icons font. The icon glyphs are provided by the Flutter SDK under its included licenses.

Icons identify the exercise category; they do not demonstrate technique or show start/finish poses. The exercise-specific written instructions remain available in details. Several related exercises intentionally share one recognizable icon. No photos, human anatomy drawings, motion illustrations or remote images are rendered.

The previous JPEGs, network-photo renderer and anatomy-illustration renderer have been removed. No Free Exercise DB photos or Hevy images are shipped. Exercise data is from the open source above; Pi Fit does not assert knowledge of Hevy's internal database.

## Reproduce or update

```sh
python3 scripts/import_exercise_catalog.py --check
python3 scripts/import_exercise_catalog.py
# After downloading a new, explicitly selected upstream snapshot:
python3 scripts/import_exercise_catalog.py --source /path/exercises.json --revision EXACT_40_CHARACTER_GIT_COMMIT
```

The importer verifies the pinned snapshot checksum, rejects duplicate or missing legacy source IDs and preserves existing user-facing IDs. Update `legacy-ids.json` only deliberately: changing IDs can orphan references in stored journals. No API key is required, and import never downloads photographs.
