moved {
  from = azurerm_application_insights.portal1
  to   = module.app_secrets.azurerm_key_vault.vault[0]
}

moved {
  from = azurerm_key_vault_secret.linked
  to   = module.app_secrets.azurerm_key_vault_secret.app_secrets
}