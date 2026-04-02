# variables.tf
# Input variables for tiered identity proof of concept
# Supply values in terraform.tfvars - never commit that file to version control

variable "my_ip" {
  description = "Your IP address for bastion SSH access (format: x.x.x.x/32)"
  type        = string
}

variable "ai_service_api_key" {
  description = "AI service API key for OpenClaw automation - supply via terraform.tfvars"
  type        = string
  sensitive   = true
}
