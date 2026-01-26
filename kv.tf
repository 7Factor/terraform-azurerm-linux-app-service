locals {
  kv_max_len = 24
  create_kv  = length(var.app_secrets) > 0

  unsafe_kv_name = templatestring(var.resource_name_options.template_safe, merge(local.name_template_vars, {
    app_name      = local.safe_app_name
    resource_type = "kv"
  }))
  kv_name_over_budget  = length(local.unsafe_kv_name) > local.kv_max_len ? length(local.unsafe_kv_name) - local.kv_max_len : 0
  safe_app_name_substr = substr(local.safe_app_name, 0, length(local.safe_app_name) - local.kv_name_over_budget)
  kv_name = templatestring(var.resource_name_options.template, merge({
    app_name      = local.safe_app_name_substr
    resource_type = "kv"
  }))

  app_secrets_by_name = {
    for s in nonsensitive(var.app_secrets) : s.name => sensitive(s)
  }

  key_vault = var.key_vault.existing_name != null ? data.azurerm_key_vault.web_app[0] : azurerm_key_vault.web_app[0]
}

resource "azurerm_key_vault" "web_app" {
  count = local.create_kv && var.key_vault.existing_name == null ? 1 : 0

  name                = local.kv_name
  location            = local.resource_group.location
  resource_group_name = local.resource_group.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = var.key_vault.sku

  rbac_authorization_enabled = true
  purge_protection_enabled   = var.key_vault.purge_protection_enabled
  soft_delete_retention_days = var.key_vault.soft_delete_retention_days

  tags = var.global_tags
}

resource "azurerm_role_assignment" "webapp_kv_reader" {
  count = local.create_kv ? 1 : 0

  scope                = local.key_vault.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.web_app.principal_id
}

data "azurerm_key_vault" "web_app" {
  count = var.key_vault.existing_name != null ? 1 : 0

  name                = var.key_vault.existing_name
  resource_group_name = var.key_vault.existing_rg_name != null ? var.key_vault.existing_rg_name : var.resource_group_name
}

resource "azurerm_key_vault_secret" "linked" {
  for_each = local.app_secrets_by_name

  name         = each.key
  value        = each.value.initial_value != null ? each.value.initial_value : ""
  key_vault_id = local.key_vault.id

  lifecycle {
    ignore_changes = [value]
  }
}
