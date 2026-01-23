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
    for s in nonsensitive(var.app_secrets) :
    try(s.app_setting_name, "") => s.name
    if length(try(s.app_setting_name, "")) > 0
  }
}

resource "azurerm_linux_web_app" "web_app" {
  name                            = trim("${var.name_prefix}-app-${var.app_name}-${var.name_suffix}", "-")
  resource_group_name             = local.resource_group.name
  location                        = local.resource_group.location
  service_plan_id                 = local.service_plan_id
  key_vault_reference_identity_id = azurerm_user_assigned_identity.web_app.id

  https_only                         = var.site_config.https_only
  client_affinity_enabled            = var.site_config.client_affinity_enabled
  client_certificate_enabled         = var.site_config.client_certificate_enabled
  client_certificate_mode            = var.site_config.client_certificate_mode
  client_certificate_exclusion_paths = var.site_config.client_certificate_exclusion_paths

  identity {
    type = var.enable_system_assigned_identity ? "SystemAssigned, UserAssigned" : "UserAssigned"
    identity_ids = [
      azurerm_user_assigned_identity.web_app.id
    ]
  }

  site_config {
    http2_enabled = true

    always_on                         = var.site_config.always_on
    api_definition_url                = var.site_config.api_definition_url
    api_management_api_id             = var.site_config.api_management_api_id
    app_command_line                  = var.site_config.app_command_line
    default_documents                 = var.site_config.default_documents
    ftps_state                        = var.site_config.ftps_state
    health_check_path                 = var.site_config.health_check_path
    health_check_eviction_time_in_min = var.site_config.health_check_eviction_time_in_min
    load_balancing_mode               = var.site_config.load_balancing_mode
    minimum_tls_version               = var.site_config.minimum_tls_version
    use_32_bit_worker                 = var.site_config.use_32_bit_worker
    websockets_enabled                = var.site_config.websockets_enabled
    worker_count                      = var.site_config.worker_count

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
      app_setting_key => "@Microsoft.KeyVault(SecretUri=${local.key_vault.vault_uri}secrets/${secret_name}/)"
    } : {}
  )

  tags = var.global_tags

  lifecycle {
    ignore_changes = [
      # Ignore changes to these tags as they may be managed externally
      tags["hidden-link: /app-insights-resource-id"],
    ]
  }

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
