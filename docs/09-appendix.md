# 09 — Appendix: Quick Reference

## Secrets Required in GitHub

| Secret | Source | Used By |
|--------|--------|---------|
| `DO_TOKEN` | DO API → Generate Token | All workflows (Terraform, build, deploy) |
| `SPACES_ACCESS_KEY` | DO Spaces → Access Key | Terraform backend, deploy (Redis backup) |
| `SPACES_SECRET_KEY` | DO Spaces → Secret Key | Same |
| `SSH_FINGERPRINT` | DO → Settings → SSH Keys → Fingerprint | Terraform (droplet.ssh_keys) |
| `SSH_PRIV_KEY` | `cat ~/.ssh/id_do_droplet` | Deploy (appleboy/ssh-action) |
| `COSIGN_PRIVATE_KEY` | `cat cosign.key \| base64 -w0` | Build (cosign sign) |
| `BOUT_ENV_FILE` | The entire .env content as a single secret | Deploy (write to Droplet) |
| `TS_OAUTH_CLIENT_ID` | Tailscale → OAuth → Client ID | Terraform (tailscale provider) |
| `TS_OAUTH_CLIENT_SECRET` | Tailscale → OAuth → Secret | Terraform (tailscale provider) |
| `GH_TS_CLIENT_ID` | Tailscale → separate GH OAuth client | Deploy (tailscale GitHub Action) |
| `GH_TS_CLIENT_SECRET` | Same client's secret | Deploy |

## Command Cheat Sheet

```bash
# Terraform lifecycle
cd terraform
terraform init
terraform plan
terraform apply -auto-approve
terraform destroy -auto-approve

# SSH via Tailscale
ssh -i ~/.ssh/id_do_droplet boutique@boutique-droplet.tail107809.ts.net

# Check containers
docker ps
docker logs deploy-caddy-1 --tail 20

# Restart stack
cd /opt/boutique/deploy
docker compose pull
docker compose up -d --remove-orphans
docker compose ps
curl -skL https://suworks.me/

# Check UFW
sudo ufw status verbose

# Check cloud-init logs
sudo cat /var/log/cloud-init-output.log | grep -i "error\|fail\|warn"

# Stri
# Strip invisible characters from YAML
tr -cd '\11\12\15\40-\176' < cloud-init.yaml > clean.yaml

# Cosign
cosign generate-key-pair
cosign sign --key cosign.key --yes image:tag
cosign verify --key cosign.pub image:tag

# Tailscale
tailscale status
tailscale up --ssh
```
