locals {
  kv_max_len = 24
  create_kv  = length(var.app_secrets) > 0

  unsafe_kv_base      = lower(replace(trim("${var.name_prefix}-kv-${var.app_name}-${var.name_suffix}", "-"), "/[^a-z0-9-]/", ""))
  kv_base_over_budget = length(local.unsafe_kv_base) > local.kv_max_len ? length(local.unsafe_kv_base) - local.kv_max_len : 0
  safe_app_name       = substr(var.app_name, 0, length(var.app_name) - local.kv_base_over_budget)
  kv_base             = lower(replace(trim("${var.name_prefix}-kv-${local.safe_app_name}-${var.name_suffix}", "-"), "/[^a-z0-9-]/", ""))

  app_secrets_by_name = {
    for s in nonsensitive(var.app_secrets) : s.name => sensitive(s)
  }
}

resource "azurerm_key_vault" "web_app" {
  count = local.create_kv ? 1 : 0

  name                = local.kv_base
  location            = local.resource_group.location
  resource_group_name = local.resource_group.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = var.key_vault_sku

  rbac_authorization_enabled = true
  purge_protection_enabled   = var.key_vault_purge_protection_enabled
  soft_delete_retention_days = var.key_vault_soft_delete_retention_days

  tags = var.global_tags
}

resource "azurerm_role_assignment" "webapp_kv_reader" {
  count = local.create_kv ? 1 : 0

  scope                = azurerm_key_vault.web_app[0].id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.web_app.principal_id
}

resource "azurerm_key_vault_secret" "linked" {
  for_each = local.app_secrets_by_name

  name         = each.key
  value        = coalesce(each.value.initial_value, "")
  key_vault_id = azurerm_key_vault.web_app[0].id

  lifecycle {
    ignore_changes = [value]
  }
}
