Setup: Integrated Valkey cluster with monitoring
cluster → redis_exporter → prometheus → grafana
==============================================================================

OVERVIEW
--------
This setup creates a complete monitoring pipeline:
1. Valkey cluster (6 nodes: 3 primaries + 3 replicas) from setup_cluster
2. Redis exporter instances (one per node) scraping metrics
3. Prometheus collecting metrics from all exporters
4. Grafana visualizing Prometheus data

PREREQUISITES
-------------
• Docker installed and running
• Valkey source tree with built binaries (src/valkey-server, src/valkey-cli)
• bash

QUICK START
-----------
1. Start cluster and all monitoring services:
   ./create_cluster_monitoring.sh /path/to/valkey start

2. Create the cluster (after servers are ready):
   ./create_cluster_monitoring.sh /path/to/valkey create

3. Access the services:
   - Prometheus: http://localhost:9090
   - Grafana:    http://localhost:3000 (admin/admin)

FULL COMMAND REFERENCE
----------------------

./create_cluster_monitoring.sh [<valkey-dir>] <command>

Commands:
  start    Start Valkey cluster + redis-exporters + Prometheus + Grafana
  create   Create cluster topology (run after start, once servers respond)
  stop     Stop all services (keeps data)
  restart  Stop and restart all services
  clean    Remove all data and containers
  status   Check cluster and services status

Examples:
  ./create_cluster_monitoring.sh /path/to/valkey start
  ./create_cluster_monitoring.sh /path/to/valkey create
  ./create_cluster_monitoring.sh stop
  ./create_cluster_monitoring.sh status
  VALKEY_DIR=/path/to/valkey ./create_cluster_monitoring.sh start

CONFIGURATION
--------------
Cluster settings (from setup_cluster/cluster_config.sh):
  CLUSTER_HOST: 127.0.0.1
  BASE_PORT: 7000
  NUM_NODES: 6 (3 primaries + 3 replicas)

Monitoring defaults (override via environment):
  EXPORTER_BASE_PORT: 9200 (exporters run at 9200-9205)
  PROMETHEUS_PORT: 9090
  GRAFANA_PORT: 3000
  MONITORING_DATA_DIR: ./config (Prometheus config + data)

Example with custom ports:
  PROMETHEUS_PORT=9999 GRAFANA_PORT=3333 \
    ./create_cluster_monitoring.sh /path/to/valkey start

GRAFANA SETUP
-------------
1. Open http://localhost:3000 in browser
2. Login with admin/admin
3. Add Prometheus datasource:
   - Go to: Connections → Data sources → New data source
   - Select: Prometheus
   - URL: http://localhost:9090
   - Click: Save & test
4. Create dashboards or import existing Redis/Valkey dashboards

PROMETHEUS TARGETS
------------------
After start, Prometheus automatically scrapes:
  redis_node_7000  →  redis-exporter on :9200
  redis_node_7001  →  redis-exporter on :9201
  redis_node_7002  →  redis-exporter on :9202
  redis_node_7003  →  redis-exporter on :9203
  redis_node_7004  →  redis-exporter on :9204
  redis_node_7005  →  redis-exporter on :9205

View targets at: http://localhost:9090/targets

View Prometheus config: ./config/prometheus.yml

TROUBLESHOOTING
---------------
Issue: Exporters fail to start
  - Ensure Valkey cluster is running: check ports 7000-7005
  - Check Docker logs: docker logs redis-exporter-7000

Issue: Prometheus has no targets
  - Wait 15-30 seconds for first scrape interval
  - Check: http://localhost:9090/config (verify prometheus.yml)
  - Verify exporters are running: docker ps | grep redis-exporter

Issue: Grafana can't connect to Prometheus
  - Check datasource URL uses: http://localhost:9090 (NOT 127.0.0.1)
  - Verify Prometheus is accessible: curl http://localhost:9090/-/healthy

CLEANUP
-------
Stop all services and remove data:
  ./create_cluster_monitoring.sh clean

This removes:
  - Valkey cluster data (./setup_cluster/data)
  - Monitoring config (./config)
  - All Docker containers (redis-exporters, prometheus, grafana)

GENERATGE TRAFFIC
-------
./src/valkey-benchmark --cluster \
  -h localhost \
  -p 7000 \
  -c 100 \
  -n 1000000 \
  -d 512 \
  -t get,set \
  -r 100000

