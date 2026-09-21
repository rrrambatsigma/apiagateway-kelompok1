#!/bin/bash

set -e

CONTAINER_NAME="${1:-gateway}"
FILTER="${2}"

echo "==================================================================="
echo "Gateway Log Viewer - Container: $CONTAINER_NAME"
echo "==================================================================="
echo ""

if [ -z "$FILTER" ]; then
    echo "Showing all logs (JSON formatted)..."
    echo ""
    docker logs -f "$CONTAINER_NAME" 2>&1 | while IFS= read -r line; do
        echo "$line" | jq -C '.' 2>/dev/null || echo "$line"
    done
else
    echo "Filtering logs for: $FILTER"
    echo ""
    docker logs -f "$CONTAINER_NAME" 2>&1 | grep --line-buffered "$FILTER" | while IFS= read -r line; do
        echo "$line" | jq -C '.' 2>/dev/null || echo "$line"
    done
fi
