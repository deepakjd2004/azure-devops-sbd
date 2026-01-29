# Akamai CDN Property Template Repository

This repository serves as a template for creating and managing new Akamai CDN configurations using Terraform and Azure DevOps pipelines.

## Overview

This template automates the deployment of Akamai CDN properties with the following features:

- Automated property creation and configuration
- Domain validation (required as of January 2026)
- Staged deployment (Staging → Production)
- Terraform state management via AWS S3
- Azure DevOps pipeline integration

## Domain Validation Requirement (Important!)

**As of January 2026, Akamai requires domain validation before activation:**

All new domains must be validated before they can be activated on the Akamai network.

## Getting Started

### Prerequisites

1. Azure DevOps account with repository access
2. Akamai API credentials
3. AWS S3 bucket for Terraform state storage. You can replace it with your choice of backend
4. Access to Akamai API - Contracts-API_Contracts(RO), CPcode and Reporting group (cprg) (RW), CPS (RW), DNS—Zone Record Management (RW), Domain Ownership Manager (RW), Edge Hostnames API (hapi) (RW), Property Manager (PAPI) (RW). Please note for SBD(as with example code in this repo) you do not need access to CPS.

### Creating a New CDN Configuration

1. **Create a new repository** in Azure DevOps
2. **Clone this template repository**

   ```bash
   git clone <template-repo-url>
   cd <new-repo-name>
   ```

3. **Update `input.yaml`** with your configuration:

   ```yaml
   cp_code_name: "your-domain.com"
   origin_hostname: "origin.your-domain.com"
   property_name: "your-domain.com"
   hostnames:
     - "your-domain.com"
     - "www.your-domain.com"
   ```

4. **Configure domain validation** in `terraform/terraform.auto.tfvars`:

   ```hcl
   # Domain Validation Settings
   enable_domain_validation  = true
   domain_validation_scope   = "HOST"      # Options: HOST, WILDCARD, DOMAIN
   domain_validation_method  = "DNS_TXT"   # Options: DNS_CNAME, DNS_TXT, HTTP
   ```

5. **Commit and push** to trigger the Azure DevOps pipeline

## Domain Validation Process

### Step 1: Pipeline Execution

When you push changes, the Azure DevOps pipeline will:

1. Update Terraform configuration from `input.yaml`
2. Initialize Terraform
3. Create domain validation resources
4. **PAUSE** - waiting for you to complete DNS/HTTP validation

### Step 2: Get Validation Challenges

After the `terraform plan` stage, check the output for validation challenge data:

```bash
# View the challenge data
terraform output domain_validation_challenges
```

You'll receive challenge data for each hostname.

### Step 3: Complete Validation

#### Option A: Automatic DNS Record Creation (Recommended)

**If your DNS is managed by Akamai Edge DNS**, enable automatic DNS record creation:

1. Set the DNS zone in `terraform/terraform.auto.tfvars`:

   ```hcl
   dns_zone = "example.com"  # Your DNS zone name
   domain_validation_method = "DNS_CNAME"  # or "DNS_TXT"
   ```

2. Terraform will automatically:
   - Create the required DNS records
   - Wait for validation
   - Proceed with activation

**No manual DNS configuration needed!**

#### Option B: Manual DNS Record Creation

**If DNS is managed externally** (Route53, Cloudflare, etc.):

#### Option A: DNS CNAME (Recommended)

Add a CNAME record to your DNS:

```
Name:   _acme-challenge.your-domain.com
Type:   CNAME
Target: <provided-by-terraform-output>
TTL:    1800
```

#### Option B: DNS TXT

Add a TXT record to your DNS:

```
Name:   _akamai-host-challenge.your-domain.com
Type:   TXT
Value:  <provided-by-terraform-output>
TTL:    3600
```

#### Option C: HTTP (HOST scope only)

Create a file on your web server:

- Path: `/.well-known/akamai/akamai-challenge/<challenge-file>`
- Content: `<provided-by-terraform-output>`

OR redirect to:

- `https://validation.akamai.com/.well-known/akamai/akamai-challenge/<challenge-data>`

### Step 4: Verify and Apply

Once DNS/HTTP changes are in place:

```bash
# The validation resource will automatically verify
# Continue with terraform apply in the pipeline
```

The pipeline will:

1. Validate domain ownership
2. Create the Akamai property
3. Activate to staging network
4. (If enabled) Activate to production network

## Validation Scope Options

### HOST

- Validates only the exact hostname specified
- Example: `example.com` (only this exact domain)
- **Recommended for most use cases**

### WILDCARD

- Validates one subdomain level
- Example: `*.example.com` (covers `a.example.com`, `b.example.com`)
- Does not cover `c.a.example.com`

### DOMAIN

- Validates all hostnames under the domain
- Example: `example.com` (covers all subdomains at any level)
- Most permissive option

## Configuration Files

### input.yaml

High-level configuration used by Azure DevOps pipeline to update Terraform variables.

### terraform/terraform.auto.tfvars

Terraform variable values. Key settings:

- `enable_domain_validation`: Set to `true` for new domains (default)
- `domain_validation_scope`: HOST, WILDCARD, or DOMAIN
- `domain_validation_method`: DNS_CNAME, DNS_TXT, HTTP, or empty for auto
- `dns_zone`: Your DNS zone name for automatic record creation (Akamai Edge DNS only)
- `activate_to_staging`: Enable staging activation
- `activate_to_production`: Enable production activation

### terraform/main.tf

Main Terraform configuration including:

- Domain validation resources
- Property configuration
- Edge hostnames
- Activation resources

## Troubleshooting

### Error: "Domain validation is pending"

- Ensure DNS records are properly configured
- Wait 5-10 minutes for DNS propagation
- Verify DNS records: `dig _acme-challenge.your-domain.com`
- Check validation status in Terraform output

### Error: "Challenge expired"

- Domain challenges expire after a certain period
- Re-run `terraform apply` to get new challenge data
- Update DNS records with new values

### Error: "Domain already validated at different scope"

- A parent domain may already be validated
- Check existing validations
- Adjust validation scope or remove parent domain validation

### Skipping Validation (Existing Domains)

For domains already validated:

```hcl
enable_domain_validation = false
```

## Pipeline Stages

1. **Prepare**: Read input.yaml and update Terraform files
2. **Validate**: Run `terraform validate`
3. **Plan**: Run `terraform plan` (shows validation challenges)
4. **Apply**: Run `terraform apply` (validates domains and activates)

## Azure DevOps Variable Groups Required

### Akamai-Secret

- `CLIENT_SECRET`
- `HOST`
- `ACCESS_TOKEN`
- `CLIENT_TOKEN`
- `ACCOUNT_SWITCH_KEY`

### AWS-S3-bucket

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

## Support and Documentation

- [Terraform Akamai Provider](https://techdocs.akamai.com/terraform/)
- [Azure DevOps Pipeline Documentation](https://docs.microsoft.com/azure/devops/pipelines/)

## Notes

- Domain validation is mandatory for new domains as of January 2026
- Validation must be completed before property activation
- Once validated, domains remain validated (no re-validation needed)
- For testing, use staging network first before production
- Keep challenge data secure and do not commit to repository
