# terraform-azurerm-app-service

A lightweight, batteries-included Terraform module for deploying an Azure App Service (Linux) with sensible defaults and optional integrations.

What you get:
- Azure App Service Plan (Linux)
- Azure Linux Web App with .NET runtime (version configurable)
- Application Insights (workspace-based if a Log Analytics Workspace ID is provided; classic otherwise)
- Optional diagnostic settings streaming to Log Analytics
- Optional Key Vault (with RBAC), placeholder secrets, and app settings references
- User-assigned managed identity for Key Vault resolution
- Simple naming and tagging

## Why this module?

Spin up an opinionated Azure Web App quickly, with:
- Minimal inputs to get running
- Safe defaults that work for most teams
- Opt-in features (Key Vault and LAW) when you need them

## Usage

Basic example:
```hcl-terraform
module "web_app" {
    source = "."

    name_prefix = "acme"
    name_suffix = "dev"
    app_name = "orders-api"

    application_stack = {
      dotnet_version = "10.0"
    }

    # Optional: App settings passed directly to the Web App
    app_settings = {
      ASPNETCORE_URLS = "http://0.0.0.0:8080"
    }

    # Optional: Link Key Vault secrets and bind to app settings
    app_secrets = [
      {
        name             = "Db-ConnectionString"
        app_setting_name = "ConnectionStrings__Database"
        initial_value    = "sample" # optional - defaults to ""
      },
      {
        name             = "Api-Key"
        app_setting_name = "MyApi__Key"
      },
      {
        name = "Unbound-Secret"
        # app_setting omitted; secret is created in Key Vault but not bound to app settings
      }
    ]

    # Optional: Centralized logging
    # log_analytics_workspace_id = "/subscriptions//resourceGroups//providers/Microsoft.OperationalInsights/workspaces/"

    global_tags = {
      environment = "dev"
      owner = "platform-team"
    }
}
```

After apply:
- If you set `app_secrets`, the module creates:
  - A Key Vault (RBAC-enabled)
  - Secrets with the given names (initial values can be set but are defaulted to "", and Terraform ignores future changes to value)
  - App settings on the Web App that reference the secrets using non-versioned URIs
- Populate real secret values later via Azure Portal or CI. The Web App will resolve the latest version via its managed identity.

## Inputs

### Required

- **app_name** (string, required)
  - Base name for resources (combined with prefix).

### Recommended
- _name_prefix_ (string, default: "")
  - Optional global prefix for resource names.

- _name_suffix_ (string, default: "")
  - Optional global suffix for resource names. (e.g. environment name)

- _app_settings_ (map(string), default: {})
  - Additional application settings to add to the Web App.

- _app_secrets_ (list(object), default: [])
  - **name** (string, required): Key Vault secret name.
  - _app_setting_ (string, optional): App setting key to bind via Key Vault reference. If omitted, the secret is created but not bound.
  - _initial_value_ (string, optional, default ""): Seed value for first deploy. Subsequent changes are ignored. Populate/rotate via Azure Portal or CI.

- _application_stack_ (object)
  - An [application_stack](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_web_app#application_stack-1) block

- _log_analytics_workspace_id_ (string, default: null)
  - If provided, Application Insights is workspace-based and diagnostic settings send logs/metrics to this workspace.

- _global_tags_ (map(string), default: {})
  - Tags applied to all resources. Often used for environment and owning team.

### Optional

- _resource_group_name_ (string, default: null)
  - Existing Resource Group name. If not provided, a new RG is created using `location`.

- _location_ (string, default: "eastus2")
  - Azure location for resources (ignored if `resource_group_id` is provided).

- _service_plan_sku_ (string, default: "B2")
  - App Service Plan SKU name (e.g., "B1", "B2", "S1", "P1v3"). If a `service_plan_id` is provided, this value is ignored.

- _service_plan_id_ (string, default: null)
  - Existing App Service Plan ID. If this is not provided, a new plan will be created.

- _diagnostic_log_category_groups_ (list(string), default: ["allLogs"])
  - List of log category groups to enable for diagnostic settings.

- _diagnostic_log_categories_ (list(string), default: [])
  - List of log categories to enable for diagnostic settings.

- _diagnostic_metric_categories_ (list(string), default: ["AllMetrics"])
  - List of metric categories to enable for diagnostic settings.

- _key_vault_sku_ (string, default: "standard")
  - If no `app_secrets` are provided, this value is ignored

- _key_vault_purge_protection_enabled_ (bool, default: false)
  - If no `app_secrets` are provided, this value is ignored

- _key_vault_soft_delete_retention_days_ (number, default: 7)
  - If no `app_secrets` are provided, this value is ignored
