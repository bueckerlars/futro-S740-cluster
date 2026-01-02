variable "nodes" {
  type = map(object({
    host = string
    role = string
  }))
}

locals {
  nodes = var.nodes
}

