#Create the SQL Availiability Sets for hardware and update redundancy
resource "azurerm_availability_set" "sqlAS" {
  name                = "${var.sqlServerConfig.vmName}-as"
  location            = var.location
  resource_group_name = var.resource_group_name
  managed             = true
}
