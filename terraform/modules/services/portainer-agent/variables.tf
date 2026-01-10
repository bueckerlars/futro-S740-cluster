variable "namespace" {
  type        = string
  description = "Namespace for Portainer Agent resources"
  default     = "portainer"
}

variable "agent_image" {
  type        = string
  description = "Docker image for Portainer Agent"
  default     = "portainer/agent:2.33.6"
}

variable "log_level" {
  type        = string
  description = "Log level for Portainer Agent (DEBUG, INFO, WARN, ERROR)"
  default     = "DEBUG"
}

