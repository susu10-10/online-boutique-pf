# Creates a fresh single use key on every apply
resource "tailscale_tailnet_key" "boutique_key" {
  reusable      = false #single-use for server boot security
  ephemeral     = false # server is permanent
  preauthorized = true  # skip manual web dashboard approval
  expiry        = 3600  # token self-destruct in 1 hr if build fails
  tags          = ["tag:boutique-servers"]
}

# Create a new Web Droplet in the nyc3 region
resource "digitalocean_droplet" "boutique" {
  image    = "ubuntu-24-04-x64"
  name     = var.droplet_name
  region   = var.region
  size     = var.droplet_size
  ssh_keys = [var.ssh_fingerprint]

  # cloud-init script and passing tailscale key into cloudinit
  user_data = templatefile("${path.module}/cloud-init.yaml", {
    tailscale_authkey = tailscale_tailnet_key.boutique_key.key
    droplet_name      = var.droplet_name
    spaces_key        = var.do_spaces_access_key
    spaces_secret     = var.do_spaces_secret_key
  })

  # do monitoring agent
  monitoring = true
}

resource "digitalocean_project_resources" "boutique" {
  project = data.digitalocean_project.idpprj.id
  resources = [
    digitalocean_droplet.boutique.urn
  ]
}