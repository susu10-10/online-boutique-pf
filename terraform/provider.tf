terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "2.95.0"
    }

    tailscale = {
      source  = "tailscale/tailscale"
      version = "0.29.2"
    }
  }
}

provider "digitalocean" {
  # Configuration options
}

provider "tailscale" {
  oauth_client_id     = var.ts_client_id
  oauth_client_secret = var.ts_client_secret
}