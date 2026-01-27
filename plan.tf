resource "azurerm_service_plan" "web_app" {
  count = var.service_plan_id == null ? 1 : 0

  name = templatestring(var.resource_name_options.template, merge(local.name_template_vars, {
    resource_type = "plan"
  }))
  resource_group_name = local.resource_group.name
  location            = local.resource_group.location
  os_type             = "Linux"
  sku_name            = var.service_plan_sku

  tags = merge(
    var.global_tags,
    {
      purpose = "Service plan for ${var.app_name} app service"
    }
  )
}

locals {
  service_plan_id = var.service_plan_id == null ? azurerm_service_plan.web_app[0].id : var.service_plan_id
}