#
#  Copyright (c) 2024 Metaform Systems, Inc.
#
#  This program and the accompanying materials are made available under the
#  terms of the Apache License, Version 2.0 which is available at
#  https://www.apache.org/licenses/LICENSE-2.0
#
#  SPDX-License-Identifier: Apache-2.0
#
#  Contributors:
#       Metaform Systems, Inc. - initial API and implementation
#

resource "kubernetes_stateful_set" "postgres" {
  metadata {
    name      = local.app-name
    namespace = var.namespace
    labels = {
      App = local.app-name
    }
  }

  spec {
    service_name = "${local.app-name}-service"

    replicas = 1
    selector {
      match_labels = {
        App = local.app-name
      }
    }
    template {
      metadata {
        labels = {
          App = local.app-name
        }
      }
      spec {
        container {
          image = local.pg-image
          name  = local.app-name

          env_from {
            config_map_ref {
              name = kubernetes_config_map.postgres-env.metadata[0].name
            }
          }
          port {
            container_port = 5432
            name           = "postgres-port"
          }
          volume_mount {
            name = "pgdata"
            mount_path = "/var/lib/postgresql/data"
            sub_path = ""
          }

          dynamic "volume_mount" {
            for_each = toset(var.init-sql-configs)
            content {
              mount_path = "/docker-entrypoint-initdb.d/${volume_mount.value}.sql"
              name       = volume_mount.value
              sub_path   = "${volume_mount.value}.sql"
              read_only  = true
            }
          }

          # Uncomment this to assign (more) resources
          #          resources {
          #            limits = {
          #              cpu    = "2"
          #              memory = "512Mi"
          #            }
          #            requests = {
          #              cpu    = "250m"
          #              memory = "50Mi"
          #            }
          #          }
          liveness_probe {
            exec {
              command = ["pg_isready", "-U", "postgres"]
            }
            failure_threshold = 10
            period_seconds    = 5
            timeout_seconds   = 30
          }
        }

        dynamic "volume" {
          for_each = toset(var.init-sql-configs)
          content {
            name = volume.value
            config_map {
              name = volume.value
            }
          }
        }
      }
    }
    volume_claim_template {
      metadata {
        name = "pgdata"
      }
      spec {
        access_modes       = ["ReadWriteOnce"]
        storage_class_name = "standard"
        resources {
          requests = {
            storage = "10M"
          }
        }
      }
    }

   persistent_volume_claim_retention_policy {
     when_deleted = "Delete"
     when_scaled  = "Delete"
    }

  }
}

resource "kubernetes_config_map" "postgres-env" {
  metadata {
    name      = "${local.app-name}-env"
    namespace = var.namespace
  }

  ## Create databases for keycloak and MIW, create users and assign privileges
  data = {
    POSTGRES_USER     = "postgres"
    POSTGRES_PASSWORD = "postgres"
  }
}

resource "kubernetes_service" "pg-service" {
  metadata {
    name      = "${local.app-name}-service"
    namespace = var.namespace
  }
  spec {
    selector = {
      App = kubernetes_stateful_set.postgres.spec.0.template.0.metadata[0].labels.App
    }
    port {
      name        = "pg-port"
      port        = var.database-port
      target_port = var.database-port
    }
  }
}

locals {
  app-name = "${var.instance-name}-postgres"
  pg-image = "postgres:16.3-alpine3.20"
  db-ip    = kubernetes_service.pg-service.spec.0.cluster_ip
  db-url   = "${kubernetes_service.pg-service.metadata[0].name}:${var.database-port}"
}
