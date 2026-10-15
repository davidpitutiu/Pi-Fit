#!/usr/bin/env python3
"""Generate the complete English catalog from the pinned, checksummed snapshot.
Stable legacy IDs and Romanian search aliases are preserved. Exercise icons
are rendered locally; this importer never downloads exercise photographs.
"""
from pathlib import Path
import argparse, hashlib, json, re
root = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--source', type=Path)
parser.add_argument('--revision')
parser.add_argument('--check', action='store_true')
args = parser.parse_args()
snapshot_path = root/'assets/exercise-data/catalog.json'
snapshot = json.loads(snapshot_path.read_text())
if args.source:
    if not args.revision or not re.fullmatch(r'[0-9a-f]{40}', args.revision):
        parser.error('--source requires --revision with an exact Git commit')
    records = json.loads(args.source.read_text()); revision = args.revision
else:
    records = snapshot['exercises']; revision = snapshot['source']['revision']
    digest = hashlib.sha256(json.dumps(records,ensure_ascii=False,sort_keys=True,separators=(',',':')).encode()).hexdigest()
    if digest != snapshot['source']['canonicalSha256']: raise SystemExit('Snapshot checksum mismatch')
assert len({item['id'] for item in records}) == len(records)
legacy = json.loads((root/'assets/exercise-data/legacy-ids.json').read_text())
by_source = {item['id']:item for item in records}
assert all(not item['sourceId'] or item['sourceId'] in by_source for item in legacy)
used = {item['sourceId'] for item in legacy}
ordered = [(item,by_source.get(item['sourceId'])) for item in legacy]
ordered += [({'id':'db_'+re.sub('[^a-z0-9]+','_',item['id'].lower()).strip('_'),'name':item['name']},item) for item in records if item['id'] not in used]
muscles={'abdominals':'Abs','abductors':'Glutes','adductors':'Adductors','biceps':'Biceps','calves':'Calves','chest':'Chest','forearms':'Forearms','glutes':'Glutes','hamstrings':'Hamstrings','lats':'Back','lower back':'Back','middle back':'Back','neck':'Neck','quadriceps':'Quadriceps','shoulders':'Shoulders','traps':'Back','triceps':'Triceps'}
equipment={'body only':'Bodyweight','barbell':'Barbell','dumbbell':'Dumbbells','cable':'Cable','machine':'Machine','e-z curl bar':'EZ bar','kettlebells':'Kettlebell','bands':'Resistance band','exercise ball':'Stability ball','medicine ball':'Medicine ball','other':'Special equipment','foam roll':'Foam roller',None:'Bodyweight'}
categories={'strength':'Strength','powerlifting':'Strength','olympic weightlifting':'Strength','strongman':'Strength','cardio':'Cardio','stretching':'Mobility','plyometrics':'Plyometrics'}
levels={'beginner':'Beginner','intermediate':'Intermediate','expert':'Advanced'}
notes={
'Iron_Cross':['Stand with a stable stance and hold light dumbbells in front with a soft bend in your elbows.','Lower into a controlled squat while keeping the weights in front of you.','Stand up, open your arms to a comfortable height, then return slowly.'],
'One-Arm_Kettlebell_Swings':['Hold the kettlebell in one hand and hinge at your hips with a stable back.','Drive through your hips to swing the bell forward; guide it with your arm rather than pulling.','Let the bell return between your legs and absorb the movement through your hips. Stop safely before changing hands.']}
notes.update({
'Push_Press':['Start with the bar supported at your shoulders, feet stable and core braced.','Dip slightly through your knees, then drive upward through your legs and press overhead.','Finish with the bar balanced overhead and lower it under control to your shoulders.'],
'Side_Bridge':['Lie on your side with your elbow under your shoulder and legs comfortably extended.','Lift your hips until your trunk is aligned, keeping your neck neutral.','Hold with steady breathing, lower with control and repeat on the other side.'],
'Side_Jackknife':['Lie on your side with your legs extended and your lower arm supporting balance.','Lift your legs and upper torso toward each other with controlled side-body contraction.','Lower slowly without pulling your neck and repeat on the other side.']})
custom={
'bird_dog':{'name':'Bird Dog','muscle':'Abs','equipment':'Bodyweight','movement':'Stabilization','steps':['Begin on your hands and knees with a neutral back.','Extend your opposite arm and leg while keeping your hips level.','Return with control and alternate sides.']},
'kettlebell_swing':{'name':'Two-Hand Kettlebell Swing','muscle':'Glutes','equipment':'Kettlebell','movement':'Hip hinge','steps':['Stand with feet slightly wider than hip width and hold the bell with both hands.','Hinge back, then drive through your hips to swing the bell forward.','Let the bell return between your legs while keeping your back stable.']}}
def q(text):return "'"+text.replace('\\','\\\\').replace("'","\\'").replace('$','\\$').replace('\n','\\n').replace('\r','\\r')+"'"
def dart(value):return '['+', '.join(q(x) for x in value)+']' if isinstance(value,list) else q(value)
def movement(item,category):
    low=item['id'].lower()
    if category=='Mobility':return 'Mobility'
    if category=='Cardio':return 'Locomotion'
    if category=='Plyometrics':return 'Explosive'
    if any(x in low for x in ['squat','lunge','step_up','leg_press']):return 'Squat'
    if any(x in low for x in ['deadlift','good_morning','thrust','bridge','pull_through','swing','glute_kickback']):return 'Hip hinge'
    if item.get('force')=='push':return 'Push'
    if item.get('force')=='pull':return 'Pull'
    return 'Stabilization' if 'abdominals' in item['primaryMuscles'] else 'Isolation'
