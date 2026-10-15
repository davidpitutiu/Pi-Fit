# Exercise catalog and vector illustrations

Pi Fit includes all **876 records** from the open [Free Exercise DB](https://github.com/yuhonas/free-exercise-db), pinned at commit `f00c92c7dcf1216a928a52c3706c7ce8e2f71ed5`, plus original Bird Dog and Two-Hand Kettlebell Swing entries. The upstream database is distributed under the **Unlicense**; its snapshot/provenance are retained in `assets/exercise-data/catalog.json`.

The app displays English names, metadata and instructions. Original English source instructions are preserved verbatim when available. Five source records have no instructions (Iron Cross, One-Arm Kettlebell Swings, Push Press, Side Bridge and Side Jackknife); these receive original Pi Fit notes, as do the two original entries. Difficulty is the catalog's training level, distinct from a user's subjective 1–10 effort rating.

`assets/exercise-data/legacy-ids.json` preserves all 216 curated identifiers and their old search names. Existing workout histories, favorites and routine references keep working. Imported IDs remain deterministic. Romanian names remain search aliases, while the interface/catalog display English. No historical user text is machine-translated or replaced.

## Rendering

Exercise pictures are original Flutter vector drawings (`lib/ui/exercise_illustration.dart`) across 23 movement families, selected from the actual exercise's name, movement, equipment and muscle metadata. They scale without raster downloads and follow the light/dark/lime theme. Supported families have two positions; held movements have one. The pictures are movement-family overviews, not 878 individually verified anatomical animations. The detail screen says to follow the exercise-specific written instructions.

The previous bundled JPEGs and network photo renderer have been removed. No Free Exercise DB photos or Hevy images are shipped. Exercise data is from the open source above; Pi Fit does not assert knowledge of Hevy's internal database.

## Reproduce or update

```sh
python3 scripts/import_exercise_catalog.py --check
python3 scripts/import_exercise_catalog.py
# After downloading a new, explicitly selected upstream snapshot:
python3 scripts/import_exercise_catalog.py --source /path/exercises.json --revision EXACT_40_CHARACTER_GIT_COMMIT
```

The importer verifies the pinned snapshot checksum, rejects duplicate or missing legacy source IDs and preserves existing user-facing IDs. Update `legacy-ids.json` only deliberately: changing IDs can orphan references in stored journals. No API key is required, and import never downloads photographs.
