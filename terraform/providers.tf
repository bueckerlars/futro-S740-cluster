provider "k3s" {
  endpoint = var.k3s_api_endpoint
  token    = var.k3s_token
  insecure = true
}

