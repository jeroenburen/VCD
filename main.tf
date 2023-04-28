# Recommended using the required_providers block to set the
# VMware VCD Provider source and version being used
terraform {
  required_providers {
    vcd = {
      source  = "vmware/vcd"
      version = "3.9.0"
    }
  }
}

variable "vcd_user" {
    description = "vCloud user"
}
variable "vcd_pass" {
    description = "vCloud pass"
}
variable "vcd_max_retry_timeout" {
    default = 60
}
variable "vcd_allow_unverified_ssl" {
    default = true
}
variable "vcd_url" {}

variable "org_name" {}
variable "org_fullname" {}
variable "org_description" {}

variable "vdc_name" {}
variable "vdc_description" {}

variable "pvdc_name" {}
variable "allocation_model" {}
variable "vdc_cpu_alloc" {}
variable "vdc_cpu_limit" {}
variable "vdc_cpu_speed" {}
variable "vdc_memory_alloc" {}
variable "vdc_memory_limit" {}
variable "network_pool_name" {}

variable "org_admin" {}
variable "org_admin_fullname" {}
variable "org_admin_description" {}
variable "org_admin_email" {}
variable "org_admin_role" {}
variable "org_admin_password" {}

variable "edge_network" {}
variable "edge_name" {}
variable "edge_primary_ip" {}

# Connect VMware vCloud Director Provider
provider "vcd" {
  user                 = var.vcd_user
  password             = var.vcd_pass
  org                  = "System"
  url                  = var.vcd_url
  max_retry_timeout    = var.vcd_max_retry_timeout
  allow_unverified_ssl = var.vcd_allow_unverified_ssl
}

#Create a new Organization"
resource "vcd_org" "org-name" {
  name             = var.org_name
  full_name        = var.org_fullname
  description      = var.org_description
  is_enabled       = "true"
  delete_recursive = "true"
  delete_force     = "true"
}

# Create Org VDC for above org
resource "vcd_org_vdc" "vdc-name" {
  name        = var.vdc_name
  description = var.vdc_description
  org         = var.org_name
  provider_vdc_name = var.pvdc_name
  allocation_model = var.allocation_model
  elasticity = true
  include_vm_memory_overhead = true
  cpu_speed = var.vdc_cpu_speed
  compute_capacity {
    cpu {
      allocated = var.vdc_cpu_alloc
      limit = var.vdc_cpu_limit
    }
    memory {
      allocated = var.vdc_memory_alloc
      limit = var.vdc_memory_limit
    }
  }
  memory_guaranteed = 1 # 100%
  storage_profile {
    name     = "Standard SSD Tier (Amsterdam, VM Based)"
    limit    = 500000
    default  = false    
  }
  storage_profile {
    name     = "Standard SSD Tier (Rotterdam, VM Based)"
    limit    = 500000
    default  = false    
  }
  storage_profile {
    name     = "Standard SSD Tier (Stretched, VM Based)"
    limit    = 500000
    default  = true    
  }
  vm_quota                 = 250 #Max no. of VMs 
  network_quota            = 100
  enabled                  = true
  enable_thin_provisioning = true
  enable_fast_provisioning = true
  delete_force             = true
  delete_recursive         = true
  network_pool_name = var.network_pool_name
  depends_on = [vcd_org.org-name]
}

#Create a new Organization Admin
resource "vcd_org_user" "org-admin" {
  org = var.org_name  
  name = var.org_admin
  full_name = var.org_admin_fullname
  description = var.org_admin_description
  role = var.org_admin_role
  password = var.org_admin_password
  enabled = true
  email_address = var.org_admin_email
  depends_on = [vcd_org.org-name]
}

data "vcd_external_network_v2" "nsxt-ext-net" {
  name = var.edge_network
}

resource "vcd_nsxt_edgegateway" "nsxt-edge" {
  org         = var.org_name
  owner_id    = vcd_org_vdc.vdc-name.id
  name        = var.edge_name
  external_network_id = data.vcd_external_network_v2.nsxt-ext-net.id
  subnet {
    primary_ip = var.edge_primary_ip
    prefix_length = 32
  }
}