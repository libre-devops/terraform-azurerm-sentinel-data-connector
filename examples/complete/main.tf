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
      # Azure and Entra: tenant/subscription scoped, no service license needed to connect.
      "entra-id"                 = { kind = "azure_active_directory" }
      "defender-for-cloud"       = { kind = "azure_security_center" }
      "defender-identity-legacy" = { kind = "azure_advanced_threat_protection" }
      "defender-iot"             = { kind = "iot" }

      # Microsoft 365 family: service toggles exercised on office_365.
      "office"          = { kind = "office_365", exchange_enabled = true, sharepoint_enabled = true, teams_enabled = true }
      "office-project"  = { kind = "office_365_project" }
      "office-defender" = { kind = "office_atp" }
      "office-irm"      = { kind = "office_irm" }
      "office-powerbi"  = { kind = "office_power_bi" }
      "dynamics"        = { kind = "dynamics_365" }
      "defender-apps"   = { kind = "microsoft_cloud_app_security", alerts_enabled = true, discovery_logs_enabled = false }

      # Threat intelligence: the TI platforms feed and the Microsoft emerging threat feed.
      "ti-platforms" = { kind = "threat_intelligence", lookback_date = "2026-01-01T00:00:00Z" }
      "msft-threat-intel" = {
        kind                                         = "microsoft_threat_intelligence"
        microsoft_emerging_threat_feed_lookback_date = "2026-01-01T00:00:00Z"
      }
    }],

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
