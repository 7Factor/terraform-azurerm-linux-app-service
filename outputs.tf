output "app_id" {
  value = azurerm_linux_web_app.web_app.id
}

output "app_default_hostname" {
  value = azurerm_linux_web_app.web_app.default_hostname
}

output "app_service_plan_id" {
  value = local.service_plan_id
}

output "application_insights_connection_string" {
  value = azurerm_application_insights.web_app.connection_string
}

output "application_insights_id" {
  value = azurerm_application_insights.web_app.id
}
