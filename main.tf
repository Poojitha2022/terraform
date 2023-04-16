terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "4.51.0"
    }
	null = {
      source = "hashicorp/null"
      version = "3.2.1"
    }
  }
}

provider "null" {
  # Configuration options
}

provider "google" {
  project = "project1-378704"
  region  = "us-central1"
  zone    = "us-central1-c"
}

resource "google_compute_network" "wp_vpc" {
  name                    = "wp-vpc"
  auto_create_subnetworks = false
  mtu                     = 1460
}

resource "google_compute_subnetwork" "app_subnet" {
  name          =  "app-subnet"
  ip_cidr_range = "10.10.0.0/16"
  region        =  "us-central1"
  network       = google_compute_network.wp_vpc.id
  private_ip_google_access = true
}

resource "google_compute_subnetwork" "db_subnet" {
  name          =  "db-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        =  "us-central1"
  network       = google_compute_network.wp_vpc.id
  private_ip_google_access = true
}

resource "google_compute_firewall" "ssh" {
  name = "allow-ssh"
  allow {
    ports    = ["22","80"]
    protocol = "tcp"
  }
  direction     = "INGRESS"
  network       = google_compute_network.wp_vpc.id
  priority      = 1000
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_address" "static_ip" {
  name = "static-ip"
  region = "us-central1"
  project = "project1-378704"
}

data "google_project" "prod_project" {}

resource "google_container_cluster" "wp_gke" {
  depends_on = [
    google_compute_subnetwork.app_subnet
  ]
  name     = "cluster-name"
  location = "us-central1-c"
  initial_node_count       = 1
  remove_default_node_pool = true
  network       = google_compute_network.wp_vpc.id
  subnetwork = google_compute_subnetwork.app_subnet.name
}

resource "google_sql_database_instance" "sql_db" {
  depends_on = [
    google_compute_subnetwork.db_subnet
  ]
  name = "sqldb"
  database_version = "MYSQL 8.0"
  region       = "us-central1"
  settings {
    tier = "db-f1-micro"

     ip_configuration {
                ipv4_enabled = true
                require_ssl  = false
                
                authorized_networks {
                    name  = "wpSQLconnect"
                    // value = var.static_ip_wp
                    value = "0.0.0.0/0"
         }
      }
   }
}

resource "google_sql_database" "database" {
  name      = "database-name"
  instance  = google_sql_database_instance.sql_db.name
}

resource "google_sql_user" "users" {
  name     = "db-username"
  instance = google_sql_database_instance.sql_db.name
  password = "db-password"
}

resource "google_container_node_pool" "wp_cluster_nodes" {
  name       = "nodepool-name"
  location   = "us-central1-c"
  cluster    = google_container_cluster.wp_gke.name
  node_count = 1

  node_config {
    machine_type = "n1-standard-1"
    disk_size_gb = 100
    disk_type = "pd-standard"

    metadata = {
      disable-legacy-endpoints = "true"
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]
  }
}

resource "null_resource" "update_kubeconfig"  {
depends_on = [
    google_container_node_pool.wp_cluster_nodes
  ]
	provisioner "local-exec" {
        command = <<EOF
     	 gcloud container clusters get-credentials ${google_container_cluster.wp_gke.name} --zone ${google_container_cluster.wp_gke.location} --project ${data.google_project.prod_project.project_id}
       sleep 5
       EOF
    
    interpreter = ["PowerShell", "-Command"]
  	}
}

variable "uname" {}
variable "pass" {}
variable "dbname" {}

data "google_client_config" "provider" {}

data "google_container_cluster" "my_cluster" {
  depends_on = [
    google_container_cluster.wp_gke
  ]
  name     =  "cluster-name"
  location =  "us-central1-c"
}

provider "kubernetes" {
  host  = "https://${data.google_container_cluster.my_cluster.endpoint}"
  token = data.google_client_config.provider.access_token
  cluster_ca_certificate = base64decode(
    data.google_container_cluster.my_cluster.master_auth.0.cluster_ca_certificate,
  )
}

resource "kubernetes_deployment" "wp_deploy" {
  metadata {
    name = "wordpress"
    labels = {
      app = "wordpress"
    }
  }
  spec {
      replicas = 1
    selector {
      match_labels = {
        app = "wordpress"
      }
    }
    template {
      metadata {
        labels = {
          app = "wordpress"
        }
      }
      spec {
        container {
          image = "wordpress"
          name  = "wordpress-pod"
          env {
            name = "WORDPRESS_DB_HOST"
            value = google_sql_database_instance.sql_db.public_ip_address
            }
          env {
            name = "WORDPRESS_DB_DATABASE"
            value = var.dbname
            }
          env {
            name = "WORDPRESS_DB_USER"
            value = var.uname
            }
          env {
            name = "WORDPRESS_DB_PASSWORD"
            value = var.pass
          }
          port {
        container_port = 80
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "wp_service" {
  metadata {
    name = "wp-service"
   
  }
  spec {
    load_balancer_ip = google_compute_address.static_ip.address
    selector = {
      app = "wordpress"
    }
    port {
      port        = 80
      target_port = 80
    }
    type = "LoadBalancer"
  
  }
}
