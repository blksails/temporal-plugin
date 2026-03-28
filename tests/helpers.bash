#!/usr/bin/env bash
# tests/helpers.bash - Test helper functions for temporal plugin BATS tests

# ---------------------------------------------------------------------------
# Environment setup
# ---------------------------------------------------------------------------

# Ensure TEST_TMP is set (each test file can override before sourcing)
: "${TEST_TMP:=/tmp/dokku-temporal-test-$$}"

# Plugin directory (two levels up from tests/)
PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ---------------------------------------------------------------------------
# setup / teardown
# ---------------------------------------------------------------------------

setup() {
  # Create isolated temporary DOKKU_LIB_ROOT
  export TEST_TMP
  mkdir -p "$TEST_TMP"

  # Override DOKKU_LIB_ROOT so all scripts use the test directory
  export DOKKU_LIB_ROOT="$TEST_TMP/lib"
  mkdir -p "$DOKKU_LIB_ROOT/services/temporal"

  export PLUGIN_BASE_PATH="$DOKKU_LIB_ROOT/services/temporal"

  # Put mock binaries first in PATH
  export MOCK_BIN="$TEST_TMP/bin"
  mkdir -p "$MOCK_BIN"
  mock_docker
  mock_dokku
  export PATH="$MOCK_BIN:$PATH"

  # Export remaining plugin vars (sourced from config in scripts, but useful directly)
  export PLUGIN_COMMAND_PREFIX="temporal"
  export PLUGIN_SERVICE="Temporal"
  export PLUGIN_IMAGE="temporalio/auto-setup"
  export PLUGIN_IMAGE_VERSION="1.25.2"
  export PLUGIN_UI_IMAGE="temporalio/ui"
  export PLUGIN_UI_IMAGE_VERSION="2.32.0"
  export PLUGIN_SCHEME="temporal"
  export DOCKER_BIN="$MOCK_BIN/docker"
}

teardown() {
  rm -rf "$TEST_TMP"
  unset DOKKU_LIB_ROOT PLUGIN_BASE_PATH MOCK_BIN
}

# ---------------------------------------------------------------------------
# mock_docker — write a fake docker binary to $MOCK_BIN
# ---------------------------------------------------------------------------

mock_docker() {
  cat > "$MOCK_BIN/docker" <<'MOCK'
#!/usr/bin/env bash
# Mock docker binary for temporal plugin tests
CMD="${1:-}"
shift || true

case "$CMD" in
  inspect)
    # inspect: default exit 1 (container/network not found)
    # Callers check $? or use &>/dev/null
    exit 1
    ;;
  network)
    # network inspect: pretend network doesn't exist
    exit 1
    ;;
  ps)
    echo ""
    exit 0
    ;;
  run)
    # docker run: succeed silently (wait container, UI container etc.)
    echo "mock-container-id"
    exit 0
    ;;
  create)
    echo "mock-container-id-$(date +%s)"
    exit 0
    ;;
  start)
    exit 0
    ;;
  stop)
    exit 0
    ;;
  rm)
    exit 0
    ;;
  logs)
    echo "[mock] no logs available"
    exit 0
    ;;
  exec)
    exit 0
    ;;
  *)
    exit 0
    ;;
esac
MOCK
  chmod +x "$MOCK_BIN/docker"
}

# ---------------------------------------------------------------------------
# mock_dokku — write a fake dokku binary to $MOCK_BIN
# ---------------------------------------------------------------------------

