# Local Valkey cluster settings — sourced by create_valkey_cluster.sh.
# Env vars set before invoking the script still win (${VAR:-default}).
#
# For data directory default (<script-dir>/data), omit CLUSTER_DATA_DIR or set explicitly.

CLUSTER_HOST="${CLUSTER_HOST:-127.0.0.1}"
BASE_PORT="${BASE_PORT:-7000}"

# 3 primaries + 3 replicas with CLUSTER_REPLICAS=1 ⇒ 6 nodes
NUM_MASTERS="${NUM_MASTERS:-3}"
NUM_NODES="${NUM_NODES:-6}"
CLUSTER_REPLICAS="${CLUSTER_REPLICAS:-1}"

PROTECTED_MODE="${PROTECTED_MODE:-yes}"
CLUSTER_NODE_TIMEOUT="${CLUSTER_NODE_TIMEOUT:-2000}"

# Optional explicit state dir for logs / nodes-*.conf / RDB / AOF
# CLUSTER_DATA_DIR="/tmp/valkey-cluster-dev"
