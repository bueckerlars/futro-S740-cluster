output "namespace" {
  description = "Namespace where Portainer Agent resources are deployed"
  value       = var.namespace
}

output "service_name" {
  description = "Name of the LoadBalancer service for Portainer Agent"
  value       = kubernetes_service_v1.portainer_agent.metadata[0].name
}

output "service_endpoint" {
  description = "Service endpoint information for Portainer configuration"
  value = {
    namespace = kubernetes_namespace.portainer.metadata[0].name
    name      = kubernetes_service_v1.portainer_agent.metadata[0].name
    port      = 9001
  }
}

