#!/usr/bin/env bash
set -euo pipefail

dart run bin/migrate.dart
exec dart run build/bin/server.dart
