#!/usr/bin/env bash
set -euo pipefail

# The existing Vercel project has web/ as its Root Directory. Build Flutter
# from the repo root; publishing web/ itself would serve only the source shell.
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
version=$(node -p "JSON.parse(require('fs').readFileSync('.fvmrc', 'utf8')).flutter")
scratch=$(mktemp -d)
trap 'rm -rf -- "$scratch"' EXIT

if ! command -v flutter >/dev/null || ! flutter --version | grep -Fq "Flutter $version "; then
  git clone --quiet --depth 1 --branch "$version" https://github.com/flutter/flutter.git "$scratch/flutter"
  export PATH="$scratch/flutter/bin:$PATH"
fi

rm -rf -- web/dist
flutter pub get --enforce-lockfile
flutter build web --release --no-pub --base-href / --output "$scratch/site"
rm -f -- "$scratch/site/vercel.json"
mv -- "$scratch/site" web/dist
