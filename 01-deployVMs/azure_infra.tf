provider "azurerm" {
  features {
    
  }
}

resource "random_id" "random_id" {
  byte_length = 8
}

resource "azurerm_resource_group" "azureRG" {
  name = var.azure_resourcegroup
  location = var.azure_region
  tags = var.tags
}

resource "azurerm_virtual_network" "azureVnet" {
  name = var.azure_vnetname
  location = azurerm_resource_group.azureRG.location
  resource_group_name = azurerm_resource_group.azureRG.name
  address_space = ["172.17.0.0/16"]
  tags = var.tags
}

resource "azurerm_subnet" "azureSubnet1" {
  name = "subnet1"
  resource_group_name = azurerm_resource_group.azureRG.name
  virtual_network_name = azurerm_virtual_network.azureVnet.name
  address_prefixes = ["172.17.0.0/24"]
}

resource "azurerm_public_ip" "azurePublicIP" {
  name = "pip-vmip"
  location = azurerm_resource_group.azureRG.location
  resource_group_name = azurerm_resource_group.azureRG.name
  allocation_method = "Dynamic"
}

resource "azurerm_network_security_group" "azureNSG" {
  name = "nsg-sshallow"
  location = azurerm_resource_group.azureRG.location
  resource_group_name = azurerm_resource_group.azureRG.name
}

resource "azurerm_network_security_rule" "azureNSRule" {
  name = "nsrule-ssh"
  priority = 1001
  direction = "Inbound"
  access = "Allow"
  protocol = "Tcp"
  source_port_range = "*"
  destination_port_range = "*"
  source_address_prefix = "*"
  destination_address_prefix = "*"
  resource_group_name = azurerm_resource_group.azureRG.name
  network_security_group_name = azurerm_network_security_group.azureNSG.name
}

resource "azurerm_network_interface" "azureVMNIC" {
  name = "nic-vm"
  location = azurerm_resource_group.azureRG.location
  resource_group_name = azurerm_resource_group.azureRG.name
  ip_configuration {
    name = "nic-vm_configuration"
    subnet_id = azurerm_subnet.azureSubnet1.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.azurePublicIP.id
  }
}

resource "azurerm_network_interface_security_group_association" "azureNSGAssoc" {
  network_interface_id = azurerm_network_interface.azureVMNIC.id
  network_security_group_id = azurerm_network_security_group.azureNSG.id
}

resource "azurerm_storage_account" "azureBootDiagsStore" {
  name = "diag${random_id.random_id.hex}"
  location = azurerm_resource_group.azureRG.location
  resource_group_name = azurerm_resource_group.azureRG.name
  account_tier = "Standard"
  account_replication_type = "LRS"
}

data "template_file" "user_data" {
  template = file("./scripts/user_data.tmpl")
}

data "template_cloudinit_config" "cloud_config" {
  gzip = true
  base64_encode = true

  part {
    filename = "cloud.cfg"
    content_type = "text/cloud-config"
    content = "${data.template_file.user_data.rendered}"
  }
}

resource "azurerm_linux_virtual_machine" "azureVM" {
  name = "vm-entratest"
  location = azurerm_resource_group.azureRG.location
  resource_group_name = azurerm_resource_group.azureRG.name
  network_interface_ids = [azurerm_network_interface.azureVMNIC.id]
  size = "Standard_DS1_v2"

  os_disk {
    name = "vmOSDisk"
    caching = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer = "0001-com-ubuntu-server-jammy"
    sku = "22_04-lts-gen2"
    version = "latest"
  }

  admin_username = "ladmin"

  admin_ssh_key {
    username = "ladmin"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  user_data = "${data.template_cloudinit_config.cloud_config.rendered}"
  
  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.azureBootDiagsStore.primary_blob_endpoint
  }
}

output "vm_ip" {
  value = azurerm_linux_virtual_machine.azureVM.public_ip_address
}

resource "azurerm_role_assignment" "azureVMAdminLogin" {
  scope = azurerm_resource_group.azureRG.id
  role_definition_name = "Virtual Machine Administrator Login"
  
}