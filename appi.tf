resource "azurerm_application_insights" "web_app" {
  name                = trim("${var.name_prefix}-appi-${var.app_name}-${var.name_suffix}", "-")
  resource_group_name = local.resource_group.name
  location            = local.resource_group.location

  // If workspace id provided, create workspace-based; else classic
  workspace_id = var.log_analytics_workspace_id

  application_type = "web"

  tags = var.global_tags
}