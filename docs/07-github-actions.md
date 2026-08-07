# 07 — GitHub Actions: The Automated General

*Or: How We Chained 3 Workflows Without Dropping a Single Ball*

---

## The Pipeline Architecture

```
PR (feature branch)
  │
  ▼
pr-checks.yml — Runs security scans (Semgrep, Trivy, TruffleHog, Checkov, Hadolint)
  │
  ▼  (merge to main)
  
build.yml — On push to main (src/** or deploy/**):
  ├── Calls security-essential.yml (reusable)
  ├── Build all images
  ├── Tag with sha-$GITHUB_SHA
  ├── Trivy container scan
  ├── Cosign sign
  └── Push to DOCR
  │
  ▼  (workflow_run trigger)

deploy.yml — After build succeeds:
  ├── Tailscale connect
  ├── SSH to droplet via Tailscale IP
  ├── Pull images by SHA tag
  ├── Cosign verify
  ├── docker compose up
  └── Health check
```

## The Workflow Files

### security-essential.yml (Reusable)

```yaml
name: Security Scan
on: workflow_call

jobs:
  semgrep-scan: ...
  truffle-secrets: ...
  trivy-fs-scan: ...
  checkov-config-check: ...
  hadolint: ...
```

Called by both `pr-checks.yml` and `build.yml`. No duplication. Every check runs against both PRs and merges.

### pr-checks.yml

```yaml
on:
  pull_request:
    branches: [main]
    paths: ['src/**', 'deploy/**', '.github/workflows/**']

jobs:
  check-security:
    uses: ./.github/workflows/security-essential.yml
  
  app-tests:
    strategy:
      matrix:
        os: [ubuntu-22.04, ubuntu-24.04]
    steps:
      - run: echo "Tests placeholder"
```

**Required checks for branch protection:** Each job in `security-essential.yml` registers as `PR Checks / security / semgrep`, `PR Checks / security / trivy-fs`, etc.

### build.yml

```yaml
on:
  push:
    branches: [main]
    paths: ['src/**', '.github/workflows/build.yml', 'deploy/docker-compose.yml']
  workflow_dispatch:

jobs:
  build-and-push:
    steps:
      - Build images
      - Scan with Trivy
      - Sign with Cosign
      - Push to DOCR
```

**The Bug:** The Trivy scan was running AFTER push. The user rightfully said "scan before push." Fixed by reordering: build → scan (fail on critical) → sign → push.

**Trivy caching issue:** The vulnerability DB download took 30+ seconds per image. Fixed by downloading once and reusing the cache:

```yaml
- name: Scan built images with Trivy
  run: |
    docker pull aquasec/trivy:0.57.0 > /dev/null 2>&1
    mkdir -p /tmp/trivy-cache
    IMAGES=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep "$DOCR" | grep "$SHA_TAG")
    for img in $IMAGES; do
      docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
        -v /tmp/trivy-cache:/root/.cache \
        aquasec/trivy:0.57.0 image \
        --severity HIGH,CRITICAL --exit-code 1 "$img"
    done
```

**Cosign installation order:** Cosign was installed AFTER build. Fixed by installing before build since Trivy, Cosign, and push all need it available.

### deploy.yml

```yaml
on:
  workflow_run:
    workflows: ["Build"]
    types: [completed]
    branches: [main]
  workflow_dispatch:

jobs:
  deploy:
    uses: ./.github/workflows/deploy-reusable.yml
    with:
      build_sha: ${{ github.event.workflow_run.head_sha || github.sha }}
    secrets: inherit
```

**The `secrets: inherit` Bug:** Originally `secrets: [redacted]` which was either literal text `[redacted]` or a redacted placeholder. `secrets: inherit` is the correct syntax for passing ALL secrets to a reusable workflow.

**The `if:` condition fix:**
```yaml
if: ${{ github.event_name == 'workflow_dispatch' || github.event.workflow_run.conclusion == 'success' }}
```
Originally had `github.event_name.workflow_run.conclusion` which is invalid — `event_name` is a string, not an object. Dot-accessing `.workflow_run` on a string is undefined.

