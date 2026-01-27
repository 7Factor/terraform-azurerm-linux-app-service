resource "azurerm_resource_group" "web_app" {
  count = var.resource_group_name == null ? 1 : 0

  location = var.location
  name = templatestring(var.resource_name_options.template, merge(local.name_template_vars, {
    resource_type = "rg"
  }))

  tags = merge(
    var.global_tags,
    {
      purpose = "Resource group for resources related to ${var.app_name}"
    }
  )
}

data "azurerm_resource_group" "web_app" {
  count = var.resource_group_name != null ? 1 : 0

  name = var.resource_group_name
}

locals {
  resource_group = var.resource_group_name != null ? data.azurerm_resource_group.web_app[0] : azurerm_resource_group.web_app[0]
}