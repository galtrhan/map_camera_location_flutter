#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PUBSPEC="$PROJECT_DIR/pubspec.yaml"

if [ ! -f "$PUBSPEC" ]; then
  echo "pubspec.yaml not found at $PUBSPEC"
  exit 1
fi

CURRENT=$(grep '^version:' "$PUBSPEC" | head -1 | sed 's/^version:[[:space:]]*//')
if [ -z "$CURRENT" ]; then
  echo "Could not find version: line in pubspec.yaml"
  exit 1
fi

# Package version is X.Y.Z or X.Y.Z+N
if [[ "$CURRENT" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)(\+([0-9]+))?$ ]]; then
  major="${BASH_REMATCH[1]}"
  minor="${BASH_REMATCH[2]}"
  patch="${BASH_REMATCH[3]}"
  build="${BASH_REMATCH[5]:-}"
else
  echo "Unsupported version format: $CURRENT (expected X.Y.Z or X.Y.Z+N)"
  exit 1
fi

patch=$((patch + 1))
if [ -n "$build" ]; then
  build=$((build + 1))
  NEW_VERSION="${major}.${minor}.${patch}+${build}"
else
  NEW_VERSION="${major}.${minor}.${patch}"
fi

sed -i "s/^version: .*/version: ${NEW_VERSION}/" "$PUBSPEC"

echo "Version bumped: ${CURRENT} -> ${NEW_VERSION}"
