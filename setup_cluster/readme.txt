Setup: local Valkey Cluster (six nodes — three primaries + three replicas)
==============================================================================

Dependencies
------------
• A built Valkey source tree with src/valkey-server and src/valkey-cli (run make
  in your Valkey repo).
• bash

Configuration lives in cluster_config.sh (ports, hosts, timeouts). Node server
directives come from valkey.conf.template. Each running instance writes
CLUSTER_DATA_DIR/<port>/valkey.conf at start (default CLUSTER_DATA_DIR is ./data).


Start and form the cluster
--------------------------
From this directory:

  ./create_valkey_cluster.sh /path/to/valkey start
  ./create_valkey_cluster.sh /path/to/valkey create

Or set VALKEY_DIR:

  export VALKEY_DIR=/path/to/valkey
  ./create_valkey_cluster.sh start
  ./create_valkey_cluster.sh create

"start" launches one Valkey server per configured port under CLUSTER_DATA_DIR.
"create" waits until every instance answers PING, then runs valkey-cli
--cluster create with one replica per primary.

After "create", you should see cluster_state:ok in cluster info.


Check cluster status
--------------------

  ./create_valkey_cluster.sh /path/to/valkey status

Or use valkey-cli directly (host/port from cluster_config.sh, often 127.0.0.1:7000):

  /path/to/valkey/src/valkey-cli -h HOST -p PORT cluster info
  /path/to/valkey/src/valkey-cli -h HOST -p PORT cluster nodes

Use "valkey-cli -c" for normal key commands so MOVED redirections follow the cluster.


Stop servers
------------

  ./create_valkey_cluster.sh /path/to/valkey stop

Sends SHUTDOWN NOSAVE to each configured instance.


Clean local data
----------------

  ./create_valkey_cluster.sh /path/to/valkey clean

"clean" removes files under CLUSTER_DATA_DIR only; it does not stop servers.
If nodes are still running, run "stop" first, then "clean" for a safe reset.

Full reset workflow: stop → clean → start → create
