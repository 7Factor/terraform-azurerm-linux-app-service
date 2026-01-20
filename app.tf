resource "azurerm_user_assigned_identity" "web_app" {
  location            = local.resource_group.location
  resource_group_name = local.resource_group.name
  name                = trim("${var.name_prefix}-id-${var.app_name}-${var.name_suffix}", "-")
}

resource "azurerm_role_assignment" "acr_pull" {
  count = var.private_acr_id != null ? 1 : 0

  scope                = var.private_acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.web_app.principal_id
}

locals {
  app_secret_bindings = {
    for s in nonsensitive(var.app_secrets) : s.app_setting_name => s.name
    if try(s.app_setting_name != null && length(trim(s.app_setting_name)) > 0, false)
  }
}

resource "azurerm_linux_web_app" "web_app" {
  name                            = trim("${var.name_prefix}-app-${var.app_name}-${var.name_suffix}", "-")
  resource_group_name             = local.resource_group.name
  location                        = local.resource_group.location
  service_plan_id                 = local.service_plan_id
  key_vault_reference_identity_id = azurerm_user_assigned_identity.web_app.id

  identity {
    type = var.enable_system_assigned_identity ? "SystemAssigned, UserAssigned" : "UserAssigned"
    identity_ids = [
      azurerm_user_assigned_identity.web_app.id
    ]
  }

  site_config {
    container_registry_use_managed_identity       = var.private_acr_id != null
    container_registry_managed_identity_client_id = var.private_acr_id != null ? azurerm_user_assigned_identity.web_app.client_id : null

    application_stack {
      docker_image_name        = var.application_stack.docker_image_name
      docker_registry_url      = var.application_stack.docker_registry_url
      docker_registry_username = var.application_stack.docker_registry_username
      docker_registry_password = var.application_stack.docker_registry_password
      dotnet_version           = var.application_stack.dotnet_version
      go_version               = var.application_stack.go_version
      java_server              = var.application_stack.java_server
      java_server_version      = var.application_stack.java_server_version
      java_version             = var.application_stack.java_version
      node_version             = var.application_stack.node_version
      php_version              = var.application_stack.php_version
      python_version           = var.application_stack.python_version
      ruby_version             = var.application_stack.ruby_version
    }
  }

  app_settings = merge(
    var.app_settings,
    {
      "APPLICATIONINSIGHTS_CONNECTION_STRING"      = azurerm_application_insights.web_app.connection_string
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

  name                       = trim("${var.name_prefix}-diag-${var.app_name}-${var.name_suffix}", "-")
  target_resource_id         = azurerm_linux_web_app.web_app.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  dynamic "enabled_log" {
    for_each = toset(var.diagnostic_log_category_groups)
    content {
      category_group = enabled_log.value
    }
  }

  dynamic "enabled_log" {
    for_each = toset(var.diagnostic_log_categories)
    content {
      category = enabled_log.value
    }
  }

  dynamic "enabled_metric" {
    for_each = toset(var.diagnostic_metric_categories)
    content {
      category = enabled_metric.value
    }
  }
}
