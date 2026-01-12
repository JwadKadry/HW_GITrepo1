#!/usr/bin/env bash
set -euo pipefail

CSV_FILE="tasks.csv"

if [[ $# -lt 1 ]]; then 
 echo "❌ Error: TASK_ID is required"
 exit 1
fi

TASK_ID="$1"
OPTIONAL_MSG="${2:-}"

if [[ ! -f "$CSV_FILE" ]]; then
 echo "❌ Error: tasks.csv not found"
 exit 1
fi

if [[ ! -d ".git" ]]; then
  echo "❌ Error: current directory is not a git repository"
  exit 1
fi

# Find matching row by TaskID (6th column)
TASK_LINE="$(awk -F',' -v id="$TASK_ID" 'NR>1 && $6==id {print; exit}' "$CSV_FILE")"
if [[ -z "${TASK_LINE}" ]]; then
  echo "❌ Error: TASK_ID $TASK_ID not found in CSV"
  exit 1
fi

IFS=',' read -r REPO_PATH GITHUB_URL DEV_NAME BRANCH TASK_DESC TASKID <<< "$TASK_LINE"

CURRENT_BRANCH="$(git branch --show-current)"
if [[ "$CURRENT_BRANCH" != "$BRANCH" ]]; then
  echo "❌ Error: branch mismatch"
  echo "   Expected: $BRANCH"
  echo "   Current : $CURRENT_BRANCH"
  exit 1
fi

# Ensure origin exists and is SSH URL
if ! git remote get-url origin >/dev/null 2>&1; then
  git remote add origin "$GITHUB_URL"
else
  ORIGIN_URL="$(git remote get-url origin)"
  if [[ "$ORIGIN_URL" != "$GITHUB_URL" ]]; then
    git remote set-url origin "$GITHUB_URL"
  fi
fi
# git-remote set-url is an official command; used here to enforce SSH. :contentReference[oaicite:1]{index=1}

# Must have changes
if git diff --quiet && git diff --cached --quiet; then
  echo "❌ Error: no changes to commit"
  exit 1
fi

DATETIME="$(date '+%Y-%m-%d %H:%M')"
COMMIT_MSG="$TASKID - $DATETIME - $BRANCH - $DEV_NAME - $TASK_DESC"
if [[ -n "$OPTIONAL_MSG" ]]; then
  COMMIT_MSG="$COMMIT_MSG - $OPTIONAL_MSG"
fi

git add .

# No -m: commit message via stdin (git commit -F - reads message from stdin) :contentReference[oaicite:2]{index=2}
git commit -F - <<EOF
$COMMIT_MSG
EOF

COMMIT_HASH="$(git rev-parse --short HEAD)"
git push -u origin "$BRANCH"

echo "----------------------------------------"
echo "✅ Repo      : $(basename "$(pwd)")"
echo "✅ Task ID   : $TASKID"
echo "✅ Branch    : $BRANCH"
echo "✅ Message   : $COMMIT_MSG"
echo "✅ Hash      : $COMMIT_HASH"
echo "✅ Pushed    : origin/$BRANCH"
echo "----------------------------------------"
BASH

