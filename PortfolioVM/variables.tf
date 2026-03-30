variable "location" {
  default = "centralindia"
}

variable "resource_group_name" {
  default = "RG-Devops"
}

variable "vm_name" {
  default = "portfolio-vm"
}

variable "vm_size" {
  default = "Standard_B1s"
}

variable "admin_username" {
  default = "azureuser"
}

variable "ssh_key_name" {
  default = "portfolio_key"
}

variable "pat_token" {
  description = "Azure DevOps PAT Token"
  type        = string
  sensitive   = true
}

variable "admin_email" {
  description = "Admin email address"
  type        = string
  default     = "admin@example.com"
}