#!/usr/bin/env bash
# =============================================================================
# push-and-review.sh – Push the demo project and trigger auto code review
# =============================================================================
# This helper:
#   1. Verifies the GitLab stack is running
#   2. Creates a project in GitLab (if not already present)
#   3. Pushes the demo project as a new branch
#   4. Opens (or simulates) a Merge Request
#   5. Watches the pipeline until it finishes
#
# Usage:
#   ./scripts/push-and-review.sh [branch-name]
#   ./scripts/push-and-review.sh feature/my-change
#
# Requirements:
#   - GitLab stack is running (./scripts/run-lab.sh 2)
#   - gitlab.local is in /etc/hosts
#   - curl and git are available
# =============================================================================

set -euo pipefail

# ── Configuration ─────────────────────────────────────────────────────────────
GITLAB_URL="http://gitlab.local:8080"
GITLAB_USER="root"
GITLAB_API="${GITLAB_URL}/api/v4"
PROJECT_NAME="gitlab-demo-project"
PROJECT_PATH="root/${PROJECT_NAME}"
GITLAB_TOKEN="${GITLAB_TOKEN:-}"
DEMO_DIR="${DEMO_DIR:-./gitlab-demo-project}"

BRANCH="${1:-feature/auto-review-demo}"
DESCRIPTION="${2:-Auto code review demo}"

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

info()  { echo -e "${CYAN}›${RESET}  $1"; }
ok()    { echo -e "${GREEN}✓${RESET}  $1"; }
warn()  { echo -e "${YELLOW}!${RESET}  $1"; }
fail()  { echo -e "${RED}✗${RESET}  $1"; exit 1; }
title() { echo -e "\n${BOLD}═══  $1  ═══${RESET}\n"; }

# ── Pre-flight checks ────────────────────────────────────────────────────────
title "Pre-flight Checks"

if ! grep -q "gitlab.local" /etc/hosts; then
  warn "gitlab.local not in /etc/hosts – adding now (requires sudo)"
  echo "127.0.0.1 gitlab.local" | sudo tee -a /etc/hosts > /dev/null || \
    fail "Failed to add gitlab.local to /etc/hosts"
  ok "Added gitlab.local to /etc/hosts"
else
  ok "gitlab.local is in /etc/hosts"
fi

if ! curl -sf "${GITLAB_URL}/-/health" > /dev/null; then
  fail "GitLab is not reachable at ${GITLAB_URL}. Start it with: ./scripts/run-lab.sh 2"
fi
ok "GitLab is reachable"

# ── Authentication ───────────────────────────────────────────────────────────
title "Authentication"

if [[ -z "$GITLAB_TOKEN" ]]; then
  warn "GITLAB_TOKEN is not set. Falling back to interactive password prompt."
  echo "    To set up token: GitLab UI → User Settings → Access Tokens → create with 'api' scope"
  echo ""
  read -rsp "GitLab password for ${GITLAB_USER}: " GITLAB_PASSWORD
  echo ""

  # Get a personal access token using the password (admin endpoint)
  info "Creating personal access token via admin API..."
  TOKEN_RESPONSE=$(curl -sf -X POST \
    -H "Content-Type: application/json" \
    -d "{\"login\":\"${GITLAB_USER}\",\"password\":\"${GITLAB_PASSWORD}\"}" \
    -c /tmp/gitlab-cookies.txt \
    "${GITLAB_URL}/users/sign_in" 2>&1) || true

  # Simpler approach: ask the user to provide an existing token
  echo ""
  read -rsp "Paste a GitLab personal access token (with 'api' scope): " GITLAB_TOKEN
  echo ""

  if [[ -z "$GITLAB_TOKEN" ]]; then
    fail "No token provided. Aborting."
  fi
fi

# Verify the token works
info "Verifying token..."
USER_INFO=$(curl -sf -H "PRIVATE-TOKEN: ${GITLAB_TOKEN}" "${GITLAB_API}/user" 2>&1) || \
  fail "Token verification failed – is the token valid?"

ok "Authenticated as $(echo "$USER_INFO" | python3 -c 'import json,sys; print(json.load(sys.stdin)["username"])' 2>/dev/null || echo "$GITLAB_USER")"

# ── Project creation ────────────────────────────────────────────────────────
title "Project Setup"

info "Checking if project '${PROJECT_PATH}' exists..."

EXISTING=$(curl -sf -H "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
  "${GITLAB_API}/projects/${PROJECT_PATH//\//%2F}" 2>&1) || EXISTING=""

if echo "$EXISTING" | grep -q '"id"'; then
  ok "Project already exists: ${PROJECT_PATH}"
else
  info "Creating project '${PROJECT_NAME}'..."
  curl -sf -X POST \
    -H "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{
      \"name\": \"${PROJECT_NAME}\",
      \"visibility\": \"private\",
      \"initialize_with_readme\": false
    }" \
    "${GITLAB_API}/projects" > /dev/null || fail "Failed to create project"
  ok "Project created: ${PROJECT_PATH}"
fi

# ── Git setup ────────────────────────────────────────────────────────────────
title "Git Push to Local GitLab"

cd "${DEMO_DIR}" || fail "Cannot enter ${DEMO_DIR}"

