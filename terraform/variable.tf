variable "do_token" {
  description = "DigitalOcean API token"
  type        = string
  sensitive   = true
}

variable "do_spaces_access_key" {
  description = "DigitalOcean Spaces Access Key"
  type        = string
  sensitive   = true
}

variable "do_spaces_secret_key" {
  description = "DigitalOcean Spaces Secret Key"
  type        = string
  sensitive   = true
}

variable "region" {
  description = "DigitalOcean region"
  type        = string
  default     = "nyc3"
}
variable "domain_name" {
  description = "Domain name"
  type        = string
  default     = "suworks.me"
}

variable "ssh_fingerprint" {
  description = "SSH fingerprint"
  type        = string
  default     = "77:c4:ad:48:d9:6f:00:fb:07:9a:ea:f5:21:33:27:a0"
}

variable "droplet_size" {
  description = "Droplet size"
  type        = string
  default     = "s-2vcpu-4gb"
}

variable "vpc_cidr" {
  description = "CIDR Block for VPC Network"
  type        = string
  default     = "10.111.0.0/20"
}

variable "github_actions_ip" {
  description = "IP address for GitHub Actions"
  type        = string
  default     = "0.0.0.0/0"
}