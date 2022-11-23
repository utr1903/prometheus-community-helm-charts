#!/bin/bash

# Get commandline arguments
while (( "$#" )); do
  case "$1" in
    --deployment)
      deployment="$2"
      shift
      ;;
    --deployment-namespace)
      deploymentNamespace="$2"
      shift
      ;;
    --cluster)
      cluster="$2"
      shift
      ;;
    --newrelic-region)
      newrelicRegion="$2"
      shift
      ;;
    --kube-state-metrics)
      kubeStateMetricsEnabled="$2"
      shift
      ;;
    --node-exporter)
      nodeExporterEnabled="$2"
      shift
      ;;
    *)
      shift
      ;;
  esac
done

### Check input

# New Relic license key
if [[ $NEWRELIC_LICENSE_KEY == "" ]]; then
  echo "Define New Relic license key as an environment variable [NEWRELIC_LICENSE_KEY]. For example: -> export NEWRELIC_LICENSE_KEY=xxx"
  exit 1
fi

# Deployment name
if [[ $deployment == "" ]]; then
  echo "Define deployment name with the flag [--deployment]. For example: -> prometheus"
  exit 1
fi

# Deployment namespace
if [[ $deploymentNamespace == "" ]]; then
  echo "Define deployment namespace name with the flag [--deployment-namespace]. For example -> monitoring"
  exit 1
fi

# Cluster name
if [[ $cluster == "" ]]; then
  echo "Define cluster name with the flag [--cluster]. For example -> <mydopeclusterprod>"
  exit 1
fi

# New Relic region
if [[ $newrelicRegion == "" ]]; then
  echo "Define New Relic region with the flag [--newrelicRegion]. For example: -> 'us' or 'eu'"
  exit 1
else
  if [[ $newrelicRegion != "us" && $newrelicRegion != "eu" ]]; then
    echo "New Relic region can either be 'us' or 'eu'."
    exit 1
  fi

  if [[ $newrelicRegion == "us" ]]; then
    newrelicPrometheusEndpoint="https://metric-api.newrelic.com/prometheus/v1/write?prometheus_server=${cluster}"
  else
    newrelicPrometheusEndpoint="https://metric-api.eu.newrelic.com/prometheus/v1/write?prometheus_server=${cluster}"
  fi
fi

# Enable kube-state-metrics
if [[ $kubeStateMetricsEnabled == "true" ]]; then
  kubeStateMetricsEnabled="true"
else
  kubeStateMetricsEnabled="false"
fi

# Enable node-exporter
if [[ $nodeExporterEnabled == "true" ]]; then
  nodeExporterEnabled="true"
else
  nodeExporterEnabled="false"
fi

### Helm deployment

# Update Helm dependencies
helm dependency update "../."

# Install / upgrade Helm deployment
helm upgrade $deployment \
  --install \
  --wait \
  --debug \
  --create-namespace \
  --namespace $deploymentNamespace \
  --set kubeStateMetrics.enabled=$kubeStateMetricsEnabled \
  --set prometheus-node-exporter.enabled=$nodeExporterEnabled \
  --set alertmanager.enabled="false" \
  --set prometheus-pushgateway.enabled="false" \
  --set server.defaultFlagsOverride[0]="--enable-feature=agent" \
  --set server.defaultFlagsOverride[1]="--storage.agent.retention.max-time=30m" \
  --set server.defaultFlagsOverride[2]="--config.file=/etc/config/prometheus.yml" \
  --set serverFiles."prometheus\.yml".rule_files=null \
  --set server.remoteWrite[0].url=$newrelicPrometheusEndpoint \
  --set server.remoteWrite[0].bearer_token=$NEWRELIC_LICENSE_KEY \
  "../."
