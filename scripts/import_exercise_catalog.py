#!/usr/bin/env python3
"""Rebuild the complete external exercise catalog from a pinned public snapshot.

Default operation is offline and preserves all curated Romanian exercise records.
Use --check in CI. To import a newer snapshot, download dist/exercises.json from
an explicitly chosen upstream revision and supply --source FILE --revision SHA.
No API token is required, and the generator never downloads or alters photos.
"""
from pathlib import Path
import argparse
import hashlib
import json
import re
import urllib.parse

root = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--source', type=Path, help='Downloaded Free Exercise DB dist/exercises.json')
parser.add_argument('--revision', help='Exact 40-character upstream Git revision; required with --source')
parser.add_argument('--check', action='store_true', help='Verify generated output without writing files')
args = parser.parse_args()
snapshot_path = root / 'assets/exercise-data/catalog.json'
snapshot = json.loads(snapshot_path.read_text(encoding='utf-8'))
if args.source:
    if not args.revision or not re.fullmatch(r'[0-9a-f]{40}', args.revision):
        parser.error('--source requires --revision with an exact 40-character Git SHA')
    db = json.loads(args.source.read_text(encoding='utf-8'))
    commit = args.revision
else:
    if args.revision:
        parser.error('--revision is only used with --source')
    db = snapshot['exercises']
    commit = snapshot['source']['revision']
    canonical = json.dumps(db, ensure_ascii=False, sort_keys=True, separators=(',', ':')).encode()
    if hashlib.sha256(canonical).hexdigest() != snapshot['source']['canonicalSha256']:
        raise SystemExit('Snapshot checksum mismatch: restore the trusted snapshot before importing.')
assert len({e['id'] for e in db}) == len(db), 'Duplicate upstream source IDs'
source_uri = f'https://raw.githubusercontent.com/yuhonas/free-exercise-db/{commit}/dist/exercises.json'
photo_base = f'https://raw.githubusercontent.com/yuhonas/free-exercise-db/{commit}/exercises/'
existing_sources = {}
for name in ['exercise_catalog.dart', 'exercise_metadata.dart']:
    text = (root / 'lib/domain' / name).read_text(encoding='utf-8')
    for block in re.findall(r'  Exercise\(\n.*?\n  \),', text, re.S):
        uid = re.search(r"id: '([^']+)'", block)
        sid = re.search(r"sourceId: '([^']+)'", block)
        if sid:
            assert sid[1] not in existing_sources, f'Duplicate curated source ID: {sid[1]}'
            existing_sources[sid[1]] = uid[1]
missing_curated = existing_sources.keys() - {e['id'] for e in db}
if missing_curated:
    raise SystemExit(f'New snapshot omits curated source IDs: {sorted(missing_curated)}')

def write_generated(path, content):
    # Dart formatting is a separate, deterministic final step. --check compares
    # semantic generated text with whitespace removed outside quoted literals.
    if args.check:
        def tokens(value):
            raw_tokens = re.findall(r"'(?:\\.|[^'\\])*'|\S", value)
            return [item for i, item in enumerate(raw_tokens) if not (item == ',' and i + 1 < len(raw_tokens) and raw_tokens[i + 1] in [']', ')'])]
        if tokens(path.read_text(encoding='utf-8')) != tokens(content):
            raise SystemExit(f'Generated catalog is stale: {path.relative_to(root)}')
    else:
        path.write_text(content, encoding='utf-8')

muscle_map={'abdominals':'Abdomen','abductors':'Fesieri','adductors':'Adductori','biceps':'Biceps','calves':'Gambe','chest':'Piept','forearms':'Antebrațe','glutes':'Fesieri','hamstrings':'Ischiogambieri','lats':'Spate','lower back':'Spate','middle back':'Spate','neck':'Gât','quadriceps':'Cvadricepși','shoulders':'Umeri','traps':'Spate','triceps':'Triceps'}
equipment_map={'body only':'Greutatea corpului','barbell':'Bară','dumbbell':'Gantere','cable':'Cablu','machine':'Aparat','e-z curl bar':'Bară EZ','kettlebells':'Kettlebell','bands':'Bandă elastică','exercise ball':'Minge fitness','medicine ball':'Minge medicinală','other':'Echipament special','foam roll':'Rolă de masaj',None:'Greutatea corpului'}
level_map={'beginner':'Începător','intermediate':'Intermediar','expert':'Avansat'}
category_map={'strength':'Forță','powerlifting':'Forță','olympic weightlifting':'Forță','strongman':'Forță','cardio':'Cardio','stretching':'Mobilitate','plyometrics':'Pliometrie'}
def q(s):
 # Escape interpolation as well as quotes; external instructions are literal data.
 s=s.replace('\\','\\\\').replace('$','\\$').replace('\r','\\r').replace('\n','\\n')
 return "'"+s.replace("'","\\'")+"'"
def dart(value):
 if isinstance(value,list):return '['+', '.join(q(x) for x in value)+']'
 return q(value)
