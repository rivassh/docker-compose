#!/usr/bin/env bash
# =============================================================================
# Lab Runner Script – GitLab Local Ecosystem Launcher
# =============================================================================
# This script lets you start the GitLab stack in different modes:
#   1. Baseline only (empty stack)
#   2. Baseline + GitLab (full stack)
#   3. Auto-register the local GitLab Runner
#
# Usage:
#   ./scripts/run-lab.sh [option]
#
# Options:
#   1 – baseline only (no GitLab)
#   2 – baseline + GitLab (full stack)
#   3 – auto-register runner (requires GitLab to be up)
#   -h, --help – show this help
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------
usage() {
  sed -n '3,20p' "$0" | tail -n +2 | sed 's/^# //'
  exit 0
}

show_help() {
  usage
}

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
MODE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    1|2|3|-h|--help)
      MODE="$1"
      shift
      ;;
    *)
      echo "Unknown option: $1"
      show_help
      exit 1
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Mode 1: Baseline only (no GitLab services)
# ---------------------------------------------------------------------------
if [[ "$MODE" == "1" ]]; then
  echo "🚀 Starting BASELINE INFRASTRUCTURE ONLY"
  echo "   Running: docker compose up -d"
  docker compose -f docker-compose.yml up -d
  echo ""
  echo "✅ Baseline services started."
  echo "   • No GitLab is installed yet."
  echo "   • To add GitLab, run: ./scripts/run-lab.sh 2"
  exit 0
fi

# ---------------------------------------------------------------------------
# Mode 2: Baseline + GitLab stack
# ---------------------------------------------------------------------------
if [[ "$MODE" == "2" ]]; then
  echo "🚀 Starting FULL STACK (Baseline + GitLab)"
  echo "   Running: docker compose --profile gitlab -f docker-compose.yml -f stacks/gitlab/docker-compose.yml up -d"
  docker compose --profile gitlab -f docker-compose.yml -f stacks/gitlab/docker-compose.yml up -d
  echo ""
  echo "✅ Full stack is up."
  echo "   • GitLab CE is running on http://gitlab.local:80"
  echo "   • Container Registry on http://gitlab.local:5050"
  echo "   • SSH access on http://gitlab.local:2222"
  echo "   • Runner is registered and ready."
  exit 0
fi

# ---------------------------------------------------------------------------
# Mode 3: Auto-register the local GitLab Runner
# ---------------------------------------------------------------------------
if [[ "$MODE" == "3" ]]; then
  echo "🔄 Auto-registering GitLab Runner..."
  echo "   This assumes GitLab is already running (Mode 2 must be started first)."
  
  # Check if GitLab is reachable
  if ! curl -sf http://gitlab.local:80/health >/dev/null 2>&1; then
    echo "❌ Cannot connect to GitLab at http://gitlab.local:80"
    echo "   Please start the full stack (Mode 2) first."
    exit 1
  fi
  
  echo "   Registering runner with token: ${GITLAB_RUNNER_REGISTRATION_TOKEN:-<not set>}"
  
  # Run the registration command (same as in the compose file)
  gitlab-runner register --non-interactive \
    --url "http://gitlab.local:80" \
    --registration-token "$${GITLAB_RUNNER_REGISTRATION_TOKEN}" \
    --executor "docker" \
    --description "Local Docker Runner" \
    --tag-list "local,docker" \
    --docker-image "alpine:latest" \
    --docker-volumes "/var/run/docker.sock:/var/run/docker.sock" \
    --docker-volumes "/cache:/cache" \
    --docker-extra-hosts "gitlab.local:gitlab" \
    --docker-network-mode "gitlab-net" \
    --docker-privileged \
    --name "local-runner" \
    --run-untagged \
    --locked=false
  
  echo "✅ Runner registered successfully!"
  echo "   You can now push code via SSH to gitlab.local:2222"
  echo "   Or use the built-in GitLab interface at http://gitlab.local:80"
  exit 0
fi

# ---------------------------------------------------------------------------
# Invalid mode
# ---------------------------------------------------------------------------
echo "❌ Invalid mode: $MODE"
show_help
