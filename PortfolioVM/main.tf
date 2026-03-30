# =============================================================================
# Terraform Configuration for Portfolio VM with Monitoring
# =============================================================================

# Data source for existing SSH public key
# This retrieves the SSH key that will be used for VM access
data "azurerm_ssh_public_key" "existing" {
  name                = var.ssh_key_name
  resource_group_name = var.resource_group_name
}

# ------------------------------------------------------------------------------
# Monitoring Infrastructure
# ------------------------------------------------------------------------------

# Log Analytics Workspace for storing monitoring data
# This workspace collects and stores logs and metrics from the VM
resource "azurerm_log_analytics_workspace" "law" {
  name                = "vm-monitoring-law"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"  # Pay-per-GB pricing model
  retention_in_days   = 30           # Keep data for 30 days
}

# ------------------------------------------------------------------------------
# Network Infrastructure
# ------------------------------------------------------------------------------

# Public IP address for the VM
# Provides external access to the VM
resource "azurerm_public_ip" "public_ip" {
  name                = "portfolio-ip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"  # Fixed IP address
  sku                 = "Standard" # Production-grade SKU
}

# Network Interface Card (NIC)
# Connects the VM to the virtual network
resource "azurerm_network_interface" "nic" {
  name                = "portfolio-nic"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"  # Azure assigns private IP
    public_ip_address_id          = azurerm_public_ip.public_ip.id
  }
}

# Associate Network Security Group with NIC
# Applies firewall rules to the VM's network interface
resource "azurerm_network_interface_security_group_association" "nsg_assoc" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# ------------------------------------------------------------------------------
# Virtual Machine Configuration
# ------------------------------------------------------------------------------

# Main Linux Virtual Machine
# This is the primary compute resource for the portfolio application
resource "azurerm_linux_virtual_machine" "vm" {
  name                  = var.vm_name
  location              = var.location
  resource_group_name   = var.resource_group_name
  size                  = var.vm_size
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.nic.id]

  # OS disk configuration
  os_disk {
    caching              = "ReadWrite"  # Improves performance
    storage_account_type = "Standard_LRS" # Locally redundant storage
  }

  # VM image specification
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"  # Ubuntu 22.04 LTS Gen2
    version   = "latest"
  }

  # SSH key for secure access
  admin_ssh_key {
    username   = var.admin_username
    public_key = data.azurerm_ssh_public_key.existing.public_key
  }

  # User data script for VM initialization
  # This script runs on first boot to configure the application
custom_data = base64encode(templatefile("userdata.sh", {
    PAT_TOKEN = var.pat_token
    USERNAME  = "rajagaur333"
    REPO_URL  = "https://dev.azure.com/rajagaur333/Devops_Learning/_git/portfolio"
  }))
}

# ------------------------------------------------------------------------------
# Monitoring and Alerting Configuration
# ------------------------------------------------------------------------------

# Azure Monitor Linux Agent Extension
# Installs the monitoring agent on the VM to collect metrics and logs
resource "azurerm_virtual_machine_extension" "ama" {
  name                 = "AzureMonitorLinuxAgent"
  virtual_machine_id   = azurerm_linux_virtual_machine.vm.id
  publisher            = "Microsoft.Azure.Monitor"
  type                 = "AzureMonitorLinuxAgent"
  type_handler_version = "1.20"
  auto_upgrade_minor_version = true
}

# Data Collection Rule for VM Monitoring
# Defines what metrics to collect and where to send them
resource "azurerm_monitor_data_collection_rule" "dcr" {
  name                = "vm-dcr"
  location            = var.location
  resource_group_name = var.resource_group_name

  # Destination for collected data
  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.law.id
      name                  = "logdest"  # Reference name for the destination
    }
  }

  # Data sources to collect
  data_sources {
    performance_counter {
      name                          = "cpuMetrics"
      sampling_frequency_in_seconds = 60  # Collect every 60 seconds
      streams                       = ["Microsoft-Perf"]

      # Metrics to collect
      counter_specifiers = [
        "\\Processor(_Total)\\% Processor Time",  # CPU usage
        "\\Memory\\Available Bytes"               # Available memory
      ]
    }
  }

  # Data flow configuration
  data_flow {
    streams      = ["Microsoft-Perf"]
    destinations = ["logdest"]
  }
}

# Data Collection Rule Association
# Links the data collection rule to the specific VM
resource "azurerm_monitor_data_collection_rule_association" "assoc" {
  name                    = "vm-dcr-association"
  target_resource_id      = azurerm_linux_virtual_machine.vm.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.dcr.id
}

# Action Group for Alert Notifications
# Defines how alerts are sent (email, SMS, etc.)
resource "azurerm_monitor_action_group" "email_alert" {
  name                = "vm-alert-group"
  resource_group_name = var.resource_group_name
  short_name          = "vmalert"  # Display name in alerts

  # Email notification configuration
  email_receiver {
    name          = "admin"               # Friendly name
    email_address = var.admin_email        # From variables.tf
  }
}

# Memory Alert Configuration
# Triggers when available memory drops below threshold
resource "azurerm_monitor_metric_alert" "memory_alert" {
  name                = "low-memory-alert"
  resource_group_name = var.resource_group_name
  scopes              = [azurerm_linux_virtual_machine.vm.id]

  # Alert condition
  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "Available Memory Bytes"
    aggregation      = "Average"  # How to aggregate multiple data points
    operator         = "LessThan" # Comparison operator
    threshold        = 500000000   # ~500MB in bytes
  }

  # Monitoring frequency and evaluation window
  frequency   = "PT1M"  # Check every 1 minute
  window_size = "PT5M"  # Evaluate over 5-minute window

  # Action to take when alert fires
  action {
    action_group_id = azurerm_monitor_action_group.email_alert.id
  }
}

