# Create a new Web Droplet in the nyc3 region
resource "digitalocean_droplet" "boutique" {
  image    = "ubuntu-24-04-x64"
  name     = "boutique-droplet"
  region   = var.region
  size     = var.droplet_size
  ssh_keys = [var.ssh_fingerprint]

  # cloud-init script
  user_data = file("${path.module}/cloud-init.yaml")

  # do monitoring agent
  monitoring = true
}