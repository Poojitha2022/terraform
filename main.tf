# 1. Configure the terraform azure provider
terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "=3.0.1"
    }
  }
}

# 2. Configure the AzureRM Provider

provider "azurerm" {
  features {}
}

# 3. Create a resource group

resource "azurerm_resource_group" "example" {
  name     = "myResourceGroup"
  location = "West Europe"
}

# 4. Create a virtual network within the resource group

resource "azurerm_virtual_network" "example" {
  name                = "my first-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
}

# 4. Create a subnetwork within the resource group

resource "azurerm_subnet" "example" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.0.2.0/24"]
}

# 4. Create a publicIP within the resource group

resource "azurerm_public_ip" "public_ip" {
  name                = "vm_public_ip"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  allocation_method   = "Dynamic"
}
