output "web_app" {
  value = azurerm_linux_web_app.web_app
}

output "service_plan" {
  value = azurerm_service_plan.web_app
}

output "application_insights" {
  value = azurerm_application_insights.web_app
}
