output "namespace" {
  description = "Namespace where Forgejo is deployed"
  value       = kubernetes_namespace.forgejo.metadata[0].name
}

output "service_name" {
  description = "Name of the Forgejo service"
  value       = "forgejo"
}
