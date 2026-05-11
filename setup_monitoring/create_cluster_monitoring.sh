#!/usr/bin/env bash


echo "Creating cluster"
docker run -d --name valkey -p 6379:6379 valkey/valkey:latest

echo "Creating monitoring"
docker run -d --name redis-exporter -p 9121:9121 oliver006/redis_exporter:latest

echo "Creating prometheus"
docker run -d --name prometheus -p 9090:9090 prom/prometheus

echo "Creating grafana"
docker run -d --name grafana -p 3000:3000 grafana/grafana