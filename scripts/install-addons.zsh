#!/usr/bin/env zsh
set -euo pipefail

# ==============================================================================
# install-addons.zsh — CollectionBuilder-CSV Add-on Installer (Method C)
#
# Copies add-on files into the current CollectionBuilder-CSV repository and
# applies the minimal existing-file edits idempotently (safe to run more than
# once).
#
# Prerequisites:
#   - Run from the root of a CollectionBuilder-CSV repository (_config.yml and
#     Gemfile present).
#   - Either sibling clones (../<name>_cb-add-on) or git + network access to
#     clone from https://github.com/nakamura196/<name>_cb-add-on.git.
#
# Usage:
#   zsh ../cb-ja-demo/scripts/install-addons.zsh [options] [addons...]
#
# Add-ons (if none given, all three are installed):
#   cjk-search     cjk-search_cb-add-on   (CJK 2-gram search & browse)
#   static-iiif    static-iiif_cb-add-on  (IIIF v3 manifests & UV item layout)
#   museum-theme   museum-theme_cb-add-on (modern/museum looks & dark mode)
#
# Options:
#   --variants=LIST  Set cjk_index variants in _config.yml (e.g. --variants=ja,zh)
#   --local-gems     Point Gemfile at local ../cjk_index and ../static_iiif paths
#   -h, --help       Show this help message
# ==============================================================================

SCRIPT_DIR="${0:A:h}"
WORKSPACE_DIR="${SCRIPT_DIR:h:h}"

usage() {
  sed -n '4,28p' "$0" | sed 's/^# \{0,1\}//'
}

typeset -a ADDONS=()
CJK_VARIANTS=""
LOCAL_GEMS=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    cjk-search|static-iiif|museum-theme)
      ADDONS+=("$1")
      shift
      ;;
    --variants=*)
      CJK_VARIANTS="${1#--variants=}"
      shift
      ;;
    --variants)
      CJK_VARIANTS="${2:-}"
      shift 2
      ;;
    --local-gems)
      LOCAL_GEMS=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Error: unknown argument '$1'" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ ${#ADDONS[@]} -eq 0 ]]; then
  ADDONS=(cjk-search static-iiif museum-theme)
fi

if [[ ! -f "_config.yml" || ! -f "Gemfile" ]]; then
  echo "Error: run this script from the root of a CollectionBuilder-CSV repository (_config.yml and Gemfile must exist)." >&2
  exit 1
fi

TMP_CLONE_DIR=""
cleanup() {
  if [[ -n "$TMP_CLONE_DIR" && -d "$TMP_CLONE_DIR" ]]; then
    rm -rf "$TMP_CLONE_DIR"
  fi
}
trap cleanup EXIT

resolve_addon_dir() {
  local name="$1"
  local repo_name="${name}_cb-add-on"
  if [[ -d "../${repo_name}" ]]; then
    echo "${${:-"../${repo_name}"}:A}"
    return 0
  fi
  if [[ -d "${WORKSPACE_DIR}/${repo_name}" ]]; then
    echo "${WORKSPACE_DIR}/${repo_name}"
    return 0
  fi
  if [[ -z "$TMP_CLONE_DIR" ]]; then
    TMP_CLONE_DIR="$(mktemp -d)"
  fi
  local target="${TMP_CLONE_DIR}/${repo_name}"
  if [[ ! -d "$target" ]]; then
    echo "Cloning ${repo_name} from GitHub..." >&2
    git clone --quiet --depth 1 "https://github.com/nakamura196/${repo_name}.git" "$target"
  fi
  echo "$target"
}

copy_addon_files() {
  local addon_dir="$1"
  rsync -a --ignore-existing \
    --exclude '.git' \
    --exclude '.DS_Store' \
    --exclude 'README*' \
    --exclude 'LICENSE' \
    "${addon_dir}/" ./
}

