# Portainer Agent Service Module
# Deploys Portainer Agent as a Kubernetes Deployment with LoadBalancer service

# Create portainer namespace
resource "kubernetes_namespace" "portainer" {
  metadata {
    name = var.namespace
  }
}

# ServiceAccount for Portainer Agent with cluster-admin permissions
resource "kubernetes_service_account_v1" "portainer_sa" {
  metadata {
    name      = "portainer-sa-clusteradmin"
    namespace = kubernetes_namespace.portainer.metadata[0].name
  }
}

# ClusterRoleBinding to grant cluster-admin role to ServiceAccount
resource "kubernetes_cluster_role_binding_v1" "portainer_crb" {
  metadata {
    name = "portainer-crb-clusteradmin"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.portainer_sa.metadata[0].name
    namespace = kubernetes_namespace.portainer.metadata[0].name
  }
}

# Portainer Agent Deployment
resource "kubernetes_deployment_v1" "portainer_agent" {
  metadata {
    name      = "portainer-agent"
    namespace = kubernetes_namespace.portainer.metadata[0].name
    labels = {
      app = "portainer-agent"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "portainer-agent"
      }
    }

    template {
      metadata {
        labels = {
          app = "portainer-agent"
        }
      }

      spec {
        service_account_name = kubernetes_service_account_v1.portainer_sa.metadata[0].name

        container {
          name  = "portainer-agent"
          image = var.agent_image
          image_pull_policy = "Always"

          port {
            container_port = 9001
            protocol      = "TCP"
            name          = "http"
          }

          env {
            name  = "LOG_LEVEL"
            value = var.log_level
          }

          env {
            name  = "AGENT_CLUSTER_ADDR"
            value = "portainer-agent-headless"
          }

          env {
            name = "KUBERNETES_POD_IP"
            value_from {
              field_ref {
                field_path = "status.podIP"
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_service_account_v1.portainer_sa
  ]
}

# LoadBalancer Service for Portainer Agent
resource "kubernetes_service_v1" "portainer_agent" {
  metadata {
    name      = "portainer-agent"
    namespace = kubernetes_namespace.portainer.metadata[0].name
    labels = {
      app = "portainer-agent"
    }
  }

  spec {
    type = "LoadBalancer"
    selector = {
      app = "portainer-agent"
    }
    port {
      name        = "http"
      protocol    = "TCP"
      port        = 9001
      target_port = 9001
    }
  }

  depends_on = [
    kubernetes_deployment_v1.portainer_agent
  ]
}

# Headless Service for Portainer Agent (used for cluster communication)
resource "kubernetes_service_v1" "portainer_agent_headless" {
  metadata {
    name      = "portainer-agent-headless"
    namespace = kubernetes_namespace.portainer.metadata[0].name
    labels = {
      app = "portainer-agent"
    }
  }

  spec {
    cluster_ip = "None"
    selector = {
      app = "portainer-agent"
    }
  }

  depends_on = [
    kubernetes_deployment_v1.portainer_agent
  ]
}

