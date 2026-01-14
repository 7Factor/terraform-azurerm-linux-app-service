resource "azurerm_service_plan" "web_app" {
  name                = trim("${var.name_prefix}-plan-${var.app_name}", "-")
  resource_group_name = azurerm_resource_group.web_app.name
  location            = azurerm_resource_group.web_app.location
  os_type             = "Linux"
  sku_name            = var.plan_sku

  tags = merge(
    var.global_tags,
    {
      purpose = "Service plan for ${var.app_name} app service"
    }
  )
}

resource "azurerm_user_assigned_identity" "web_app" {
  location            = azurerm_resource_group.web_app.location
  resource_group_name = azurerm_resource_group.web_app.name
  name                = trim("${var.name_prefix}-id-${var.app_name}", "-")
}

resource "azurerm_linux_web_app" "web_app" {
  name                            = trim("${var.name_prefix}-app-${var.app_name}", "-")
  resource_group_name             = azurerm_resource_group.web_app.name
  location                        = azurerm_resource_group.web_app.location
  service_plan_id                 = azurerm_service_plan.web_app.id
  key_vault_reference_identity_id = azurerm_user_assigned_identity.web_app.id

  identity {
    type = "UserAssigned"
    identity_ids = [
      azurerm_user_assigned_identity.web_app.id
    ]
  }

  site_config {
    application_stack {
      dotnet_version = var.dotnet_version // minimal runtime config
    }
  }

  app_settings = merge(
    var.app_settings,
    {
      "APPINSIGHTS_CONNECTIONSTRING"               = azurerm_application_insights.web_app.connection_string
      "ApplicationInsightsAgent_EXTENSION_VERSION" = "~3"
      "XDT_MicrosoftApplicationInsights_Mode"      = "recommended"
    },
    length(local.app_secret_bindings) > 0 ? {
      for app_setting_key, secret_name in local.app_secret_bindings :
      app_setting_key => "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault.web_app[0].vault_uri}secrets/${secret_name}/)"
    } : {}
  )

  tags = var.global_tags

  depends_on = [
    azurerm_role_assignment.webapp_kv_reader
  ]
}

// Only create diagnostic settings if a LAW is provided
resource "azurerm_monitor_diagnostic_setting" "app_to_law" {
  count = var.log_analytics_workspace_id == null ? 0 : 1

  name                       = trim("${var.name_prefix}-diag-${var.app_name}", "-")
  target_resource_id         = azurerm_linux_web_app.web_app.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}
