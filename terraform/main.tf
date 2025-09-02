terraform {
  backend "s3" {
    bucket = "xxxxx"
    key    = "xxxxxx/${var.property_name}.terraform.tfstate"
    region = "us-east-1"
  }
  required_providers {
    akamai = {
      source  = "akamai/akamai"
      version = ">= 7.1.0"
    }
  }
  required_version = ">= 1.0"
}

provider "akamai" {
  edgerc         = var.edgerc_path
  config_section = var.config_section
}

data "akamai_contract" "contract" {
  group_name = var.group_name
}

locals {
  ehn_domain = coalesce(
    var.ehn_domain,
    (var.enhanced_tls == true) ? "edgekey.net" : "edgesuite.net"
  )

  etls_hostnames = var.enhanced_tls ? var.hostnames : []

  stls_hostnames = (var.enhanced_tls && var.secure_by_default) ? [] : var.hostnames

  ehn_certificate = (var.enhanced_tls == true && var.secure_by_default == false) ? var.certificate_id : null
}

/* resource "akamai_edge_hostname" "my_edge_hostname" {
  product_id    = var.product_id
  contract_id   = data.akamai_contract.contract.id
  group_id      = data.akamai_contract.contract.group_id
  ip_behavior   = var.edge_hostname_ip_behavior
  edge_hostname = var.edge_hostname
} */

resource "akamai_edge_hostname" "my_edge_hostname" {
  for_each      = toset(local.stls_hostnames)
  product_id    = var.product_id
  contract_id   = data.akamai_contract.contract.id
  group_id      = data.akamai_contract.contract.group_id
  edge_hostname = "${each.key}.${local.ehn_domain}"
  certificate   = local.ehn_certificate
  ip_behavior   = var.ip_behavior
}

resource "akamai_cp_code" "cp_code" {
  product_id  = var.product_id
  contract_id = data.akamai_contract.contract.id
  group_id    = data.akamai_contract.contract.group_id
  name        = var.cp_code_name
}


resource "akamai_property" "this" {
  name        = var.property_name
  contract_id = data.akamai_contract.contract.id
  group_id    = data.akamai_contract.contract.group_id
  product_id  = var.product_id

   dynamic "hostnames" {
    for_each = var.hostnames
    content {
      cname_from             = hostnames.value
      cname_to               = "${hostnames.value}.${local.ehn_domain}"
      cert_provisioning_type = var.secure_by_default ? "DEFAULT" : "CPS_MANAGED"
    }
  }
  rule_format   = data.akamai_property_rules_builder.my_rule_default.rule_format
  rules         = data.akamai_property_rules_builder.my_rule_default.json
  version_notes = var.version_notes
  # Version notes depend on values that change on every commit. Ignoring notes as a valid change
  lifecycle {
    ignore_changes = [
      version_notes,
    ]
  }
  depends_on = [
    akamai_edge_hostname.my_edge_hostname
#    ,
#    akamai_edge_hostname.stls
  ]
}

# NOTE: Be careful when removing this resource as you can disable traffic
resource "akamai_property_activation" "my_property_activation_staging" {
  property_id                    = akamai_property.this.id
  contact                        = [var.email]
  version                        = var.activate_to_staging ? akamai_property.this.latest_version : akamai_property.this.staging_version
  network                        = "STAGING"
  note                           = var.version_notes
  auto_acknowledge_rule_warnings = true

  # Activation notes depend on values that change on every commit. Ignoring notes as valid change
  lifecycle {
    ignore_changes = [
      note,
    ]
  }
  
}

# NOTE: Be careful when removing this resource as you can disable traffic
resource "akamai_property_activation" "production" {
  count       = var.activate_to_production ? 1 : 0
  network     = "PRODUCTION"
  property_id = akamai_property.this.id
  version     = akamai_property.this.latest_version
  auto_acknowledge_rule_warnings = true
  note        = var.activation_notes
  contact     = [var.email]
  lifecycle {
    ignore_changes = [
      note,
    ]
  }
  compliance_record {
    noncompliance_reason_no_production_traffic {
      ticket_id = "123"
    }
  }
  depends_on = [
    akamai_property_activation.my_property_activation_staging,
    akamai_edge_hostname.my_edge_hostname
  ]
}
