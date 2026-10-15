"""Offline regression checks for the public Firebase configuration generator."""
import importlib.util
import json
from pathlib import Path
import shutil
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('configure_firebase', REPO / 'scripts/configure_firebase.py')
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)
WEB_APP_ID = '1:942783822335:web:52e8ccf86e545c2ed28fca'


class PublicFirebaseConfigTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='pifit-firebase-test-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for relative in ['android/app/google-services.json', 'ios/Runner/GoogleService-Info.plist']:
            destination = self.root / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(REPO / relative, destination)

    def test_generates_startup_defaults_and_preserves_only_local_ai_endpoint(self):
        local = self.root / 'firebase/client-config.local.json'
        local.parent.mkdir(parents=True)
        local.write_text(json.dumps({'AI_COACH_URL': 'https://coach.example.invalid'}))
        MODULE.configure(self.root, web_app_id=WEB_APP_ID)
        source = (self.root / 'lib/firebase_options.dart').read_text()
        self.assertIn(WEB_APP_ID, source)
        self.assertIn('static const android = FirebaseOptions(', source)
        self.assertIn('static const ios = FirebaseOptions(', source)
        self.assertNotIn('coach.example.invalid', source)
        self.assertEqual(json.loads(local.read_text())['AI_COACH_URL'], 'https://coach.example.invalid')
        self.assertEqual(json.loads((self.root / 'firebase/web-config.json').read_text())['appId'], WEB_APP_ID)

    def test_server_credentials_are_rejected_before_any_generated_file_is_written(self):
        path = self.root / 'android/app/google-services.json'
        data = json.loads(path.read_text())
        data['client'][0]['server_credentials'] = {'private_key': 'not-a-real-key'}
        path.write_text(json.dumps(data))
        with self.assertRaises(ValueError):
            MODULE.configure(self.root, web_app_id=WEB_APP_ID)
        self.assertFalse((self.root / 'lib/firebase_options.dart').exists())
        self.assertFalse((self.root / 'firebase/web-config.json').exists())

    def test_unrelated_project_and_wrong_platform_are_rejected(self):
        path = self.root / 'android/app/google-services.json'
        original = path.read_text()
        data = json.loads(original)
        data['project_info']['project_id'] = 'unrelated-project'
        path.write_text(json.dumps(data))
        with self.assertRaises(ValueError):
            MODULE.configure(self.root, web_app_id=WEB_APP_ID)
        path.write_text(original)
        with self.assertRaises(ValueError):
            MODULE.configure(self.root, web_app_id=WEB_APP_ID.replace(':web:', ':ios:'))
        self.assertFalse((self.root / 'lib/firebase_options.dart').exists())

    def test_an_exported_web_configuration_replaces_the_inferred_public_key(self):
        MODULE.configure(self.root, web_app_id=WEB_APP_ID)
        exported = self.root / 'exported-web.json'
        exported.write_text(json.dumps({
            'apiKey': 'supplied-web-public-key', 'appId': WEB_APP_ID,
            'messagingSenderId': '942783822335', 'projectId': 'pi-fit-663f2',
            'authDomain': 'pi-fit-663f2.firebaseapp.com',
        }))
        MODULE.configure(self.root, web=exported)
        public_web = json.loads((self.root / 'firebase/web-config.json').read_text())
        self.assertEqual(public_web['apiKey'], 'supplied-web-public-key')
        source = (self.root / 'lib/firebase_options.dart').read_text()
        self.assertIn("apiKey: 'supplied-web-public-key'", source)
        self.assertEqual((self.root / 'android/app/google-services.json').read_bytes(),
                         (REPO / 'android/app/google-services.json').read_bytes())


if __name__ == '__main__':
    unittest.main()
