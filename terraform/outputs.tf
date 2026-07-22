output "droplet_ip" {
    description = "Public Ip of the Boutique Droplet"
    value = digitalocean_droplet.boutique.ipv4_address
}

output "domain" {
    description = "Domain name for the Boutique"
    value = var.domain_name
}

output "droplet_urn" {
    description = "URN of the Boutique Droplet"
    value = digitalocean_droplet.boutique.urn
}