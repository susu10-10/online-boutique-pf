# No resources needed in main; the droplet, firewall, and DNS are in their own files

# let terraform find my Project ID using the humarreadable project name
data "digitalocean_project" "idpprj" {
  name = "idp project"
}

