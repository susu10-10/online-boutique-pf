
# Online Boutique: Production-Grade DevSecOps Pipeline

A hardened, GitOps-driven deployment of Google's 11-microservice Online Boutique app on DigitalOcean. This project demonstrates enterprise-grade zero-trust security, automated CI/CD hardening, and immutable infrastructure designed for high security and low operational overhead.

## 🛠️ Architecture Highlights

- Zero-Trust Network: Public ingress restricted entirely to HTTPS (443). SSH is fully blocked on the public internet, accessible only via a private Tailscale Mesh VPN.

- Cryptographic Supply Chain: Container images are dynamically signed during CI via `Cosign` and cryptographically verified on the host machine before execution to prevent tampering.

- Container Hardening: Microservices execute using read-only root filesystems, dropped Linux capabilities (`cap_drop: [ALL]`), strict resource quotas, and running as non-root users.

- Isolated Networking: Segmented application layer into two distinct Docker networks (`boutique-net for frontend/gRPC and backend-net for database/caching`) to eliminate lateral movement vectors.

## 🏗️ Technical Stack

| Layer | Technology | Architectural Purpose |
|---|---|---|
| IaC | Terraform | Declarative infrastructure provisioning with remote state locking in DO Spaces. |
| Host | DigitalOcean Droplet | Single Ubuntu node (`s-2vcpu-4gb`) hardened via UFW and cloud firewalls. |
| VPN | Tailscale | Secure mesh overlay network providing private management planes (SSH). |
| Proxy | Caddy Server | Reverse proxy featuring automatic ACME TLS, HSTS, and strict CSP headers. |
| Runtime | Docker Compose | Multi-container orchestration utilizing dual-network isolation. |
| Registry | DO Container Registry (DOCR) | Private OCI-compliant registry for secure artifact storage. |
| Signing | Sigstore Cosign | Keyless/Secret-backed OCI image signing and runtime verification. |
| CI/CD | GitHub Actions | Automated 3-stage GitOps pipeline (Lint & Test ➡️ Build & Sign ➡️ Deploy). |

## 🔄 Deployment Pipeline & System Topology

