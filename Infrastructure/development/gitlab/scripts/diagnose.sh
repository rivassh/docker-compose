#!/usr/bin/env bash
# =============================================================================
# diagnose.sh – GitLab Local Stack Health Diagnostic Script
# =============================================================================
# Automatically checks all 12 common failure categories for the local GitLab
# pipeline. Run this whenever something breaks before digging deeper.
#
# Usage:
#   ./scripts/diagnose.sh           # full diagnostic (all checks)
#   ./scripts/diagnose.sh --quick  # container + health only (no deep checks)
#   ./scripts/diagnose.sh --fix    # attempt to fix common issues automatically
#   ./scripts/diagnose.sh --reset  # full nuclear reset (prompts for confirmation)
# =============================================================================

set -euo pipefail

# ── Color output ──────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

OK="${GREEN}✓${RESET}"
FAIL="${RED}✗${RESET}"
WARN="${YELLOW}!${RESET}"
INFO="${CYAN}›${RESET}"

# ── Helper functions ───────────────────────────────────────────────────────────
section() {
  echo ""
  echo -e "${BOLD}━━━  $1  ━━━${RESET}"
}

pass() {
  echo -e "  ${OK}  $1"
}

fail() {
  echo -e "  ${FAIL}  $1"
}

warn() {
  echo -e "  ${WARN}  $1"
}

info() {
  echo -e "  ${INFO}  $1"
}

cmd_ok() {
  "$@" > /dev/null 2>&1
}

cmd_out() {
  "$@" 2>&1
}

# ── Argument parsing ───────────────────────────────────────────────────────────
MODE="${1:-full}"

# ═══════════════════════════════════════════════════════════════════════════════
# CHECK 9.1 – Pre-flight: Container & Network Health
# ═══════════════════════════════════════════════════════════════════════════════
check_containers() {
  section "9.1  Container & Network Health"

  # GitLab CE
  if cmd_ok docker inspect gitlab-ce > /dev/null 2>&1; then
    local gitlab_status
    gitlab_status=$(docker inspect --format='{{.State.Status}}' gitlab-ce 2>/dev/null || echo "unknown")
    if [[ "$gitlab_status" == "running" ]]; then
      pass "gitlab-ce is running"
    else
      fail "gitlab-ce is $gitlab_status (expected: running)"
    fi
  else
    fail "gitlab-ce container not found"
  fi

  # GitLab Runner
  if cmd_ok docker inspect gitlab-runner > /dev/null 2>&1; then
    local runner_status
    runner_status=$(docker inspect --format='{{.State.Status}}' gitlab-runner 2>/dev/null || echo "unknown")
    if [[ "$runner_status" == "running" ]]; then
      pass "gitlab-runner is running"
    else
      fail "gitlab-runner is $runner_status (expected: running)"
    fi
  else
    warn "gitlab-runner container not found (did you start with --profile gitlab?)"
  fi

  # deploy-test target (optional)
  if cmd_ok docker inspect deploy-test > /dev/null 2>&1; then
    pass "deploy-test is present"
  else
    warn "deploy-test container not found (needed for deploy stage)"
  fi

  # gitlab-net network
  if docker network inspect gitlab-net > /dev/null 2>&1; then
    pass "gitlab-net network exists"
  else
    fail "gitlab-net network not found – run ./scripts/run-lab.sh 2"
  fi
}

check_web_health() {
  section "9.2  GitLab Web Health"

  if cmd_ok curl -sf http://gitlab.local:8080/-/health; then
    pass "GitLab web health check passed"
  else
    fail "GitLab web health check FAILED – http://gitlab.local:8080/-/health"
    info "Wait 5–10 minutes after first start; check logs: docker logs -f gitlab-ce"
  fi
}

