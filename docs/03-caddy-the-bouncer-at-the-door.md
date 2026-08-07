# 03 — Caddy: The Bouncer at the Door

*Or: How One Configuration File Caused a 24-Hour Debugging Session*

---

## Why Caddy (Not Traefik)

Before we built anything, there was a debate: Caddy or Traefik?

| Factor | Caddy | Traefik |
|--------|-------|---------|
| TLS | Automatic (Let's Encrypt), zero config | Needs certificate resolver block, storage config |
| Config file | 15-line Caddyfile | 60+ line YAML with middleware chains |
| Use case | 1 frontend, 1 droplet, simple routing | Multi-service, dynamic discovery, Swarm/K8s |
| Setup time | 5 minutes | 30 minutes |

For a single Droplet with one frontend service, Caddy wins on every axis. The Caddyfile is small enough to fit in a README, and automatic HTTPS is literally a one-liner.

## The Caddyfile

The final, working, not-lying-to-you Caddyfile:

```
suworks.me {
    reverse_proxy frontend:8080

    header {
        X-Content-Type-Options "nosniff"
        X-XSS-Protection "1; mode=block"
        X-Frame-Options "DENY"
        Referrer-Policy "strict-origin-when-cross-origin"
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        Content-Security-Policy "default-src 'self'; style-src 'self' 'unsafe-inline' https://stackpath.bootstrapcdn.com https://fonts.googleapis.com; script-src 'self' https://stackpath.bootstrapcdn.com; font-src 'self' https://fonts.gstatic.com; img-src 'self' data:;"
    }
}

www.suworks.me {
    redir https://suworks.me{uri} permanent
}
```

15 lines. That's it. HTTPS, security headers, reverse proxy, domain redirect. All of it.

## The Security Headers

Each header serves a purpose:

| Header | Protects Against |
|--------|-----------------|
| `X-Content-Type-Options: nosniff` | MIME-type sniffing attacks |
| `X-XSS-Protection: 1; mode=block` | XSS in older browsers |
| `X-Frame-Options: DENY` | Clickjacking |
| `Referrer-Policy: strict-origin-when-cross-origin` | Referrer leakage |
| `Strict-Transport-Security: max-age=31536000` | SSL stripping |
| `Content-Security-Policy: ...` | XSS via inline scripts |

## The CSP War

**This was the single most frustrating bug of the entire project.**

The frontend templates load Bootstrap CSS and JavaScript from CDNs:

```html
<link rel="stylesheet" href="https://stackpath.bootstrapcdn.com/bootstrap/4.1.1/css/bootstrap.min.css">
<link href="https://fonts.googleapis.com/css2?family=DM+Sans...">
<script src="https://stackpath.bootstrapcdn.com/bootstrap/4.1.1/js/bootstrap.min.js"></script>
```

But the original CSP only allowed `'self'`:

```
Content-Security-Policy "default-src 'self'; style-src 'self' 'unsafe-inline'; script-src 'self'; img-src 'self' data:; font-src 'self'"
```

Result: the page loaded with zero styling. No Bootstrap. No fonts. No JavaScript. Just raw HTML.

The errors were clear in the browser console:

```
Loading the stylesheet 'https://stackpath.bootstrapcdn.com/bootstrap/4.1.1/css/bootstrap.min.css'
violates the following Content Security Policy directive: "style-src 'self' 'unsafe-inline'"
```

**The Fix:** Expanded the CSP to allow the specific CDNs the templates expect:

```
Content-Security-Policy "default-src 'self'; style-src 'self' 'unsafe-inline' https://stackpath.bootstrapcdn.com https://fonts.googleapis.com; script-src 'self' https://stackpath.bootstrapcdn.com; font-src 'self' https://fonts.gstatic.com; img-src 'self' data:;"
```

**The Stupid Part:** I told you to fix it on the droplet with `nano`. But the next deploy overwrote the Caddyfile with the repo's broken version. The fix had to be in the **repo**, not just on the server. Took three rounds to get this through my head.

## The `rate_limit` Module That Doesn't Exist

**The Error:**
```
Error: adapting config using caddyfile: /etc/caddy/Caddyfile:3: unrecognized directive: rate_limit
```

Caddy has two builds: the standard `caddy:2-alpine` image (which we used), and an enterprise build with premium modules. `rate_limit` is a **premium module** — it's not in the standard image.

**The Fix:** Removed the `rate_limit` block entirely. The standard image doesn't support it. If rate limiting is needed, switch to `caddy:2-builder` with custom modules, or use nginx instead.

## The Logging Crash

**The Error:**
```
Error: loading initial config: opening log writer using .../var/log/caddy/access.log: mkdir /var/log/caddy: read-only file system
```

**The Cause:** Caddy had `read_only: true` in the compose file, but the log block tried to write to `/var/log/caddy/`.

**The Fix 1:** Add `/var/log` to Caddy's `tmpfs` list:

```yaml
caddy:
  read_only: true
  tmpfs:
    - /tmp
    - /var/run
    - /var/log
```

**The Fix 2 (Cleaner):** Remove the `log` block entirely. Caddy already logs to stdout, which Docker captures. `docker logs deploy-caddy-1` shows everything. The file output was redundant.

## The Caddyfile Formatting Warning

```
Caddyfile input is not formatted; run 'caddy fmt --overwrite' to fix inconsistencies
```

This is cosmetic. The Caddyfile works fine. But `caddy fmt --overwrite` can't write because the file is bind-mounted as `:ro`. The only way to fix it:

```bash
# On the host:
docker cp /opt/boutique/deploy/Caddyfile deploy-caddy-1:/tmp/Caddyfile
docker exec deploy-caddy-1 caddy fmt --overwrite /tmp/Caddyfile
docker cp deploy-caddy-1:/tmp/Caddyfile /opt/boutique/deploy/Caddyfile
docker exec deploy-caddy-1 caddy reload --config /etc/caddy/Caddyfile
```

Or just ignore the warning — it doesn't affect functionality.

## How to Verify

```bash
curl -skL -o /dev/null -w '%{http_code}' https://suworks.me/
# Returns: 200

curl -sI https://suworks.me/ | grep -i strict-transport-security
# Returns: Strict-Transport-Security: max-age=31536000; includeSubDomains; preload
```

---

**Next: [04 — Tailscale: The Secret Tunnel](04-tailscale-the-secret-tunnel.md)**
