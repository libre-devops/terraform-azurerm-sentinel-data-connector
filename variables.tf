variable "data_connectors" {
  description = <<DESC
Data connectors keyed by connector name, with `kind` selecting the connector type (the azurerm
resource suffix: office_365, azure_active_directory, threat_intelligence, aws_s3, and so on).
Fields apply per kind and setting one on the wrong kind is rejected at plan:

- `tenant_id`: the Microsoft 365 / Entra / Defender connectors (defaults to the caller's tenant).
- `subscription_id`: azure_security_center and iot (defaults to the caller's subscription).
- `aws_role_arn` (+ `destination_table`, `sqs_urls` for aws_s3): the AWS connectors. The role must
  really exist in AWS with the workspace id as its external id; Azure validates it at create.
- `alerts_enabled` / `discovery_logs_enabled`: microsoft_cloud_app_security service toggles.
- `exchange_enabled` / `sharepoint_enabled` / `teams_enabled`: office_365 service toggles.
- `lookback_date` (threat_intelligence, threat_intelligence_taxii) and
  `microsoft_emerging_threat_feed_lookback_date` (microsoft_threat_intelligence, required): RFC3339.
- `api_root_url`, `collection_id`, `display_name`, `user_name`, `polling_frequency`:
  threat_intelligence_taxii (the password rides in the separate, sensitive `taxii_passwords` map).

LICENSING: creation is validated by Azure against tenant licensing and consent. On an unlicensed
tenant, microsoft_defender_advanced_threat_protection and microsoft_threat_protection fail with
401 InvalidLicense; the rest of the Microsoft connectors create without the backing service.
DESC

  type = map(object({
    kind = string

    tenant_id       = optional(string)
    subscription_id = optional(string)

    aws_role_arn      = optional(string)
    destination_table = optional(string)
    sqs_urls          = optional(list(string))

    alerts_enabled         = optional(bool)
    discovery_logs_enabled = optional(bool)

    exchange_enabled   = optional(bool)
    sharepoint_enabled = optional(bool)
    teams_enabled      = optional(bool)

    lookback_date                                = optional(string)
    microsoft_emerging_threat_feed_lookback_date = optional(string)

    api_root_url      = optional(string)
    collection_id     = optional(string)
    display_name      = optional(string)
    user_name         = optional(string)
    polling_frequency = optional(string)
  }))
  default = {}

  validation {
    condition = alltrue([
      for c in values(var.data_connectors) : contains([
        "aws_cloud_trail", "aws_s3", "azure_active_directory", "azure_advanced_threat_protection",
        "azure_security_center", "dynamics_365", "iot", "microsoft_cloud_app_security",
        "microsoft_defender_advanced_threat_protection", "microsoft_threat_intelligence",
        "microsoft_threat_protection", "office_365", "office_365_project", "office_atp",
        "office_irm", "office_power_bi", "threat_intelligence", "threat_intelligence_taxii"
      ], c.kind)
    ])
    error_message = "kind must be one of the 17 azurerm sentinel data connector kinds (aws_cloud_trail, aws_s3, azure_active_directory, azure_advanced_threat_protection, azure_security_center, dynamics_365, iot, microsoft_cloud_app_security, microsoft_defender_advanced_threat_protection, microsoft_threat_intelligence, microsoft_threat_protection, office_365, office_365_project, office_atp, office_irm, office_power_bi, threat_intelligence, threat_intelligence_taxii)."
  }

  validation {
    condition     = alltrue([for c in values(var.data_connectors) : !contains(["aws_cloud_trail", "aws_s3"], c.kind) || c.aws_role_arn != null])
    error_message = "The AWS connectors require aws_role_arn."
  }

  validation {
    condition     = alltrue([for c in values(var.data_connectors) : c.kind != "aws_s3" || (c.destination_table != null && c.sqs_urls != null)])
    error_message = "aws_s3 requires destination_table and sqs_urls."
  }

  validation {
    condition     = alltrue([for c in values(var.data_connectors) : c.kind != "microsoft_threat_intelligence" || c.microsoft_emerging_threat_feed_lookback_date != null])
    error_message = "microsoft_threat_intelligence requires microsoft_emerging_threat_feed_lookback_date (RFC3339, for example 1970-01-01T00:00:00Z)."
  }

  validation {
    condition     = alltrue([for c in values(var.data_connectors) : c.kind != "threat_intelligence_taxii" || (c.api_root_url != null && c.collection_id != null && c.display_name != null)])
    error_message = "threat_intelligence_taxii requires api_root_url, collection_id, and display_name."
  }

  validation {
    condition     = alltrue([for c in values(var.data_connectors) : c.polling_frequency == null ? true : contains(["OnceAMinute", "OnceAnHour", "OnceADay"], c.polling_frequency)])
    error_message = "polling_frequency must be OnceAMinute, OnceAnHour, or OnceADay."
  }

  validation {
    condition = alltrue([
      for c in values(var.data_connectors) : alltrue([
        for d in [c.lookback_date, c.microsoft_emerging_threat_feed_lookback_date] : d == null ? true : can(formatdate("YYYY", d))
      ])
    ])
    error_message = "lookback dates must be RFC3339 timestamps (for example 1970-01-01T00:00:00Z)."
  }

  # Cross-kind hygiene: reject fields set on kinds that silently ignore them.
  validation {
    condition = alltrue([
      for c in values(var.data_connectors) : alltrue([
        c.tenant_id == null || !contains(["aws_cloud_trail", "aws_s3", "azure_security_center", "iot"], c.kind),
        c.subscription_id == null || contains(["azure_security_center", "iot"], c.kind),
        c.aws_role_arn == null || contains(["aws_cloud_trail", "aws_s3"], c.kind),
        (c.destination_table == null && c.sqs_urls == null) || c.kind == "aws_s3",
        (c.alerts_enabled == null && c.discovery_logs_enabled == null) || c.kind == "microsoft_cloud_app_security",
        (c.exchange_enabled == null && c.sharepoint_enabled == null && c.teams_enabled == null) || c.kind == "office_365",
        c.lookback_date == null || contains(["threat_intelligence", "threat_intelligence_taxii"], c.kind),
        c.microsoft_emerging_threat_feed_lookback_date == null || c.kind == "microsoft_threat_intelligence",
        (c.api_root_url == null && c.collection_id == null && c.display_name == null && c.user_name == null && c.polling_frequency == null) || c.kind == "threat_intelligence_taxii",
      ])
    ])
    error_message = "A connector sets a field its kind does not support (for example exchange_enabled outside office_365, subscription_id outside azure_security_center/iot); remove the inapplicable field."
  }
}

variable "taxii_passwords" {
  description = "Passwords for threat_intelligence_taxii connectors that need one, keyed by the same connector name used in data_connectors. Kept out of the main map so the connector definitions stay non-sensitive."
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "workspace_id" {
  description = <<DESC
The workspace the data connectors feed. Accepts either the Log Analytics workspace id or, better,
the sentinel module's onboarding_id (an onboardingStates id): the workspace id is parsed back out
of it, and taking the onboarding id makes the Sentinel onboarding dependency explicit.
DESC

  type     = string
  nullable = false

  validation {
    condition     = can(regex("(?i)/providers/Microsoft.OperationalInsights/workspaces/[^/]+$", var.workspace_id)) || can(regex("(?i)/providers/Microsoft.OperationalInsights/workspaces/[^/]+/providers/Microsoft.SecurityInsights/onboardingStates/", var.workspace_id))
    error_message = "workspace_id must be a Log Analytics workspace id or a Sentinel onboarding (onboardingStates) id."
  }
}
