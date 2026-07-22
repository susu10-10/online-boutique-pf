# Security Posture

This document outlines the security controls implemented in the Online Boutique deployment pipeline and runtime environment.

## Pipeline Security Gates

Every code change passes through automated security scanning before reaching production.

| Gate | Tool | What it checks | Stage |
|------|------|---------------|-------|
| Dockerfile linting | Hadolint | 140+ best-practice rules (untagged images, pinned packages, root user) | CI/CD lint step |
| IaC misconfiguration | Trivy | Terraform and Docker Compose security misconfigs | CI/CD lint step |
| Compose validation | Docker Compose | Syntax correctness of deployment manifest | CI/CD lint step |
| Container vulnerabilities | Trivy (future) | CVE scanning of built images | CI/CD build step |

### Hadolint — Real Catch

On first pipeline run, Hadolint flagged **3 untagged base images** (DL3006):

src/frontend/Dockerfile:32
DL3006: Always tag the version of an image explicitly

src/productcatalogservice/Dockerfile:32
DL3006: Always tag the version of an image explicitly

src/shippingservice/Dockerfile:32
DL3006: Always tag the version of an image explicitly

**Risk:** Untagged `FROM` lines pull whatever `latest` resolves to on each build. This is a non-deterministic supply chain — a compromised or incompatible image version could be deployed silently.

**Fix:** Pinned all three to `gcr.io/distroless/static:nonroot`. The `:nonroot` tag also enforces non-root execution inside containers — defense in depth.

**Evidence:** Pipeline now passes this gate. All future PRs are scanned automatically.

---

## Network Security

| Layer | Control | Detail |
|-------|---------|--------|
| Perimeter | DO Cloud Firewall | Only ports 22, 80, 443 open inbound. All microservice ports (7070, 3550, 7000, 50051, 5050, 8080, 9555) blocked at the network level. |
| Internal | Docker bridge network | All service-to-service communication over `boutique-net` — isolated from host and internet. |
| Transport | Caddy TLS (Let's Encrypt) | Automatic HTTPS termination at the edge. HTTP → HTTPS redirect. HSTS preload headers. |

### Exposed Surface

Only one container has host port mappings:
- **Caddy** — ports 80 (HTTP redirect) and 443 (HTTPS)

All 10 backend services are accessible only within the Docker internal network. No microservice port is reachable from the internet.

---

## Identity & Access

| Layer | Control |
|-------|---------|
| Droplet SSH | Key-based authentication only. Password login disabled. |
| CI/CD deploy | SSH private key stored in GitHub Actions secrets. Never on disk. |
| Terraform state | Encrypted at rest in DO Spaces bucket. Access key in GitHub secrets. |
| Application auth | OAuth2 Proxy (future) — login gate via GitHub OIDC before reaching the storefront. |

---

## Secrets Management

- No secrets in git. `.env` and `terraform.tfvars` in `.gitignore`.
- Environment file stored as GitHub Actions secret (`BOUT_ENV_FILE`), written to the server during deploy.
- DO API token, Spaces credentials, and SSH keys are GitHub Actions secrets — injected as `TF_VAR_*` environment variables at runtime.
- All secrets are scoped to the repository. No shared credentials.

---

## Observability & Incident Response

- All services log structured JSON to stdout (collected by Docker).
- Health check endpoint: `/_healthz` on the frontend (returns HTTP 200).
- Verify script runs after every deploy to confirm all containers are healthy.
- Container restart policy: `always` — crashed containers restart automatically.

---

## Supply Chain

- Base images pinned to SHA256 digests where possible (checkoutservice, frontend, adservice, emailservice, loadgenerator, paymentservice, currencyservice, recommendationservice, shoppingassistantservice).
- Distroless images used for Go services — minimal surface area (no shell, no package manager).
- Non-root runtime images (`:nonroot` tag) for all distroless services.

---

## Roadmap

| Control | Status | Target |
|---------|--------|--------|
| Hadolint Dockerfile linting | ✅ Implemented | Live |
| Trivy IaC scanning | ✅ Implemented | Live |
| TLS termination (Caddy + Let's Encrypt) | ✅ Implemented | Live |
| OAuth2 Proxy authentication | 📋 Planned | Phase 2 |
| Container CVE scanning (Trivy image) | 📋 Planned | Phase 2 |
| Internal mTLS for gRPC | 📋 Planned | Phase 3 |
| Container resource limits | 📋 Planned | Phase 3 |
| Prometheus monitoring | 📋 Planned | Phase 4 |
