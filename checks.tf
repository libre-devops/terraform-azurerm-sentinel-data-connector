# check blocks run after every plan and apply and warn (without blocking) on configuration that would
# quietly misbehave.

# A TAXII connector with a user name but no password (or the reverse) is usually a forgotten entry
# in taxii_passwords; anonymous TAXII servers use neither.
check "taxii_credentials_are_paired" {
  assert {
    condition = alltrue([
      for k, c in var.data_connectors :
      c.kind != "threat_intelligence_taxii" ? true : ((c.user_name != null) == contains(keys(var.taxii_passwords), k))
    ])
    error_message = "One or more TAXII connectors set user_name without a matching taxii_passwords entry (or the reverse)."
  }
}
