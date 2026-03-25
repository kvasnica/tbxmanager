#!/bin/bash
# Hook: PreToolUse on Bash
# Blocks git push if CHANGELOG.md has no [Unreleased] entries for feat/fix/refactor commits.

INPUT=$(cat)

TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

# Only check on git push commands
if [[ "$TOOL" == "Bash" ]] && echo "$CMD" | grep -qE '\bgit push\b'; then
    REPO_ROOT="/Users/mw/pyprojects/tbxmanager"
    CHANGELOG="$REPO_ROOT/CHANGELOG.md"

    # Check if CHANGELOG.md exists
    if [[ ! -f "$CHANGELOG" ]]; then
        echo "CHANGELOG.md not found. Create it before pushing." >&2
        exit 2
    fi

    # Find commits since last push that need changelog entries
    # (feat, fix, refactor, docs, perf — not test/ci/chore/style)
    REMOTE_BRANCH=$(git -C "$REPO_ROOT" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)
    if [[ -n "$REMOTE_BRANCH" ]]; then
        NEEDS_ENTRY=$(git -C "$REPO_ROOT" log "$REMOTE_BRANCH"..HEAD --format="%s" 2>/dev/null | grep -cE '^(feat|fix|refactor|docs|perf)(\(.+\))?!?:')

        if [[ "$NEEDS_ENTRY" -gt 0 ]]; then
            # Check if [Unreleased] section has any actual entries (non-empty lines under ### headers)
            HAS_ENTRIES=$(sed -n '/^## \[Unreleased\]/,/^## \[/p' "$CHANGELOG" | grep -cE '^- ')

            if [[ "$HAS_ENTRIES" -eq 0 ]]; then
                echo "Blocked: $NEEDS_ENTRY commit(s) need CHANGELOG.md entries under [Unreleased]. Update the changelog before pushing." >&2
                exit 2
            fi
        fi
    fi
fi

exit 0
