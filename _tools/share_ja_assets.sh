#!/usr/bin/env bash
# After the English build (_config.en.yml, into <site>/en), drop its copy of the
# images and IIIF files (objects/) and point its pages at the Japanese build's, so that
# every image keeps one URL (/cb-ja-demo/objects/...) and the site is published once, not twice.
# (The English build already takes its manifests from the Japanese build: static_iiif.manifests in _config.en.yml.)
# Usage: bash _tools/share_ja_assets.sh <site dir, e.g. _site>
set -euo pipefail
site=${1:?site dir}
en=$site/en
if [[ ! -d $en/objects || ! -d $site/objects ]]; then echo "no $en/objects or $site/objects" >&2; exit 1; fi
rm -rf "$en/objects"
grep -rl --null --include='*.html' --include='*.json' --include='*.js' --include='*.xml' --include='*.csv' '/cb-ja-demo/en/objects/' "$en" | while IFS= read -r -d '' f; do
  sed -i.bak -e 's#/cb-ja-demo/en/objects/#/cb-ja-demo/objects/#g' "$f"
done || true
find "$en" -name '*.bak' -delete
left=$( (grep -rl '/cb-ja-demo/en/objects/' "$en" || true) | wc -l | tr -d ' ')
echo "en: images and IIIF shared with the Japanese build ($left files still pointing at en)"