# Configure git identity (local to this repo)
git config user.name  "${GITLAB_USER}"
git config user.email "${GITLAB_USER}@gitlab.local"

# Add or update origin
if git remote get-url origin > /dev/null 2>&1; then
  git remote set-url origin "${GITLAB_URL}/${PROJECT_PATH}.git"
else
  git remote add origin "${GITLAB_URL}/${PROJECT_PATH}.git"
fi
ok "Remote origin set to ${GITLAB_URL}/${PROJECT_PATH}.git"

# Create the feature branch
git checkout -B "${BRANCH}"
ok "On branch: ${BRANCH}"

# Stage and commit
info "Staging files..."
git add .

# Check if there's anything to commit
if git diff --cached --quiet; then
  info "No changes to commit – using existing state"
else
  git commit -m "${DESCRIPTION}" || true
  ok "Committed changes"
fi

# Push (using token in URL to avoid interactive prompt)
info "Pushing to ${BRANCH}..."
git push -u "http://${GITLAB_USER}:${GITLAB_TOKEN}@gitlab.local:8080/${PROJECT_PATH}.git" "${BRANCH}" 2>&1 | \
  grep -E "^(To|remote|!|error)" || true
ok "Pushed ${BRANCH}"

# ── Pipeline monitoring ─────────────────────────────────────────────────────
title "Pipeline Monitoring"

sleep 3

info "Waiting for pipeline to start..."
PROJECT_ID=$(curl -sf -H "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
  "${GITLAB_API}/projects/${PROJECT_PATH//\//%2F}" | python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])')

# Get latest pipeline for this branch
MAX_WAIT=180
WAITED=0
PIPELINE_ID=""

while [[ $WAITED -lt $MAX_WAIT ]]; do
  PIPELINE=$(curl -sf -H "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
    "${GITLAB_API}/projects/${PROJECT_ID}/pipelines?ref=${BRANCH}&per_page=1" | \
    python3 -c 'import json,sys; p=json.load(sys.stdin); print(p[0]["id"] if p else "")' 2>/dev/null || echo "")

  if [[ -n "$PIPELINE" ]]; then
    PIPELINE_ID="$PIPELINE"
    break
  fi
  sleep 5
  WAITED=$((WAITED + 5))
  echo -n "."
done
echo ""

if [[ -z "$PIPELINE_ID" ]]; then
  warn "No pipeline started after ${MAX_WAIT}s. Check the UI manually."
  echo "   ${GITLAB_URL}/${PROJECT_PATH}/-/pipelines"
  exit 0
fi

ok "Pipeline #${PIPELINE_ID} is running"
info "Watching pipeline status (max 5 minutes)..."

# Watch the pipeline until it finishes
MAX_WATCH=300
WATCHED=0
LAST_STATUS=""

while [[ $WATCHED -lt $MAX_WATCH ]]; do
  STATUS=$(curl -sf -H "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
    "${GITLAB_API}/projects/${PROJECT_ID}/pipelines/${PIPELINE_ID}" | \
    python3 -c 'import json,sys; print(json.load(sys.stdin)["status"])' 2>/dev/null || echo "unknown")

  if [[ "$STATUS" != "$LAST_STATUS" ]]; then
    echo ""
    info "Pipeline status: ${STATUS}"
    LAST_STATUS="$STATUS"
  fi

  case "$STATUS" in
    success)
      ok "Pipeline SUCCEEDED"
      break
      ;;
    failed)
      fail "Pipeline FAILED – check ${GITLAB_URL}/${PROJECT_PATH}/-/pipelines/${PIPELINE_ID}"
      ;;
    canceled|skipped)
      warn "Pipeline was ${STATUS}"
      break
      ;;
  esac

  sleep 10
  WATCHED=$((WATCHED + 10))
  echo -n "."
done
echo ""

# ── Summary ──────────────────────────────────────────────────────────────────
title "Summary"

echo -e "${BOLD}Pipeline:${RESET}     ${GITLAB_URL}/${PROJECT_PATH}/-/pipelines/${PIPELINE_ID}"
echo -e "${BOLD}Branch:${RESET}       ${BRANCH}"
echo -e "${BOLD}Status:${RESET}       ${STATUS}"
echo ""

if [[ "$STATUS" == "success" ]]; then
  echo -e "${GREEN}✅  Auto code review completed!${RESET}"
  echo ""
  echo "Next steps:"
  echo "  1. Open the pipeline:  ${GITLAB_URL}/${PROJECT_PATH}/-/pipelines/${PIPELINE_ID}"
  echo "  2. View artifacts:     click any review job → Browse artifacts → review-output/"
  echo "  3. View security tab:  ${GITLAB_URL}/${PROJECT_PATH}/-/security/vulnerability_report"
  echo "  4. Create a Merge Request:"
  echo "       ${GITLAB_URL}/${PROJECT_PATH}/-/merge_requests/new?merge_request%5Bsource_branch%5D=${BRANCH}"
  echo ""
  echo "After the MR is opened, a new pipeline will run with:"
  echo "  - The same review jobs"
  echo "  - Code Quality widget visible in the MR"
  echo "  - Security findings under 'Security & Compliance'"
fi
