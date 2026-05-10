#!/usr/bin/env bash
# Start and create a local Valkey cluster: 3 primaries + 3 replicas (6 nodes,
# one replica per primary — typical HA baseline).
# Requires a built Valkey tree (src/valkey-server and src/valkey-cli).
#
# Usage:
#   ./create_valkey_cluster.sh /path/to/valkey start
#   ./create_valkey_cluster.sh /path/to/valkey create
#   ./create_valkey_cluster.sh /path/to/valkey stop
#   ./create_valkey_cluster.sh /path/to/valkey clean   # data only — run stop first if nodes are up
#
# Or set VALKEY_DIR and omit the path:
#   VALKEY_DIR=/path/to/valkey ./create_valkey_cluster.sh start
#
# Defaults live in cluster_config.sh (alongside this script). Override via env vars
# or edit that file. CLUSTER_DATA_DIR defaults to <this-dir>/data if unset.
#
# Each node runs from <CLUSTER_DATA_DIR>/<port>/ using valkey.conf generated from
# valkey.conf.template (override path with VALKEY_CONF_TEMPLATE).
#
# CLUSTER_READY_TIMEOUT seconds to wait for PING before cluster create (default 120).

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
CLUSTER_CONFIG="${CLUSTER_CONFIG:-$SCRIPT_DIR/cluster_config.sh}"

if [[ ! -f "$CLUSTER_CONFIG" ]]; then
  echo "error: cluster config file not found: $CLUSTER_CONFIG" >&2
  echo "hint: CLUSTER_CONFIG=/path/to/config.sh $0 ..." >&2
  exit 1
fi
# shellcheck source=cluster_config.sh
source "$CLUSTER_CONFIG"

CLUSTER_DATA_DIR="${CLUSTER_DATA_DIR:-$SCRIPT_DIR/data}"

if [[ -n "${1:-}" && -d "$1" && -x "$1/src/valkey-server" ]]; then
  VALKEY_DIR="$(cd -- "$1" && pwd)"
  shift
fi

VALKEY_DIR="${VALKEY_DIR:-}"
CMD="${1:-}"

usage() {
  cat <<EOF
Usage:
  $(basename "$0") [<valkey-dir>] <start|create|stop|restart|clean|status>

<valkey-dir> must contain built binaries at src/valkey-server and src/valkey-cli.
Cluster layout: ${NUM_MASTERS} masters + $((NUM_NODES - NUM_MASTERS)) replicas (${NUM_NODES} nodes),
ports ${BASE_PORT}-$((BASE_PORT + NUM_NODES - 1)), created with --cluster-replicas ${CLUSTER_REPLICAS}.

Environment:
  VALKEY_DIR, CLUSTER_CONFIG, VALKEY_CONF_TEMPLATE — plus cluster_config.sh (CLUSTER_HOST, …)
EOF
}

if [[ -z "$CMD" ]]; then
  usage
  exit 1
fi

if [[ -z "$VALKEY_DIR" ]]; then
  echo "error: set VALKEY_DIR or pass <valkey-dir> as the first argument." >&2
  usage
  exit 1
fi

# Nodes start with cwd=<data>/<port>; VALKEY_* must be absolute so exec finds the binaries.
VALKEY_DIR="$(cd -- "$VALKEY_DIR" && pwd)"
VALKEY_SERVER="$VALKEY_DIR/src/valkey-server"
VALKEY_CLI="$VALKEY_DIR/src/valkey-cli"

for b in "$VALKEY_SERVER" "$VALKEY_CLI"; do
  if [[ ! -x "$b" ]]; then
    echo "error: missing or not executable: $b (build Valkey with 'make' first)." >&2
    exit 1
  fi
done

mkdir -p "$CLUSTER_DATA_DIR"
CLUSTER_DATA_DIR="$(cd -- "$CLUSTER_DATA_DIR" && pwd)"
LAST_PORT=$((BASE_PORT + NUM_NODES - 1))

VALKEY_CONF_TEMPLATE="${VALKEY_CONF_TEMPLATE:-$SCRIPT_DIR/valkey.conf.template}"

