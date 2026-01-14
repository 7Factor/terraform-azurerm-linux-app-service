resource "azurerm_resource_group" "web_app" {
  location = var.location
  name     = trim("${var.name_prefix}-rg-${var.app_name}", "-")

  tags = merge(
    var.global_tags,
    {
      purpose = "Resource group for resources related to ${var.app_name}"
    }
  )
}

import {
  for_each = var.resource_group_id != null ? [var.resource_group_id] : []

  to = azurerm_resource_group.web_app
  id = var.resource_group_id
}