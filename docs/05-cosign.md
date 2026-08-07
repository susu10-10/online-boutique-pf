# 05 — Cosign: The Digital Wax Seal

*Or: How a Missing Base64 Decode Cost Us a Day*

---

## Why Sign Images?

Container images are binaries. When pulled from a registry, how do you know the image you're getting is exactly the one your build produced? An attacker could slip a malicious layer into the registry, and `docker pull` would happily download it.

**Cosign solves this:** You sign the image with a private key during CI, then verify the signature during deploy. If the image has been tampered with — even a single byte changed — the signature verification fails and the deploy aborts.

## The Key Generation

```bash
cosign generate-key-pair
```

This creates two files:

- `cosign.key` — **PRIVATE KEY, NEVER COMMIT**
- `cosign.pub` — **PUBLIC KEY, COMMIT TO REPO**

The private key is stored as a GitHub secret (`COSIGN_PRIVATE_KEY`), base64-encoded:

```bash
cat cosign.key | base64 -w0
# Paste the output into GitHub → Settings → Secrets → COSIGN_PRIVATE_KEY
```

The public key is committed to the repo (`deploy/cosign.pub`), written to the droplet via cloud-init, and used during verification.

## The Signing (Build Pipeline)

```yaml
- name: Install Cosign
  uses: sigstore/cosign-installer@v4.1.0

- name: Sign images
  run: |
    echo "${{ secrets.COSIGN_PRIVATE_KEY }}" | base64 -d > /tmp/cosign.key
    cosign sign --key /tmp/cosign.key --yes \
      "registry.digitalocean.com/idpreg/frontend:sha-${{ github.sha }}"
    rm -f /tmp/cosign.key
```

**The Bug:** The private key was stored in two formats at different times. First as raw PEM text (output of `cat cosign.key`), then as base64 (`cat cosign.key | base64`). The signing method must match:

- **If raw PEM:** `cosign sign --key env://COSIGN_PRIVATE_KEY`
- **If base64:** `echo "$KEY" | base64 -d > /tmp/key && cosign sign --key /tmp/key`

Mismatch gives `invalid pem block` error.

## The Verification (Deploy Pipeline)

```yaml
docker pull "$DOCR/frontend:$SHA_TAG"
cosign verify --key /opt/cosign.pub "$DOCR/frontend:$SHA_TAG"
docker tag "$DOCR/frontend:$SHA_TAG" "$DOCR/frontend:latest"
```

Cosign verifies:

1. The signature was created with the matching private key
2. The image digest matches what was signed
3. The signature exists in the transparency log (optional but verified by default)

If verification fails, the `exit 1` from cosign stops the deploy.

## The SHA Tag Mismatch

**The Bug:** The build signs `sha-abc123`. The deploy pulls `sha-abc123`. But if the deploy runs manually (workflow_dispatch) instead of automatically (workflow_run), `github.sha` is the HEAD commit, not the build commit. The SHA tag doesn't exist in the registry.

**The Fix:** Pass `github.event.workflow_run.head_sha` through the reusable workflow input:

```yaml
deploy:
  uses: ./.github/workflows/deploy-reusable.yml
  with:
    build_sha: ${{ github.event.workflow_run.head_sha || github.sha }}
  secrets: inherit
```

## The Digest Warning

```
WARNING: Image reference uses a tag, not a digest, to identify the image to sign.
This can lead you to sign a different image than the intended one.
```

Cosign prefers `image@sha256:...` (digest reference) over `image:tag` (label reference). Tags can be moved. Digests are immutable. For production, you'd resolve the digest and sign that. For this project, `sha-XXXX` tags are close enough — they're unique per build and can't be overwritten.


**Next: [06 - Cloud-Init Integration](06-cloud-init.md)**
