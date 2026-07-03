<!--
  Header for the complete example README. Edit this file, then run `just docs`
  (or ./Sort-LdoTerraform.ps1 -IncludeExamples) to regenerate the section between the markers.
  The example's main.tf is embedded into the README automatically (see .terraform-docs.yml).
-->
<div align="center">
  <a href="https://libredevops.org">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://libredevops.org/assets/libre-devops-white.png">
      <img alt="Libre DevOps" src="https://libredevops.org/assets/libre-devops-black.png" width="200">
    </picture>
  </a>
</div>

# Complete example

Every feature of the module. A CSV file watchlist exercising the full attribute surface (display
name, ISO8601 retention, description, labels), an inline CSV with deliberately messy spacing that
the trim pipeline cleans on import, and a native-items watchlist, all wired through the sentinel
module's onboarding_id so the onboarding ordering is explicit. Run it with `just e2e complete`,
which applies the stack then always destroys it.

[![Terraform Registry](https://img.shields.io/badge/registry-libre--devops-7B42BC?logo=terraform&logoColor=white)](https://registry.terraform.io/namespaces/libre-devops)

<!-- BEGIN_TF_DOCS -->
## Example configuration

```hcl
# Every feature of the module. Live by default: the thirteen Microsoft connectors that create
# without extra licensing on this tenant (verified empirically), exercising every kind-specific
# field. Gated off by default: the two license-gated connectors (Defender for Endpoint and
# Defender XDR fail with 401 InvalidLicense on unlicensed tenants) and the external-dependency
# connectors (AWS validates the role against a real AWS account; TAXII polls a real server).
# Applied then destroyed in one CI run.
locals {
  location = lookup(var.regions, var.loc, "uksouth")
  rg_name  = "rg-${var.short}-${var.loc}-${terraform.workspace}-002"
  law_name = "log-${var.short}-${var.loc}-${terraform.workspace}-002"
}

module "tags" {
  source  = "libre-devops/tags/azurerm"
  version = "~> 4.0"

  cost_centre     = "1888/67"
  owner           = "platform@example.com"
  deployed_branch = var.deployed_branch
  deployed_repo   = var.deployed_repo
  additional_tags = { Application = "terraform-azurerm-sentinel-data-connector" }
}

module "rg" {
  source  = "libre-devops/rg/azurerm"
  version = "~> 4.0"

  resource_groups = [{ name = local.rg_name, location = local.location, tags = module.tags.tags }]
}

module "log_analytics" {
  source  = "libre-devops/log-analytics-workspace/azurerm"
  version = "~> 4.0"

  resource_group_id = module.rg.ids[local.rg_name]
  location          = local.location
  tags              = module.tags.tags

  log_analytics_workspaces = { (local.law_name) = {} }
}

module "sentinel" {
  source  = "libre-devops/sentinel/azurerm"
  version = "~> 4.0"

  workspace_id = module.log_analytics.workspace_ids[local.law_name]
}

module "sentinel_data_connector" {
  source = "../../"

  workspace_id = module.sentinel.onboarding_id

  # The gated groups ride through concat + merge instead of ternaries: conditional branches must
  # unify types, and these maps are deliberately heterogeneous.
  data_connectors = merge(concat(
    [{
      # Subscription-scoped connectors plus the Microsoft emerging threat feed: creatable by an
      # ordinary service principal with workspace rights (verified empirically), so these run live
      # in CI.
      "defender-for-cloud" = { kind = "azure_security_center" }
      "defender-iot"       = { kind = "iot" }
      "msft-threat-intel" = {
        kind                                         = "microsoft_threat_intelligence"
        microsoft_emerging_threat_feed_lookback_date = "2026-01-01T00:00:00Z"
      }
    }],

    # Tenant-scoped connectors: the service returns 401 Access denied unless the CALLER holds
    # tenant security-admin rights (a human security admin works; a plain CI service principal
    # does not). Enable when applying as a sufficiently privileged identity.
    [for m in [{
      "entra-id"                 = { kind = "azure_active_directory" }
      "defender-identity-legacy" = { kind = "azure_advanced_threat_protection" }
      "defender-apps"            = { kind = "microsoft_cloud_app_security", alerts_enabled = true, discovery_logs_enabled = false }
      "dynamics"                 = { kind = "dynamics_365" }
      "office"                   = { kind = "office_365", exchange_enabled = true, sharepoint_enabled = true, teams_enabled = true }
      "office-project"           = { kind = "office_365_project" }
      "office-defender"          = { kind = "office_atp" }
      "office-irm"               = { kind = "office_irm" }
      "office-powerbi"           = { kind = "office_power_bi" }
      "ti-platforms"             = { kind = "threat_intelligence", lookback_date = "2026-01-01T00:00:00Z" }
    }] : m if var.enable_tenant_scoped_connectors],

    # License-gated (401 InvalidLicense without Defender for Endpoint / Microsoft 365 Defender).
    [for m in [{
      "defender-endpoint" = { kind = "microsoft_defender_advanced_threat_protection" }
      "defender-xdr"      = { kind = "microsoft_threat_protection" }
    }] : m if var.enable_licensed_connectors],

    # External dependencies: Azure validates the AWS role (workspace id as external id) against a
    # real AWS account, and the TAXII server must answer.
    [for m in [{
      "aws-cloudtrail" = { kind = "aws_cloud_trail", aws_role_arn = var.aws_cloudtrail_role_arn }
      "aws-s3-flowlogs" = {
        kind              = "aws_s3"
        aws_role_arn      = var.aws_s3_role_arn
        destination_table = "AWSVPCFlow"
        sqs_urls          = var.aws_s3_sqs_urls
      }
      "ti-taxii-feed" = {
        kind              = "threat_intelligence_taxii"
        display_name      = "Partner TAXII feed"
        api_root_url      = var.taxii_api_root_url
        collection_id     = var.taxii_collection_id
        user_name         = "feeduser"
        polling_frequency = "OnceADay"
      }
    }] : m if var.enable_external_connectors],
  )...)

  taxii_passwords = merge([for m in [{ "ti-taxii-feed" = var.taxii_password }] : m if var.enable_external_connectors]...)
}
```

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.0, < 2.0.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 4.0.0, < 5.0.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.0.0, < 4.0.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_log_analytics"></a> [log\_analytics](#module\_log\_analytics) | libre-devops/log-analytics-workspace/azurerm | ~> 4.0 |
| <a name="module_rg"></a> [rg](#module\_rg) | libre-devops/rg/azurerm | ~> 4.0 |
| <a name="module_sentinel"></a> [sentinel](#module\_sentinel) | libre-devops/sentinel/azurerm | ~> 4.0 |
| <a name="module_sentinel_data_connector"></a> [sentinel\_data\_connector](#module\_sentinel\_data\_connector) | ../../ | n/a |
| <a name="module_tags"></a> [tags](#module\_tags) | libre-devops/tags/azurerm | ~> 4.0 |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_cloudtrail_role_arn"></a> [aws\_cloudtrail\_role\_arn](#input\_aws\_cloudtrail\_role\_arn) | The AWS role ARN for the CloudTrail connector (external id must be the workspace id). | `string` | `"arn:aws:iam::123456789012:role/SentinelCloudTrail"` | no |
| <a name="input_aws_s3_role_arn"></a> [aws\_s3\_role\_arn](#input\_aws\_s3\_role\_arn) | The AWS role ARN for the S3 connector (OIDC\_ prefixed when using web identity). | `string` | `"arn:aws:iam::123456789012:role/OIDC_SentinelS3"` | no |
| <a name="input_aws_s3_sqs_urls"></a> [aws\_s3\_sqs\_urls](#input\_aws\_s3\_sqs\_urls) | The SQS queue URLs the S3 connector reads notifications from. | `list(string)` | <pre>[<br/>  "https://sqs.eu-west-1.amazonaws.com/123456789012/flowlogs"<br/>]</pre> | no |
| <a name="input_deployed_branch"></a> [deployed\_branch](#input\_deployed\_branch) | Git branch the deployment came from. Auto-filled in CI from TF\_VAR\_deployed\_branch. | `string` | `""` | no |
| <a name="input_deployed_repo"></a> [deployed\_repo](#input\_deployed\_repo) | Repository URL the deployment came from. Auto-filled in CI from TF\_VAR\_deployed\_repo. | `string` | `""` | no |
| <a name="input_enable_external_connectors"></a> [enable\_external\_connectors](#input\_enable\_external\_connectors) | Create the AWS and TAXII connectors. Off by default: Azure validates the AWS role against a real AWS account and polls the TAXII server at create. | `bool` | `false` | no |
| <a name="input_enable_licensed_connectors"></a> [enable\_licensed\_connectors](#input\_enable\_licensed\_connectors) | Create the Defender for Endpoint and Defender XDR connectors. Off by default: they fail with 401 InvalidLicense on tenants without those licenses. | `bool` | `false` | no |
| <a name="input_enable_tenant_scoped_connectors"></a> [enable\_tenant\_scoped\_connectors](#input\_enable\_tenant\_scoped\_connectors) | Create the tenant-scoped connectors (Entra ID, Defender for Identity, Defender for Cloud Apps, Dynamics 365, the Office family, TI platforms). Off by default: the service returns 401 Access denied unless the caller holds tenant security-admin rights, which CI service principals usually do not. | `bool` | `false` | no |
| <a name="input_loc"></a> [loc](#input\_loc) | Outfix: short Azure region code used in resource names (for example uks). | `string` | `"uks"` | no |
| <a name="input_regions"></a> [regions](#input\_regions) | Map of short region codes to Azure region slugs. | `map(string)` | <pre>{<br/>  "eus": "eastus",<br/>  "euw": "westeurope",<br/>  "uks": "uksouth",<br/>  "ukw": "ukwest"<br/>}</pre> | no |
| <a name="input_short"></a> [short](#input\_short) | Infix: short product code used in resource names. | `string` | `"ldo"` | no |
| <a name="input_taxii_api_root_url"></a> [taxii\_api\_root\_url](#input\_taxii\_api\_root\_url) | The TAXII 2.x API root URL. | `string` | `"https://taxii.example.com/api/v21/"` | no |
| <a name="input_taxii_collection_id"></a> [taxii\_collection\_id](#input\_taxii\_collection\_id) | The TAXII collection id to poll. | `string` | `"0aba3e12-0000-4000-8000-000000000001"` | no |
| <a name="input_taxii_password"></a> [taxii\_password](#input\_taxii\_password) | The TAXII password (paired with the connector's user\_name). | `string` | `"change-me"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_data_connector_ids_zipmap"></a> [data\_connector\_ids\_zipmap](#output\_data\_connector\_ids\_zipmap) | Map of connector name to { name, id }. |
| <a name="output_data_connectors"></a> [data\_connectors](#output\_data\_connectors) | Map of connector name to { id, kind, name }. |
<!-- END_TF_DOCS -->
