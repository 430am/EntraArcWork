provider "azurerm" {
  features {
    
  }
}

data "template_file" "ansible_data" {
  template = file("./scripts/ansible_data.tmpl")
}

data "template_cloudinit_config" "ansible_config" {
  gzip = true
  base64_encode = true

  part {
    filename = "cloud.cfg"
    content_type = "text/cloud-config"
    content = "${data.template_cloudinit_config.cloud_config.rendered}"
  }
}

resource "azurerm_public_ip" "ansiblePublicIP" {
  name = "pip-ansible"
  location = azurerm_resource_group.azureRG.location
  resource_group_name = azurerm_resource_group.azureRG.name
  allocation_method = "Dynamic"
}

resource "azurerm_network_interface" "azureAnsibleNIC" {
  name = "nic-ansiblevm"
  location = azurerm_resource_group.azureRG.location
  resource_group_name = azurerm_resource_group.azureRG.name
  ip_configuration {
    name = "nic-ansible_config"
    subnet_id = azurerm_subnet.azureSubnet1.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.ansiblePublicIP.id
  }
}

resource "azurerm_network_interface_security_group_association" "ansibleNSGassoc" {
  network_interface_id = azurerm_network_interface.azureAnsibleNIC.id
  network_security_group_id = azurerm_network_security_group.azureNSG.id
}

resource "azurerm_linux_virtual_machine" "vm_ansible" {
  name = "vm-ansiblecontrol"
  location = azurerm_resource_group.azureRG.location
  resource_group_name = azurerm_resource_group.azureRG.name
  network_interface_ids = azurerm_network_interface.azureAnsibleNIC.id
  size = "Standard_DS2_v4"

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

  user_data = "${data.template_cloudinit_config.ansible_config.rendered}"

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.azureBootDiagsStore.primary_blob_endpoint
  }
}

output "vm_ip" {
  value = azurerm_linux_virtual_machine.vm_ansible.public_ip_address
}