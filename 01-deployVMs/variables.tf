variable "server_count" {
    default = 3
}

variable "aws_region" {
    default = "us-west-2"
}

variable "aws_availabilityzone" {
  default = "us-west-2a"
}

variable "azure_region" {
    default = "westus2"
}

variable "aws_hostname" {
    default = "aws-server"
}

variable "azure_hostname" {
    default = "azure-server"
}

variable "azure_resourcegroup" {
  type = string
  default = "rg-DemoInfrastructure"
}

variable "azure_vnetname" {
  default = "vnet-Demo"
}

variable "tags" {
  type = map(any)
  default = {
    "Env" = "Demo"
  }
}

variable "gcp_hostname" {
    default = "gcp-server"
}

variable "subscription_id" {
  
}

variable "client_id" {
  
}

variable "client_secret" {
  sensitive = true
}

variable "tenant_id" {
  
}