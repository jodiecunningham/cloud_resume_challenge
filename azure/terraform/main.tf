terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.28.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "mainrg" {
  name     = var.azurerm_mainrg
  location = var.azurerm_mainlocation
}

resource "azurerm_static_site" "jodiesiteswa" {
  name                = var.azurerm_jodiesitename
  resource_group_name = azurerm_resource_group.mainrg.name
  location            = "centralus"

  lifecycle {
    ignore_changes = [
      tags
    ]
  }
}

resource "azurerm_cosmosdb_account" "jodiesitecosmosdb" {
  name                = var.azurerm_jodiesitecosmosdbname
  resource_group_name = azurerm_resource_group.mainrg.name
  location            = azurerm_static_site.jodiesiteswa.location
  offer_type          = "Standard"
  enable_free_tier    = true

  consistency_policy {
    consistency_level = "Eventual"
  }
  geo_location {
    location          = azurerm_static_site.jodiesiteswa.location
    failover_priority = 0
  }
  capabilities {
    name = "EnableTable"
  }
}

resource "azurerm_cosmosdb_table" "jodiesitecosmostable" {
  name                = var.azurerm_jodiesitecosmostablename
  resource_group_name = azurerm_cosmosdb_account.jodiesitecosmosdb.resource_group_name
  account_name        = azurerm_cosmosdb_account.jodiesitecosmosdb.name
  throughput          = 400
}

resource "azurerm_template_deployment" "jodiesiteconnstr" {
  name                = "jodiesite-connstr-arm"
  resource_group_name = azurerm_resource_group.mainrg.name
  template_body       = file("swaappsettings-arm.json")
  deployment_mode     = "Incremental"
  parameters = {
    "appinsightsInstrumentationKey" = azurerm_application_insights.jodiesiteappinsights.instrumentation_key,
    "appinsightsConnectionString"   = azurerm_application_insights.jodiesiteappinsights.connection_string,
    "cosmosConnectionString"        = azurerm_cosmosdb_account.jodiesitecosmosdb.connection_strings[4]
  }
  depends_on = [
    azurerm_cosmosdb_table.jodiesitecosmostable
  ]
}

resource "azurerm_application_insights" "jodiesiteappinsights" {
  name = azurerm_static_site.jodiesiteswa.name
  location = azurerm_static_site.jodiesiteswa.location
  resource_group_name = azurerm_resource_group.mainrg.name
  application_type = "web"
}


resource "azurerm_dns_zone" "jodiesitedns" {
  resource_group_name = azurerm_resource_group.mainrg.name
  name                = "jodie.site"
}

resource "azurerm_dns_a_record" "jodiesiteapexrecord" {
  name                = "@"
  zone_name           = azurerm_dns_zone.jodiesitedns.name
  resource_group_name = azurerm_resource_group.mainrg.name
  ttl                 = 300
  target_resource_id  = azurerm_static_site.jodiesiteswa.id
}

resource "azurerm_static_site_custom_domain" "jodiesitecustomdomain" {
  static_site_id  = azurerm_static_site.jodiesiteswa.id
  domain_name     = azurerm_dns_zone.jodiesitedns.name
  validation_type = "dns-txt-token"
}

resource "azurerm_dns_txt_record" "txtapex" {
  name                = "@"
  zone_name           = azurerm_dns_zone.jodiesitedns.name
  resource_group_name = azurerm_resource_group.mainrg.name
  ttl                 = 300
  record {
    value = azurerm_static_site_custom_domain.jodiesitecustomdomain.validation_token
  }
}

resource "azurerm_dns_mx_record" "mxrecord" {
  name                = "@"
  zone_name           = azurerm_dns_zone.jodiesitedns.name
  resource_group_name = azurerm_resource_group.mainrg.name
  ttl                 = 300
  record {
    preference = 1
    exchange   = "ASPMX.L.GOOGLE.COM."
  }
  record {
    preference = 5
    exchange   = "ALT1.ASPMX.L.GOOGLE.COM."
  }
  record {
    preference = 5
    exchange   = "ALT2.ASPMX.L.GOOGLE.COM."
  }
  record {
    preference = 10
    exchange   = "ALT3.ASPMX.L.GOOGLE.COM."
  }
  record {
    preference = 10
    exchange   = "ALT4.ASPMX.L.GOOGLE.COM."
  }
}
