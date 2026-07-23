
# Online Boutique: DevSecOps Deployment

This repository deploys Google Cloud Platform's "Online Boutique" microservice demo on a single DigitalOcean Droplet using Docker Compose, with security hardened from day one through automated CI/CD pipelines.

Tools: `Terraform` + `Docker Compose` + `Caddy` + `DigitalOcean Container Registry`
CI/CD: `GitHub Actions` (build → scan → push → pull → deploy)
Security: `Hadolint`, `Trivy`, `non-root containers`, `TLS`, `network isolation`, `resource limits`

```mermaid
flowchart TD
    %% Base Theme Styling
    classDef gitops fill:#e6f4ea,stroke:#137333,stroke-width:1px,color:#137333;
    classDef security fill:#fce8e6,stroke:#c5221f,stroke-width:1px,color:#c5221f;
    classDef cloud fill:#e8f0fe,stroke:#1a73e8,stroke-width:1px,color:#1a73e8;
    classDef app fill:#f1f3f4,stroke:#5f6368,stroke-width:1px,color:#3c4043;
    classDef infra fill:#fef7e0,stroke:#b06000,stroke-width:1px,color:#b06000;

    %% GitHub & Trigger Layer
    subgraph GitHub ["📦 GitOps Core"]
        REPO["📁 online-boutique-pf <br/> (Source Repository)"]
        ACTIONS["🚀 GitHub Actions <br/> (CI/CD Orchestration)"]
    end
    class GitHub,REPO,ACTIONS gitops;

    %% Infrastructure Pipeline
    subgraph Pipeline_TF ["🛠️ IaC Stage (terraform.yml)"]
        TF_INIT["terraform init"]
        TF_PLAN["terraform plan"]
        TF_APPLY["terraform apply"]
        
        TF_INIT --> TF_PLAN --> TF_APPLY
    end
    class Pipeline_TF,TF_INIT,TF_PLAN,TF_APPLY cloud;

    %% Build & Security Pipeline
    subgraph Pipeline_Build ["🔒 Build & Security Stage (build.yml)"]
        SEC["🛡️ Hadolint + Trivy IaC <br/> (Static Linting)"]
        BUILD["📦 docker compose build <br/> (Multi-service Build)"]
        TRIVY["🔍 Trivy Container Scan <br/> (CVE Block Gate)"]
        PUSH["📤 docker compose push <br/> (Image Upload)"]
        
        SEC --> BUILD --> TRIVY --> PUSH
    end
    class Pipeline_Build,BUILD,PUSH cloud;
    class SEC,TRIVY security;

    %% CD Deployment Pipeline
    subgraph Pipeline_Deploy ["🚚 CD Target Stage (deploy.yml)"]
        DEPLOY["🔀 SSH Target Run <br/> (compose pull && up -d)"]
        HEALTH["🚦 Zero-Downtime Test <br/> (curl frontend healthcheck)"]
        
        DEPLOY --> HEALTH
    end
    class Pipeline_Deploy,DEPLOY,HEALTH cloud;

    %% Cloud Infrastructure Providers
    subgraph DigitalOcean ["☁️ DigitalOcean Managed Infrastructure"]
        SPACES[("🗄️ DO Spaces <br/> (Remote S3 TF State)")]
        DOCR[("🐳 DO Container Registry <br/> (Secure Private Registry)")]
        FIREWALL["🔒 DO Cloud Firewall <br/> (Ingress: 22, 80, 443)"]
        DNS["🌐 DO DNS <br/> (suworks.me Mapping)"]
        
        subgraph Compute ["Compute Nodes"]
            DROPLET["🐧 Ubuntu Droplet <br/> (nyc3 | s-2vcpu-4gb)"]
        end
    end
    class DigitalOcean,SPACES,DOCR,FIREWALL,DNS,Compute infra;

    %% Container Runtime Application Architecture
    subgraph Runtime ["🐋 Production Docker Application Stack"]
        CADDY["🛡️ Caddy Reverse Proxy <br/> (Automatic TLS / Headers)"]
        FRONTEND["🌐 Frontend Web Engine <br/> (HTTP :8080 Target)"]
        SERVICES["⚙️ Microservices Core <br/> (10x gRPC Backend Apps)"]
        REDIS[("💾 Redis In-Memory <br/> (Stateful Cart Cache)")]
        
        CADDY --> FRONTEND --> SERVICES --> REDIS
    end
    ```

    class Runtime,CADDY,FRONTEND,SERVICES,REDIS app;

    %% Structural Triggers and State Relations
    REPO -->|"terraform/** changes"| ACTIONS
    REPO -->|"src/** or deploy/** changes"| ACTIONS
    REPO -->|"Manual Dispatch Run"| ACTIONS

    ACTIONS -->|"1. Provisions"| Pipeline_TF
    ACTIONS -->|"2. Validates"| Pipeline_Build
    ACTIONS -->|"3. Executes"| Pipeline_Deploy

    TF_INIT -.->|Remote State Lock| SPACES
    TF_APPLY -->|Deploys / Modifies| Compute
    TF_APPLY -->|Configures Rules| FIREWALL
    TF_APPLY -->|Binds Records| DNS

    PUSH -->|Artifact Delivery| DOCR
    DEPLOY -->|Fetch Secure Images| DOCR

    FIREWALL -.->|Protects| Compute
    DNS -.->|Routes Traffic To| CADDY
    CADDY -.->|Hosts On| DROPLET