#!/bin/bash
# Builds the site and copies dist to the server. Files on the server that
# aren't in dist are deleted, so old images go when they're gone from
# public/images. Extra arguments go to rsync, eg. ./deploy.sh --dry-run
set -euo pipefail

DEST=bertrand@server:/web/stranded.bert.org/

cd "$(dirname "$0")"

npm run build

# --partial so that an interrupted upload of an image picks up where it left off
rsync -rlt --delete --partial --exclude .DS_Store --compress --human-readable --itemize-changes "$@" dist/ "$DEST"
