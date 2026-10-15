#!/usr/bin/env bash
# Repeatable Linux cloud setup; repositories remain in their existing checkout.
set -euo pipefail
task_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ ! -x /workspace/flutter-sdk/bin/flutter ]]; then
  git clone --depth 1 --branch 3.47.7 https://github.com/flutter/flutter.git /workspace/flutter-sdk
fi
task_flutter_commit="$(git -C /workspace/flutter-sdk rev-parse HEAD)"
if [[ "$task_flutter_commit" != abaf9c523780a608bd46686fd5e53740a07077f8 ]]; then
  echo 'Flutter SDK does not match pinned 3.47.7. Keep existing work; resolve the SDK path before setup.' >&2
  exit 1
fi
cd "$task_root"
./scripts/flutterw pub get --enforce-lockfile
bash scripts/setup_node.sh
export PATH=/workspace/node22/bin:$PATH
(
  cd firebase/functions
  npm ci --cache /workspace/.npm-cache --no-audit --no-fund
)
bash scripts/setup_android.sh
