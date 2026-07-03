locals {
  # The workspace id, parsed back out of an onboarding (onboardingStates) id when given one. Taking
  # the sentinel module's onboarding_id makes the onboarding dependency explicit in composition.
  workspace_id = can(regex("(?i)/providers/Microsoft.SecurityInsights/onboardingStates/", var.workspace_id)) ? regex("(?i)^(.*)/providers/Microsoft\\.SecurityInsights/onboardingStates/[^/]*$", var.workspace_id)[0] : var.workspace_id

  by_kind = {
    for kind in [
      "aws_cloud_trail", "aws_s3", "azure_active_directory", "azure_advanced_threat_protection",
      "azure_security_center", "dynamics_365", "iot", "microsoft_cloud_app_security",
      "microsoft_defender_advanced_threat_protection", "microsoft_threat_intelligence",
      "microsoft_threat_protection", "office_365", "office_365_project", "office_atp",
      "office_irm", "office_power_bi", "threat_intelligence", "threat_intelligence_taxii"
    ] : kind => { for k, c in var.data_connectors : k => c if c.kind == kind }
  }
}

resource "azurerm_sentinel_data_connector_aws_cloud_trail" "this" {
  for_each = local.by_kind["aws_cloud_trail"]

  log_analytics_workspace_id = local.workspace_id
  name                       = each.key
  aws_role_arn               = each.value.aws_role_arn
}

resource "azurerm_sentinel_data_connector_aws_s3" "this" {
  for_each = local.by_kind["aws_s3"]

  log_analytics_workspace_id = local.workspace_id
  name                       = each.key
  aws_role_arn               = each.value.aws_role_arn
  destination_table          = each.value.destination_table
  sqs_urls                   = each.value.sqs_urls
}

resource "azurerm_sentinel_data_connector_azure_active_directory" "this" {
  for_each = local.by_kind["azure_active_directory"]

  log_analytics_workspace_id = local.workspace_id
  name                       = each.key
  tenant_id                  = each.value.tenant_id
}

resource "azurerm_sentinel_data_connector_azure_advanced_threat_protection" "this" {
  for_each = local.by_kind["azure_advanced_threat_protection"]

  log_analytics_workspace_id = local.workspace_id
  name                       = each.key
  tenant_id                  = each.value.tenant_id
}

resource "azurerm_sentinel_data_connector_azure_security_center" "this" {
  for_each = local.by_kind["azure_security_center"]

  log_analytics_workspace_id = local.workspace_id
  name                       = each.key
  subscription_id            = each.value.subscription_id
}

resource "azurerm_sentinel_data_connector_dynamics_365" "this" {
  for_each = local.by_kind["dynamics_365"]

  log_analytics_workspace_id = local.workspace_id
  name                       = each.key
  tenant_id                  = each.value.tenant_id
}

resource "azurerm_sentinel_data_connector_iot" "this" {
  for_each = local.by_kind["iot"]

  log_analytics_workspace_id = local.workspace_id
  name                       = each.key
  subscription_id            = each.value.subscription_id
}

resource "azurerm_sentinel_data_connector_microsoft_cloud_app_security" "this" {
  for_each = local.by_kind["microsoft_cloud_app_security"]

  log_analytics_workspace_id = local.workspace_id
  name                       = each.key
  tenant_id                  = each.value.tenant_id
  alerts_enabled             = each.value.alerts_enabled
  discovery_logs_enabled     = each.value.discovery_logs_enabled
}

resource "azurerm_sentinel_data_connector_microsoft_defender_advanced_threat_protection" "this" {
  for_each = local.by_kind["microsoft_defender_advanced_threat_protection"]

  log_analytics_workspace_id = local.workspace_id
  name                       = each.key
  tenant_id                  = each.value.tenant_id
}

resource "azurerm_sentinel_data_connector_microsoft_threat_intelligence" "this" {
  for_each = local.by_kind["microsoft_threat_intelligence"]

  log_analytics_workspace_id                   = local.workspace_id
  name                                         = each.key
  tenant_id                                    = each.value.tenant_id
  microsoft_emerging_threat_feed_lookback_date = each.value.microsoft_emerging_threat_feed_lookback_date
}

resource "azurerm_sentinel_data_connector_microsoft_threat_protection" "this" {
  for_each = local.by_kind["microsoft_threat_protection"]

  log_analytics_workspace_id = local.workspace_id
  name                       = each.key
  tenant_id                  = each.value.tenant_id
}

resource "azurerm_sentinel_data_connector_office_365" "this" {
  for_each = local.by_kind["office_365"]

  log_analytics_workspace_id = local.workspace_id
  name                       = each.key
  tenant_id                  = each.value.tenant_id
  exchange_enabled           = each.value.exchange_enabled
  sharepoint_enabled         = each.value.sharepoint_enabled
  teams_enabled              = each.value.teams_enabled
}

resource "azurerm_sentinel_data_connector_office_365_project" "this" {
  for_each = local.by_kind["office_365_project"]

  log_analytics_workspace_id = local.workspace_id
  name                       = each.key
  tenant_id                  = each.value.tenant_id
}

resource "azurerm_sentinel_data_connector_office_atp" "this" {
  for_each = local.by_kind["office_atp"]

  log_analytics_workspace_id = local.workspace_id
  name                       = each.key
  tenant_id                  = each.value.tenant_id
}

resource "azurerm_sentinel_data_connector_office_irm" "this" {
  for_each = local.by_kind["office_irm"]

  log_analytics_workspace_id = local.workspace_id
  name                       = each.key
  tenant_id                  = each.value.tenant_id
}

resource "azurerm_sentinel_data_connector_office_power_bi" "this" {
  for_each = local.by_kind["office_power_bi"]

  log_analytics_workspace_id = local.workspace_id
  name                       = each.key
  tenant_id                  = each.value.tenant_id
}

resource "azurerm_sentinel_data_connector_threat_intelligence" "this" {
  for_each = local.by_kind["threat_intelligence"]

  log_analytics_workspace_id = local.workspace_id
  name                       = each.key
  tenant_id                  = each.value.tenant_id
  lookback_date              = each.value.lookback_date
}

resource "azurerm_sentinel_data_connector_threat_intelligence_taxii" "this" {
  for_each = local.by_kind["threat_intelligence_taxii"]

  log_analytics_workspace_id = local.workspace_id
  name                       = each.key
  display_name               = each.value.display_name
  api_root_url               = each.value.api_root_url
  collection_id              = each.value.collection_id

  tenant_id         = each.value.tenant_id
  user_name         = each.value.user_name
  password          = lookup(var.taxii_passwords, each.key, null)
  polling_frequency = each.value.polling_frequency
  lookback_date     = each.value.lookback_date
}
