# Tests for the module. azurerm is mocked (no credentials, no cloud):
#   terraform init -backend=false && terraform test

mock_provider "azurerm" {}

variables {
  workspace_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-001/providers/Microsoft.OperationalInsights/workspaces/log-ldo-uks-tst-001"
}

# One connector of every kind in a single call, exercising every kind-specific field.
run "all_kinds" {
  command = apply

  variables {
    data_connectors = {
      "aws-cloudtrail"    = { kind = "aws_cloud_trail", aws_role_arn = "arn:aws:iam::123456789012:role/SentinelCloudTrail" }
      "aws-s3-flowlogs"   = { kind = "aws_s3", aws_role_arn = "arn:aws:iam::123456789012:role/OIDC_SentinelS3", destination_table = "AWSVPCFlow", sqs_urls = ["https://sqs.eu-west-1.amazonaws.com/123456789012/flowlogs"] }
      "entra-id"          = { kind = "azure_active_directory" }
      "defender-identity" = { kind = "azure_advanced_threat_protection" }
      "defender-cloud"    = { kind = "azure_security_center", subscription_id = "00000000-0000-0000-0000-00000000beef" }
      "dynamics"          = { kind = "dynamics_365" }
      "defender-iot"      = { kind = "iot" }
      "defender-apps"     = { kind = "microsoft_cloud_app_security", alerts_enabled = true, discovery_logs_enabled = false }
      "defender-endpoint" = { kind = "microsoft_defender_advanced_threat_protection" }
      "msft-threat-intel" = { kind = "microsoft_threat_intelligence", microsoft_emerging_threat_feed_lookback_date = "1970-01-01T00:00:00Z" }
      "defender-xdr"      = { kind = "microsoft_threat_protection" }
      "office"            = { kind = "office_365", exchange_enabled = true, sharepoint_enabled = true, teams_enabled = false }
      "office-project"    = { kind = "office_365_project" }
      "office-defender"   = { kind = "office_atp" }
      "office-irm"        = { kind = "office_irm" }
      "office-powerbi"    = { kind = "office_power_bi" }
      "ti-platforms"      = { kind = "threat_intelligence", lookback_date = "2026-01-01T00:00:00Z" }
      "ti-taxii-feed" = {
        kind              = "threat_intelligence_taxii"
        display_name      = "Partner TAXII feed"
        api_root_url      = "https://taxii.example.com/api/v21/"
        collection_id     = "0aba3e12-0000-4000-8000-000000000001"
        user_name         = "feeduser"
        polling_frequency = "OnceADay"
        lookback_date     = "2026-01-01T00:00:00Z"
      }
    }

    taxii_passwords = {
      "ti-taxii-feed" = "s3cr3t"
    }
  }

  assert {
    condition     = length(output.data_connector_ids) == 18
    error_message = "All 18 connectors should be created and exported."
  }

  assert {
    condition     = output.data_connectors["office"].kind == "office_365"
    error_message = "The flat map should carry each connector's kind."
  }

  assert {
    condition     = azurerm_sentinel_data_connector_office_365.this["office"].teams_enabled == false
    error_message = "Office 365 service toggles should pass through."
  }

  assert {
    condition     = azurerm_sentinel_data_connector_threat_intelligence_taxii.this["ti-taxii-feed"].polling_frequency == "OnceADay"
    error_message = "TAXII settings should pass through."
  }

  assert {
    condition     = azurerm_sentinel_data_connector_aws_s3.this["aws-s3-flowlogs"].destination_table == "AWSVPCFlow"
    error_message = "AWS S3 settings should pass through."
  }
}

# An onboarding (onboardingStates) id is accepted and parsed back to the workspace id.
run "parses_onboarding_id" {
  command = apply

  variables {
    workspace_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-001/providers/Microsoft.OperationalInsights/workspaces/log-ldo-uks-tst-001/providers/Microsoft.SecurityInsights/onboardingStates/default"

    data_connectors = {
      "entra-id" = { kind = "azure_active_directory" }
    }
  }

  assert {
    condition     = azurerm_sentinel_data_connector_azure_active_directory.this["entra-id"].log_analytics_workspace_id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-001/providers/Microsoft.OperationalInsights/workspaces/log-ldo-uks-tst-001"
    error_message = "The workspace id should be parsed out of the onboarding id."
  }
}

# A TAXII connector with a user name but no password entry trips the pairing check.
run "flags_unpaired_taxii_credentials" {
  command = apply

  variables {
    data_connectors = {
      "ti-taxii-feed" = {
        kind          = "threat_intelligence_taxii"
        display_name  = "Partner TAXII feed"
        api_root_url  = "https://taxii.example.com/api/v21/"
        collection_id = "0aba3e12-0000-4000-8000-000000000001"
        user_name     = "feeduser"
      }
    }
  }

  expect_failures = [check.taxii_credentials_are_paired]
}

# An unknown kind is rejected.
run "rejects_bad_kind" {
  command = plan

  variables {
    data_connectors = {
      bad = { kind = "gcp_pubsub" }
    }
  }

  expect_failures = [var.data_connectors]
}

# aws_s3 without its required extras is rejected.
run "rejects_incomplete_aws_s3" {
  command = plan

  variables {
    data_connectors = {
      bad = { kind = "aws_s3", aws_role_arn = "arn:aws:iam::123456789012:role/x" }
    }
  }

  expect_failures = [var.data_connectors]
}

# microsoft_threat_intelligence without its required lookback is rejected.
run "rejects_msti_without_lookback" {
  command = plan

  variables {
    data_connectors = {
      bad = { kind = "microsoft_threat_intelligence" }
    }
  }

  expect_failures = [var.data_connectors]
}

# A field on the wrong kind is rejected (office toggles on an office_atp connector).
run "rejects_inapplicable_field" {
  command = plan

  variables {
    data_connectors = {
      bad = { kind = "office_atp", exchange_enabled = true }
    }
  }

  expect_failures = [var.data_connectors]
}

# subscription_id on a tenant-scoped connector is rejected.
run "rejects_subscription_on_tenant_connector" {
  command = plan

  variables {
    data_connectors = {
      bad = { kind = "office_365", subscription_id = "00000000-0000-0000-0000-00000000beef" }
    }
  }

  expect_failures = [var.data_connectors]
}

# A malformed lookback date is rejected.
run "rejects_bad_lookback" {
  command = plan

  variables {
    data_connectors = {
      bad = { kind = "threat_intelligence", lookback_date = "last year" }
    }
  }

  expect_failures = [var.data_connectors]
}

# A workspace_id that is neither shape is rejected.
run "rejects_wrong_workspace_id" {
  command = plan

  variables {
    workspace_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-x/providers/Microsoft.KeyVault/vaults/kv-x"
  }

  expect_failures = [var.workspace_id]
}
