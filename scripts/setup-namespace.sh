#!/usr/bin/env bash
# setup-namespace.sh - Registers the 'default' namespace in Temporal if it does not exist.
# Called by subcommands/start after the container is ready.
# Usage: setup-namespace.sh <container_name>
set -eo pipefail
[[ $DOKKU_TRACE ]] && set -x

CONTAINER_NAME="${1:-}"

if [[ -z "$CONTAINER_NAME" ]]; then
  echo "Usage: $0 <container_name>" >&2
  exit 1
fi

# Detect docker binary
if [[ -z "${DOCKER_BIN:-}" ]]; then
  if command -v nerdctl &>/dev/null; then
    DOCKER_BIN="nerdctl"
  else
    DOCKER_BIN="docker"
  fi
fi

# Resolve container IP for tctl --address
CONTAINER_IP="$($DOCKER_BIN inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$CONTAINER_NAME" 2>/dev/null || echo "")"
TCTL_ADDR="${CONTAINER_IP:+--address ${CONTAINER_IP}:7233}"

echo "-----> Ensuring 'default' namespace exists..."

# Check if the namespace already exists
if $DOCKER_BIN exec "$CONTAINER_NAME" tctl $TCTL_ADDR --namespace default namespace describe &>/dev/null 2>&1; then
  echo "       Namespace 'default' already exists"
  exit 0
fi

# Register the default namespace
if $DOCKER_BIN exec "$CONTAINER_NAME" tctl $TCTL_ADDR --namespace default namespace register 2>&1; then
  echo "       Namespace 'default' registered"
else
  echo "!      Failed to register 'default' namespace (may already exist or service not ready)" >&2
  # Non-fatal: do not exit with error, the namespace may have been auto-created
fi
