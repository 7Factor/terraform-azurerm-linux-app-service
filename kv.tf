locals {
  kv_max_len = 24

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

  needs_kv_role = length(local.app_secret_bindings) > 0
}

module "app_secrets" {
  source  = "7Factor/app-secrets/azurerm"
  version = ">= 1"

  app_secrets = var.app_secrets

  managed_identity_principal_id = local.needs_kv_role ? azurerm_user_assigned_identity.web_app[0].principal_id : null

  key_vault_settings = {
    name                       = var.key_vault.existing_name != null ? var.key_vault.existing_name : local.kv_name
    rg_name                    = var.key_vault.existing_rg_name != null ? var.key_vault.existing_rg_name : var.resource_group_name
    externally_created         = var.key_vault.existing_name != null
    sku_name                   = var.key_vault.sku
    purge_protection_enabled   = var.key_vault.purge_protection_enabled
    soft_delete_retention_days = var.key_vault.soft_delete_retention_days
    tags                       = var.global_tags
  }
}
