# -------------------------------------------------
# Common Variables 
# -------------------------------------------------

variable "group_name" {
  description = "Akamai Group Name"
  type        = string
}


variable "edgerc_path" {
  type    = string
  default = "~/.edgerc"
}

variable "config_section" {
  type    = string
  default = "default"
}

# -------------------------------------------------
# Edge Hostname
# -------------------------------------------------


variable "edge_hostname_ip_behavior" {
  description = "Akamai Edge Hostname IP behavior"
  type        = string
  default     = "IPV6_COMPLIANCE"
}

# -------------------------------------------------
# Property
# -------------------------------------------------

variable "property_name" {
  description = "Akamai Property/Configuration Name"
  type        = string
} 


variable "cp_code_name" {
  description = "Name for the CP Code"
  type        = string
}

variable "origin_hostname" {
  type = string
  description = "Origin hostname"
}

variable "version_notes" {
  type        = string
  description = "Version Notes for the Property"
}


## ----------------------------------------------------------------------------
## Scope
## ----------------------------------------------------------------------------

variable "contract_id" {
  description = "Contract ID for property/config creation"
  type        = string
}


## ----------------------------------------------------------------------------
## Property
## ----------------------------------------------------------------------------

variable "product_id" {
  description = "Property Manager product - Default will be Ion Premier."
  type        = string
  default     = "SPM"
}


variable "hostnames" {
  description = "List of hostnames."
  type        = list(string)
}

variable "enhanced_tls" {
  description = "Boolean to switch between Enhanced and Standard TLS modes"
  type        = bool
}


variable "rule_format" {
  description = "Property rule format"
  type        = string
  default     = "v2023-10-30"
}


## ----------------------------------------------------------------------------
## Activation
## ----------------------------------------------------------------------------

variable "email" {
  description = "Email address used for activations."
  type        = string
}

variable "activate_to_staging" {
  description = "Set to true to directly activate on the staging network."
  type        = bool
  default     = false
}

variable "activate_to_production" {
  description = "Set to true to directly activate on the production network."
  type        = bool
  default     = false
}

variable "compliance_record" {
  description = <<-EOD
    Set this according to the change management policy if activate_to_production is true.

    Refer to https://collaborate.akamai.com/confluence/pages/viewpage.action?spaceKey=DEVOPSHARMONY&title=Terraform+for+Akamai+PS
    for further guidance.
  EOD
  type = object({
    noncompliance_reason = string
    peer_reviewed_by     = optional(string)
    customer_email       = optional(string)
    unit_tested          = optional(bool)
  })
  default = null
}

variable "activation_notes" {
  description = "Activation notes. Leave default value until DXE-2373 is resolved, unless you know what you are doing."
  type        = string
  default     = "activated with terraform"
}

## ----------------------------------------------------------------------------
## CP Code
## ----------------------------------------------------------------------------

variable "cpcode_name" {
  description = "Default CP Code name. Will be the property name (var.name) if null."
  type        = string
  default     = null
}

## ----------------------------------------------------------------------------
## Certificate
## ----------------------------------------------------------------------------

variable "secure_by_default" {
  description = <<-EOD
    Secure by default. Set to true to use the DEFAULT certificate provisioning type.

    This is the easiest for automation, because Akamai takes care of provisioning the certificate
    using a Let's Encrypt DV SAN in a fully managed way.

    If the customer requires an OV SAN, or Secure by Default is inapplicable for whatever
    other reason, set this to false.
  EOD
  type        = bool
  default     = false
}

variable "certificate_id" {
  description = <<-EOD
    Certificate enrollment id. Only applicable if enhanced_tls is true, and secure_by_default
    is false.

    Can be retrieved using AkamaiPowershell or the Akamai CPS CLI.
  EOD
  type        = string
  default     = null
}

## ----------------------------------------------------------------------------
## EdgeHostname
## ----------------------------------------------------------------------------

variable "ehn_domain" {
  description = <<-EOD
    EdgeHostname domain, e.g. edgesuite.net or edgekey.net. Will default to one or
    the other, based on the value of enhanced_tls.
  EOD
  type        = string
  default     = null
}

variable "ip_behavior" {
  description = <<-EOD
    EdgeHostname IP behaviour.
  EOD
  type        = string
  default     = "IPV6_COMPLIANCE"

  validation {
    condition     = length(regexall("^(IPV4|IPV6_COMPLIANCE|IPV6_PERFORMANCE)$", var.ip_behavior)) > 0
    error_message = "ERROR: Valid types are IPV4, IPV6_COMPLIANCE or IPV6_PERFORMANCE."
  }
}
