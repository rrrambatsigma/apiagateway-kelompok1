#!/bin/bash

set -e

CONTAINER_NAME="${1:-gateway}"

echo "==================================================================="
echo "Gateway Log Analysis"
echo "==================================================================="
echo ""

LOGS=$(docker logs "$CONTAINER_NAME" 2>&1)

echo "📊 Request Statistics:"
echo "-------------------------------------------------------------------"

TOTAL=$(echo "$LOGS" | grep -c '"request_method"' || echo "0")
echo "Total Requests: $TOTAL"

echo ""
echo "Status Codes:"
echo "$LOGS" | grep '"status"' | grep -oP '"status":\K[0-9]+' | sort | uniq -c | sort -rn | while read count status; do
    echo "  $status: $count requests"
done

echo ""
RATE_LIMITED=$(echo "$LOGS" | grep -c '"status":429' || echo "0")
echo "Rate Limited (429): $RATE_LIMITED requests"

echo ""
AUTH_401=$(echo "$LOGS" | grep -c '"status":401' || echo "0")
AUTH_403=$(echo "$LOGS" | grep -c '"status":403' || echo "0")
echo "Auth Errors:"
echo "  401 Unauthorized: $AUTH_401"
echo "  403 Forbidden: $AUTH_403"

echo ""
SERVER_ERROR=$(echo "$LOGS" | grep -cP '"status":5\d{2}' || echo "0")
echo "Server Errors (5xx): $SERVER_ERROR"

echo ""
echo "🔗 Upstream Statistics:"
echo "-------------------------------------------------------------------"

AVG_TIME=$(echo "$LOGS" | grep -oP '"request_time":\K[0-9.]+' | awk '{sum+=$1; count++} END {if(count>0) print sum/count; else print 0}')
echo "Average Request Time: ${AVG_TIME}s"

AVG_UPSTREAM=$(echo "$LOGS" | grep -oP '"upstream_response_time":"?\K[0-9.]+' | awk '{sum+=$1; count++} END {if(count>0) print sum/count; else print 0}')
echo "Average Upstream Time: ${AVG_UPSTREAM}s"

echo ""
echo "Top Upstream Servers:"
echo "$LOGS" | grep -oP '"upstream_addr":"\K[^"]+' | sort | uniq -c | sort -rn | head -5 | while read count addr; do
    echo "  $addr: $count requests"
done

echo ""
echo "📍 Top Endpoints:"
echo "-------------------------------------------------------------------"
echo "$LOGS" | grep -oP '"request_uri":"\K[^"]+' | sort | uniq -c | sort -rn | head -10 | while read count uri; do
    echo "  $uri: $count requests"
done

echo ""
echo "🌐 Top Client IPs:"
echo "-------------------------------------------------------------------"
echo "$LOGS" | grep -oP '"remote_addr":"\K[^"]+' | sort | uniq -c | sort -rn | head -10 | while read count ip; do
    echo "  $ip: $count requests"
done

echo ""
echo "==================================================================="
