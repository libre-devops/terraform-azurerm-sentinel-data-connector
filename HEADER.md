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
- **Licensing is documented, not discovered.** Creation is validated by Azure against tenant
  licensing: on an unlicensed tenant `microsoft_defender_advanced_threat_protection` and
  `microsoft_threat_protection` fail with 401 InvalidLicense (verified empirically); the other
  Microsoft connectors create without the backing service. The complete example gates those two
  (and the external-dependency AWS/TAXII connectors) behind flags.
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
- [`examples/complete`](./examples/complete) - the thirteen license-free Microsoft connectors live,
  with the license-gated and external-dependency connectors present behind flags.

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
