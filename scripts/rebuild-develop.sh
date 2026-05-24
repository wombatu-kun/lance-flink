#!/usr/bin/env bash
#
# rebuild-develop.sh — regenerate the local `develop` integration branch.
#
# `develop` is a DISPOSABLE branch that combines all of our in-flight topic
# branches for daily build/CI. It is never pushed upstream; the topic branches
# are the deliverables. This script rebuilds it deterministically from:
#     main  +  (merge of all active topic branches)  +  two fork-only commits.
#
# It does NOT touch upstream or any PR. Syncing `main` from upstream and
# rebasing the topic branches is a SEPARATE step you run first when `main` has
# moved (see ONBOARDING / the project workflow notes). Run this only when
# develop's foundation shifted — after an upstream sync, after you rewrote a
# topic branch, or to get a clean reproducible develop. Routine feature
# delivery is just `git merge --no-ff <branch>` into develop; no rebuild needed.
#
# Requirements: a clean working tree and a JDK 11+ on PATH (spotless/gjf cannot
# run on JDK 8, and the build targets Java 8 bytecode regardless).
#
# Usage:  scripts/rebuild-develop.sh

set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

# The branch that carries the mass spotless reformat (#24) + CI (#25). It is
# merged LAST so that, by the time it lands, develop already contains every
# feature; any conflict is then "feature vs pure reformat" and is safely
# resolved by keeping develop's side (--ours) — the spotless sweep below
# re-applies formatting to the kept feature code.
FORMAT_STACK_TIP="build/ci-makefile"

# Prefixes under which our PR-able topic branches live.
PREFIXES=(refs/heads/feature refs/heads/build refs/heads/chore refs/heads/ci)

if [[ -n "$(git status --porcelain --untracked-files=no)" ]]; then
  echo "error: working tree has tracked changes; commit/stash first." >&2
  exit 1
fi

# --- Auto-derive the merge list (no hand-maintained list) -------------------
# Candidates: prefixed branches that still have commits not yet in main.
candidates=()
while IFS= read -r b; do
  [[ -z "$b" ]] && continue
  if [[ "$(git rev-list --count "main..$b")" -gt 0 ]]; then
    candidates+=("$b")
  fi
done < <(git for-each-ref --format='%(refname:short)' "${PREFIXES[@]}")

# Drop any candidate that is an ancestor of another candidate, so only stack
# *tips* are merged (e.g. build/ci-makefile, not its #23/#24 ancestors).
leaves=()
for b in "${candidates[@]}"; do
  is_ancestor=0
  for other in "${candidates[@]}"; do
    [[ "$b" == "$other" ]] && continue
    if git merge-base --is-ancestor "$b" "$other"; then is_ancestor=1; break; fi
  done
  [[ "$is_ancestor" -eq 0 ]] && leaves+=("$b")
done

# Order: everything except the format/CI stack tip first, that tip last.
ordered=()
for b in "${leaves[@]}"; do [[ "$b" != "$FORMAT_STACK_TIP" ]] && ordered+=("$b"); done
for b in "${leaves[@]}"; do [[ "$b" == "$FORMAT_STACK_TIP" ]] && ordered+=("$b"); done

echo "Rebuilding develop from main + merges: ${ordered[*]}"

# --- Reset develop to main and re-merge -------------------------------------
git switch main >/dev/null
git switch -C develop >/dev/null

for b in "${ordered[@]}"; do
  if ! git merge --no-ff --no-edit "$b"; then
    conflicted="$(git diff --name-only --diff-filter=U)"
    echo "  resolving conflicts (keep feature side) in: $conflicted"
    # shellcheck disable=SC2086
    git checkout --ours -- $conflicted
    # shellcheck disable=SC2086
    git add $conflicted
    git commit --no-edit
  fi
done

# --- Fork-only commit 1: spotless sweep over the integrated tree ------------
# Covers feature code that the frozen #24 artifact did not format.
mvn -q spotless:apply
if [[ -n "$(git status --porcelain --untracked-files=no)" ]]; then
  git add -u   # tracked files only — never sweep in untracked local files
  git commit -m "style: spotless sweep over integrated develop (fork-only)"
fi

# --- Fork-only commit 2: CI trigger on develop + this script ----------------
# develop must be in flink.yml push triggers (upstream/topic copies keep [main]).
if ! grep -qE '^\s*branches:\s*\[.*\bdevelop\b.*\]' .github/workflows/flink.yml; then
  sed -i -E 's/^(\s*branches:\s*\[)main(\])/\1main, develop\2/' .github/workflows/flink.yml
fi
git add .github/workflows/flink.yml scripts/rebuild-develop.sh
if [[ -n "$(git diff --cached --name-only)" ]]; then
  git commit -m "ci: trigger Flink CI on develop pushes + rebuild script (fork-only)"
fi

# --- Publish the disposable integration branch ------------------------------
git push --force-with-lease origin develop
echo "develop rebuilt and pushed."
