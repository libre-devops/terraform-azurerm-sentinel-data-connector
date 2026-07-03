variable "aws_cloudtrail_role_arn" {
  description = "The AWS role ARN for the CloudTrail connector (external id must be the workspace id)."
  type        = string
  default     = "arn:aws:iam::123456789012:role/SentinelCloudTrail"
}

variable "aws_s3_role_arn" {
  description = "The AWS role ARN for the S3 connector (OIDC_ prefixed when using web identity)."
  type        = string
  default     = "arn:aws:iam::123456789012:role/OIDC_SentinelS3"
}

variable "aws_s3_sqs_urls" {
  description = "The SQS queue URLs the S3 connector reads notifications from."
  type        = list(string)
  default     = ["https://sqs.eu-west-1.amazonaws.com/123456789012/flowlogs"]
}

# Forwarded into the tags module for the DeployedBranch / DeployedRepo tags. The terraform-azure
# action fills these in CI via TF_VAR_deployed_branch / TF_VAR_deployed_repo; empty when run locally.
variable "deployed_branch" {
  description = "Git branch the deployment came from. Auto-filled in CI from TF_VAR_deployed_branch."
  type        = string
  default     = ""
}

variable "deployed_repo" {
  description = "Repository URL the deployment came from. Auto-filled in CI from TF_VAR_deployed_repo."
  type        = string
  default     = ""
}

variable "enable_external_connectors" {
  description = "Create the AWS and TAXII connectors. Off by default: Azure validates the AWS role against a real AWS account and polls the TAXII server at create."
  type        = bool
  default     = false
}

variable "enable_licensed_connectors" {
  description = "Create the Defender for Endpoint and Defender XDR connectors. Off by default: they fail with 401 InvalidLicense on tenants without those licenses."
  type        = bool
  default     = false
}

variable "loc" {
  description = "Outfix: short Azure region code used in resource names (for example uks)."
  type        = string
  default     = "uks"
}

variable "regions" {
  description = "Map of short region codes to Azure region slugs."
  type        = map(string)
  default = {
    uks = "uksouth"
    ukw = "ukwest"
    eus = "eastus"
    euw = "westeurope"
  }
}

variable "short" {
  description = "Infix: short product code used in resource names."
  type        = string
  default     = "ldo"
}

variable "taxii_api_root_url" {
  description = "The TAXII 2.x API root URL."
  type        = string
  default     = "https://taxii.example.com/api/v21/"
}

variable "taxii_collection_id" {
  description = "The TAXII collection id to poll."
  type        = string
  default     = "0aba3e12-0000-4000-8000-000000000001"
}

variable "taxii_password" {
  description = "The TAXII password (paired with the connector's user_name)."
  type        = string
  default     = "change-me"
  sensitive   = true
}
