#!/bin/sh
set -eu
INKWAVE_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$INKWAVE_ROOT"
if [ ! -f source_reference/src/config.js ]; then
  git clone https://github.com/jaydendavisnc/inkwave.git source_reference
  git -C source_reference checkout 98ea29694ab3eebaaeaa995c2b525ac883a48de5
fi
npm ci --prefix tools --ignore-scripts --no-audit --no-fund
if [ ! -e source_reference/node_modules ]; then ln -s ../tools/node_modules source_reference/node_modules; fi
node tools/export_source.mjs maps
node tools/export_source.mjs characters
node tools/export_source.mjs appearance
node tools/export_source.mjs boss
