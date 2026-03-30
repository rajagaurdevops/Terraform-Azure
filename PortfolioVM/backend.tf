terraform {
  backend "azurerm" {
    resource_group_name  = "RG-Devops"
    storage_account_name = "portfolioinfra001"
    container_name       = "portfolio-container"
    key                  = "portfolio-vm.tfstate"
  }
}

