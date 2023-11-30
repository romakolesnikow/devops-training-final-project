terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  service_account_key_file = "./authorized_key.json"
  folder_id                = local.folder_id
  zone                     = "ru-central1-a"
}

resource "yandex_vpc_network" "foo" {}

resource "yandex_vpc_subnet" "foo" {
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.foo.id
  v4_cidr_blocks = ["10.5.1.0/24"]
}

resource "yandex_vpc_address" "addr" {
  deletion_protection = true
  name = "bingo-db-adress"
  external_ipv4_address {
    zone_id = "ru-central1-a"
  }
}

resource "yandex_container_registry" "bingo_registry" {
}

locals {
  folder_id = "b1g36oe50ssd59n9jrug"
  service-accounts = toset([
    "bingo-sa",
    "bingo-ig-sa",
  ])
  bingo-sa-roles = toset([
    "container-registry.images.puller",
    "monitoring.editor",
  ])
  bingo-ig-sa-roles = toset([
    "compute.editor",
    "iam.serviceAccounts.user",
    "load-balancer.admin",
    "vpc.publicAdmin",
    "vpc.user",
  ])
}

data "yandex_compute_image" "coi" {
  family = "container-optimized-image"
}

resource "yandex_compute_instance" "bingo-db" {
    name = "bingo-db"
    allow_stopping_for_update = true
    platform_id        = "standard-v2"
    service_account_id = yandex_iam_service_account.service-accounts["bingo-sa"].id
    resources {
      cores         = 2
      memory        = 2
      core_fraction = 5
    }
    scheduling_policy {
      preemptible = true
    }
    network_interface {
      subnet_id = "${yandex_vpc_subnet.foo.id}"
      nat = true
      nat_ip_address = yandex_vpc_address.addr.external_ipv4_address[0].address
    }
    boot_disk {
      initialize_params {
        type = "network-hdd"
        size = "30"
        image_id = data.yandex_compute_image.coi.id
      }
    }
    metadata = {
      docker-compose = file("${path.module}/docker-compose-pg.yaml")
      ssh-keys  = "alpine:${file("~/.ssh/devops_training.pub")}"
    }
}

resource "yandex_compute_instance_group" "bingo" {
  depends_on = [
    yandex_resourcemanager_folder_iam_member.bingo-ig-roles
  ]
  name               = "bingo"
  service_account_id = yandex_iam_service_account.service-accounts["bingo-ig-sa"].id
  allocation_policy {
    zones = ["ru-central1-a"]
  }
  deploy_policy {
    max_unavailable = 1
    max_creating    = 2
    max_expansion   = 2
    max_deleting    = 2
  }
  scale_policy {
    fixed_scale {
      size = 2
    }
  }
  instance_template {
    platform_id        = "standard-v2"
    service_account_id = yandex_iam_service_account.service-accounts["bingo-sa"].id
    resources {
      cores         = 2
      memory        = 2
      core_fraction = 5
    }
    scheduling_policy {
      preemptible = true
    }
    network_interface {
      network_id = yandex_vpc_network.foo.id
      subnet_ids = ["${yandex_vpc_subnet.foo.id}"]
      nat        = true
    }
    boot_disk {
      initialize_params {
        type     = "network-hdd"
        size     = "30"
        image_id = data.yandex_compute_image.coi.id
      }
    }
    metadata = {
      docker-compose = templatefile(
        "${path.module}/docker-compose-app.yaml",
        {
          folder_id   = "${local.folder_id}",
          registry_id = "${yandex_container_registry.bingo_registry.id}",
        }
      )
      #user-data = file("${path.module}/cloud-config.yaml")
      ssh-keys  = "alpine:${file("~/.ssh/devops_training.pub")}"
    }
  }
  load_balancer {
    target_group_name = "bingo"
  }
}

resource "yandex_compute_instance" "bingo-proxy" {
    name = "bingo-proxy"
    platform_id        = "standard-v2"
    service_account_id = yandex_iam_service_account.service-accounts["bingo-sa"].id
    resources {
      cores         = 2
      memory        = 1
      core_fraction = 5
    }
    scheduling_policy {
      preemptible = true
    }
    network_interface {
      subnet_id = "${yandex_vpc_subnet.foo.id}"
      nat = true
    }
    boot_disk {
      initialize_params {
        type = "network-hdd"
        size = "30"
        image_id = data.yandex_compute_image.coi.id
      }
    }
    metadata = {
      docker-compose = file("${path.module}/docker-compose-proxy.yaml")
      ssh-keys  = "alpine:${file("~/.ssh/devops_training.pub")}"
    }
}

resource "yandex_lb_network_load_balancer" "lb-bingo" {
  name = "bingo"

  listener {
    name        = "bingo-listener"
    port        = 80
    target_port = 30238
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_compute_instance_group.bingo.load_balancer[0].target_group_id

    healthcheck {
      name = "http"
      http_options {
        port = 30238
        path = "/ping"
      }
    }
  }
}

resource "yandex_iam_service_account" "service-accounts" {
  for_each = local.service-accounts
  name     = "${local.folder_id}-${each.key}"
}

resource "yandex_resourcemanager_folder_iam_member" "bingo-roles" {
  for_each  = local.bingo-sa-roles
  folder_id = local.folder_id
  member    = "serviceAccount:${yandex_iam_service_account.service-accounts["bingo-sa"].id}"
  role      = each.key
}

resource "yandex_resourcemanager_folder_iam_member" "bingo-ig-roles" {
  for_each  = local.bingo-ig-sa-roles
  folder_id = local.folder_id
  member    = "serviceAccount:${yandex_iam_service_account.service-accounts["bingo-ig-sa"].id}"
  role      = each.key
}