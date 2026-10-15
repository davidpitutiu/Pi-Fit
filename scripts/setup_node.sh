#!/usr/bin/env bash
set -euo pipefail

# Firebase Functions targets Node 22. Keep the cloud runtime outside the checkout.
pi_fit_node_version="22.23.3"
pi_fit_node_target="${PI_FIT_NODE_DIR:-/workspace/node22}"
pi_fit_node_cache="${PI_FIT_NODE_DOWNLOAD_DIR:-/workspace/.cache/pi-fit-node}"

if [[ "$(uname -s)" != "Linux" || "$(uname -m)" != "x86_64" ]]; then
  echo "This cloud helper supports Linux x86_64. Use Node 22 for your platform." >&2
  exit 1
fi

if [[ -x "$pi_fit_node_target/bin/node" ]]; then
  if [[ "$("$pi_fit_node_target/bin/node" --version)" == "v$pi_fit_node_version" ]]; then
    echo "Node v$pi_fit_node_version is ready at $pi_fit_node_target."
    exit 0
  fi
  echo "A different Node version already exists at $pi_fit_node_target; choose PI_FIT_NODE_DIR explicitly." >&2
  exit 1
fi

if [[ -d "$pi_fit_node_target" && -n "$(ls -A "$pi_fit_node_target")" ]]; then
  echo "Refusing to overwrite an existing nonempty directory: $pi_fit_node_target" >&2
  exit 1
fi

mkdir -p "$pi_fit_node_cache" "$pi_fit_node_target"
pi_fit_node_archive="node-v$pi_fit_node_version-linux-x64.tar.xz"
pi_fit_node_url="https://nodejs.org/dist/v$pi_fit_node_version"
curl --fail --silent --show-error --location --proto '=https' --tlsv1.2 \
  "$pi_fit_node_url/SHASUMS256.txt" -o "$pi_fit_node_cache/SHASUMS256.txt"
curl --fail --silent --show-error --location --proto '=https' --tlsv1.2 \
  "$pi_fit_node_url/$pi_fit_node_archive" -o "$pi_fit_node_cache/$pi_fit_node_archive"
pi_fit_node_expected="$(awk -v archive="$pi_fit_node_archive" '$2 == archive {print $1}' "$pi_fit_node_cache/SHASUMS256.txt")"
if [[ ! "$pi_fit_node_expected" =~ ^[0-9a-f]{64}$ ]]; then
  echo "The official checksum list does not contain the expected Node archive." >&2
  exit 1
fi
printf '%s  %s\n' "$pi_fit_node_expected" "$pi_fit_node_cache/$pi_fit_node_archive" | sha256sum --check --status
tar -xJf "$pi_fit_node_cache/$pi_fit_node_archive" --strip-components=1 -C "$pi_fit_node_target"
"$pi_fit_node_target/bin/node" --version
echo "Use PATH=$pi_fit_node_target/bin:\$PATH for backend commands."
