output "data_connector_ids" {
  description = "Map of connector name to its id."
  value       = { for k, c in local.connector_objects : k => c.id }
}

output "data_connector_ids_zipmap" {
  description = "Map of connector name to { name, id }, for easy composition with other modules."
  value       = { for k, c in local.connector_objects : k => { name = c.name, id = c.id } }
}

output "data_connectors" {
  description = "Map of connector name to { id, kind, name }."
  value       = local.connector_objects
}

output "workspace_id" {
  description = "The Log Analytics workspace id the connectors feed (parsed from an onboarding id when one was given)."
  value       = local.workspace_id
}
