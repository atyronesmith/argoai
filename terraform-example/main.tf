terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
  config_context = "crc-admin"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
    config_context = "crc-admin"
  }
}

resource "kubernetes_namespace" "argo_ai_demo" {
  metadata {
    name = "argo-ai-demo"
    labels = {
      "app" = "ai-document-pipeline"
      "environment" = var.environment
    }
  }
}

resource "helm_release" "argo_workflows" {
  name       = "argo-workflows"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-workflows"
  version    = "0.41.1"
  namespace  = kubernetes_namespace.argo_ai_demo.metadata[0].name

  values = [
    yamlencode({
      server = {
        extraArgs = ["--auth-mode=server", "--secure=false"]
        readinessProbe = {
          httpGet = {
            scheme = "HTTP"
          }
        }
      }
      controller = {
        workflowDefaults = {
          spec = {
            serviceAccountName = "argo"
          }
        }
      }
    })
  ]
}

resource "kubernetes_deployment" "ollama" {
  metadata {
    name      = "ollama"
    namespace = kubernetes_namespace.argo_ai_demo.metadata[0].name
    labels = {
      app = "ollama"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "ollama"
      }
    }

    template {
      metadata {
        labels = {
          app = "ollama"
        }
      }

      spec {
        container {
          name  = "ollama"
          image = "ollama/ollama:latest"

          port {
            container_port = 11434
          }

          env {
            name  = "OLLAMA_HOST"
            value = "0.0.0.0"
          }

          resources {
            requests = {
              memory = "4Gi"
              cpu    = "2"
            }
            limits = {
              memory = "8Gi"
              cpu    = "4"
            }
          }

          volume_mount {
            name       = "models"
            mount_path = "/models"
          }
        }

        volume {
          name = "models"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.ollama_models.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "ollama_models" {
  metadata {
    name      = "ollama-models-pvc"
    namespace = kubernetes_namespace.argo_ai_demo.metadata[0].name
  }

  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "20Gi"
      }
    }
  }
}

output "namespace" {
  value = kubernetes_namespace.argo_ai_demo.metadata[0].name
}

output "argo_server_url" {
  value = "https://argo-server-${kubernetes_namespace.argo_ai_demo.metadata[0].name}.apps-crc.testing"
}
