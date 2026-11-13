#!/usr/bin/env bash
# Install (or remove) the pre-push hook that runs `scripts/ci-local.sh --fast` (AGENTS.md). Same file in every ILTIAM
# repo. Re-runnable: running it again changes nothing.
#
#   scripts/install-hooks.sh               install
#   scripts/install-hooks.sh --uninstall   remove it and put back what was there before
#
# Existing hooks are kept:
#   - a pre-push hook already in the hooks directory is moved to pre-push.local-ci-chained and runs first;
#   - with a custom core.hooksPath (husky, lefthook, a tracked .githooks/ ...), nothing in that directory is changed:
#     a private hooks directory in .git/ gets the pre-push hook plus a pass-through for every other hook there, and
#     core.hooksPath (this clone only) points at it; the old value is kept in local-ci.originalHooksPath.
# The hook is local and bypassable (`git push --no-verify`): a safety net, not enforcement.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
MARK="# iltiam-local-ci pre-push hook"
mode=install
case "${1:-}" in
  "") ;;
  --uninstall) mode=uninstall ;;
  *) echo "usage: $0 [--uninstall]" >&2; exit 2 ;;
esac

git_dir="$(cd "$(git rev-parse --git-common-dir)" && pwd)"
private="$git_dir/local-ci-hooks"
custom="$(git config --local --get core.hooksPath || true)"
original="$(git config --local --get local-ci.originalHooksPath || true)"

write_hook() { # <hook file> <chained hook or empty>
  cat >"$1" <<EOF
#!/usr/bin/env bash
$MARK (scripts/install-hooks.sh; remove with scripts/install-hooks.sh --uninstall)
input="\$(cat)"
chained="$2"
if [ -n "\$chained" ] && [ -x "\$chained" ]; then
  printf '%s\n' "\$input" | "\$chained" "\$@" || exit \$?
fi
# Only deleting remote branches: nothing to check.
if [ -n "\$input" ] && ! printf '%s\n' "\$input" | awk '\$2 !~ /^0+\$/ { f = 1 } END { exit !f }'; then
  exit 0
fi
echo "pre-push: scripts/ci-local.sh --fast (AGENTS.md). Bypass only knowingly: git push --no-verify"
exec bash "\$(git rev-parse --show-toplevel)/scripts/ci-local.sh" --fast </dev/null
EOF
  chmod +x "$1"
}

if [ "$mode" = uninstall ]; then
  if [ -n "$original" ] || [ "$custom" = "$private" ]; then
    if [ -n "$original" ]; then git config --local core.hooksPath "$original"; else git config --local --unset core.hooksPath || true; fi
    git config --local --unset local-ci.originalHooksPath || true
    rm -rf "$private"
    echo "Removed; core.hooksPath is back to ${original:-its default}."
    exit 0
  fi
  hooks="$(git rev-parse --git-path hooks)"
  if [ -f "$hooks/pre-push" ] && grep -qF "$MARK" "$hooks/pre-push"; then
    rm -f "$hooks/pre-push"
    if [ -f "$hooks/pre-push.local-ci-chained" ]; then
      mv "$hooks/pre-push.local-ci-chained" "$hooks/pre-push"
      echo "Removed; the previous pre-push hook is back."
    else
      echo "Removed."
    fi
  else
    echo "No local-CI hook installed."
  fi
  exit 0
fi

# --- install -----------------------------------------------------------------------------------------------------
if [ -n "$custom" ] && [ "$custom" != "$private" ]; then
  # A custom hooks directory: leave it untouched and chain to it from a private one.
  target="$custom"
  case "$target" in /* | [A-Za-z]:*) ;; *) target="$PWD/$target" ;; esac
  mkdir -p "$private"
  for h in "$target"/*; do
    if [ ! -f "$h" ] || [ ! -x "$h" ]; then continue; fi
    name="$(basename "$h")"
    [ "$name" = pre-push ] && continue
    printf '#!/usr/bin/env bash\nexec "%s" "$@"\n' "$h" >"$private/$name"
    chmod +x "$private/$name"
  done
  write_hook "$private/pre-push" "$target/pre-push"
  git config --local local-ci.originalHooksPath "$custom"
  git config --local core.hooksPath "$private"
  echo "Installed in $private (chains to $custom); core.hooksPath now points there for this clone."
  exit 0
fi

if [ "$custom" = "$private" ]; then
  write_hook "$private/pre-push" "${original:+$original/pre-push}"
  echo "Already installed in $private; hook refreshed."
  exit 0
fi

hooks="$(git rev-parse --git-path hooks)"
mkdir -p "$hooks"
chained=""
if [ -f "$hooks/pre-push" ] && ! grep -qF "$MARK" "$hooks/pre-push"; then
  if [ -f "$hooks/pre-push.local-ci-chained" ]; then
    cp "$hooks/pre-push" "$hooks/pre-push.local-ci-backup.$(date +%Y%m%d%H%M%S)"
  fi
  mv "$hooks/pre-push" "$hooks/pre-push.local-ci-chained"
  echo "Kept the existing pre-push hook: it runs first, from pre-push.local-ci-chained."
fi
[ -f "$hooks/pre-push.local-ci-chained" ] && chained="$(cd "$hooks" && pwd)/pre-push.local-ci-chained"
write_hook "$hooks/pre-push" "$chained"
echo "Installed: $hooks/pre-push runs scripts/ci-local.sh --fast before every push."
