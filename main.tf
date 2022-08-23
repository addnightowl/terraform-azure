terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.0.0"
    }
  }
}

provider "azurerm" {
  features {

  }
}
################
# after this run terraform fmt, then terraform init
################

resource "azurerm_resource_group" "test-rg" {
  name     = "test-resources"
  location = "East Us"
  tags = {
    "environment" = "dev"
  }
}
################
# after this run terraform fmt, then terraform plan, then terraform apply
################
resource "azurerm_virtual_network" "test-vn" {
  name                = "test-network"
  resource_group_name = azurerm_resource_group.test-rg.name
  location            = azurerm_resource_group.test-rg.location
  address_space       = ["10.123.0.0/16"]

  tags = {
    "environment" = "dev"
  }
}
################
# after this run terraform fmt, then terraform plan, then terraform apply
# run terraform state list, then terraform state show (any item from the list)
# tf state is to view what was created and more
# ex: terraform state show azurerm_resource_group.test-rg (to view specific resources)
# run terraform show - to see the entire state
################

resource "azurerm_subnet" "test-subnet" {
  name                 = "test-subnet"
  resource_group_name  = azurerm_resource_group.test-rg.name
  virtual_network_name = azurerm_virtual_network.test-vn.name
  address_prefixes     = ["10.123.1.0/24"]
}

resource "azurerm_network_security_group" "test-sg" {
  name                = "test-sg"
  location            = azurerm_resource_group.test-rg.location
  resource_group_name = azurerm_resource_group.test-rg.name

  tags = {
    "environment" = "dev"
  }
}

resource "azurerm_network_security_rule" "test-dev-rule" {
  name                        = "test-dev-rule"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "73.115.239.96/32"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.test-rg.name
  network_security_group_name = azurerm_network_security_group.test-sg.name
}

resource "azurerm_subnet_network_security_group_association" "test-sga" {
  subnet_id                 = azurerm_subnet.test-subnet.id
  network_security_group_id = azurerm_network_security_group.test-sg.id
}

resource "azurerm_public_ip" "test-public-ip" {
  name                = "test-public-ip"
  resource_group_name = azurerm_resource_group.test-rg.name
  location            = azurerm_resource_group.test-rg.location
  allocation_method   = "Dynamic"

  tags = {
    "environment" = "dev"
  }
}

resource "azurerm_network_interface" "test-nic" {
  name                = "test-nic"
  location            = azurerm_resource_group.test-rg.location
  resource_group_name = azurerm_resource_group.test-rg.name

  ip_configuration {
    name                          = "Internal"
    subnet_id                     = azurerm_subnet.test-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.test-public-ip.id
  }

  tags = {
    "environment" = "dev"
  }
}

# VM Build
resource "azurerm_linux_virtual_machine" "test-vm" {
  name                  = "test-vm"
  resource_group_name   = azurerm_resource_group.test-rg.name
  location              = azurerm_resource_group.test-rg.location
  size                  = "Standard_B1s"
  admin_username        = "adminuser"
  network_interface_ids = [azurerm_network_interface.test-nic.id]

  # bootstap our image and install the docker engine
  # linux vm deployed with docker
  custom_data = filebase64("customdata.tpl")

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/testazurekey.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  provisioner "local-exec" {
    command = templatefile("${var.host_os}-ssh-script.tpl", {
      hostname     = self.public_ip_address,
      user         = "adminuser",
      identityfile = "~/.ssh/testazurekey"
    })
    interpreter = var.host_os == "linux" ? ["bash", "-c"] : ["Powershell", "Command"]
  }

  tags = {
    "environment" = "dev"
  }
}

# query azure api to use data for outputs
data "azurerm_public_ip" "test-public-ip-data" {
  name                = azurerm_public_ip.test-public-ip.name
  resource_group_name = azurerm_resource_group.test-rg.name
}

# outputs using interpolation syntax ${}
output "public_ip_address" {
  value = "${azurerm_linux_virtual_machine.test-vm.name}: ${data.azurerm_public_ip.test-public-ip-data.ip_address}"
}