```mermaid
flowchart TD
    classDef gitops fill:#e6f4ea,stroke:#137333,stroke-width:1px,color:#137333;
    classDef security fill:#fce8e6,stroke:#c5221f,stroke-width:1px,color:#c5221f;
    classDef cloud fill:#e8f0fe,stroke:#1a73e8,stroke-width:1px,color:#1a73e8;
    classDef app fill:#f1f3f4,stroke:#5f6368,stroke-width:1px,color:#3c4043;
    classDef infra fill:#fef7e0,stroke:#b06000,stroke-width:1px,color:#b06000;

    subgraph GitHub ["📦 GitOps Code Management & Governance"]
        PROT["🛡️ Branch Protection rules<br/>• Require Peer PR Review<br/>• Require Passing Status Checks<br/>• Enforce Signed Commits Only"]
        REPO["📁 online-boutique-pf<br/>(Monorepo)"]
        ACTIONS["🚀 GitHub Actions<br/>(Pipeline Engine)"]
    end
    class GitHub,REPO,ACTIONS gitops;
    class PROT security;

    subgraph CI ["🛡️ CI Verification & Supply Chain"]
        SEC["⚙️ Static Analysis<br/>Semgrep • Checkov • Hadolint"]
        BUILD["📦 Multi-Service Build<br/>Docker Compose (Immutable SHA)"]
        SCAN["🔍 Vulnerability Scanning<br/>Trivy Container Scan"]
        SIGN["🔑 Artifact Signing<br/>Sigstore Cosign"]
    end
    class CI,BUILD cloud;
    class SEC,SCAN,SIGN security;

    subgraph CD ["🚚 CD Target Execution"]
        TAIL["🔒 Tailnet Authentication<br/>Ephemeral OIDC Client"]
        VERIFY["🛡️ Runtime Verification<br/>Cosign Signature Check"]
        UP["🐳 Idempotent Deploy<br/>docker compose up -d"]
    end
    class CD,TAIL,UP cloud;
    class VERIFY security;

    subgraph DO ["☁️ DigitalOcean Hardened Cloud Enclave"]
        SPACES[("🗄️ DO Spaces<br/>Encrypted TF State Lock")]
        DOCR[("🐳 Private DOCR<br/>OCI Registry")]
        FIREWALL["🔥 Cloud Firewall / UFW<br/>Public: 80, 443<br/>SSH: Tailscale Only"]
        
        subgraph Host ["Compute Instance"]
            DROPLET["🐧 Ubuntu Droplet<br/>nyc3 (2vCPU / 4GB)"]
            
            subgraph Sandbox ["Docker Network Isolation"]
                CADDY["🛡️ Caddy Proxy<br/>Auto-TLS & CSP"]
                FRONTEND["🌐 Frontend Web<br/>Exposed via Proxy"]
                BACKEND["⚙️ 10x Microservices<br/>Isolated gRPC Mesh"]
                REDIS[("💾 Redis Cache<br/>Stateful Data")]
            end
        end
    end
    class DO,SPACES,DOCR,FIREWALL,Host,DROPLET infra;
    class Sandbox,CADDY,FRONTEND,BACKEND,REDIS app;

    %% Orchestration Flows
    PROT -->|"Enforces Rules On"| REPO
    REPO -->|"Valid PR or Approved Commit"| ACTIONS
    ACTIONS -->|"1. Scans & Builds"| CI
    CI -->|"2. Pushes Signed Artifacts"| DOCR
    ACTIONS -->|"3. Orchestrates Via Tailnet"| CD
    
    %% Target Deploy Connections
    TAIL -->|"Secure Tunnel"| DROPLET
    VERIFY -->|"Validates Signatures"| DOCR
    UP -->|"Spawns Containers"| Sandbox
    
    %% Architectural Protections
    FIREWALL -.->|"Enforces Ingress Policy"| DROPLET
    REPO -.->|"State Ops"| SPACES

```


## 🔒 Security Architecture

1. Branch Protection & Supply Chain Governance

Before a single line of code ever hits the pipeline, it must pass GitHub repository compliance rules:

- Peer Reviews: Merges to the primary branch are blocked until they receive explicit code review approvals.
- Cryptographic Provenance: Commit signature verification is strictly enforced. Any code block that isn't signed with a trusted GPG or SSH key is rejected at push time, eliminating developer identity spoofing.
- Linear History Enforcement: Avoids complex merge commits by requiring clean fast-forward or squash merges, ensuring clear audibility for system changes.

2. Shift-Left Security (CI Gates)

Every pull request undergoes strict static analysis and code quality gates before infrastructure or code changes are accepted:

- Checkov: Scans Terraform configurations to prevent infrastructure misconfigurations (e.g., open security groups).

- Hadolint: Validates Dockerfiles against production best practices (e.g., forcing `non-root` users, pinning base image digests).

- Semgrep & TruffleHog: Analyzes application code for anti-patterns and scans the commit history to ensure no secrets or API keys are leaked.

- Trivy: Runs deep scans on both filesystem files and compiled container layers to detect known `CVEs`, blocking the pipeline if high-severity vulnerabilities are found.

3. Host and Runtime Hardening (Least Privilege)

The production system is built around defense-in-depth principles at the operating system and container layers:

- Attack Surface Reduction: SSH access via the public IP is completely disabled using a combination of DigitalOcean Cloud Firewalls and local `UFW` rules. System maintenance can only occur through an authenticated `Tailscale` node (`tag:boutique-servers`).

- Immutable Container Root FS: Containers run with a read-only root filesystem (read_only: true), rendering runtime malware injections or unauthorized configuration modifications impossible.

- Kernel Capability Dropping: All default Linux capabilities are stripped from the microservices (cap_drop: [ALL]), ensuring that even if a service is compromised, the attacker cannot interact with the host system kernel.