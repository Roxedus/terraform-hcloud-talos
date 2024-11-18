output "talosconfig" {
  value     = data.talos_client_configuration.this.talos_config
  sensitive = true
}

output "kubeconfig" {
  value     = local.kubeconfig
  sensitive = true
}

output "talos_client_configuration" {
  value = data.talos_client_configuration.this
}

output "talos_machine_configurations_control_plane" {
  value     = data.talos_machine_configuration.control_plane
  sensitive = true
}

output "talos_machine_configurations_worker" {
  value     = data.talos_machine_configuration.worker
  sensitive = true
}

output "kubeconfig_data" {
  description = "Structured kubeconfig data to supply to other providers"
  value       = local.kubeconfig_data
  sensitive   = true
}

output "public_ipv4_list" {
  description = "List of public IPv4 addresses of all control plane nodes"
  value       = local.control_plane_public_ipv4_list
}

output "hetzner_network_id" {
  description = "Network ID of the network created at cluster creation"
  value       = hcloud_network.this.id
}

output "hetzner_control_planes" {
  description = "List of control plane nodes as objects"
  value = [for control_plane in hcloud_server.control_planes : {
    name = control_plane.name
    id   = control_plane.id
    ipv4 = control_plane.ipv4_address
    ipv6 = var.enable_ipv6 ? control_plane.ipv6_address : false
  }]
}

output "hetzner_workers" {
  description = "List of worker nodes as objects"
  value = var.worker_count <= 0 ? [for worker in hcloud_server.workers : {
    name = worker.name
    id   = worker.id
    ipv4 = worker.ipv4_address
    ipv6 = var.enable_ipv6 ? worker.ipv6_address : false
  }] : []
}