write_node_valkey_conf() {
  local port=$1
  local datadir="$CLUSTER_DATA_DIR/$port" line
  if [[ ! -f "$VALKEY_CONF_TEMPLATE" ]]; then
    echo "error: missing valkey config template: $VALKEY_CONF_TEMPLATE" >&2
    exit 1
  fi
  mkdir -p "$datadir"
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line//@PORT@/$port}"
    line="${line//@CLUSTER_HOST@/$CLUSTER_HOST}"
    line="${line//@PROTECTED_MODE@/$PROTECTED_MODE}"
    line="${line//@CLUSTER_NODE_TIMEOUT@/$CLUSTER_NODE_TIMEOUT}"
    printf '%s\n' "$line"
  done <"$VALKEY_CONF_TEMPLATE" >"$datadir/valkey.conf"
}

start_servers() {
  local port
  for ((port = BASE_PORT; port <= LAST_PORT; port++)); do
    write_node_valkey_conf "$port"
    echo "Starting $CLUSTER_HOST:$port (config $CLUSTER_DATA_DIR/$port/valkey.conf)"
    (cd "$CLUSTER_DATA_DIR/$port" && exec "$VALKEY_SERVER" ./valkey.conf)
  done
}

stop_servers() {
  local port
  for ((port = BASE_PORT; port <= LAST_PORT; port++)); do
    echo "Stopping $CLUSTER_HOST:$port"
    "$VALKEY_CLI" -h "$CLUSTER_HOST" -p "$port" shutdown nosave 2>/dev/null || true
  done
}

wait_for_servers() {
  local port deadline=$((SECONDS + ${CLUSTER_READY_TIMEOUT:-120}))
  for ((port = BASE_PORT; port <= LAST_PORT; port++)); do
    while true; do
      if "$VALKEY_CLI" -h "$CLUSTER_HOST" -p "$port" ping 2>/dev/null | grep -q PONG; then
        echo "Ready $CLUSTER_HOST:$port"
        break
      fi
      if (( SECONDS >= deadline )); then
        echo "error: Valkey did not respond on $CLUSTER_HOST:$port within ${CLUSTER_READY_TIMEOUT:-120}s (see $CLUSTER_DATA_DIR/$port/valkey.log)." >&2
        exit 1
      fi
      sleep 0.2
    done
  done
}

create_cluster() {
  local -a nodes=()
  local port
  for ((port = BASE_PORT; port <= LAST_PORT; port++)); do
    nodes+=("$CLUSTER_HOST:$port")
  done

  echo "Waiting for all instances to reply to PING..."
  wait_for_servers

  echo "Creating cluster (--cluster-replicas ${CLUSTER_REPLICAS}): ${nodes[*]}"
  "$VALKEY_CLI" --cluster-yes --cluster create "${nodes[@]}" --cluster-replicas "$CLUSTER_REPLICAS"

  echo "Done. Cluster nodes:"
  "$VALKEY_CLI" -h "$CLUSTER_HOST" -p "$BASE_PORT" cluster nodes
}

clean_data() {
  local port
  for ((port = BASE_PORT; port <= LAST_PORT; port++)); do
    rm -rf "${CLUSTER_DATA_DIR:?}/$port"
  done
  # Legacy flat layout (older script revisions)
  (
    cd "$CLUSTER_DATA_DIR"
    rm -f ./*.log
    rm -rf ./appendonlydir-*
    rm -f ./dump-*.rdb
    rm -f ./nodes-*.conf
  )
  echo "Cleaned per-node dirs under $CLUSTER_DATA_DIR (+ legacy flat files if present)"
}

case "$CMD" in
start)
  start_servers
  ;;
create)
  create_cluster
  ;;
stop)
  stop_servers
  ;;
restart)
  stop_servers
  sleep 1
  start_servers
  ;;
clean)
  clean_data
  ;;
status)
  "$VALKEY_CLI" -h "$CLUSTER_HOST" -p "$BASE_PORT" cluster info 2>/dev/null ||
    echo "Cluster not responding on $CLUSTER_HOST:$BASE_PORT"
  "$VALKEY_CLI" -h "$CLUSTER_HOST" -p "$BASE_PORT" cluster nodes 2>/dev/null || true
  ;;
*)
  usage
  exit 1
  ;;
esac
