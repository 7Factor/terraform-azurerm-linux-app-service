variable "name_prefix" {
  description = "(Optional) Global prefix for resource names."
  type        = string
  default     = ""
}

variable "resource_group_name" {
  description = "(Optional) Existing Resource Group name. If this is not provided, a resource group will be created automatically."
  type        = string
  default     = null
}

variable "location" {
  description = "Azure location for resources. If a resource_group_id is provided, this value is ignored."
  type        = string
  default     = "eastus2"
}

variable "app_name" {
  description = "Base name for the App Service (combined with prefix)."
  type        = string
}

variable "app_settings" {
  description = "Additional application settings to add to the app."
  type        = map(string)
  default     = {}
}

variable "app_secrets" {
  description = "List of secrets to create and optionally bind to app settings."
  type = list(object({
    name             = string
    app_setting_name = optional(string)
    initial_value    = optional(string, "")
  }))
  default   = []
  sensitive = true

  validation {
    condition     = length([for s in var.app_secrets : s.name]) == length(distinct([for s in var.app_secrets : s.name]))
    error_message = "Each app_secrets entry must have a unique 'name'."
  }
}

variable "application_stack" {
  type = object({
    docker_image_name        = optional(string)
    docker_registry_url      = optional(string)
    docker_registry_username = optional(string)
    docker_registry_password = optional(string)
    dotnet_version           = optional(string)
    go_version               = optional(string)
    java_server              = optional(string)
    java_server_version      = optional(string)
    java_version             = optional(string)
    node_version             = optional(string)
    php_version              = optional(string)
    python_version           = optional(string)
    ruby_version             = optional(string)
  })
  default = {}
}

variable "service_plan_sku" {
  description = "App Service Plan size within the tier, e.g., B2."
  type        = string
  default     = "B2"
}

variable "service_plan_id" {
  description = "Existing App Service Plan ID. If this is not provided, a new plan will be created."
  type        = string
  default     = null
}

variable "log_analytics_workspace_id" {
  description = "Optional Log Analytics Workspace ID. If provided, App Insights is workspace-based and diagnostics will send logs/metrics to LAW."
  type        = string
  default     = null
}

variable "diagnostic_log_category_groups" {
  description = "List of log category groups to enable for diagnostic settings."
  type        = list(string)
  default     = ["allLogs"]
}

variable "diagnostic_log_categories" {
  description = "List of log categories to enable for diagnostic settings."
  type        = list(string)
  default     = []
}

variable "diagnostic_metric_categories" {
  description = "List of metric categories to enable for diagnostic settings."
  type        = list(string)
  default     = ["AllMetrics"]
}

variable "global_tags" {
  description = "Tags to apply to all resources (e.g., environment, cost-center)."
  type        = map(string)
  default     = {}
}

variable "key_vault_sku" {
  type    = string
  default = "standard"
}

variable "key_vault_purge_protection_enabled" {
  description = "Enable purge protection on Key Vault."
  type        = bool
  default     = false
}

variable "key_vault_soft_delete_retention_days" {
  description = "Soft delete retention in days."
  type        = number
  default     = 7
}

locals {
  # Index secrets by name for easy for_each
  app_secrets_by_name = {
    for s in nonsensitive(var.app_secrets) : s.name => sensitive(s)
  }

  # App settings subset (only those with app_setting provided)
  app_secret_bindings = {
    for s in var.app_secrets : nonsensitive(s.app_setting_name) => nonsensitive(s.name)
    if try(s.app_setting_name != null && length(trim(s.app_setting_name)) > 0, false)
  }
}
