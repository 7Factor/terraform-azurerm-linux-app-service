data "azurerm_client_config" "current" {}

locals {
  create_kv = length(var.app_secrets) > 0
  kv_base   = lower(replace(trim("${var.name_prefix}-${var.app_name}", "-"), "/[^a-z0-9-]/", ""))
}

resource "azurerm_key_vault" "web_app" {
  count = local.create_kv ? 1 : 0

  name                = substr(local.kv_base, 0, 24)
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
