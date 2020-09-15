# Template for SQL Server Cluster
# Note if running this many times for testing make sure to delete the AD and DNS objects
terraform {
  required_version = ">= 0.12.1"
  backend "azurerm" {
    storage_account_name = "${var.storage_account_name}"
    container_name       = "${var.container_name}"
    key                  = "${var.key}"
    access_key           = "${var.access_key}"
  }
}

