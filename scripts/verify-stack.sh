#!/bin/bash
# verify-stack.sh

DROPLET_IP="${1:?Usage: $0 <droplet-ip>}"
SSH_USER="boutique"

echo "→ Verifying stack on ${DROPLET_IP}..."

ssh ${SSH_USER}@${DROPLET_IP} "
    echo '=== Container Status ==='
    docker compose -f /opt/boutique/deploy/docker-compose.yml ps

    echo ''
    echo '=== Resource Usage ==='
    docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}'
    
    echo ''
    echo '=== Frontend Health (internal) ==='
    curl -so /dev/null -w 'HTTP %{http_code}\n' http://frontend:8080/_healthz
"