def movement(e,category):
 low=e['id'].lower()
 if category=='Mobilitate':return 'Mobilitate'
 if category=='Cardio':return 'Locomoție'
 if category=='Pliometrie':return 'Exploziv'
 if any(w in low for w in ['squat','lunge','step_up','leg_press']):return 'Genuflexiune'
 if any(w in low for w in ['deadlift','good_morning','thrust','bridge','pull_through','swing','glute_kickback']):return 'Extensie șold'
 if e.get('force')=='push':return 'Împins'
 if e.get('force')=='pull':return 'Tracțiune'
 if 'abdominals' in e['primaryMuscles']:return 'Stabilizare'
 return 'Izolare'
missing_notes={
 'Iron_Cross':[
 'Stai cu tălpile stabile și ține două gantere ușoare în față, cu brațele aproape întinse.',
 'Coboară într-o genuflexiune controlată păstrând ganterele în fața corpului.',
 'Ridică-te și deschide brațele lateral până la o înălțime confortabilă, apoi revino lent în față.',
 ],
 'One-Arm_Kettlebell_Swings':[
 'Prinde kettlebellul cu o mână, depărtează tălpile și împinge șoldurile înapoi cu spatele stabil.',
 'Din balansul dintre picioare, extinde șoldurile pentru a propulsa greutatea înainte; brațul ghidează, fără să tragă activ.',
 'Lasă greutatea să revină și absoarbe balansul din șolduri, păstrând bazinul drept; oprește în siguranță înainte de a schimba mâna.',
 ],
}
blocks=[];idmap=[]
for e in db:
 if e['id'] in existing_sources:continue
 uid='db_'+re.sub('[^a-z0-9]+','_',e['id'].lower()).strip('_')
 category=category_map[e['category']]
 muscle='Cardio' if category=='Cardio' else muscle_map[e['primaryMuscles'][0]]
 equipment='Smith' if e['id'].startswith('Smith_') else equipment_map[e.get('equipment')]
 images=[photo_base+urllib.parse.quote(x,safe='/') for x in e['images']]
 steps=[s for s in e['instructions'] if s.strip()]
 lang='en'
 tips=['Source: Free Exercise DB. Technique instructions are preserved in their original English.']
 description=f'Exercițiu din baza externă Free Exercise DB. Grupa principală: {muscle.lower()}. Instrucțiunile originale sunt în engleză.'
 if not images:description+=' Sursa nu furnizează imagini pentru această mișcare.'
 if e['id'] in missing_notes:
  steps=missing_notes[e['id']];lang='ro'
  description=f'Exercițiu din Free Exercise DB, cu fotografii originale și note tehnice redactate de Pi Fit. Grupa principală: {muscle.lower()}.'
  tips=['Sursa nu conține pași tehnici pentru această mișcare; pașii de mai sus sunt redactați de Pi Fit.', 'Folosește o greutate mică pentru a învăța controlul și cere ajutorul unui antrenor dacă mișcarea este nouă.']
 assert steps,e['id']
 aliases=list(dict.fromkeys([e['name'],e['id'].replace('_',' '),muscle,equipment]))
 body={'id':uid,'sourceId':e['id'],'name':e['name'],'muscle':muscle,'equipment':equipment,'secondaryMuscles':', '.join(dict.fromkeys(muscle_map[x] for x in e['secondaryMuscles'] if muscle_map[x]!=muscle)),'description':description,'imageUrl':images[0] if images else '', 'secondaryImageUrl':images[1] if len(images)>1 else '', 'instructionLanguage':lang,'difficulty':level_map[e['level']],'category':category,'movement':movement(e,category),'sourceName':'Free Exercise DB · '+e['name'],'aliases':aliases,'steps':steps,'tips':tips}
 blocks.append('  Exercise(\n'+'\n'.join('    '+key+': '+dart(value)+',' for key,value in body.items())+'\n  ),')
 idmap.append((uid,e['id'],len(images),lang))
assert len({row[0] for row in idmap})==len(idmap)
write_generated(root/'lib/domain/external_exercise_catalog.dart',"import 'models.dart';\n\n/// Complete remaining Free Exercise DB snapshot, without duplicating curated IDs.\n/// Source revision: "+commit+". The Unlicense; see docs/exercise-sources.md.\n/// English instructions are preserved verbatim; facets remain Romanian.\nconst List<Exercise> externalExerciseCatalog = [\n"+'\n'.join(blocks)+'\n];\n')

if args.source:
    source_info = {
        'name': 'Free Exercise DB',
        'repository': 'https://github.com/yuhonas/free-exercise-db',
        'revision': commit,
        'url': source_uri,
        'license': 'Unlicense',
        'sourceSha256': hashlib.sha256(args.source.read_bytes()).hexdigest(),
        'canonicalSha256': hashlib.sha256(json.dumps(db, ensure_ascii=False, sort_keys=True, separators=(',', ':')).encode()).hexdigest(),
    }
    write_generated(snapshot_path, json.dumps({'schemaVersion': 1, 'source': source_info, 'exercises': db}, ensure_ascii=False, indent=2) + '\n')
print(f'{len(db)} source records; {len(existing_sources)} curated source IDs; {len(idmap)} imported records.')
print('Generated catalog verified.' if args.check else 'Run dart format lib/domain/external_exercise_catalog.dart, then flutter test test/domain_test.dart.')
