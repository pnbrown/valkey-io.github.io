#!/usr/bin/env bash
# Netlify preview build for the valkey.io site.
#
# Netlify clones only this repo, but the command reference, topics, and clients
# pages are assembled at build time from sibling repos. This script fetches
# those siblings, wires up the build symlinks via the existing init scripts,
# installs the pinned Zola version, and builds the site into public/.
#
# Keep ZOLA_VERSION in lockstep with the version the deploy and preview
# workflows use (currently 0.23.6).
set -euo pipefail

ZOLA_VERSION="0.23.6"

# 1. Fetch the sibling content repos next to this checkout. Netlify builds run
#    in the repo root; clone the siblings one level up so the init scripts'
#    ../<repo> relative paths resolve.
clone_sibling() {
  local repo="$1" dir="../$2"
  if [ ! -d "$dir" ]; then
    git clone --depth 1 "https://github.com/valkey-io/$repo.git" "$dir"
  fi
}
clone_sibling valkey-doc valkey-doc
clone_sibling valkey valkey
clone_sibling valkey-bloom valkey-bloom
clone_sibling valkey-json valkey-json
clone_sibling valkey-search valkey-search

# 2. Assemble the injected content (same steps as the GitHub workflows).
./build/init-topics-and-clients.sh ../valkey-doc/topics ../valkey-doc/clients
./build/init-commands.sh ../valkey-doc/commands \
  ../valkey/src/commands ../valkey-bloom/src/commands \
  ../valkey-json/src/commands ../valkey-search/src/commands

# 3. Install the pinned Zola binary into a local bin on PATH.
mkdir -p "$HOME/bin"
if [ ! -x "$HOME/bin/zola" ]; then
  curl -sSL \
    "https://github.com/getzola/zola/releases/download/v${ZOLA_VERSION}/zola-v${ZOLA_VERSION}-x86_64-unknown-linux-gnu.tar.gz" \
    | tar xz -C "$HOME/bin" zola
fi
export PATH="$HOME/bin:$PATH"
zola --version

# 4. Build. On a deploy preview Netlify sets DEPLOY_PRIME_URL to the unique
#    preview URL; use it as base_url so internal links resolve. Fall back to
#    URL (the site's own URL) for production-context builds.
BASE_URL="${DEPLOY_PRIME_URL:-${URL:-}}"
if [ -n "$BASE_URL" ]; then
  zola build --base-url "$BASE_URL"
else
  zola build
fi
