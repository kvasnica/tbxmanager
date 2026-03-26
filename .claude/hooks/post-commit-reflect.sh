#!/bin/bash
# Hook: PostToolUse on Bash
# Detects git commit commands and prompts Claude to run the self-reflect agent.

INPUT=$(cat)

TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
OUTPUT=$(echo "$INPUT" | jq -r '.tool_output // empty' 2>/dev/null)

# Only trigger on successful git commit commands
if [[ "$TOOL" == "Bash" ]] && echo "$CMD" | grep -qE '\bgit commit\b'; then
    # Verify the commit actually succeeded (not a dry-run or failed hook)
    if echo "$OUTPUT" | grep -qiE '(create mode|file changed|files changed|insertions|deletions|\[.+\])'; then
        COMMIT_HASH=$(git -C /Users/mw/pyprojects/tbxmanager log -1 --format="%h" 2>/dev/null)
        COMMIT_SUBJECT=$(git -C /Users/mw/pyprojects/tbxmanager log -1 --format="%s" 2>/dev/null)
        echo "Commit ${COMMIT_HASH} landed: ${COMMIT_SUBJECT}. @.claude/agents/self-reflect.md, please review this commit and improve agent prompts if needed. Use: Agent tool with subagent_type or prompt referencing self-reflect."
    fi
fi

exit 0