mock_dokku() {
  cat > "$MOCK_BIN/dokku" <<'MOCK'
#!/usr/bin/env bash
# Mock dokku binary for temporal plugin tests
CMD="${1:-}"
shift || true

case "$CMD" in
  config:set)
    # Record env vars set into a state file keyed by app
    # Format: config:set [--no-restart] <app> KEY=VAL ...
    NO_RESTART=false
    if [[ "${1:-}" == "--no-restart" ]]; then
      NO_RESTART=true
      shift
    fi
    APP="${1:-}"
    shift || true
    STATE_FILE="${MOCK_STATE_DIR:-/tmp}/${APP}.env"
    mkdir -p "$(dirname "$STATE_FILE")"
    for pair in "$@"; do
      KEY="${pair%%=*}"
      VAL="${pair#*=}"
      # Write/update the key in the state file
      if [[ -f "$STATE_FILE" ]]; then
        grep -v "^${KEY}=" "$STATE_FILE" > "${STATE_FILE}.tmp" 2>/dev/null || true
        mv "${STATE_FILE}.tmp" "$STATE_FILE"
      fi
      echo "${KEY}=${VAL}" >> "$STATE_FILE"
    done
    exit 0
    ;;
  config:unset)
    # Remove env vars from state file
    if [[ "${1:-}" == "--no-restart" ]]; then
      shift
    fi
    APP="${1:-}"
    shift || true
    STATE_FILE="${MOCK_STATE_DIR:-/tmp}/${APP}.env"
    if [[ -f "$STATE_FILE" ]]; then
      for KEY in "$@"; do
        grep -v "^${KEY}=" "$STATE_FILE" > "${STATE_FILE}.tmp" 2>/dev/null || true
        mv "${STATE_FILE}.tmp" "$STATE_FILE"
      done
    fi
    exit 0
    ;;
  config:show)
    APP="${1:-}"
    STATE_FILE="${MOCK_STATE_DIR:-/tmp}/${APP}.env"
    if [[ -f "$STATE_FILE" ]]; then
      while IFS='=' read -r key val; do
        echo "${key}: ${val}"
      done < "$STATE_FILE"
    fi
    exit 0
    ;;
  config:get)
    APP="${1:-}"
    KEY="${2:-}"
    STATE_FILE="${MOCK_STATE_DIR:-/tmp}/${APP}.env"
    if [[ -f "$STATE_FILE" ]]; then
      grep "^${KEY}=" "$STATE_FILE" | cut -d= -f2- 2>/dev/null || true
    fi
    exit 0
    ;;
  apps:exists)
    # Treat any app name as existing
    exit 0
    ;;
  temporal:start)
    # Mock temporal:start — do nothing (service already set up by fixture)
    exit 0
    ;;
  *)
    exit 0
    ;;
esac
MOCK
  chmod +x "$MOCK_BIN/dokku"
}

# ---------------------------------------------------------------------------
# helper: init_mock_state
# Call in setup() after mock_dokku when you need per-app env var tracking.
# ---------------------------------------------------------------------------
init_mock_state() {
  export MOCK_STATE_DIR="$TEST_TMP/state"
  mkdir -p "$MOCK_STATE_DIR"
}

# ---------------------------------------------------------------------------
# helper: create_service_fixture
# Creates a minimal service directory for a given service name, simulating
# what subcommands/create would produce.
# ---------------------------------------------------------------------------

create_service_fixture() {
  local service="$1"
  local service_root="$PLUGIN_BASE_PATH/$service"

  mkdir -p "$service_root"
  chmod 700 "$service_root"

  echo "temporalio/auto-setup"  > "$service_root/IMAGE"
  echo "1.25.2"                 > "$service_root/IMAGE_VERSION"
  echo "7233"                   > "$service_root/PORT"
  echo "8233"                   > "$service_root/UI_PORT"
  touch                           "$service_root/LINKS"

  chmod 640 "$service_root/IMAGE"
  chmod 640 "$service_root/IMAGE_VERSION"
  chmod 640 "$service_root/PORT"
  chmod 640 "$service_root/UI_PORT"
  chmod 640 "$service_root/LINKS"
}

# ---------------------------------------------------------------------------
# helper: run_subcommand
# Runs a plugin subcommand with the test environment sourced.
# ---------------------------------------------------------------------------

run_subcommand() {
  local subcmd="$1"
  shift
  bash "$PLUGIN_DIR/subcommands/$subcmd" "$@"
}
