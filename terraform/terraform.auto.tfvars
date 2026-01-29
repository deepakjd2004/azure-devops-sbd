# Common Variables
contract_id = "ctr_xxxxx"
group_name = "DJ"
email      = "xxx@akamai.com"
config_section = "default"

# Domain/Hostnames
property_name = "dj-0206253-demo.com"
hostnames     = ["dj-0206253-demo.com", "www.dj-0206253-demo.com"]

# Property 

product_id   = "SPM"
cp_code_name = "dj-tf-demo.com"
origin_hostname = "origin.dj-0206252-demo.com"
version_notes                   = "Initial version"
activate_to_staging    = true
activate_to_production = true
enhanced_tls = true
secure_by_default = true

# Domain Validation
# Enable domain validation for new domains (required as of Jan 2026)
enable_domain_validation  = true
domain_validation_scope   = "HOST"      # Options: HOST, WILDCARD, DOMAIN
domain_validation_method  = "DNS_CNAME" # Options: DNS_CNAME, DNS_TXT, HTTP (empty for auto)

# DNS Zone for automatic record creation
# If your DNS is managed by Akamai Edge DNS, provide the zone name here
# Leave empty ("") if DNS is managed externally or for manual DNS record creation
dns_zone                  = ""          # Example: "example.com"
