#!/usr/bin/env bash
# scripts/new-client.sh — scaffold a new client site from this template repo.
#
# Requires: gh (authenticated: gh auth login)
#
# Usage:
#   ./scripts/new-client.sh <client-slug> [--template owner/repo] [--org <github-org>]
#
# Example:
#   ./scripts/new-client.sh chen-wedding
#   → creates https://github.com/<you>/gallery-chen-wedding (public, Pages-ready),
#     clones it into ./gallery-chen-wedding and prints next steps.
#
# Notes:
#   - The repo must be PUBLIC: free GitHub accounts only serve Pages from
#     public repos. Privacy comes from the access code + unguessable URL.
#   - --template defaults to the repo this checkout came from.
set -euo pipefail

SLUG="${1:-}"
if [[ -z "$SLUG" || "$SLUG" == --* ]]; then
  echo "usage: $0 <client-slug> [--template owner/repo] [--org <github-org>]" >&2
  exit 1
fi
shift

TEMPLATE=""
ORG=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --org) ORG=(--org "$2"); shift 2 ;;
    --template) TEMPLATE="$2"; shift 2 ;;
    *) echo "unknown option: $1" >&2; exit 1 ;;
  esac
done

if ! command -v gh >/dev/null; then
  echo "install the GitHub CLI first:  brew install gh && gh auth login" >&2
  exit 1
fi

if [[ -z "$TEMPLATE" ]]; then
  # detect from the origin URL of the repo this script lives in (works from any cwd)
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  TEMPLATE="$(git -C "$SCRIPT_DIR" remote get-url origin 2>/dev/null | sed -E 's#(git@github\.com[:/]|https?://github\.com/)##; s#\.git$##')"
fi
if [[ -z "$TEMPLATE" ]]; then
  echo "could not detect the template repo — pass --template owner/repo" >&2
  exit 1
fi

NAME="gallery-$SLUG"
TEMPLATE_OWNER="${TEMPLATE%%/*}"
echo "→ creating $NAME from template $TEMPLATE" >&2
gh repo create "$NAME" --template "$TEMPLATE" --public "${ORG[@]}" --clone
cd "$NAME"

# Enable Pages now, with YOUR credentials — the Actions token is not allowed
# to create the Pages site (403), so this cannot be done inside the workflow.
PAGES_OWNER="${ORG[1]:-$TEMPLATE_OWNER}"
echo "→ enabling GitHub Pages (workflow build type)" >&2
gh api -X POST "repos/$PAGES_OWNER/$NAME/pages" -f build_type=workflow >/dev/null 2>&1 \
  && echo "   ✓ Pages enabled" >&2 \
  || echo "   ! could not enable — run:  gh api -X POST repos/$PAGES_OWNER/$NAME/pages -f build_type=workflow" >&2

echo
echo "✓ ./$NAME ready. Next steps:"
echo "  1) edit src/config.json (studio, client, collections)"
echo "  2) npm run code -- \"<access code>\""
echo "  3) npm run previews -- <originals-dir> <collection-dir-name>"
echo "  4) git add -A && git commit -m 'set up gallery' && git push"
echo "  5) npm run deliver -- <originals-dir> --tag delivery   # full-res originals"