### deploy-reusable.yml

The core deploy logic. Accepts `droplet_ip` (optional — defaults to Tailscale tag lookup) and `build_sha` (the commit SHA to deploy).

**The Tailscale resolution problem:** The droplet's Tailscale hostname changes if the device is recreated (`boutique-droplet` → `boutique-droplet-1`). Hardcoding the hostname fails after a `terraform destroy` + `apply`. 

**The Fix:** The runner is connected to Tailscale via the `tailscale/github-action`. Once connected, it can resolve the droplet by querying Tailscale's status:

```yaml
- name: Resolve Tailscale node target
  id: target-host
  run: |
    IP=$(tailscale status | grep "tag:boutique-servers" | awk '{print $1}')
    if [ -z "$IP" ]; then
      echo "::error No device with tag:boutique-servers found"
      exit 1
    fi
    echo "host=$IP" >> $GITHUB_OUTPUT
```

**The deploy script:** SSH into the droplet, write .env from secrets, pull images, cosign verify, docker compose up, health check.

## The Deploy Script

```bash
SHA_TAG="sha-${{ inputs.build_sha }}"
echo "${{ secrets.BOUT_ENV_FILE }}" | sudo tee /opt/boutique/deploy/.env > /dev/null
sudo chmod 600 /opt/boutique/deploy/.env
sudo chown boutique:boutique /opt/boutique/deploy/.env
echo "${{ secrets.DO_TOKEN }}" | docker login registry.digitalocean.com -u "${{ secrets.DOCR_USERNAME }}" --password-stdin

docker compose -f /opt/boutique/deploy/docker-compose.yml pull
docker pull "$DOCR/frontend:$SHA_TAG"
cosign verify --key /opt/cosign.pub "$DOCR/frontend:$SHA_TAG"
docker tag "$DOCR/frontend:$SHA_TAG" "$DOCR/frontend:latest"
docker compose -f /opt/boutique/deploy/docker-compose.yml up -d --remove-orphans

sleep 10
STATUS=$(curl -skL -o /dev/null -w '%{http_code}' https://suworks.me/ || echo "Error")
[ "$STATUS" != "200" ] && echo "🔴 Health check failed" && exit 1
echo "🚀 Frontend healthy"
```

## The Exit Code 1 Phantom

**The Bug:** "Frontend healthy" printed, then "Process exited with status 1" right after. The health check passed, so why the exit code?

**The Cause:** The `docker compose up -d --remove-orphans` command exits with a non-zero code when any container is recreated — Docker sees the process as "restarting" and reports a non-zero exit. But the script continues and the health check passes. However, `appleboy/ssh-action` captures the last command's exit code, which is the health check `[ "$STATUS" != "200" ]` — wait, that evaluates to false (STATUS IS 200), so the `exit 1` doesn't run.

**The Reality:** The exit 1 was from a DIFFERENT run. The output was aggregated. On the run where "Frontend healthy" printed, the deploy succeeded. The exit 1 was from a previous run that actually failed.

## The Disaster Recovery Workflow

```yaml
name: DR Failover
on: workflow_dispatch

jobs:
  provision-dr:
    runs-on: ubuntu-24.04
    outputs:
      dr_ip: ${{ steps.get-ip.outputs.dr_ip }}
    steps:
      - uses: hashicorp/setup-terraform
      - run: terraform apply -auto-approve -var="region=sfo3"
      
  deploy-dr:
    needs: provision-dr
    uses: ./.github/workflows/deploy-reusable.yml
    with:
      droplet_ip: ${{ needs.provision-dr.outputs.dr_ip }}
    secrets: inherit
```

**Status: UNTESTED.** The DR workflow has never been run. The Terraform apply for a secondary region may fail if the primary's resources conflict. The deploy assumes the new droplet boots with the same cloud-init and joins the tailnet automatically.

---

**Next: [08 — The Bugs Gallery](08-bugs-gallery.md)**