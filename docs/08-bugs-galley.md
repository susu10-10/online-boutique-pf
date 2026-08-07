# 08 — The Bugs Gallery

*Every error, misconfiguration, and facepalm moment, cataloged for posterity*

---

## The YAML Indentation Wars

| Bug | File | Symptom | Fix |
|-----|------|---------|-----|
| Service names at wrong indent | `docker-compose.yml` | `redis-cart:` at 0 spaces (sibling of `services:`) | Add 2 spaces before every service name |
| `expose:` inside `networks:` | `docker-compose.yml` | 6-space indent when it should be 4-space | Align expose/environment with build/image |
| `permission:` vs `permissions:` | `cloud-init.yaml` | Cloud-init silently skips file writes | Change to `permissions: '0644'` |
| Comment indentation in `write_files` | `cloud-init.yaml` | `# Write custom...` at 0 spaces breaks YAML list | Add 2 spaces before comment lines |
| Invisible Unicode `0x9f` | `cloud-init.yaml` | YAML parser fails silently, `runcmd` never runs | `tr -cd '\11\12\15\40-\176'` |

## The Tailscale Authentication Black Hole

| Attempt | Error | Root Cause |
|---------|-------|------------|
| `reusable = false` | `API key not valid` | Key consumed before cloud-init uses it |
| `ephemeral = false` | Stale devices (`-1`, `-2` suffixes) | Device registration persists after destroy |
| No OAuth tag | `403: not enough permissions` | OAuth client scope doesn't match key tag |
| Admin-owned tag | Device stuck pending approval | Tag ownership requires manual approval |
| Duplicate `systemctl enable` | `tailscaled.service: failed` | Install script already enables the service |
| Stale TUN device | `device or resource busy` | Previous `tailscale up` left interface open |
| `{1..15}` in `/bin/sh` | Wait loop exits immediately | Bash brace expansion not supported in `sh` |

## The Caddy Catastrophes

| Bug | Symptom | Fix |
|-----|---------|-----|
| `rate_limit` directive | `unrecognized directive: rate_limit` | `rate_limit` is a premium module, not in standard image |
| Read-only filesystem + log file | `mkdir /var/log/caddy: read-only file system` | Add `/var/log` to tmpfs |
| CSP blocking CDNs | Page loads with no styling | Add CDN domains to CSP header |
| HSTS before TLS ready | Browser refuses to connect | Remove HSTS during development, add after TLS verified |
| Caddyfile `:ro` mount | `caddy fmt --overwrite` fails | Edit on host, `caddy reload` inside container |

## The Docker Compose Disasters

| Bug | Symptom | Fix |
|-----|---------|-----|
| Health check on distroless | `executable file not found` | `healthcheck: disable: true` on distroless images |
| `cap_drop: ALL` on Redis | Redis exits 127 | Remove cap_drop from Redis |
| `version: "3.9"` | Deprecation warning | Remove the line |
| `DOCR` env var in SSH script | Pulls from Docker Hub instead of DOCR | `export DOCR=...` inside the SSH script |
| SHA tag mismatch | `manifest unknown` | Pass `build_sha` from workflow_run event |

## The CI/CD Pipeline Pitfalls

| Bug | Symptom | Fix |
|-----|---------|-----|
| `secrets: [redacted]` | Secrets not passed to reusable workflow | `secrets: inherit` |
| `github.event.workflow_run.conclusion` on wrong object | Condition never true | `github.event_name == 'workflow_dispatch' \|\| github.event.workflow_run.conclusion == 'success'` |
| Trivy scanning after push | Vulnerabilities pushed to registry | Move scan between build and push |
| Cosign installed after build | Not available for signing | Install before build step |
| `docker compose pull` overwrites retagged SHA | Old `:latest` replaces verified image | Pull before SHA tag operations |
| s3cmd without config | `ERROR: /home/boutique/.s3cfg: None` | Remove s3cmd blocks from deploy script |

## The Terraform Traps

| Bug | Symptom | Fix |
|-----|---------|-----|
| Wrong bucket name | `terraform init` fails silently | Match bucket name to DO Spaces name |
| `cloud-init.sh` vs `cloud-init.yaml` | File not found | Match filename in `file()` call |
| `ssh_keys = [data.ssh_key.fingerprint]` vs `.id` | SSH key not found | Use `.id` for numerical ID |
| Droplet_name var not defined | `terraform apply` fails on DR workflow | Add `variable "droplet_name"` |



**Next: [09 - Appendix: Quick Reference](09-appendix.md)**
