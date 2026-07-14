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

# Domain Validation Resources
# Required to validate domain ownership before activation
resource "akamai_property_domainownership_domains" "domains" {
  count = var.enable_domain_validation ? 1 : 0

  domains = [
    for hostname in var.hostnames : {
      domain_name      = hostname
      validation_scope = var.domain_validation_scope
    }
  ]

  lifecycle {
    ignore_changes = [
      # Challenge data changes frequently, ignore to prevent unnecessary updates
      domains,
    ]
  }
}

# Local helper to extract zone from hostname
locals {
  # Extract DNS zone from hostnames if not explicitly provided
  # Takes last 2 parts of hostname (e.g., api.staging.example.com -> example.com)
  auto_dns_zone = var.dns_zone != "" ? var.dns_zone : (
    length(var.hostnames) > 0 ? (
      length(split(".", var.hostnames[0])) >= 2 ?
        join(".", slice(split(".", var.hostnames[0]), length(split(".", var.hostnames[0])) - 2, length(split(".", var.hostnames[0])))) :
        var.hostnames[0]
    ) : ""
  )
  
  # Create a map of hostname to domain validation data for easier access
  domain_validation_map = var.enable_domain_validation && length(akamai_property_domainownership_domains.domains) > 0 ? {
    for idx, domain in akamai_property_domainownership_domains.domains[0].domains :
    domain.domain_name => domain
  } : {}
}

# Automatic DNS CNAME Record Creation for Domain Validation
# Creates _acme-challenge CNAME records for DNS_CNAME validation method
resource "akamai_dns_record" "domain_validation_cname" {
  for_each = var.enable_domain_validation && local.auto_dns_zone != "" && (var.domain_validation_method == "DNS_CNAME" || var.domain_validation_method == "") ? toset(var.hostnames) : []

  zone       = local.auto_dns_zone
  name       = "_acme-challenge.${each.value}"
  recordtype = "CNAME"
  ttl        = 60
  
  # Extract target from validation challenge data
  target = [
    local.domain_validation_map[each.value].validation_challenge.cname_record.target
  ]

  depends_on = [
    akamai_property_domainownership_domains.domains
  ]
}

# Automatic DNS TXT Record Creation for Domain Validation
# Creates _akamai-{scope}-challenge TXT records for DNS_TXT validation method
resource "akamai_dns_record" "domain_validation_txt" {
  for_each = var.enable_domain_validation && local.auto_dns_zone != "" && var.domain_validation_method == "DNS_TXT" ? toset(var.hostnames) : []

  zone       = local.auto_dns_zone
  name       = "_akamai-${lower(var.domain_validation_scope)}-challenge.${each.value}"
  recordtype = "TXT"
  ttl        = 60
  
  # Extract token from validation challenge data
  target = [
    local.domain_validation_map[each.value].validation_challenge.txt_record.value
  ]

  depends_on = [
    akamai_property_domainownership_domains.domains
  ]
}

# Domain Validation - triggers actual validation after DNS/HTTP setup
resource "akamai_property_domainownership_validation" "validation" {
  count = var.enable_domain_validation ? 1 : 0

  domains = [
    for hostname in var.hostnames : {
      domain_name       = hostname
      validation_scope  = var.domain_validation_scope
      validation_method = var.domain_validation_method != "" ? var.domain_validation_method : null
    }
  ]

  depends_on = [
    akamai_property_domainownership_domains.domains,
    akamai_dns_record.domain_validation_cname
  ]
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
  
  depends_on = [
    akamai_property_domainownership_validation.validation
  ]
}

# NOTE: Be careful when removing this resource as you can disable traffic
resource "akamai_property_activation" "production" {
  property_id = akamai_property.this.id
  version = var.activate_to_production ? akamai_property.this.latest_version : akamai_property.this.production_version
  network     = "PRODUCTION"
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
    akamai_edge_hostname.my_edge_hostname,
    akamai_property_domainownership_validation.validation
  ]
}