# ------------
# App namespace
# -------------
resource "kubernetes_namespace_v1" "app" {
  metadata {
    name = "rearc"
  }
}

#
# Secret: SECRET_WORD (Phase 2 sets this)
#
resource "kubernetes_secret_v1" "secret_word" {
  metadata {
    name      = "rearc-quest-secret"
    namespace = kubernetes_namespace_v1.app.metadata[0].name
  }

  type = "Opaque"

  data = {
    SECRET_WORD = var.secret_word
  }
}

#
# Deployment
#
resource "kubernetes_deployment_v1" "app" {
  metadata {
    name      = "rearc-quest"
    namespace = kubernetes_namespace_v1.app.metadata[0].name
    labels    = { app = "rearc-quest" }
  }

  spec {
    replicas = 2

    selector {
      match_labels = { app = "rearc-quest" }
    }

    template {
      metadata {
        labels = { app = "rearc-quest" }
      }

      spec {
        container {
          name  = "app"
          image = var.image_uri

          port {
            container_port = 3000
          }

          env {
            name  = "PORT"
            value = "3000"
          }

          env {
            name = "SECRET_WORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.secret_word.metadata[0].name
                key  = "SECRET_WORD"
              }
            }
          }

          # simple readiness so service doesn't route too early
          readiness_probe {
            http_get {
              path = "/docker"
              port = 3000
            }   
            initial_delay_seconds = 20
            period_seconds        = 10
            timeout_seconds       = 10
            failure_threshold     = 6
          }
        }
      }
    }
  }

  depends_on = [helm_release.aws_load_balancer_controller]
}

# ---------
# Service
# -----------
resource "kubernetes_service_v1" "app" {
  metadata {
    name      = "rearc-quest"
    namespace = kubernetes_namespace_v1.app.metadata[0].name
    labels    = { app = "rearc-quest" }
  }

  spec {
    selector = { app = "rearc-quest" }

    port {
      port        = 80
      target_port = 3000
    }

    type = "NodePort"
  }
}

#
# Ingress -> creates ALB (internet-facing) + HTTPS + redirect
#
resource "kubernetes_ingress_v1" "app" {
  metadata {
    name      = "rearc-quest"
    namespace = kubernetes_namespace_v1.app.metadata[0].name

    annotations = {
      "kubernetes.io/ingress.class"               = "alb"
      "alb.ingress.kubernetes.io/scheme"          = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"     = "ip"
      "alb.ingress.kubernetes.io/listen-ports"    = "[{\"HTTP\":80},{\"HTTPS\":443}]"
      "alb.ingress.kubernetes.io/ssl-redirect"    = "443"
      "alb.ingress.kubernetes.io/certificate-arn" = aws_acm_certificate.selfsigned.arn
    }
  }

  spec {
    rule {
      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service_v1.app.metadata[0].name
              port { number = 80 }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.aws_load_balancer_controller]
}