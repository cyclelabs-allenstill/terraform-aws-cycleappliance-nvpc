# ---------------------------------------------------------------------------------------------------------------------
# awscanvpc.vars.tf AWS Cycle Appliance Existing-VPC
# The variable declaration terraform file for deploying the Cycle Appliance to AWS with a new VPC
# ---------------------------------------------------------------------------------------------------------------------

## AWS Network Variables
variable "az_name" {
  description = "AZ to use for your network resources"
  type        = string
}

variable "vpc_cidr" {
  description = "The CIDR to use for the entire vpc"
  type        = string
}

variable "private_sn_cidr" {
  description = "The CIDR to use for the private subnet"
  type        = string
}

variable "nat_sn_cidr" {
  description = "The CIDR to use for the post nat subnet"
  type        = string
}

variable "network_prefix" {
  default     = "cycleappliance"
  description = "A prefix for the name of all network resources deployed with this code (we recommend cycleappliance or something similar)"
  type        = string
}


## AWS Variables
variable "jenkins_ip" {
  description = "IP address for the Jenkins manager"
  type        = string
}

variable "allow_cidrs" {
  default     = []
  description = "Optional CIDRs you want to allow to access the Jenkins manager in your security group"
  type        = list(any)
}

variable "region_name" {
  description = "The region you'll be deploying these resources to"
  type        = string
}

variable "resource_name_prefix" {
  default     = "cycleappliance"
  description = "A prefix for the name of all resources deployed with this code (we recommend cycleappliance or something similar)"
  type        = string
}

variable "mgr_ssh_key_name" {
  default     = "ca-mgr"
  description = "Name of the manager SSH keypair file(s) within the /keys/ directory that you created using ssh-keygen. We will append the .pub and .pem."
  type        = string
}

variable "agent_ssh_key_name" {
  default     = "ca-agent"
  description = "Name of the agent SSH keypair file(s) within the /keys/ directory that you created using ssh-keygen. We will append the .pub and .pem."
  type        = string
}

variable "instance_type" {
  default     = "t2.small"
  description = "Instance type used for the EC2 instance for the Jenkins manager (we recommend at least a 't2.small' and above)"
  type        = string
}

variable "volume_size" {
  default     = 30
  description = "Size in GB for the Jenkins manager OS disk (we recommend at least 30GBs to allow some room)"
  type        = number
}

variable "backup_schedule" {
  default     = "cron(0 5 ? * MON-FRI *)"
  description = "The schedule in cron format to use for backing up the Jenkins manager"
  type        = string
}

variable "backup_retention_days" {
  default     = 7
  description = "The amount of days to retain of Jenkins manager backups"
  type        = number
}

locals {
  backups = {
    schedule  = var.backup_schedule
    retention = var.backup_retention_days
  }
}

## Jenkins Variables
variable "jenkinsadmin" {
  description = "Default Jenkins Admin user"
  type        = string
}

variable "jenkinspassword" {
  type        = string
  description = "Default Jenkins Admin password"
}

variable "agentadminusername" {
  default     = "administrator"
  description = "Agent Admin username"
  type        = string
}

variable "agentadminpassword" {
  default     = "68q79h4W#mN4k87P#!JQ"
  description = "Agent Admin password"
  type        = string
}


## Jenkins EC2 Plugin Variables
variable "ami_name" {
  default     = "cycleready-*"
  description = "The AMI name that you'd like to use for pulling latest for the Jenkins agents"
  type        = string
}

variable "ami_owner" {
  description = "The OwnerID value from AWS that is assigned to the AMI you'd like to use for Jenkins agents"
  type        = string
}


## Variables for tags with a local variable at the end to pull all tag key:pairs as an map
variable "env_tag" {
  description = "The environment this resource is deployed in"
  type        = string
}

variable "owner_tag" {
  description = "The person who created the resource"
  type        = string
}

#This locals block combines both the env_tag and owner_tag together. Feel free to add more variables for tags, add 
#those tags to the locals block (using owner and environment below as examples), and they'll be merged into all resources created with this code.
locals {
  std_tags = {
    owner       = var.owner_tag
    environment = var.env_tag
  }
}
