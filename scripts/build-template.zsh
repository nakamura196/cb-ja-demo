#!/usr/bin/env zsh
set -euo pipefail

# ==============================================================================
# build-template.zsh — Built On Template Generator for CB-CSV (Method D)
#
# Creates or updates a "Built On" CollectionBuilder-CSV template repository
# (e.g. collectionbuilder-csv-cjk-iiif) with:
#   1. All three add-ons installed via install-addons.zsh:
#      - cjk-search_cb-add-on   (cjk_index gem)
#      - static-iiif_cb-add-on  (static_iiif gem)
#      - museum-theme_cb-add-on (modern/museum looks, dark mode, grid/list)
#   2. Built On quality-of-life fixes:
#      - Un-ignores objects/ in .gitignore so images and IIIF level 0 tiles can
#        be committed directly
#      - Adds .github/workflows/pages.yml for Jekyll 4 + plugin builds on
#        GitHub Pages
#      - Adds silence_deprecations: [if-function] under sass: in _config.yml
#      - Adds development-only <meta name="referrer" content="no-referrer"> in
#        _includes/head/head.html for IIIF servers that block localhost referers
#
# Usage:
#   zsh scripts/build-template.zsh [options] [target-dir]
#
# Options:
#   --in-place       Apply to the current working directory instead of cloning
#   --variants=LIST  Pass --variants=LIST to install-addons.zsh (e.g. ja,zh)
#   --local-gems     Pass --local-gems to install-addons.zsh
#   -h, --help       Show this help message
# ==============================================================================

SCRIPT_DIR="${0:A:h}"
WORKSPACE_DIR="${SCRIPT_DIR:h:h}"
UPSTREAM_COMMIT="93b76d2"

usage() {
  sed -n '4,30p' "$0" | sed 's/^# \{0,1\}//'
}

IN_PLACE=false
 target_dir=""
typeset -a INSTALL_OPTS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --in-place)
      IN_PLACE=true
      shift
      ;;
    --variants=*|--local-gems)
      INSTALL_OPTS+=("$1")
      shift
      ;;
    --variants)
      INSTALL_OPTS+=("--variants=${2:-}")
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      echo "Error: unknown option '$1'" >&2
      usage >&2
      exit 1
      ;;
    *)
      target_dir="$1"
      shift
      ;;
  esac
done

if [[ "$IN_PLACE" == true ]]; then
  target_dir="$(pwd)"
elif [[ -z "$target_dir" ]]; then
  echo "Error: specify a target directory or pass --in-place." >&2
  usage >&2
  exit 1
fi

if [[ "$IN_PLACE" == false && ! -d "$target_dir" ]]; then
  echo "==> Creating new CB-CSV repository at ${target_dir}"
  if [[ -d "${WORKSPACE_DIR}/cb-theme-test/.git" ]]; then
    git clone --quiet "${WORKSPACE_DIR}/cb-theme-test" "$target_dir"
    git -C "$target_dir" checkout --quiet -B main "$UPSTREAM_COMMIT"
    git -C "$target_dir" remote remove origin 2>/dev/null || true
  elif [[ -d "${WORKSPACE_DIR}/manual-try/my-collection/.git" ]]; then
    git clone --quiet "${WORKSPACE_DIR}/manual-try/my-collection" "$target_dir"
    git -C "$target_dir" remote remove origin 2>/dev/null || true
  else
    git clone --quiet --depth 1 "https://github.com/CollectionBuilder/collectionbuilder-csv.git" "$target_dir"
    git -C "$target_dir" remote remove origin 2>/dev/null || true
  fi
fi

cd "$target_dir"

if [[ ! -f "_config.yml" || ! -f "Gemfile" ]]; then
  echo "Error: ${target_dir} is not a CollectionBuilder-CSV repository." >&2
  exit 1
fi

echo "==> Step 1: Installing add-ons via install-addons.zsh"
zsh "${SCRIPT_DIR}/install-addons.zsh" "${INSTALL_OPTS[@]}" cjk-search static-iiif museum-theme

echo "==> Step 2: Applying Built On template improvements"

# 1. Remove objects/ from .gitignore so collection images and IIIF tiles are tracked
if [[ -f ".gitignore" ]] && grep -q "^objects/" .gitignore; then
  ruby -0777 -i -pe 'gsub(/^objects\/[ \t]*(\r?\n|\z)/, "")' .gitignore
  echo "    Updated .gitignore (removed objects/ ignore rule)"
fi

# 2. Silence Dart Sass 3 if-function deprecation warning in _config.yml
if [[ -f "_config.yml" ]] && ! grep -q "silence_deprecations" _config.yml; then
  ruby -0777 -i -pe 'sub(/^sass:\s*\n\s*style:\s*compressed/, "sass:\n  style: compressed\n  silence_deprecations: [if-function]")' _config.yml
  echo "    Updated _config.yml (added sass.silence_deprecations: [if-function])"
fi

# 3. Add development-only no-referrer meta tag in _includes/head/head.html
if [[ -f "_includes/head/head.html" ]] && ! grep -q 'name="referrer"' _includes/head/head.html; then
  ruby -0777 -i -pe 'sub(/\A/, "{% if jekyll.environment == \"development\" %}<!-- dev only: some IIIF hosts reject http:// referers such as localhost -->\n<meta name=\"referrer\" content=\"no-referrer\">{% endif %}\n")' _includes/head/head.html
  echo "    Updated _includes/head/head.html (added dev no-referrer meta tag)"
fi

# 4. Add .github/workflows/pages.yml for GitHub Pages deployment
if [[ ! -f ".github/workflows/pages.yml" ]]; then
  mkdir -p .github/workflows
  cat > .github/workflows/pages.yml <<'EOF'
# Build the Jekyll site and publish it to GitHub Pages.
# CollectionBuilder with cjk_index / static_iiif needs Jekyll 4 and custom
# plugins, so the classic "deploy from branch" Pages build cannot be used.
name: Deploy to GitHub Pages

on:
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: pages
  cancel-in-progress: false

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      - uses: ruby/setup-ruby@7f797815d8adceb1c412e7abefdd1ab4abc47a5f # v1.335.0
        with:
          ruby-version: "3.3"
          bundler-cache: true
      - id: pages
        uses: actions/configure-pages@45bfe0192ca1faeb007ade9deae92b16b8254a0d # v6.0.0
      - run: bundle exec jekyll build
        env:
          JEKYLL_ENV: production
      - uses: actions/upload-pages-artifact@fc324d3547104276b827a68afc52ff2a11cc49c9 # v5.0.0

  deploy:
    needs: build
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - id: deployment
        uses: actions/deploy-pages@368f82528645a54fb793d4d04e342629a3f51346 # v5.0.1
EOF
  echo "    Created .github/workflows/pages.yml"
fi

echo ""
echo "==> Built On template ready at: $(pwd)"
git status -s
