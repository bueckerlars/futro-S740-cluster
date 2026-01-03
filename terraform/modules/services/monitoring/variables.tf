variable "namespace" {
  type        = string
  description = "Namespace for monitoring resources"
  default     = "monitoring"
}

variable "prometheus_nodeport" {
  type        = number
  description = "NodePort for Prometheus service"
  default     = 30909
}

variable "grafana_nodeport" {
  type        = number
  description = "NodePort for Grafana service"
  default     = 30300
}

variable "master_ip" {
  type        = string
  description = "IP address of the master node for URL outputs"
}

variable "grafana_admin_password" {
  type        = string
  description = "Admin password for Grafana"
  sensitive   = true
  default     = "admin"
}

