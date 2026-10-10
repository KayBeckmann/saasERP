#!/usr/bin/env bash
set -euo pipefail

dart run bin/migrate.dart
# Independent daily UTC worker; does not rely on incoming authenticated requests.
dart run bin/order_subscription_scheduler.dart &
scheduler_pid=$!
dart run build/bin/server.dart &
server_pid=$!
cleanup() {
  trap - EXIT TERM INT
  kill "$scheduler_pid" "$server_pid" 2>/dev/null || true
  wait "$scheduler_pid" "$server_pid" 2>/dev/null || true
}
trap cleanup EXIT TERM INT
# Restart the container if either the API or the billing worker exits.
wait -n "$server_pid" "$scheduler_pid"
