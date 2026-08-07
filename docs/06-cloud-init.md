# 06 — Cloud Init: The First Breath

*Or: How One Syntax Error Killed the Entire Bootstrap*

---

## What Cloud-Init Does

When the Droplet boots for the very first time, cloud-init runs a script defined in `user_data`. This script is the **entire server setup** — install packages, configure users, enable services, harden SSH, set up the firewall, install Tailscale, install Cosign.

If cloud-init fails, the Droplet is useless until you manually fix it or rebuild. There is no fallback. This is the moment of truth for IaC.

## The Final Script (Annotated)

```yaml
#cloud-config
package_update: true
package_upgrade: false
preserve_hostname: false
hostname: ${droplet_name}
ssh_pwauth: false

packages:
  - docker.io
  - docker-compose-v2
  - ufw
  - unattended-upgrades
  - curl
  - jq
  - s3cmd
```

**Note:** Tailscale is NOT in packages. It's installed via the official script in `runcmd` because the apt repo URL is finicky and the script handles it reliably.

```yaml
users:
  - name: boutique
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: docker
    shell: /bin/bash
    ssh_authorized_keys:
      - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDB2D98TyoRKmi9slFwHrVMnI35goM7EF3o+CzoxovP4 idp-deploy
```

**The Bug:** The SSH public key had a typo — `ssh-ed25519` written as `ssh-ed2551` (missing the `9`). Copying and pasting the key introduced an invisible Unicode character (`0x9f`) that corrupted the entire YAML file.

## The Invisible Character Horror

```
2026-07-24 21:30:54,755 - util.py[WARNING]: Failed loading yaml blob.
unacceptable character #x009f: special characters are not allowed
```

The `#x009f` character is an invisible Unicode "Application Program Command" character. It's not visible in any text editor, not caught by standard linters, and breaks the YAML parser silently. Cloud-init skips the entire `runcmd` section when this happens — no Tailscale, no UFW, no Docker, no Cosign.

**The Fix:**
```bash
tr -cd '\11\12\15\40-\176' < cloud-init.yaml > cloud-init-clean.yaml
mv cloud-init-clean.yaml cloud-init.yaml
```

This strips out everything except tabs, newlines, returns, and printable ASCII. The invisible characters are gone. Cloud-init runs perfectly.

## The Runcmd Order

The order of commands matters:

```yaml
runcmd:
  # 1. Update kernel configs
  - sysctl --system

  # 2. Deployment directories
  - mkdir -p /opt/boutique/{deploy,scripts,data}
  - chown -R boutique:boutique /opt/boutique

  # 3. Harden SSH
  - sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
  - sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
  - systemctl restart ssh

  # 4. Install Tailscale via official script
  - curl -fsSL https://tailscale.com/install.sh | sh

  # 5. Wait for tailscaled to be fully active
  - sh -c 'for i in $(seq 1 15); do systemctl is-active tailscaled >/dev/null 2>&1 && break; sleep 1; done'

  # 6. Join tailnet via Terraform-generated auth key
  - tailscale up --authkey="${tailscale_authkey}" --ssh --accept-routes --accept-dns=false

  # 7. Start Docker
  - systemctl enable --now docker

  # 8. UFW policies (after Tailscale is online — tailscale0 must exist)
  - ufw default deny incoming
  - ufw default allow outgoing
  - ufw allow in on tailscale0
  - ufw allow out on tailscale0
  - ufw allow 80/tcp comment 'Public HTTP Web'
  - ufw allow 443/tcp comment 'Public HTTPS Web'
  - ufw deny in on eth0 to any port 22
  - sed -i 's/DEFAULT_FORWARD_POLICY="DROP"/DEFAULT_FORWARD_POLICY="ACCEPT"/' /etc/default/ufw
  - ufw --force enable
  - ufw reload

  # 9. Install Cosign binary
  - curl -sL https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64 -o /usr/local/bin/cosign
  - chmod +x /usr/local/bin/cosign
```

## Key Design Decisions

**Docker after Tailscale:** Docker is started after Tailscale because UFW needs `tailscale0` to exist before configuring firewall rules. If Docker starts first, it might interfere with UFW's iptables rules (a known Linux issue). The `DEFAULT_FORWARD_POLICY` fix addresses this.

**UFW after Tailscale:** The UFW rule `ufw deny in on eth0 to any port 22` blocks SSH on the public interface. If applied before Tailscale is running, you'd lock yourself out. Tailscale creates `tailscale0`, and UFW allows SSH on that interface.

**No duplicate service enable:** The Tailscale install script already runs `systemctl enable --now tailscaled`. Running it again in `runcmd` causes a race condition where systemd sees the service start and stop twice, hits the rate limit, and marks the unit as failed.

## The Cosign Public Key

```yaml
  - path: /opt/cosign.pub
    content: |
      -----BEGIN PUBLIC KEY-----
      MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEFser5E5Yw6U9xkMvxr7OG4wPhyaY
      qsk5srtZNDcf5REO2Zor/lmsynfPN6gZ72al9Z9DAssJzY5SSbUvburT5A==
      -----END PUBLIC KEY-----
    owner: root:root
    permissions: '0644'
```

This writes the cosign public key during first boot. The deploy workflow also writes it (with `sudo tee`), but having it in cloud-init ensures it exists even before the first deploy runs.

## The `spaces_secret` Redaction

**The Bug:** The `spaces_secret` value in `templatefile()` showed as `[redacted]` in the Terraform state. If this is the tool masking an actual variable reference (`var.do_spaces_secret_key`), it's fine. But if it's the literal string `[redacted]`, the backup script in cloud-init will have a broken Spaces credential.

---

**Next: [07 — GitHub Actions](07-github-actions.md)**