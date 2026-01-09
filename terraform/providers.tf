terraform {
  required_providers {
    ssh = {
      source  = "loafoe/ssh"
      version = "~> 2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

provider "ssh" {}

# Kubernetes Provider configuration for k3s
# Uses kubeconfig file from master node (fetched by null_resource.kubeconfig)
provider "kubernetes" {
  config_path = pathexpand("~/.kube/config")
}

# Helm Provider configuration
# Uses kubeconfig file from master node (fetched by null_resource.kubeconfig)
provider "helm" {
  kubernetes {
    config_path = pathexpand("~/.kube/config")
  }
}

# Cloudflare Provider configuration
# Uses API token for DNS management
provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