blocks=[]
for old,item in ordered:
    if item:
        category=categories[item['category']]; muscle='Cardio' if category=='Cardio' else muscles[item['primaryMuscles'][0]]
        steps=[x for x in item['instructions'] if x.strip()] or notes[item['id']]
        body={'id':old['id'],'sourceId':item['id'],'name':item['name'],'muscle':muscle,'equipment':'Smith machine' if item['id'].startswith('Smith_') else equipment[item.get('equipment')], 'secondaryMuscles':', '.join(dict.fromkeys(muscles[x] for x in item['secondaryMuscles'] if muscles[x]!=muscle)), 'description':f"{item['name']} targets {muscle.lower()}. Follow the movement instructions and use a controlled range of motion.", 'instructionLanguage':'en','difficulty':levels[item['level']],'category':category,'movement':movement(item,category),'sourceName':'Free Exercise DB · '+item['name'],'aliases':list(dict.fromkeys([old['name'],item['name'],item['id'].replace('_',' ')])),'steps':steps,'tips':['Use a comfortable range of motion and a load you can control.','Stop if the movement causes pain; ask a qualified trainer when learning a new technique.']}
    else:
        data=custom.get(old['id'])
        if data is None: raise SystemExit('Custom movement needs English instructions: '+old['id'])
        body={'id':old['id'],'name':data['name'],'muscle':data['muscle'],'equipment':data['equipment'],'description':data['name']+': use a controlled, comfortable range of motion.','instructionLanguage':'en','difficulty':'Beginner','category':'Strength','movement':data['movement'],'sourceName':'Pi Fit original movement notes','aliases':[old['name'],data['name']],'steps':data['steps'],'tips':['Keep your movement controlled.','Use the illustration as an overview and follow the written instructions.']}
    blocks.append('  Exercise(\n'+'\n'.join('    '+key+': '+dart(value)+',' for key,value in body.items())+'\n  ),')
assert len({row[0]['id'] for row in ordered}) == len(ordered)
content="import 'models.dart';\n\n/// English catalog with stable legacy IDs. Source revision: "+revision+".\n/// The Unlicense; see docs/exercise-sources.md. Exercise visuals use Material icons.\nconst List<Exercise> externalExerciseCatalog = [\n"+'\n'.join(blocks)+'\n];\n'
path=root/'lib/domain/external_exercise_catalog.dart'
if args.check:
    def tokens(text):
        items=re.findall(r"'(?:\\.|[^'\\])*'|\S",text)
        return [v for i,v in enumerate(items) if not(v==',' and i+1<len(items) and items[i+1] in [']',')'])]
    if tokens(path.read_text()) != tokens(content):raise SystemExit('Generated catalog is stale')
else:path.write_text(content)
if args.source:
    snapshot['source'].update(revision=revision,url=f'https://raw.githubusercontent.com/yuhonas/free-exercise-db/{revision}/dist/exercises.json',sourceSha256=hashlib.sha256(args.source.read_bytes()).hexdigest(),canonicalSha256=hashlib.sha256(json.dumps(records,ensure_ascii=False,sort_keys=True,separators=(',',':')).encode()).hexdigest())
    snapshot['exercises']=records
    if not args.check:snapshot_path.write_text(json.dumps(snapshot,ensure_ascii=False,indent=2)+'\n')
print(f'{len(records)} source records; {len(ordered)} English movements; legacy IDs preserved.')
