#!/usr/bin/env bash
# Installs the Android toolchain used by Flutter 3.47.7 from Google's official repository.
set -euo pipefail
if [[ "$(uname -s)" != Linux || "$(uname -m)" != x86_64 ]]; then
  echo 'This cloud setup script targets Linux x86_64. Install the Android SDK for your host platform.' >&2
  exit 1
fi
export ANDROID_HOME="${ANDROID_HOME:-/workspace/android-sdk}"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export ANDROID_USER_HOME="${ANDROID_USER_HOME:-/workspace/.android}"
export GRADLE_USER_HOME="${GRADLE_USER_HOME:-/workspace/.gradle}"
mkdir -p "$ANDROID_HOME" "$ANDROID_USER_HOME" "$GRADLE_USER_HOME"
task_android_tmp="$(mktemp -d /tmp/pi-fit-android.XXXXXX)"
trap 'rm -rf "$task_android_tmp"' EXIT
task_managed_jdk="${PI_FIT_JDK_HOME:-/workspace/jdk21}"

# The base image can contain a JRE without javac. Install a complete,
# checksum-verified Eclipse Temurin JDK only when no compiler is available.
if [[ -z "${JAVA_HOME:-}" && -x "$task_managed_jdk/bin/javac" ]]; then
  export JAVA_HOME="$task_managed_jdk"
fi
if [[ ! -x "${JAVA_HOME:-/nonexistent}/bin/javac" ]] && ! command -v javac >/dev/null 2>&1; then
  export JAVA_HOME="$task_managed_jdk"
  task_jdk_release='https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.12.1%2B1/OpenJDK21U-jdk_x64_linux_hotspot_21.0.12.1_1.tar.gz'
  curl --fail --location --retry 2 --silent --show-error \
    --output "$task_android_tmp/jdk.tar.gz" "$task_jdk_release"
  curl --fail --location --retry 2 --silent --show-error \
    --output "$task_android_tmp/jdk.sha256" "$task_jdk_release.sha256.txt"
  python3 - "$task_android_tmp" "$JAVA_HOME" <<'PY'
from pathlib import Path
import hashlib
import sys
import tarfile

cache, destination = map(Path, sys.argv[1:])
payload = cache / 'jdk.tar.gz'
expected = (cache / 'jdk.sha256').read_text().split()[0]
assert hashlib.sha256(payload.read_bytes()).hexdigest() == expected, 'Official JDK SHA256 mismatch'
destination.mkdir(parents=True, exist_ok=True)
with tarfile.open(payload) as source:
    for item in source.getmembers():
        path = Path(item.name)
        assert not path.is_absolute() and '..' not in path.parts
        relative = Path(*path.parts[1:])
        if not relative.parts:
            continue
        item.name = str(relative)
        source.extract(item, destination, filter='data')
print('Official Eclipse Temurin JDK verified against its published SHA256.')
PY
fi
if [[ -n "${JAVA_HOME:-}" ]]; then
  export PATH="$JAVA_HOME/bin:$PATH"
  if [[ "$JAVA_HOME" == "$task_managed_jdk" && -f "${CODEX_PROXY_CERT:-/nonexistent}" && -f "$JAVA_HOME/lib/security/cacerts" ]]; then
    if ! "$JAVA_HOME/bin/keytool" -list -cacerts -storepass changeit \
      -alias pifit-cloud-network >/dev/null 2>&1; then
      "$JAVA_HOME/bin/keytool" -importcert -noprompt -trustcacerts -cacerts \
        -alias pifit-cloud-network -file "$CODEX_PROXY_CERT" -storepass changeit
    fi
  fi
fi

# Java does not inherit HTTP(S)_PROXY. Reuse an unauthenticated cloud proxy
# through the local Gradle user configuration without saving credentials.
python3 - <<'PY'
from pathlib import Path
import os
from urllib.parse import urlsplit

path = Path(os.environ['GRADLE_USER_HOME']) / 'gradle.properties'
existing = path.read_text() if path.exists() else ''
keys = {line.split('=', 1)[0] for line in existing.splitlines() if '=' in line}
additions = []
for scheme, variable in [('https', 'HTTPS_PROXY'), ('http', 'HTTP_PROXY')]:
    if not os.environ.get(variable):
        continue
    proxy = urlsplit(os.environ[variable])
    if proxy.username or proxy.password:
        print('Authenticated proxy detected; provide Java proxy credentials through secure local configuration.')
        continue
    if proxy.hostname:
        additions.extend([
            f'systemProp.{scheme}.proxyHost={proxy.hostname}',
            f'systemProp.{scheme}.proxyPort={proxy.port or 80}',
        ])
if additions:
    additions.append('systemProp.http.nonProxyHosts=localhost|127.*|[::1]')
    missing = [line for line in additions if line.split('=', 1)[0] not in keys]
    if missing:
        path.write_text(existing + '\n# Cloud network proxy for Java/Gradle.\n' + '\n'.join(missing) + '\n')
PY

if ! command -v javac >/dev/null 2>&1; then
  echo 'A complete Java 17 or newer JDK is required before Android setup.' >&2
  exit 1
fi

if [[ ! -x "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" ]]; then
  curl --fail --location --retry 2 --silent --show-error \
    --output "$task_android_tmp/repository.xml" \
    https://dl.google.com/android/repository/repository2-3.xml
  curl --fail --location --retry 2 --silent --show-error \
    --output "$task_android_tmp/tools.zip" \
    https://dl.google.com/android/repository/commandlinetools-linux-16111833_latest.zip
  python3 - "$task_android_tmp" "$ANDROID_HOME" <<'PY'
from pathlib import Path
import hashlib
import sys
import xml.etree.ElementTree as ET
import zipfile

cache, sdk = map(Path, sys.argv[1:])
repository = ET.parse(cache / 'repository.xml').getroot()
package = next(
    item for item in repository
    if item.tag.endswith('remotePackage') and item.get('path') == 'cmdline-tools;23.0'
)
archive = next(
    item for item in package.find('archives') if item.findtext('host-os') == 'linux'
).find('complete')
assert archive.findtext('url') == 'commandlinetools-linux-16111833_latest.zip'
payload = (cache / 'tools.zip').read_bytes()
assert len(payload) == int(archive.findtext('size')), 'Android tools size verification failed'
checksum = archive.find('checksum')
algorithm = checksum.get('type')
assert algorithm in ('sha1', 'sha256', 'sha512'), 'Unsupported repository checksum'
assert hashlib.new(algorithm, payload).hexdigest() == checksum.text.strip(), 'Android tools checksum failed'
target = sdk / 'cmdline-tools/latest'
with zipfile.ZipFile(cache / 'tools.zip') as source:
    for item in source.infolist():
        path = Path(item.filename)
        assert path.parts[0] == 'cmdline-tools' and '..' not in path.parts
        destination = target.joinpath(*path.parts[1:])
        if item.is_dir():
            destination.mkdir(parents=True, exist_ok=True)
            continue
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(source.read(item))
        permissions = item.external_attr >> 16
        if permissions:
            destination.chmod(permissions)
print('Android command-line tools verified against the official repository checksum.')
PY
fi

# Command-line Tools 23 accepts SDK licenses during package installation.
# The sdkmanager compatibility entry point delegates to the supported Android CLI.
"$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" \
  --sdk_root="$ANDROID_HOME" \
  'platform-tools' 'platforms;android-34' 'platforms;android-35' 'platforms;android-36' \
  'build-tools;36.0.0' 'ndk;28.2.13676358'
