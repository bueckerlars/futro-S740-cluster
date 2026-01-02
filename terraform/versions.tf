terraform {
  required_version = ">= 1.5.0"

  required_providers {
    k3s = {
      source  = "k3s-io/k3s"
      version = "~> 0.1"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }
}

