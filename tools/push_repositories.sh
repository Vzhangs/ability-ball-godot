#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
branch="$(git symbolic-ref --quiet --short HEAD)"
for remote in origin github; do
  git remote get-url "$remote" >/dev/null
  git push "$remote" "$branch"
done
