#!/bin/sh

echo "[gateway] waiting for upstreams.conf to have all 3 backend servers..."

MAX_RETRIES=30
RETRY_INTERVAL=2

for i in $(seq 1 $MAX_RETRIES); do
    if grep -q "api-1" /etc/nginx/conf.d/upstreams.conf 2>/dev/null && \
       grep -q "api-2" /etc/nginx/conf.d/upstreams.conf 2>/dev/null && \
       grep -q "api-3" /etc/nginx/conf.d/upstreams.conf 2>/dev/null; then
        echo "[gateway] upstreams.conf is ready with all 3 servers"
        exec nginx -g 'daemon off;'
    fi
    echo "[gateway] waiting... ($i/$MAX_RETRIES)"
    sleep $RETRY_INTERVAL
done

echo "[gateway] WARNING: upstreams.conf not ready after $MAX_RETRIES retries, starting anyway"
exec nginx -g 'daemon off;'