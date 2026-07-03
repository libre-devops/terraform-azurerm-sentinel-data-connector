<!--
  Keep the title and badges OUTSIDE the centered <div>: the Terraform Registry's markdown renderer
  does not parse markdown inside an HTML block, so a # heading or [![badge]] in the div renders as
  literal text on the registry. Only the logo (HTML) goes in the div.
-->
<div align="center">
  <a href="https://libredevops.org">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://libredevops.org/assets/libre-devops-white.png">
      <img alt="Libre DevOps" src="https://libredevops.org/assets/libre-devops-black.png" width="300">
    </picture>
  </a>
</div>

# Terraform Azure Sentinel Data Connector

All seventeen Microsoft Sentinel data connector kinds behind one map, with the per-kind rules
enforced at plan.

[![CI](https://github.com/libre-devops/terraform-azurerm-sentinel-data-connector/actions/workflows/ci.yml/badge.svg)](https://github.com/libre-devops/terraform-azurerm-sentinel-data-connector/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/libre-devops/terraform-azurerm-sentinel-data-connector?sort=semver&label=release)](https://github.com/libre-devops/terraform-azurerm-sentinel-data-connector/releases/latest)
[![Terraform Registry](https://img.shields.io/badge/registry-libre--devops-7B42BC?logo=terraform&logoColor=white)](https://registry.terraform.io/namespaces/libre-devops)
[![License](https://img.shields.io/github/license/libre-devops/terraform-azurerm-sentinel-data-connector)](./LICENSE)

---

## Overview

The azurerm provider models Sentinel data connectors as seventeen near-identical resources whose
small differences (which take a tenant id, which take a subscription id, which carry service
toggles) are easy to get wrong one connector at a time. This module folds them into one map with
a `kind` discriminator:

- **One map, seventeen kinds.** Each entry names a connector and picks its kind (`office_365`,
  `azure_active_directory`, `threat_intelligence`, `aws_s3`, ...). The module routes each entry to
  the right resource.
- **Per-kind rules enforced at plan.** Required extras (the AWS role, the S3 queue and table, the
  Microsoft TI lookback, the TAXII endpoint) are demanded for their kind, and a field set on a
  kind that silently ignores it is rejected instead of shipped.
- **Secrets stay out of the definitions.** The TAXII password rides in a separate sensitive map
  keyed by connector name, so the connector map itself stays printable; a check flags a user name
  without a password entry (and the reverse).
- **Licensing and permissions are documented, not discovered.** All verified empirically: the
  subscription-scoped connectors (Defender for Cloud, Defender for IoT) and the Microsoft
  emerging threat feed create with ordinary workspace rights; the tenant-scoped connectors
  (Entra ID, the Office family, Dynamics, Defender for Identity and Cloud Apps, TI platforms)
  return 401 Access denied unless the caller holds tenant security-admin rights; and
  `microsoft_defender_advanced_threat_protection` plus `microsoft_threat_protection` fail with
  401 InvalidLicense on unlicensed tenants. The complete example runs the first group live and
  gates the rest behind documented flags.
- **Explicit onboarding dependency.** `workspace_id` accepts the sentinel module's
  `onboarding_id` (or a plain workspace id) and parses the workspace id back out of it.

Requires Terraform >= 1.9 and azurerm >= 4.0. Pairs with
[`libre-devops/sentinel/azurerm`](https://registry.terraform.io/modules/libre-devops/sentinel/azurerm/latest),
which owns the workspace onboarding.

## Usage

```hcl
module "sentinel" {
  source  = "libre-devops/sentinel/azurerm"
  version = "~> 4.0"

  workspace_id = module.log_analytics.workspace_ids["log-ldo-uks-prd-001"]
}

module "sentinel_data_connector" {
  source  = "libre-devops/sentinel-data-connector/azurerm"
  version = "~> 4.0"

  workspace_id = module.sentinel.onboarding_id

  data_connectors = {
    "entra-id"           = { kind = "azure_active_directory" }
    "defender-for-cloud" = { kind = "azure_security_center" }
    "office"             = { kind = "office_365", exchange_enabled = true, teams_enabled = true }
    "ti-platforms"       = { kind = "threat_intelligence", lookback_date = "2026-01-01T00:00:00Z" }

    "aws-s3-flowlogs" = {
      kind              = "aws_s3"
      aws_role_arn      = "arn:aws:iam::123456789012:role/OIDC_SentinelS3"
      destination_table = "AWSVPCFlow"
      sqs_urls          = ["https://sqs.eu-west-1.amazonaws.com/123456789012/flowlogs"]
    }
  }
}
```

## Examples

- [`examples/minimal`](./examples/minimal) - one subscription-scoped connector on a freshly
  onboarded workspace.
- [`examples/complete`](./examples/complete) - the service-principal-creatable connectors live,
  with the tenant-scoped, license-gated, and external-dependency connectors behind flags.

## Developing

Local work needs **PowerShell 7+** and **[`just`](https://github.com/casey/just)**, because the recipes
wrap the [LibreDevOpsHelpers](https://www.powershellgallery.com/packages/LibreDevOpsHelpers)
PowerShell module (the same engine the `libre-devops/terraform-azure` action runs in CI). Install
just with `brew install just`, or `uv tool add rust-just` then `uv run just <recipe>`.

Run `just` to list recipes: `just update-ldo-pwsh` (install or force-update LibreDevOpsHelpers from
PSGallery), `just validate`, `just scan` (Trivy only), `just pwsh-analyze` (PSScriptAnalyzer only),
`just plan`, `just apply`, `just destroy`, `just e2e`, `just test`, and `just docs` (the
plan/apply/destroy recipes mirror the action, including the storage firewall dance; `just e2e`
applies an example then always destroys it, defaulting to `minimal`, so nothing is left running).
Releasing is also `just`:
`just increment-release [patch|minor|major]` bumps, tags, and publishes a GitHub release, and the
Terraform Registry picks up the tag.

## Security scan exceptions

This module is scanned with [Trivy](https://github.com/aquasecurity/trivy); HIGH and CRITICAL
findings fail the build. Any waiver is a deliberate, reviewed decision, never a way to quiet a
finding that should be fixed. Waivers live in a `.trivyignore.yaml` (the machine-applied source of
truth, passed to Trivy with `--ignorefile`) and are mirrored in a table here so the reason is
auditable.

There are currently **no exceptions**: the module and its examples scan clean.

## Reference

The Requirements, Providers, Inputs, Outputs, and Resources below are generated by `terraform-docs`.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.0, < 2.0.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 4.0.0, < 5.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | >= 4.0.0, < 5.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azurerm_sentinel_data_connector_aws_cloud_trail.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/sentinel_data_connector_aws_cloud_trail) | resource |
| [azurerm_sentinel_data_connector_aws_s3.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/sentinel_data_connector_aws_s3) | resource |
| [azurerm_sentinel_data_connector_azure_active_directory.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/sentinel_data_connector_azure_active_directory) | resource |
| [azurerm_sentinel_data_connector_azure_advanced_threat_protection.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/sentinel_data_connector_azure_advanced_threat_protection) | resource |
| [azurerm_sentinel_data_connector_azure_security_center.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/sentinel_data_connector_azure_security_center) | resource |
| [azurerm_sentinel_data_connector_dynamics_365.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/sentinel_data_connector_dynamics_365) | resource |
| [azurerm_sentinel_data_connector_iot.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/sentinel_data_connector_iot) | resource |
| [azurerm_sentinel_data_connector_microsoft_cloud_app_security.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/sentinel_data_connector_microsoft_cloud_app_security) | resource |
| [azurerm_sentinel_data_connector_microsoft_defender_advanced_threat_protection.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/sentinel_data_connector_microsoft_defender_advanced_threat_protection) | resource |
| [azurerm_sentinel_data_connector_microsoft_threat_intelligence.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/sentinel_data_connector_microsoft_threat_intelligence) | resource |
| [azurerm_sentinel_data_connector_microsoft_threat_protection.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/sentinel_data_connector_microsoft_threat_protection) | resource |
| [azurerm_sentinel_data_connector_office_365.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/sentinel_data_connector_office_365) | resource |
| [azurerm_sentinel_data_connector_office_365_project.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/sentinel_data_connector_office_365_project) | resource |
| [azurerm_sentinel_data_connector_office_atp.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/sentinel_data_connector_office_atp) | resource |
| [azurerm_sentinel_data_connector_office_irm.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/sentinel_data_connector_office_irm) | resource |
| [azurerm_sentinel_data_connector_office_power_bi.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/sentinel_data_connector_office_power_bi) | resource |
| [azurerm_sentinel_data_connector_threat_intelligence.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/sentinel_data_connector_threat_intelligence) | resource |
| [azurerm_sentinel_data_connector_threat_intelligence_taxii.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/sentinel_data_connector_threat_intelligence_taxii) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_data_connectors"></a> [data\_connectors](#input\_data\_connectors) | Data connectors keyed by connector name, with `kind` selecting the connector type (the azurerm<br/>resource suffix: office\_365, azure\_active\_directory, threat\_intelligence, aws\_s3, and so on).<br/>Fields apply per kind and setting one on the wrong kind is rejected at plan:<br/><br/>- `tenant_id`: the Microsoft 365 / Entra / Defender connectors (defaults to the caller's tenant).<br/>- `subscription_id`: azure\_security\_center and iot (defaults to the caller's subscription).<br/>- `aws_role_arn` (+ `destination_table`, `sqs_urls` for aws\_s3): the AWS connectors. The role must<br/>  really exist in AWS with the workspace id as its external id; Azure validates it at create.<br/>- `alerts_enabled` / `discovery_logs_enabled`: microsoft\_cloud\_app\_security service toggles.<br/>- `exchange_enabled` / `sharepoint_enabled` / `teams_enabled`: office\_365 service toggles.<br/>- `lookback_date` (threat\_intelligence, threat\_intelligence\_taxii) and<br/>  `microsoft_emerging_threat_feed_lookback_date` (microsoft\_threat\_intelligence, required): RFC3339.<br/>- `api_root_url`, `collection_id`, `display_name`, `user_name`, `polling_frequency`:<br/>  threat\_intelligence\_taxii (the password rides in the separate, sensitive `taxii_passwords` map).<br/><br/>LICENSING: creation is validated by Azure against tenant licensing and consent. On an unlicensed<br/>tenant, microsoft\_defender\_advanced\_threat\_protection and microsoft\_threat\_protection fail with<br/>401 InvalidLicense; the rest of the Microsoft connectors create without the backing service. | <pre>map(object({<br/>    kind = string<br/><br/>    tenant_id       = optional(string)<br/>    subscription_id = optional(string)<br/><br/>    aws_role_arn      = optional(string)<br/>    destination_table = optional(string)<br/>    sqs_urls          = optional(list(string))<br/><br/>    alerts_enabled         = optional(bool)<br/>    discovery_logs_enabled = optional(bool)<br/><br/>    exchange_enabled   = optional(bool)<br/>    sharepoint_enabled = optional(bool)<br/>    teams_enabled      = optional(bool)<br/><br/>    lookback_date                                = optional(string)<br/>    microsoft_emerging_threat_feed_lookback_date = optional(string)<br/><br/>    api_root_url      = optional(string)<br/>    collection_id     = optional(string)<br/>    display_name      = optional(string)<br/>    user_name         = optional(string)<br/>    polling_frequency = optional(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_taxii_passwords"></a> [taxii\_passwords](#input\_taxii\_passwords) | Passwords for threat\_intelligence\_taxii connectors that need one, keyed by the same connector name used in data\_connectors. Kept out of the main map so the connector definitions stay non-sensitive. | `map(string)` | `{}` | no |
| <a name="input_workspace_id"></a> [workspace\_id](#input\_workspace\_id) | The workspace the data connectors feed. Accepts either the Log Analytics workspace id or, better,<br/>the sentinel module's onboarding\_id (an onboardingStates id): the workspace id is parsed back out<br/>of it, and taking the onboarding id makes the Sentinel onboarding dependency explicit. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_data_connector_ids"></a> [data\_connector\_ids](#output\_data\_connector\_ids) | Map of connector name to its id. |
| <a name="output_data_connector_ids_zipmap"></a> [data\_connector\_ids\_zipmap](#output\_data\_connector\_ids\_zipmap) | Map of connector name to { name, id }, for easy composition with other modules. |
| <a name="output_data_connectors"></a> [data\_connectors](#output\_data\_connectors) | Map of connector name to { id, kind, name }. |
| <a name="output_workspace_id"></a> [workspace\_id](#output\_workspace\_id) | The Log Analytics workspace id the connectors feed (parsed from an onboarding id when one was given). |
<!-- END_TF_DOCS -->
