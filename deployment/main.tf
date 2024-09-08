#
#  Copyright (c) 2023 Contributors to the Eclipse Foundation
#
#  See the NOTICE file(s) distributed with this work for additional
#  information regarding copyright ownership.
#
#  This program and the accompanying materials are made available under the
#  terms of the Apache License, Version 2.0 which is available at
#  https://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#  WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#  License for the specific language governing permissions and limitations
#  under the License.
#
#  SPDX-License-Identifier: Apache-2.0
#

terraform {
  required_providers {
    // for generating passwords, clientsecrets etc.
    random = {
      source = "hashicorp/random"
    }

    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    helm = {
      // used for Hashicorp Vault
      source = "hashicorp/helm"
    }
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

resource "kubernetes_namespace" "ns" {
  metadata {
    name = "mvd"
  }
}

resource "kubernetes_config_map" "vault-init-script" {
  metadata {
    namespace = "mvd"
    name = "vault-init-script"
  }

  data = {
#    "init-unseal.sh" = "${file("${path.module}/init-unseal.sh")}"
    "init-unseal.sh" = "${file("init-unseal.sh")}"
  }
}


resource "null_resource" "post_deploy" {
  provisioner "local-exec" {
    command = "./replace-token.sh"
  }

  triggers = {
    always_run = "${timestamp()}"
  }
}
