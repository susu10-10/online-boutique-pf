#!/bin/bash
# deploy-stack.sh
# Usage: ./scripts/deploy-stack.sh <droplet-ip>

set -euo pipefail

DROPLET_IP="${1:?Usage: $0 <droplet-ip>}"
REMOTE_DIR="/opt/boutique"
SSH_USER="boutique"

echo "→ Deploying to ${DROPLET_IP}..."

# 1. Copy deploy files to Droplet
echo "→ Copying compose file and config..."
scp deploy/docker-compose.yml ${SSH_USER}@${DROPLET_IP}:${REMOTE_DIR}/deploy/
scp deploy/.env ${SSH_USER}@${DROPLET_IP}:${REMOTE_DIR}/deploy/
scp deploy/Caddyfile ${SSH_USER}@${DROPLET_IP}:${REMOTE_DIR}/deploy/

# 2. Pull latest images and restart
echo "→ Pulling images and restarting stack..."
ssh ${SSH_USER}@${DROPLET_IP} "
    cd ${REMOTE_DIR}/deploy
    docker compose pull
    docker compose up -d --remove-orphans
    echo '→ Checking service health...'
    docker compose ps
"

echo "→ Deploy complete. Visit https://suworks.me"