check_api() {
  section "9.3  GitLab API"

  local api_out
  api_out=$(curl -sf http://gitlab.local:8080/api/v4/version 2>&1 || true)
  if [[ -n "$api_out" ]]; then
    pass "GitLab API responds: $api_out"
  else
    fail "GitLab API not responding – check GitLab container logs"
    info "docker logs --tail 50 gitlab-ce"
  fi
}

check_registry() {
  section "9.4  Container Registry"

  local reg_out
  reg_out=$(curl -sf http://gitlab.local:5050/v2/ 2>&1 || true)
  if [[ -n "$reg_out" ]]; then
    pass "Registry is up: $reg_out"
  else
    fail "Registry not responding on port 5050"
    info "Registry may still be starting; check: docker logs --tail 20 gitlab-ce | grep registry"
  fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# CHECK 9.2 – Runner Online & Tag Matching
# ═══════════════════════════════════════════════════════════════════════════════
check_runner_online() {
  section "9.5  Runner Registration"

  if ! cmd_ok docker inspect gitlab-runner > /dev/null 2>&1; then
    warn "gitlab-runner container not found – skipping runner checks"
    return
  fi

  # Check if runner process is alive inside the container
  if cmd_ok docker exec gitlab-runner gitlab-runner list 2>/dev/null; then
    pass "gitlab-runner process is running"
    docker exec gitlab-runner gitlab-runner list 2>/dev/null | while read -r line; do
      info "$line"
    done
  else
    fail "gitlab-runner process is NOT running inside the container"
    info "Try: docker restart gitlab-runner && sleep 5 && docker logs --tail 20 gitlab-runner"
  fi
}

check_runner_tags() {
  section "9.6  Runner Tags"

  local config_file="/tmp/runner-config-check.toml"
  docker exec gitlab-runner cat /etc/gitlab-runner/config.toml > "$config_file" 2>/dev/null || true

  if [[ -f "$config_file" ]]; then
    local tags
    tags=$(grep -A2 '\[runners' "$config_file" | grep 'tags' | awk -F'=' '{print $2}' | tr -d ' "')
    if [[ -n "$tags" ]]; then
      pass "Runner tags found: $tags"
      info "Jobs must have at least one of these tags: $tags"
    else
      warn "No tags found in runner config – runner may only run untagged jobs"
      info "To add tags, re-register: ./scripts/run-lab.sh 3"
    fi

    local locked paused
    locked=$(grep -i 'locked' "$config_file" | grep -v '^#' | head -1 || true)
    paused=$(grep -i 'paused' "$config_file" | grep -v '^#' | head -1 || true)

    if [[ -n "$locked" ]]; then
      warn "Runner is locked: $locked"
    fi
    if [[ -n "$paused" ]]; then
      fail "Runner is paused: $paused"
      info "Unpause: Admin Area → Runners → select runner → toggle Paused OFF"
    fi
  else
    fail "Cannot read runner config at /etc/gitlab-runner/config.toml"
  fi

  rm -f "$config_file"
}

# ═══════════════════════════════════════════════════════════════════════════════
# CHECK 9.3 – Docker Socket Permissions
# ═══════════════════════════════════════════════════════════════════════════════
check_docker_socket() {
  section "9.7  Docker Socket Permissions"

  if [[ -S /var/run/docker.sock ]]; then
    local socket_perms
    socket_perms=$(ls -la /var/run/docker.sock | awk '{print $1, $3, $4}')
    pass "Socket exists: $socket_perms"

    # Check docker group
    if groups | grep -q docker; then
      pass "Current user is in the docker group"
    else
      warn "Current user is NOT in the docker group"
      info "Run: sudo usermod -aG docker \$USER && newgrp docker"
    fi
  else
    fail "Docker socket not found at /var/run/docker.sock"
    info "Ensure Docker is running and the socket exists"
  fi

  # Check if socket is mounted into the runner
  local socket_mounted
  socket_mounted=$(docker inspect gitlab-runner 2>/dev/null | grep -c "docker.sock" || echo 0)
  if [[ "$socket_mounted" -gt 0 ]]; then
    pass "Docker socket is mounted into gitlab-runner"
  else
    fail "Docker socket NOT mounted into gitlab-runner"
    info "The runner needs /var/run/docker.sock:/var/run/docker.sock to run DinD jobs"
  fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# CHECK 9.4 – Registry Push Access
# ═══════════════════════════════════════════════════════════════════════════════
check_registry_push() {
  section "9.8  Registry Push Access (gitlab.local:5050)"

  # DNS from gitlab-net
  local dns_result
  dns_result=$(docker run --rm --network gitlab-net alpine:latest nslookup gitlab.local 2>&1 || true)
  if echo "$dns_result" | grep -q "Address"; then
    pass "DNS resolves gitlab.local from gitlab-net"
  else
    fail "DNS cannot resolve gitlab.local from inside gitlab-net"
    info "Check: docker network inspect gitlab-net | grep -A2 Containers"
  fi

  # Registry reachable from gitlab-net
  if docker run --rm --network gitlab-net alpine:latest wget -qO- http://gitlab.local:5050/v2/ > /dev/null 2>&1; then
    pass "Registry reachable from gitlab-net"
  else
    fail "Cannot reach registry from gitlab-net"
    info "Check: docker logs --tail 20 gitlab-ce | grep registry"
  fi

  # Registry catalog (if credentials are provided)
  if [[ -n "${GITLAB_PASSWORD:-}" ]]; then
    local catalog
    catalog=$(curl -sf -u "root:${GITLAB_PASSWORD}" http://gitlab.local:5050/v2/_catalog 2>&1 || echo "{}")
    pass "Registry catalog: $catalog"
  else
    info "Set GITLAB_PASSWORD env var to check registry catalog"
    info "  export GITLAB_PASSWORD='<your-password>'"
  fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# CHECK 9.5 – Deploy Target (SSH)
# ═══════════════════════════════════════════════════════════════════════════════
check_deploy_target() {
  section "9.9  Deploy Target (deploy-test)"

  if ! cmd_ok docker inspect deploy-test > /dev/null 2>&1; then
    warn "deploy-test container is NOT running"
    info "Create one with:"
    info "  docker run -d --name deploy-test --network gitlab-net -p 9090:80 nginx:alpine"
    return
  fi

  local deploy_status
  deploy_status=$(docker inspect --format='{{.State.Status}}' deploy-test)
  if [[ "$deploy_status" == "running" ]]; then
    pass "deploy-test container is running"

    # DNS from gitlab-net
    if docker run --rm --network gitlab-net alpine:latest getent hosts deploy-test > /dev/null 2>&1; then
      pass "deploy-test resolves from gitlab-net"
    else
      warn "deploy-test does NOT resolve from gitlab-net – check network"
    fi

    # Check if it has SSH (nginx:alpine does NOT)
    if docker exec deploy-test which sshd > /dev/null 2>&1; then
      pass "deploy-test has sshd"
    else
      warn "deploy-test does NOT have sshd (nginx:alpine has no SSH server)"
      info "For deploy stage, use a container with SSH (e.g., linuxserver/openssh-server)"
      info "  docker run -d --name deploy-test --network gitlab-net -p 2223:2222 \\"
      info "    -e USER_NAME=root -e USER_PASSWORD=rootpass \\"
      info "    lscr.io/linuxserver/openssh-server:latest"
    fi
  else
    fail "deploy-test is $deploy_status"
  fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# CHECK 9.7 – CI YAML Syntax
# ═══════════════════════════════════════════════════════════════════════════════
check_ci_yaml() {
  section "9.10  .gitlab-ci.yml Syntax"

  local ci_file
  ci_file="$(dirname "$0")/../gitlab-demo-project/.gitlab-ci.yml"
  if [[ ! -f "$ci_file" ]]; then
    ci_file="./gitlab-demo-project/.gitlab-ci.yml"
  fi

  if [[ ! -f "$ci_file" ]]; then
    warn ".gitlab-ci.yml not found in gitlab-demo-project/"
    return
  fi

  # Basic YAML checks
  if python3 -c "import yaml; yaml.safe_load(open('$ci_file'))" 2>/dev/null; then
    pass ".gitlab-ci.yml is valid YAML"
  else
    fail ".gitlab-ci.yml has YAML syntax errors"
    info "Validate online: https://gitlab.com/-/ide/project/gitlab-org/gitlab/-/blob/master/.gitlab-ci.yml"
  fi

  # Check for required keys
  local has_stages
  has_stages=$(python3 -c "import yaml; d=yaml.safe_load(open('$ci_file')); print('stages' in d)" 2>/dev/null || echo "false")
  if [[ "$has_stages" == "True" ]]; then
    pass "CI file has 'stages' defined"
  else
    warn "CI file may be missing 'stages:' key"
  fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# CHECK 9.8 – DinD Image Pull
# ═══════════════════════════════════════════════════════════════════════════════
check_dind_image() {
  section "9.11  Docker-in-Docker (DinD) Image"

  if cmd_ok docker inspect docker:24-dind > /dev/null 2>&1; then
    pass "docker:24-dind image is present locally"
  else
    warn "docker:24-dind image not pulled yet – runner will pull on first use"
    info "To pre-pull: docker pull docker:24-dind"
  fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# CHECK 9.10 – Memory & Disk
# ═══════════════════════════════════════════════════════════════════════════════
check_resources() {
  section "9.12  System Resources"

  # Memory
  local mem_info
  mem_info=$(free -h | awk '/^Mem:/ {print $2 " total, " $7 " available"}')
  if [[ -n "$mem_info" ]]; then
    if echo "$mem_info" | grep -qE "[4-9]|[0-9]{2,}G"; then
      pass "Memory: $mem_info"
    else
      warn "Memory may be low: $mem_info"
      info "GitLab needs ~4 GB; runner needs ~2 GB. Total: 6 GB recommended."
    fi
  fi

  # Disk
  local disk_info
  disk_info=$(df -h / | awk 'NR==2 {print $2 " total, " $4 " available on /"}')
  if [[ -n "$disk_info" ]]; then
    pass "Disk: $disk_info"
  fi

  # Docker disk usage
  local docker_size
  docker_size=$(docker system df --format '{{.Size}}' 2>/dev/null | head -1 || echo "unknown")
  pass "Docker disk usage: $docker_size"
}

# ═══════════════════════════════════════════════════════════════════════════════
# AUTO-FIX MODE
# ═══════════════════════════════════════════════════════════════════════════════
fix_common() {
  section "Auto-Fix Common Issues"

  echo "Attempting automatic fixes..."

  # Fix 1: Restart runner if it's not responding
  if ! cmd_ok docker exec gitlab-runner gitlab-runner list 2>/dev/null; then
    info "Restarting gitlab-runner..."
    docker restart gitlab-runner > /dev/null 2>&1 && pass "gitlab-runner restarted" || fail "Failed to restart gitlab-runner"
    sleep 3
  fi

  # Fix 2: Create deploy-test if missing
  if ! cmd_ok docker inspect deploy-test > /dev/null 2>&1; then
    info "Creating deploy-test container..."
    docker run -d \
      --name deploy-test \
      --network gitlab-net \
      -p 9090:80 \
      --restart unless-stopped \
      nginx:alpine > /dev/null 2>&1 && pass "deploy-test created" || fail "Failed to create deploy-test"
  fi

  # Fix 3: Pre-pull DinD image
  info "Pre-pulling docker:24-dind..."
  docker pull docker:24-dind > /dev/null 2>&1 && pass "docker:24-dind pulled" || warn "Could not pull docker:24-dind (check network)"

  # Fix 4: Verify /etc/hosts entry
  if ! grep -q "gitlab.local" /etc/hosts; then
    info "Adding gitlab.local to /etc/hosts (requires sudo)..."
    echo "127.0.0.1 gitlab.local" | sudo tee -a /etc/hosts > /dev/null 2>&1 && pass "gitlab.local added to /etc/hosts" || warn "Failed to modify /etc/hosts (run manually: sudo sh -c 'echo 127.0.0.1 gitlab.local >> /etc/hosts')"
  else
    pass "gitlab.local already in /etc/hosts"
  fi

  echo ""
  pass "Auto-fix complete. Run ./scripts/diagnose.sh again to verify."
}

# ═══════════════════════════════════════════════════════════════════════════════
# FULL RESET
# ═══════════════════════════════════════════════════════════════════════════════
full_reset() {
  section "FULL NUCLEAR RESET"

  echo -e "${RED}⚠  WARNING: This will destroy ALL GitLab data and settings!${RESET}"
  echo ""
  read -rp "Type YES to confirm: " confirm
  if [[ "$confirm" != "YES" ]]; then
    echo "Aborted."
    exit 0
  fi

  section "Stopping and removing containers"
  docker compose -f docker-compose.yml -f stacks/gitlab/docker-compose.yml down -v 2>/dev/null && pass "Containers stopped" || warn "No containers to stop"

  section "Removing local volume directories"
  rm -rf volumes/ && pass "volumes/ directory removed" || warn "Could not remove volumes/"
  rm -rf stacks/gitlab/runner-config stacks/gitlab/runner-cache && pass "Runner config removed" || true

  section "Restarting fresh"
  ./scripts/run-lab.sh 2
  echo ""
  echo -e "${GREEN}✅  Reset complete! GitLab is starting up (may take 5–10 minutes).${RESET}"
  info "Run ./scripts/diagnose.sh --quick to monitor startup progress."
}

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════════
main() {
  echo ""
  echo -e "${BOLD}╔══════════════════════════════════════════════════╗${RESET}"
  echo -e "${BOLD}║     GitLab Local Stack – Diagnostic Script      ║${RESET}"
  echo -e "${BOLD}╚══════════════════════════════════════════════════╝${RESET}"

  # Load .env if present
  if [[ -f .env ]]; then
    set -a
    source .env
    set +a
  fi

  case "$MODE" in
    --quick|-q)
      check_containers
      check_web_health
      check_api
      check_registry
      ;;

    --fix|-f)
      fix_common
      ;;

    --reset|--nuke)
      full_reset
      ;;

    full|*)
      check_containers
      check_web_health
      check_api
      check_registry
      check_runner_online
      check_runner_tags
      check_docker_socket
      check_registry_push
      check_deploy_target
      check_ci_yaml
      check_dind_image
      check_resources
      ;;

    --help|-h)
      echo ""
      echo "Usage: $0 [mode]"
      echo ""
      echo "Modes:"
      echo "  (none)       Full diagnostic – all 12 health checks"
      echo "  --quick, -q  Quick check – containers + web/API/registry only"
      echo "  --fix,  -f   Attempt automatic fixes for common issues"
      echo "  --reset      Nuclear reset – destroys all data, restarts fresh"
      echo "  --help, -h   Show this help"
      echo ""
      exit 0
      ;;
  esac

  echo ""
  echo -e "${BOLD}━━━  Summary  ━━━${RESET}"
  echo "Run './scripts/diagnose.sh --help' for usage."
  echo "Run './scripts/diagnose.sh --fix' to auto-fix common issues."
  echo "Run './scripts/diagnose.sh --reset' to start completely fresh."
  echo ""
}

main "$@"
