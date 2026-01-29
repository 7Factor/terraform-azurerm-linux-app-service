moved {
  from = azurerm_key_vault.web_app[0]
  to   = module.app_secrets.azurerm_key_vault.vault[0]
}

moved {
  from = azurerm_role_assignment.webapp_kv_reader[0]
  to   = module.app_secrets.azurerm_role_assignment.webapp_kv_reader[0]
}

moved {
  from = azurerm_key_vault_secret.linked
  to   = module.app_secrets.azurerm_key_vault_secret.app_secrets
}