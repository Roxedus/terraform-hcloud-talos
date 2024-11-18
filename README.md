<div align="center">
  <br>
  <img src="https://github.com/hcloud-talos/terraform-hcloud-talos/blob/main/.idea/icon.png?raw=true" alt="Terraform - Hcloud - Talos" width="200"/>
  <h1 style="margin-top: 0; padding-top: 0;">Terraform - Hcloud - Talos</h1>
  <img alt="GitHub Release" src="https://img.shields.io/github/v/release/hcloud-talos/terraform-hcloud-talos?logo=github">
</div>

---

This repository contains a Terraform module for creating a Kubernetes cluster with Talos in the Hetzner Cloud.

- Talos is a modern OS for Kubernetes. It is designed to be secure, immutable, and minimal.
- Hetzner Cloud is a cloud hosting provider with nice terraform support and cheap prices.

> [!WARNING]
> This module is under active development. Not all features are compatible with each other yet.
> Known issues are listed in the [Known Issues](#known-issues) section.
> If you find a bug or have a feature request, please open an issue.

---

## Goals 🚀

| Goals                                                                               | Status | Description                                                                                                                                                                                         |
|-------------------------------------------------------------------------------------|--------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Production ready                                                                    | ✅      | All recommendations from the [Talos Production Clusters](https://www.talos.dev/v1.6/introduction/prodnotes/) are implemented. **But you need to read it carefully to understand all implications.** |
| Use private networks for the internal communication of the cluster                  | ✅      |                                                                                                                                                                                                     |
| Do not expose the Kubernetes and Talos API to the public internet via Load-Balancer | ✅      | Actually, the APIs are exposed to the public internet, but secured via the `firewall_use_current_ip` flag and a firewall rule that only allows traffic from one IP address.                         |
| Possibility to change alls CIDRs of the networks                                    | ⁉️     | Needs to be tested.                                                                                                                                                                                 |
| Configure the Cluster as good as possible to run in the Hetzner Cloud               | ✅      | This includes manual configuration of the network devices and not via DHCP, provisioning of Floating IPs (VIP), etc.                                                                                |

## Information about the Module

- A lot of information can be found directly in the descriptions of the variables.
- You can configure the module to create a cluster with 1, 3 or 5 control planes and n workers or only the control
  planes.
- It allows scheduling pods on the control planes if no workers are created.
- It has [Multihoming](https://www.talos.dev/v1.6/introduction/prodnotes/#multihoming) configuration (etcd and kubelet
  listen on public and private IP).
- It uses [KubePrism](https://www.talos.dev/v1.6/kubernetes-guides/configuration/kubeprism/)
  as [cluster endpoint](https://www.talos.dev/v1.6/reference/cli/#synopsis-9).
- If `cluster_api_host` is set, then you should create a corresponding DNS record pointing to either one control plane, the load balancer,
  floating IP, or alias IP.
  If `cluster_api_host` is not set, then a record for `kube.[cluster_domain]` should be created.
  It totally depends on your setup.

## Additional installed software in the cluster

### [Cilium](https://cilium.io/)

- Cilium is a modern, efficient, and secure networking and security solution for Kubernetes.
- [Cilium is used as the CNI](https://www.talos.dev/v1.6/kubernetes-guides/network/deploying-cilium/) instead of the default Flannel.
- It provides a lot of features like Network Policies, Load Balancing, and more.

> [!IMPORTANT]
> The Cilium version (`cilium_version`) has to be compatible with the Kubernetes (`kubernetes_version`) version.

### [Hcloud Cloud Controller Manager](https://github.com/hetznercloud/hcloud-cloud-controller-manager)

- Updates the `Node` objects with information about the server from the Cloud , like instance Type, Location,
  Datacenter, Server ID, IPs.
- Cleans up stale `Node` objects when the server is deleted in the API.
- Routes traffic to the pods through Hetzner Cloud Networks. Removes one layer of indirection.
- Watches Services with `type: LoadBalancer` and creates Hetzner Cloud Load Balancers for them, adds Kubernetes
  Nodes as targets for the Load Balancer.

### [Talos Cloud Controller Manager](https://github.com/siderolabs/talos-cloud-controller-manager)

- [Applies labels to the nodes](https://github.com/siderolabs/talos-cloud-controller-manager?tab=readme-ov-file#node-initialize).
- [Validates and approves node CSRs](https://github.com/siderolabs/talos-cloud-controller-manager?tab=readme-ov-file#node-certificate-approval).
- In DaemonSet mode: CCM will use hostNetwork and current node to access kubernetes/talos API

## Prerequisites

### Required Software

- [terraform](https://www.terraform.io/downloads.html)
- [packer](https://www.packer.io/downloads)
- [helm](https://helm.sh/docs/intro/install/)

### Recommended Software

- [hcloud cli](https://github.com/hetznercloud/cli)
- [talosctl](https://www.talos.dev/v1.6/introduction/getting-started/#talosctl)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)

### Hetzner Cloud

> [!TIP]
> If you don't have a Hetzner account yet, you are welcome to use
> this [Hetzner Cloud Referral Link](https://hetzner.cloud/?ref=6Q6Q6Q6Q6Q6Q) to claim 20€ credit and support
> this project.

- Create a new project in the Hetzner Cloud Console
- Create a new API token in the project
- You can store the token in the environment variable `HCLOUD_TOKEN` or use it in the following commands/terraform
  files.

## Usage

### Packer

Create the talos os images (ARM and x86) via packer through running the [create.sh](_packer/create.sh).
It is using the `HCLOUD_TOKEN` environment variable to authenticate against the Hetzner Cloud API and uses the project
of the token to store the images.
The talos os version is defined in the variable `talos_version`
in [talos-hcloud.pkr.hcl](_packer/talos-hcloud.pkr.hcl).

```bash
./_packer/create.sh
```

### Terraform

Use the module as shown in the following working minimal example:

> [!NOTE]
> Actually, your current IP address has to have access to the nodes during the creation of the cluster.

```hcl
module "talos" {
  source  = "hcloud-talos/talos/hcloud"
  version = "the-latest-version-of-the-module"

  talos_version = "v1.8.1" # The version of talos features to use in generated machine configurations

  hcloud_token = "your-hcloud-token"

  # If true, the current IP address will be used as the source for the firewall rules.
  # ATTENTION: to determine the current IP, a request to a public service (https://ipv4.icanhazip.com) is made.
  # If false, you have to provide your public IP address (as list) in the variable `firewall_kube_api_source` and `firewall_talos_api_source`.
  firewall_use_current_ip = true

  cluster_name    = "dummy.com"
  datacenter_name = "fsn1-dc14"

  control_plane_count       = 1
  control_plane_server_type = "cax11"
}
```

Or a more advanced example:

```hcl
module "talos" {
  source  = "hcloud-talos/talos/hcloud"
  version = "the-latest-version-of-the-module"

  talos_version = "v1.8.1"
  kubernetes_version = "1.29.7"
  cilium_version = "1.15.7"

  hcloud_token = "your-hcloud-token"

  cluster_name     = "dummy.com"
  cluster_domain   = "cluster.dummy.com.local"
  cluster_api_host = "kube.dummy.com"

  firewall_use_current_ip = false
  firewall_kube_api_source = ["your-ip"]
  firewall_talos_api_source = ["your-ip"]

  datacenter_name = "fsn1-dc14"

  control_plane_count       = 3
  control_plane_server_type = "cax11"

  worker_count       = 3
  worker_server_type = "cax21"

  network_ipv4_cidr = "10.0.0.0/16"
  node_ipv4_cidr    = "10.0.1.0/24"
  pod_ipv4_cidr     = "10.0.16.0/20"
  service_ipv4_cidr = "10.0.8.0/21"
}
```

You need to pipe the outputs of the module:

```hcl
output "talosconfig" {
  value     = module.talos.talosconfig
  sensitive = true
}

output "kubeconfig" {
  value     = module.talos.kubeconfig
  sensitive = true
}
```

Then you can then run the following commands to export the kubeconfig and talosconfig:

```bash
terraform output --raw kubeconfig > ./kubeconfig
terraform output --raw talosconfig > ./talosconfig
```

Move these files to the correct location and use them with `kubectl` and `talosctl`.

## Additional Configuration Examples

### Kubelet Extra Args

```hcl
kubelet_extra_args = {
  system-reserved            = "cpu=100m,memory=250Mi,ephemeral-storage=1Gi"
  kube-reserved              = "cpu=100m,memory=200Mi,ephemeral-storage=1Gi"
  eviction-hard              = "memory.available<100Mi,nodefs.available<10%"
  eviction-soft              = "memory.available<200Mi,nodefs.available<15%"
  eviction-soft-grace-period = "memory.available=2m30s,nodefs.available=4m"
}
```

### Sysctls Extra Args

```hcl
sysctls_extra_args = {
  # Fix for https://github.com/cloudflare/cloudflared/issues/1176
  "net.core.rmem_default" = "26214400"
  "net.core.wmem_default" = "26214400"
  "net.core.rmem_max"     = "26214400"
  "net.core.wmem_max"     = "26214400"
}
```

### Activate Kernel Modules

```hcl
kernel_modules_to_load = [
  {
    name = "binfmt_misc" # Required for QEMU
  }
]
```

## Known Limitations

- Changes in the `user_data` (e.g. `talos_machine_configuration`) and `image` (e.g. version upgrades with `packer`) will
  not be applied to existing nodes, because it would force a recreation of the nodes.

## Known Issues

- IPv6 dual stack is not supported by Talos yet. You can activate IPv6 with `enable_ipv6`, but it should not have any
  effect.
- `enable_kube_span` let's the cluster not get in ready state. It is not clear why yet. I have to investigate it.
- `403 Forbidden user` in startup log: This is a known issue with Hetzner IPs.
  See [#46](https://github.com/hcloud-talos/terraform-hcloud-talos/issues/46) and [registry.k8s.io #138](https://github.com/kubernetes/registry.k8s.io/issues/138)

## Credits

- [kube-hetzner](https://github.com/kube-hetzner/terraform-hcloud-kube-hetzner) For the inspiration and the great
  terraform module. This module is based on many ideas and code snippets from kube-hetzner.
- [Talos](https://www.talos.dev/) For the incredible OS.
- [Hetzner Cloud](https://www.hetzner.com/cloud) For the great cloud hosting.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >=1.8.0 |
| <a name="requirement_hcloud"></a> [hcloud](#requirement\_hcloud) | >= 1.49.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 2.16.1 |
| <a name="requirement_http"></a> [http](#requirement\_http) | >= 3.4.5 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | >= 2.1.3 |
| <a name="requirement_talos"></a> [talos](#requirement\_talos) | >= 0.6.1 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | >= 4.0.6 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_hcloud"></a> [hcloud](#provider\_hcloud) | >= 1.49.0 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | >= 2.16.1 |
| <a name="provider_http"></a> [http](#provider\_http) | >= 3.4.5 |
| <a name="provider_kubectl"></a> [kubectl](#provider\_kubectl) | >= 2.1.3 |
| <a name="provider_talos"></a> [talos](#provider\_talos) | >= 0.6.1 |
| <a name="provider_tls"></a> [tls](#provider\_tls) | >= 4.0.6 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [hcloud_firewall.this](https://registry.terraform.io/providers/hetznercloud/hcloud/latest/docs/resources/firewall) | resource |
| [hcloud_floating_ip.control_plane_ipv4](https://registry.terraform.io/providers/hetznercloud/hcloud/latest/docs/resources/floating_ip) | resource |
| [hcloud_floating_ip_assignment.this](https://registry.terraform.io/providers/hetznercloud/hcloud/latest/docs/resources/floating_ip_assignment) | resource |
| [hcloud_network.this](https://registry.terraform.io/providers/hetznercloud/hcloud/latest/docs/resources/network) | resource |
| [hcloud_network_subnet.nodes](https://registry.terraform.io/providers/hetznercloud/hcloud/latest/docs/resources/network_subnet) | resource |
| [hcloud_placement_group.control_plane](https://registry.terraform.io/providers/hetznercloud/hcloud/latest/docs/resources/placement_group) | resource |
| [hcloud_placement_group.worker](https://registry.terraform.io/providers/hetznercloud/hcloud/latest/docs/resources/placement_group) | resource |
| [hcloud_primary_ip.control_plane_ipv4](https://registry.terraform.io/providers/hetznercloud/hcloud/latest/docs/resources/primary_ip) | resource |
| [hcloud_primary_ip.control_plane_ipv6](https://registry.terraform.io/providers/hetznercloud/hcloud/latest/docs/resources/primary_ip) | resource |
| [hcloud_primary_ip.worker_ipv4](https://registry.terraform.io/providers/hetznercloud/hcloud/latest/docs/resources/primary_ip) | resource |
| [hcloud_primary_ip.worker_ipv6](https://registry.terraform.io/providers/hetznercloud/hcloud/latest/docs/resources/primary_ip) | resource |
| [hcloud_server.control_planes](https://registry.terraform.io/providers/hetznercloud/hcloud/latest/docs/resources/server) | resource |
| [hcloud_server.workers](https://registry.terraform.io/providers/hetznercloud/hcloud/latest/docs/resources/server) | resource |
| [hcloud_ssh_key.this](https://registry.terraform.io/providers/hetznercloud/hcloud/latest/docs/resources/ssh_key) | resource |
| [kubectl_manifest.apply_cilium](https://registry.terraform.io/providers/alekc/kubectl/latest/docs/resources/manifest) | resource |
| [kubectl_manifest.apply_hcloud_ccm](https://registry.terraform.io/providers/alekc/kubectl/latest/docs/resources/manifest) | resource |
| [kubectl_manifest.apply_prometheus_operator_crds](https://registry.terraform.io/providers/alekc/kubectl/latest/docs/resources/manifest) | resource |
| [talos_cluster_kubeconfig.this](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/resources/cluster_kubeconfig) | resource |
| [talos_machine_bootstrap.this](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/resources/machine_bootstrap) | resource |
| [talos_machine_secrets.this](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/resources/machine_secrets) | resource |
| [tls_cert_request.dummy_issuer](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/cert_request) | resource |
| [tls_locally_signed_cert.dummy_issuer](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/locally_signed_cert) | resource |
| [tls_private_key.dummy_ca](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |
| [tls_private_key.dummy_issuer](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |
| [tls_private_key.ssh_key](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |
| [tls_self_signed_cert.dummy_ca](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/self_signed_cert) | resource |
| [hcloud_datacenter.this](https://registry.terraform.io/providers/hetznercloud/hcloud/latest/docs/data-sources/datacenter) | data source |
| [hcloud_floating_ip.control_plane_ipv4](https://registry.terraform.io/providers/hetznercloud/hcloud/latest/docs/data-sources/floating_ip) | data source |
| [hcloud_image.arm](https://registry.terraform.io/providers/hetznercloud/hcloud/latest/docs/data-sources/image) | data source |
| [hcloud_image.x86](https://registry.terraform.io/providers/hetznercloud/hcloud/latest/docs/data-sources/image) | data source |
| [hcloud_location.this](https://registry.terraform.io/providers/hetznercloud/hcloud/latest/docs/data-sources/location) | data source |
| [helm_template.cilium_default](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/data-sources/template) | data source |
| [helm_template.cilium_from_values](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/data-sources/template) | data source |
| [helm_template.hcloud_ccm](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/data-sources/template) | data source |
| [helm_template.prometheus_operator_crds](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/data-sources/template) | data source |
| [http_http.personal_ipv4](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http) | data source |
| [http_http.personal_ipv6](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http) | data source |
| [http_http.talos_health](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http) | data source |
| [kubectl_file_documents.cilium](https://registry.terraform.io/providers/alekc/kubectl/latest/docs/data-sources/file_documents) | data source |
| [kubectl_file_documents.hcloud_ccm](https://registry.terraform.io/providers/alekc/kubectl/latest/docs/data-sources/file_documents) | data source |
| [kubectl_file_documents.prometheus_operator_crds](https://registry.terraform.io/providers/alekc/kubectl/latest/docs/data-sources/file_documents) | data source |
| [talos_client_configuration.this](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/data-sources/client_configuration) | data source |
| [talos_machine_configuration.control_plane](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/data-sources/machine_configuration) | data source |
| [talos_machine_configuration.worker](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/data-sources/machine_configuration) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cilium_enable_encryption"></a> [cilium\_enable\_encryption](#input\_cilium\_enable\_encryption) | Enable transparent network encryption. | `bool` | `false` | no |
| <a name="input_cilium_enable_service_monitors"></a> [cilium\_enable\_service\_monitors](#input\_cilium\_enable\_service\_monitors) | If true, the service monitors for Prometheus will be enabled.<br/>    Service Monitor requires monitoring.coreos.com/v1 CRDs.<br/>    You can use the deploy\_prometheus\_operator\_crds variable to deploy them. | `bool` | `false` | no |
| <a name="input_cilium_values"></a> [cilium\_values](#input\_cilium\_values) | The values.yaml file to use for the Cilium Helm chart.<br/>    If null (default), the default values will be used.<br/>    Otherwise, the provided values will be used.<br/>    Example:<pre>cilium_values  = [templatefile("cilium/values.yaml", {})]</pre> | `list(string)` | `null` | no |
| <a name="input_cilium_version"></a> [cilium\_version](#input\_cilium\_version) | The version of Cilium to deploy. If not set, the `1.16.0` version will be used.<br/>    Needs to be compatible with the `kubernetes_version`: https://docs.cilium.io/en/stable/network/kubernetes/compatibility/ | `string` | `"1.16.2"` | no |
| <a name="input_cluster_api_host"></a> [cluster\_api\_host](#input\_cluster\_api\_host) | The entrypoint of the cluster. Must be a valid domain name. If not set, `kube.[cluster_domain]` will be used.<br/>    You should create a DNS record pointing to either the load balancer, floating IP, or alias IP. | `string` | `null` | no |
| <a name="input_cluster_domain"></a> [cluster\_domain](#input\_cluster\_domain) | The domain name of the cluster. | `string` | `"cluster.local"` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | The name of the cluster. | `string` | n/a | yes |
| <a name="input_cluster_prefix"></a> [cluster\_prefix](#input\_cluster\_prefix) | Prefix Hetzner Cloud resources with the cluster name. | `bool` | `false` | no |
| <a name="input_control_plane_count"></a> [control\_plane\_count](#input\_control\_plane\_count) | The number of control plane nodes to create.<br/>    Must be an odd number. Maximum 5. | `number` | n/a | yes |
| <a name="input_control_plane_server_type"></a> [control\_plane\_server\_type](#input\_control\_plane\_server\_type) | The server type to use for the control plane nodes.<br/>    Possible values: cx11, cx21, cx22, cx31, cx32, cx41, cx42, cx51, cx52, cpx11, cpx21, cpx31,<br/>    cpx41, cpx51, cax11, cax21, cax31, cax41, ccx13, ccx23, ccx33, ccx43, ccx53, ccx63 | `string` | n/a | yes |
| <a name="input_datacenter_name"></a> [datacenter\_name](#input\_datacenter\_name) | The name of the datacenter where the cluster will be created.<br/>    This is used to determine the region and zone of the cluster and network.<br/>    Possible values: fsn1-dc14, nbg1-dc3, hel1-dc2, ash-dc1, hil-dc1 | `string` | n/a | yes |
| <a name="input_deploy_prometheus_operator_crds"></a> [deploy\_prometheus\_operator\_crds](#input\_deploy\_prometheus\_operator\_crds) | If true, the Prometheus Operator CRDs will be deployed. | `bool` | `false` | no |
| <a name="input_disable_arm"></a> [disable\_arm](#input\_disable\_arm) | If true, arm images will not be used. | `bool` | `false` | no |
| <a name="input_disable_talos_coredns"></a> [disable\_talos\_coredns](#input\_disable\_talos\_coredns) | If true, the CoreDNS delivered by Talos will not be deployed. | `bool` | `false` | no |
| <a name="input_disable_x86"></a> [disable\_x86](#input\_disable\_x86) | If true, x86 images will not be used. | `bool` | `false` | no |
| <a name="input_enable_alias_ip"></a> [enable\_alias\_ip](#input\_enable\_alias\_ip) | If true, an alias IP (cidrhost(node\_ipv4\_cidr, 100)) will be created and assigned to the control plane nodes. | `bool` | `true` | no |
| <a name="input_enable_controlplane_workload"></a> [enable\_controlplane\_workload](#input\_enable\_controlplane\_workload) | If true, the control plane nodes will also run workloads. | `bool` | `false` | no |
| <a name="input_enable_floating_ip"></a> [enable\_floating\_ip](#input\_enable\_floating\_ip) | If true, a floating IP will be created and assigned to the control plane nodes. | `bool` | `false` | no |
| <a name="input_enable_ipv6"></a> [enable\_ipv6](#input\_enable\_ipv6) | If true, the servers will have an IPv6 address.<br/>    IPv4/IPv6 dual-stack is actually not supported, it keeps being an IPv4 single stack. PRs welcome! | `bool` | `false` | no |
| <a name="input_enable_kube_span"></a> [enable\_kube\_span](#input\_enable\_kube\_span) | If true, the KubeSpan Feature (with "Kubernetes registry" mode) will be enabled. | `bool` | `false` | no |
| <a name="input_extra_firewall_rules"></a> [extra\_firewall\_rules](#input\_extra\_firewall\_rules) | Additional firewall rules to apply to the cluster. | `list(any)` | `[]` | no |
| <a name="input_firewall_kube_api_source"></a> [firewall\_kube\_api\_source](#input\_firewall\_kube\_api\_source) | Source networks that have Kube API access to the servers.<br/>    If null (default), the all traffic is blocked.<br/>    If set, this overrides the firewall\_use\_current\_ip setting. | `list(string)` | `null` | no |
| <a name="input_firewall_talos_api_source"></a> [firewall\_talos\_api\_source](#input\_firewall\_talos\_api\_source) | Source networks that have Talos API access to the servers.<br/>    If null (default), the all traffic is blocked.<br/>    If set, this overrides the firewall\_use\_current\_ip setting. | `list(string)` | `null` | no |
| <a name="input_firewall_use_current_ip"></a> [firewall\_use\_current\_ip](#input\_firewall\_use\_current\_ip) | If true, the current IP address will be used as the source for the firewall rules.<br/>    ATTENTION: to determine the current IP, a request to a public service (https://ipv4.icanhazip.com) is made. | `bool` | `false` | no |
| <a name="input_floating_ip"></a> [floating\_ip](#input\_floating\_ip) | The Floating IP (ID) to use for the control plane nodes.<br/>    If null (default), a new floating IP will be created.<br/>    (using object because of https://github.com/hashicorp/terraform/issues/26755) | <pre>object({<br/>    id = number,<br/>  })</pre> | `null` | no |
| <a name="input_hcloud_ccm_version"></a> [hcloud\_ccm\_version](#input\_hcloud\_ccm\_version) | The version of the Hetzner Cloud Controller Manager to deploy. If not set, the latest version will be used. | `string` | `null` | no |
| <a name="input_hcloud_token"></a> [hcloud\_token](#input\_hcloud\_token) | The Hetzner Cloud API token. | `string` | n/a | yes |
| <a name="input_kernel_modules_to_load"></a> [kernel\_modules\_to\_load](#input\_kernel\_modules\_to\_load) | List of kernel modules to load. | <pre>list(object({<br/>    name       = string<br/>    parameters = optional(list(string))<br/>  }))</pre> | `null` | no |
| <a name="input_kube_api_extra_args"></a> [kube\_api\_extra\_args](#input\_kube\_api\_extra\_args) | Additional arguments to pass to the kube-apiserver. | `map(string)` | `{}` | no |
| <a name="input_kubelet_extra_args"></a> [kubelet\_extra\_args](#input\_kubelet\_extra\_args) | Additional arguments to pass to kubelet. | `map(string)` | `{}` | no |
| <a name="input_kubelet_extra_mounts"></a> [kubelet\_extra\_mounts](#input\_kubelet\_extra\_mounts) | Additional mounts to pass to kubelet. | <pre>list(object({<br/>    destination = string<br/>    type        = string<br/>    source      = string<br/>    options     = optional(list(string))<br/>  }))</pre> | `[]` | no |
| <a name="input_kubernetes_version"></a> [kubernetes\_version](#input\_kubernetes\_version) | The Kubernetes version to use. If not set, the latest version supported by Talos is used: https://www.talos.dev/v1.7/introduction/support-matrix/<br/>    Needs to be compatible with the `cilium_version`: https://docs.cilium.io/en/stable/network/kubernetes/compatibility/ | `string` | `"1.30.3"` | no |
| <a name="input_network_ipv4_cidr"></a> [network\_ipv4\_cidr](#input\_network\_ipv4\_cidr) | The main network cidr that all subnets will be created upon. | `string` | `"10.0.0.0/16"` | no |
| <a name="input_node_ipv4_cidr"></a> [node\_ipv4\_cidr](#input\_node\_ipv4\_cidr) | Node CIDR, used for the nodes (control plane and worker nodes) in the cluster. | `string` | `"10.0.1.0/24"` | no |
| <a name="input_output_mode_config_cluster_endpoint"></a> [output\_mode\_config\_cluster\_endpoint](#input\_output\_mode\_config\_cluster\_endpoint) | Configure which IP addresses are to be used in Talos- and Kube-config output.<br/>    Possible values: public\_ip, private\_ip, cluster\_endpoint<br/>    ATTENTION: If 'cluster\_endpoint' is selected, 'cluster\_api\_host' is used and should be set, too. | `string` | `"public_ip"` | no |
| <a name="input_pod_ipv4_cidr"></a> [pod\_ipv4\_cidr](#input\_pod\_ipv4\_cidr) | Pod CIDR, used for the pods in the cluster. | `string` | `"10.0.16.0/20"` | no |
| <a name="input_registries"></a> [registries](#input\_registries) | List of registry mirrors to use.<br/>    Example:<pre>registries = {<br/>      mirrors = {<br/>        "docker.io" = {<br/>          endpoints = [<br/>            "http://localhost:5000",<br/>            "https://docker.io"<br/>          ]<br/>        }<br/>      }<br/>    }</pre>https://www.talos.dev/v1.6/reference/configuration/v1alpha1/config/#Config.machine.registries | <pre>object({<br/>    mirrors = map(object({<br/>      endpoints    = list(string)<br/>      overridePath = optional(bool)<br/>    }))<br/>  })</pre> | `null` | no |
| <a name="input_service_ipv4_cidr"></a> [service\_ipv4\_cidr](#input\_service\_ipv4\_cidr) | Service CIDR, used for the services in the cluster. | `string` | `"10.0.8.0/21"` | no |
| <a name="input_ssh_public_key"></a> [ssh\_public\_key](#input\_ssh\_public\_key) | The public key to be set in the servers. It is not used in any way.<br/>    If you don't set it, a dummy key will be generated and used.<br/>    Unfortunately, it is still required, otherwise the Hetzner will sen E-Mails with login credentials. | `string` | `null` | no |
| <a name="input_sysctls_extra_args"></a> [sysctls\_extra\_args](#input\_sysctls\_extra\_args) | Additional sysctls to set. | `map(string)` | `{}` | no |
| <a name="input_talos_version"></a> [talos\_version](#input\_talos\_version) | The version of talos features to use in generated machine configurations. | `string` | n/a | yes |
| <a name="input_worker_count"></a> [worker\_count](#input\_worker\_count) | The number of worker nodes to create. Maximum 99. | `number` | `0` | no |
| <a name="input_worker_server_type"></a> [worker\_server\_type](#input\_worker\_server\_type) | The server type to use for the worker nodes.<br/>    Possible values: cx11, cx21, cx22, cx31, cx32, cx41, cx42, cx51, cx52, cpx11, cpx21, cpx31,<br/>    cpx41, cpx51, cax11, cax21, cax31, cax41, ccx13, ccx23, ccx33, ccx43, ccx53, ccx63 | `string` | `"cx11"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_hetzner_network_id"></a> [hetzner\_network\_id](#output\_hetzner\_network\_id) | Network ID of the network created at cluster creation |
| <a name="output_kubeconfig"></a> [kubeconfig](#output\_kubeconfig) | n/a |
| <a name="output_kubeconfig_data"></a> [kubeconfig\_data](#output\_kubeconfig\_data) | Structured kubeconfig data to supply to other providers |
| <a name="output_public_ipv4_list"></a> [public\_ipv4\_list](#output\_public\_ipv4\_list) | List of public IPv4 addresses of all control plane nodes |
| <a name="output_talos_client_configuration"></a> [talos\_client\_configuration](#output\_talos\_client\_configuration) | n/a |
| <a name="output_talos_machine_configurations_control_plane"></a> [talos\_machine\_configurations\_control\_plane](#output\_talos\_machine\_configurations\_control\_plane) | n/a |
| <a name="output_talos_machine_configurations_worker"></a> [talos\_machine\_configurations\_worker](#output\_talos\_machine\_configurations\_worker) | n/a |
| <a name="output_talosconfig"></a> [talosconfig](#output\_talosconfig) | n/a |
<!-- END_TF_DOCS -->