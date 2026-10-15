#!/usr/bin/env python3
"""Convert downloaded public Firebase client configuration to Dart defines.

Never accepts service account files; only writes an ignored local client file.
"""
import argparse
import json
import plistlib
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--android', type=Path, help='google-services.json')
parser.add_argument('--ios', type=Path, help='GoogleService-Info.plist')
parser.add_argument('--web', type=Path, help='JSON Firebase web config object')
args = parser.parse_args()
if not any((args.android, args.ios, args.web)):
    parser.error('Furnizează cel puțin --android, --ios sau --web.')
output = Path(__file__).resolve().parent.parent / 'firebase/client-config.local.json'
config = json.loads(output.read_text()) if output.exists() else {'AI_COACH_URL': ''}


def project(project_id, sender):
    existing = config.get('FIREBASE_PROJECT_ID')
    if existing and existing != project_id:
        raise ValueError('Configurațiile trebuie să aparțină aceluiași proiect Firebase.')
    if project_id != 'pi-fit-663f2':
        raise ValueError('Proiectul așteptat este pi-fit-663f2. Verifică fișierul selectat.')
    config.update(FIREBASE_PROJECT_ID=project_id, FIREBASE_MESSAGING_SENDER_ID=str(sender))


if args.android:
    data = json.loads(args.android.read_text())
    if 'private_key' in data or 'client_email' in data:
        raise ValueError('Nu folosi un service account. Este necesar google-services.json public al aplicației Android.')
    project(data['project_info']['project_id'], data['project_info']['project_number'])
    clients = [client for client in data['client'] if client['client_info'].get('android_client_info', {}).get('package_name') == 'com.pifit.app']
    if len(clients) != 1:
        raise ValueError('Nu există o configurație Android unică pentru com.pifit.app.')
    client = clients[0]
    config['FIREBASE_ANDROID_APP_ID'] = client['client_info']['mobilesdk_app_id']
    config['FIREBASE_ANDROID_API_KEY'] = client['api_key'][0]['current_key']
if args.ios:
    with args.ios.open('rb') as source:
        data = plistlib.load(source)
    if data['BUNDLE_ID'] != 'com.pifit.app':
        raise ValueError('Bundle ID trebuie să fie com.pifit.app.')
    project(data['PROJECT_ID'], data['GCM_SENDER_ID'])
    config.update(FIREBASE_IOS_APP_ID=data['GOOGLE_APP_ID'], FIREBASE_IOS_API_KEY=data['API_KEY'], FIREBASE_IOS_BUNDLE_ID=data['BUNDLE_ID'])
if args.web:
    data = json.loads(args.web.read_text())
    if 'private_key' in data or 'client_email' in data:
        raise ValueError('Fișierul trebuie să conțină configurația publică web, fără chei private.')
    project(data['projectId'], data['messagingSenderId'])
    config.update(FIREBASE_WEB_APP_ID=data['appId'], FIREBASE_WEB_API_KEY=data['apiKey'], FIREBASE_AUTH_DOMAIN=data.get('authDomain', 'pi-fit-663f2.firebaseapp.com'))
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text(json.dumps(config, indent=2) + '\n')
print('Configurația publică de client a fost salvată în firebase/client-config.local.json (ignorat de Git).')
