# K3s cluster resources module
# This module can be extended to manage K3s resources like namespaces, deployments, etc.

# Example: Create a namespace (uncomment and customize as needed)
# resource "k3s_namespace" "example" {
#   metadata {
#     name = "example"
#   }
# }

# Example: Create a deployment (uncomment and customize as needed)
# resource "k3s_deployment" "example" {
#   metadata {
#     name      = "example"
#     namespace = k3s_namespace.example.metadata[0].name
#   }
#   spec {
#     replicas = 1
#     selector {
#       match_labels = {
#         app = "example"
#       }
#     }
#     template {
#       metadata {
#         labels = {
#           app = "example"
#         }
#       }
#       spec {
#         container {
#           name  = "example"
#           image = "nginx:latest"
#         }
#       }
#     }
#   }
# }

# Placeholder output to ensure module is valid
output "cluster_ready" {
  description = "Indicates that the K3s module is configured"
  value       = true
}