install_cjk_search() {
  local dir
  dir="$(resolve_addon_dir cjk-search)"
  echo "==> Installing cjk-search_cb-add-on (from ${dir})"
  copy_addon_files "$dir"

  if ! grep -q "cjk_index" Gemfile; then
    if [[ "$LOCAL_GEMS" == true && -d "${WORKSPACE_DIR}/cjk_index" ]]; then
      cat >> Gemfile <<EOF

# CJK search: index and runtime at build time (cjk-search_cb-add-on)
group :jekyll_plugins do
  gem 'cjk_index', path: '${WORKSPACE_DIR}/cjk_index', require: 'cjk_index/jekyll'
end
EOF
    else
      cat >> Gemfile <<'EOF'

# CJK search: index and runtime at build time (cjk-search_cb-add-on)
group :jekyll_plugins do
  gem 'cjk_index', '~> 1.1', require: 'cjk_index/jekyll'
end
EOF
    fi
    echo "    Updated Gemfile (added cjk_index)"
  else
    echo "    Gemfile already references cjk_index (skipped)"
  fi

  if [[ -f "pages/search.md" ]] && grep -q "^layout:[[:space:]]*search[[:space:]]*$" pages/search.md; then
    ruby -i -pe 'gsub(/^layout:\s*search\s*$/, "layout: search-cjk\n")' pages/search.md
    echo "    Updated pages/search.md (layout: search-cjk)"
  fi

  if [[ -f "pages/browse.md" ]] && grep -q "^layout:[[:space:]]*browse[[:space:]]*$" pages/browse.md; then
    ruby -i -pe 'gsub(/^layout:\s*browse\s*$/, "layout: browse-cjk\n")' pages/browse.md
    echo "    Updated pages/browse.md (layout: browse-cjk)"
  fi

  if [[ -n "$CJK_VARIANTS" ]] && ! grep -q "^cjk_index:" _config.yml; then
    local formatted="[${CJK_VARIANTS//,/, }]"
    cat >> _config.yml <<EOF

# CJK search variant normalization (cjk-search_cb-add-on)
cjk_index:
  variants: ${formatted}
EOF
    echo "    Updated _config.yml (cjk_index.variants: ${formatted})"
  fi
}

install_static_iiif() {
  local dir
  dir="$(resolve_addon_dir static-iiif)"
  echo "==> Installing static-iiif_cb-add-on (from ${dir})"
  copy_addon_files "$dir"

  if ! grep -q "static_iiif" Gemfile; then
    if [[ "$LOCAL_GEMS" == true && -d "${WORKSPACE_DIR}/static_iiif" ]]; then
      cat >> Gemfile <<EOF

# static IIIF: manifests at build time (static-iiif_cb-add-on)
group :jekyll_plugins do
  gem 'static_iiif', path: '${WORKSPACE_DIR}/static_iiif', require: 'static_iiif/jekyll'
end
EOF
    else
      cat >> Gemfile <<'EOF'

# static IIIF: manifests at build time (static-iiif_cb-add-on)
group :jekyll_plugins do
  gem 'static_iiif', git: 'https://github.com/nakamura196/static_iiif.git', tag: 'v0.5.3', require: 'static_iiif/jekyll'
end
EOF
    fi
    echo "    Updated Gemfile (added static_iiif)"
  else
    echo "    Gemfile already references static_iiif (skipped)"
  fi
}

install_museum_theme() {
  local dir
  dir="$(resolve_addon_dir museum-theme)"
  echo "==> Installing museum-theme_cb-add-on (from ${dir})"
  copy_addon_files "$dir"

  if [[ -f "_sass/_custom.scss" ]] && ! grep -q '@use "museum";' _sass/_custom.scss; then
    cat >> _sass/_custom.scss <<'EOF'

@use "museum";
@use "modern";
EOF
    echo "    Updated _sass/_custom.scss (@use museum & modern)"
  fi

  if [[ -f "_includes/head/head.html" ]] && ! grep -q "head/color-mode.html" _includes/head/head.html; then
    ruby -i -pe 'sub(/<meta charset="utf-8">\n/, "<meta charset=\"utf-8\">\n{% include head/color-mode.html %}\n")' _includes/head/head.html
    echo "    Updated _includes/head/head.html (included head/color-mode.html)"
  fi

  if [[ -f "_layouts/default.html" ]] && ! grep -q "museum-header.html" _layouts/default.html; then
    ruby -0777 -i -pe 'sub(/^[ \t]*\{%\s*include\s+collection-banner\.html\s*%\}\r?\n[ \t]*\{%\s*include\s+collection-nav\.html\s*%\}/, "    {% include museum-header.html %}")' _layouts/default.html
    echo "    Updated _layouts/default.html (included museum-header.html)"
  fi

  if [[ -f "_data/theme.yml" ]] && ! grep -q "^theme-style:" _data/theme.yml; then
    cat >> _data/theme.yml <<'EOF'

# Museum Theme (museum-theme_cb-add-on)
theme-style: modern
color-mode-toggle: true
EOF
    echo "    Updated _data/theme.yml (theme-style: modern, color-mode-toggle: true)"
  fi
}

for addon in "${ADDONS[@]}"; do
  case "$addon" in
    cjk-search)   install_cjk_search ;;
    static-iiif)  install_static_iiif ;;
    museum-theme) install_museum_theme ;;
  esac
done

echo ""
echo "==> Done! Installed add-ons: ${ADDONS[*]}"
echo "    Modified / untracked files in $(pwd):"
git status -s
echo ""
echo "Next step: run 'bundle install' and 'bundle exec jekyll s'."
