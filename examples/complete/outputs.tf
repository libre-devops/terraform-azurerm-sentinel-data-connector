output "data_connector_ids_zipmap" {
  description = "Map of connector name to { name, id }."
  value       = module.sentinel_data_connector.data_connector_ids_zipmap
}

output "data_connectors" {
  description = "Map of connector name to { id, kind, name }."
  value       = module.sentinel_data_connector.data_connectors
}
