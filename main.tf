terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.50.0"
    }
  }
}

provider "google" {
  project = "your-gcp-project-id" # replace your GCP project ID
  region  = "us-west1"
}

# 1. Create a VPC network
resource "google_compute_network" "tiktok_stream_vpc" {
  name                    = "tiktok-stream-vpc"
  auto_create_subnetworks = false
}

# 2. Create a subnet
resource "google_compute_subnetwork" "tiktok_stream_subnet" {
  name          = "tiktok-stream-subnet-us-west1"
  ip_cidr_range = "10.10.1.0/24"
  region        = "us-west1"
  network       = google_compute_network.tiktok_stream_vpc.id
}

# 3. Create firewall rules
resource "google_compute_firewall" "allow_stream_traffic" {
  name    = "allow-stream-traffic"
  network = google_compute_network.tiktok_stream_vpc.name

  allow {
    protocol = "udp"
    ports    = ["51820"] # WireGuard port
  }

  allow {
    protocol = "tcp"
    ports    = ["22"] # SSH port
  }

  source_ranges = ["0.0.0.0/0"]
}

# 4. Create a GCE instance
resource "google_compute_instance" "wg_server_usw1" {
  name         = "wg-server-us-west1"
  machine_type = "e2-small" # e2-small is sufficient for traffic forwarding
  zone         = "us-west1-b"

  tags = ["wireguard-server"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.tiktok_stream_subnet.id
    network_ip = "10.10.1.10"
    # Key: Use the Premium Tier network
    network_tier = "PREMIUM"
    access_config {
      // Assign temporary public IP
    }
  }

  // Start script: automatically install WireGuard and turn on IP forwarding
  metadata_startup_script = <<-EOT
#! /bin/bash
apt-get update
apt-get install -y wireguard iptables
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p
EOT

  service_account {
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }
}

# Output the public IP of the GCE instance
output "wg_server_ip" {
  value = google_compute_instance.wg_server_usw1.network_interface[0].access_config[0].nat_ip
}
