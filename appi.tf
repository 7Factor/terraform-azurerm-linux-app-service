resource "azurerm_application_insights" "web_app" {
  name                = trim("${var.name_prefix}-appi-${var.app_name}", "-")
  resource_group_name = azurerm_resource_group.web_app.name
  location            = azurerm_resource_group.web_app.location

  // If workspace id provided, create workspace-based; else classic
  workspace_id = var.log_analytics_workspace_id

  application_type = "web"

  tags = var.global_tags
}