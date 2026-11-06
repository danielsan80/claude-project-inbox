#!/usr/bin/env bash
# Runs inbox.sh against throwaway inboxes and projects.
set -u

INBOX="$(cd "$(dirname "$0")" && pwd)/inbox.sh"
failures=0

setup() {
    root=$(mktemp -d)
    export CLAUDE_INBOX_DIR="$root/inbox"
    export CLAUDE_PROJECTS_DIR="$root/claude-projects"
    mkdir -p "$root/projects/alpha/sub" "$root/projects/beta" \
        "$CLAUDE_PROJECTS_DIR/-work-alpha" "$CLAUDE_PROJECTS_DIR/-work-beta"
    git -C "$root/projects/alpha" init -q
}

run() {
    output=$("$@" 2>&1)
    status=$?
}

send() { run bash -c "printf '%b' '$3' | '$INBOX' send '$1' '$2'"; }
check_from() { run bash -c "printf '{\"cwd\":\"%s\"}' '$1' | '$INBOX' check"; }
context() { jq -r '.hookSpecificOutput.additionalContext' <<< "$output" 2>/dev/null; }

pass() { echo "ok:   $1"; }
fail() {
    echo "FAIL: $1"
    echo "$output" | sed 's/^/    /'
    failures=$((failures + 1))
}
expect() { if eval "$2"; then pass "$1"; else fail "$1"; fi; }

count_messages() { find "$CLAUDE_INBOX_DIR" -type f -name '*.md' 2>/dev/null | wc -l; }
only_message() { find "$CLAUDE_INBOX_DIR" -type f -name '*.md' | head -n 1; }

setup
send beta alpha 'update the card'
expect "send succeeds" '[ "$status" -eq 0 ]'
expect "send leaves one message" '[ "$(count_messages)" -eq 1 ]'
expect "send prints the message path" '[ "$output" = "$(only_message)" ]'
expect "the message carries the body" 'grep -qF "update the card" "$(only_message)"'
expect "the message carries the sender" 'grep -qF "from: alpha" "$(only_message)"'

setup
send gamma alpha 'for a project never seen'
expect "send to an unknown project still leaves the message" '[ "$status" -eq 0 ] && [ "$(count_messages)" -eq 1 ]'
expect "send to an unknown project warns" 'grep -qiF "no Claude session has ever been opened on a project named '"'gamma'"'" <<< "$output"'

setup
send beta alpha 'for a known project'
expect "send to a known project does not warn" '! grep -qiF "no Claude session" <<< "$output"'

setup
send ../beta alpha 'off the road'
expect "a name with a slash is refused" '[ "$status" -ne 0 ] && [ -z "$(find "$root" -type f -name "*.md")" ]'

setup
send beta alpha ''
expect "an empty message is refused" '[ "$status" -ne 0 ] && [ "$(count_messages)" -eq 0 ]'

setup
check_from "$root/projects/beta"
expect "check with an empty inbox succeeds" '[ "$status" -eq 0 ]'
expect "check with an empty inbox prints nothing" '[ -z "$output" ]'

setup
send beta alpha 'line "one"\nline two\\\\'
message="$output"
check_from "$root/projects/beta"
expect "check succeeds" '[ "$status" -eq 0 ]'
expect "check prints valid JSON" 'jq -e . <<< "$output" >/dev/null'
expect "the context carries the body" 'context | grep -qF "line \"one\"" && context | grep -qF "line two"'
expect "the context names the message file" 'context | grep -qF "$message"'
expect "check does not consume the message" '[ -f "$message" ]'

setup
send alpha beta 'for-alpha'
check_from "$root/projects/alpha/sub"
expect "a subdirectory of a repo reads the repo's inbox" 'context | grep -qF for-alpha'

setup
send beta alpha 'for-beta'
check_from "$root/projects/alpha"
expect "check ignores the inboxes of other projects" '[ -z "$output" ]'

setup
send beta alpha 'old'
touch -d '8 days ago' "$(only_message)"
check_from "$root/projects/alpha"
expect "check reports messages older than a week elsewhere" 'context | grep -qiF "older than a week" && context | grep -qF "$(only_message)"'
check_from "$root/projects/alpha"
expect "the stale report comes once a day" '[ -z "$output" ]'

setup
send beta alpha 'recent'
check_from "$root/projects/alpha"
expect "messages younger than a week are not reported" '[ -z "$output" ]'

setup
send alpha beta 'old but delivered'
touch -d '8 days ago' "$(only_message)"
check_from "$root/projects/alpha"
expect "own old messages are delivered, not reported as stale" 'context | grep -qF "old but delivered" && ! context | grep -qiF "older than a week"'

setup
send alpha beta 'for-alpha'
send beta alpha 'old'
touch -d '8 days ago' "$CLAUDE_INBOX_DIR"/beta/*.md
check_from "$root/projects/alpha"
expect "deliveries and stale report come together" 'context | grep -qF for-alpha && context | grep -qiF "older than a week"'
expect "a blank line separates the stale report from the deliveries" '[ -z "$(context | grep -B1 -iF "older than a week" | head -n 1)" ]'

echo
if [ "$failures" -gt 0 ]; then
    echo "$failures failure(s)"
    exit 1
fi
echo "all passed"
