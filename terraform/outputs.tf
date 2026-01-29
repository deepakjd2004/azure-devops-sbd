# Output domain validation challenge data
# This information is needed to complete DNS or HTTP validation

output "domain_validation_challenges" {
  description = "Domain validation challenge data for DNS/HTTP setup"
  value = var.enable_domain_validation && length(akamai_property_domainownership_domains.domains) > 0 ? {
    for idx, domain in akamai_property_domainownership_domains.domains[0].domains : 
    domain.domain_name => {
      domain_name      = domain.domain_name
      validation_scope = domain.validation_scope
      status          = domain.domain_status
      
      # DNS CNAME challenge
      dns_cname = lookup(domain, "validation_challenge", null) != null && lookup(domain.validation_challenge, "cname_record", null) != null ? {
        name   = "_acme-challenge.${domain.domain_name}"
        target = domain.validation_challenge.cname_record.target
        ttl    = 1800
      } : null
      
      # DNS TXT challenge
      dns_txt = lookup(domain, "validation_challenge", null) != null && lookup(domain.validation_challenge, "txt_record", null) != null ? {
        name   = "_akamai-${lower(domain.validation_scope)}-challenge.${domain.domain_name}"
        value  = domain.validation_challenge.txt_record.value
        ttl    = 3600
      } : null
      
      # HTTP challenge
      http_file = lookup(domain, "validation_challenge", null) != null && lookup(domain.validation_challenge, "http_file", null) != null ? {
        path    = domain.validation_challenge.http_file.path
        content = domain.validation_challenge.http_file.content
      } : null
      
      http_redirect = lookup(domain, "validation_challenge", null) != null && lookup(domain.validation_challenge, "http_redirect", null) != null ? {
        to = domain.validation_challenge.http_redirect.to
      } : null
      
      expires_at = lookup(domain.validation_challenge, "expires_at", null)
    }
  } : null
  
  sensitive = false
}

output "dns_records_created" {
  description = "Automatically created DNS records for domain validation (if dns_zone is configured)"
  value = local.auto_dns_zone != "" ? {
    zone = local.auto_dns_zone
    cname_records = var.domain_validation_method == "DNS_CNAME" || var.domain_validation_method == "" ? [
      for hostname in var.hostnames : {
        name = "_acme-challenge.${hostname}"
        type = "CNAME"
      }
    ] : []
    txt_records = var.domain_validation_method == "DNS_TXT" ? [
      for hostname in var.hostnames : {
        name = "_akamai-${lower(var.domain_validation_scope)}-challenge.${hostname}"
        type = "TXT"
      }
    ] : []
    note = "DNS records automatically created by Terraform"
  } : {
    zone = null
    cname_records = []
    txt_records = []
    note = "No automatic DNS records created. Set dns_zone variable to enable automatic DNS record creation."
  }
}

output "property_id" {
  description = "Akamai Property ID"
  value       = akamai_property.this.id
}

output "property_latest_version" {
  description = "Latest property version created"
  value       = akamai_property.this.latest_version
}

output "property_staging_version" {
  description = "Property version activated on staging (0 if not yet activated)"
  value       = akamai_property.this.staging_version
}

output "property_production_version" {
  description = "Property version activated on production (0 if not yet activated)"
  value       = akamai_property.this.production_version
}

output "edge_hostnames" {
  description = "Edge hostnames created"
  value       = {
    for hostname, ehn in akamai_edge_hostname.my_edge_hostname : 
    hostname => ehn.edge_hostname
  }
}

output "cp_code_id" {
  description = "CP Code ID"
  value       = akamai_cp_code.cp_code.id
}
