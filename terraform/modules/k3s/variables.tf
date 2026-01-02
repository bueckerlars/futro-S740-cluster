variable "k3s_api_endpoint" {
  description = "K3s API endpoint"
  type        = string
}

variable "k3s_token" {
  description = "K3s token for API access"
  type        = string
  sensitive   = true
}

