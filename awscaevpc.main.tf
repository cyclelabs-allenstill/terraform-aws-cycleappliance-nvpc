# ---------------------------------------------------------------------------------------------------------------------
# awscaevpc.main.tf AWS Cycle Appliance Existing-VPC
# The main terraform file for deploying the Cycle Appliance to AWS with an existing VPC
# ---------------------------------------------------------------------------------------------------------------------

terraform {

  required_version = ">=0.12"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>4.0.0"
    }
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = "2.2.0"
    }
  }
}

provider "cloudinit" {
}

provider "aws" {
  region = var.region_name
}

# Fetches the VPC we'll be using
data "aws_vpc" "vpc" {
  cidr_block = var.vpc_cidr
}

# Fetches the subnet we'll be using for Jenkins
data "aws_subnet" "sn" {
  vpc_id     = data.aws_vpc.vpc.id
  cidr_block = var.sn_cidr
}

# Install the cloud-init configuration to install Jenkins, install Jenkins plugins, apply JCasC file, etc.
data "cloudinit_config" "server_config" {
  gzip          = true
  base64_encode = true
  part {
    content_type = "text/cloud-config"
    content = templatefile("${path.module}/../scripts/cloud-init-tf.yml", {
      "jenkinsadmin"            = var.jenkinsadmin
      "jenkinspassword"         = var.jenkinspassword
      "agentadminusername"      = var.agentadminusername
      "agentadminpassword"      = var.agentadminpassword
      "jenkinsserverport"       = "http://${var.jenkins_ip}:8080/"
      "jenkinsserver"           = var.jenkins_ip
      "aws_region"              = var.region_name
      "aws_subnet_id"           = data.aws_subnet.sn.id
      "aws_windows_agent_sg_id" = aws_security_group.windows_agents_sg.id
      "ec2_private_key"         = tls_private_key.windows_agents.private_key_pem
      "ami_name"                = var.ami_name
      "ami_owner"               = var.ami_owner
      "name_prefix"             = var.resource_name_prefix
    })
  }
}

#  Create (and display) an SSH key for the Jenkins manager
resource "tls_private_key" "jenkins_mgr" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

#  Create (and display) an SSH key for the Windows agents - Amazon EC2 supports 2048-bit SSH-2 RSA keys for Windows instances. (https://docs.aws.amazon.com/AWSEC2/latest/WindowsGuide/ec2-key-pairs.html)
resource "tls_private_key" "windows_agents" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

#  Adding the keypair into the Jenkins manager EC2 isntance
resource "aws_key_pair" "cycle-appliance-ssh-key" {
  depends_on = [
    tls_private_key.jenkins_mgr
  ]
  key_name   = var.mgr_ssh_key_name
  public_key = tls_private_key.jenkins_mgr.public_key_openssh
  tags       = merge(local.std_tags, { Name = "${var.mgr_ssh_key_name}-keypair" })
}

#  Adding the keypair to be used by the Windows agents that Jenkins will create with the EC2 plugin
resource "aws_key_pair" "cycle-windows-agents-ssh-key" {
  depends_on = [
    tls_private_key.windows_agents
  ]
  key_name   = var.agent_ssh_key_name
  public_key = tls_private_key.windows_agents.public_key_openssh
  tags       = merge(local.std_tags, { Name = "${var.agent_ssh_key_name}-keypair" })
}

#  Building out AWS Backup vault, backup plan, and backup selection.
resource "aws_backup_vault" "cycleappliancevault" {
  depends_on = [
    aws_instance.jenkins
  ]
  name = "${var.resource_name_prefix}-vault"
  tags = merge(local.std_tags, { Name = "${var.resource_name_prefix}-vault" })
}

resource "aws_backup_plan" "defaultplan" {
  name = "${var.resource_name_prefix}-backupplan"
  depends_on = [
    aws_instance.jenkins
  ]
  tags = merge(local.std_tags, { Name = "${var.resource_name_prefix}-backup-plan" })
  rule {
    rule_name         = "${var.resource_name_prefix}-backuprule"
    target_vault_name = aws_backup_vault.cycleappliancevault.name
    schedule          = local.backups.schedule
    start_window      = 60
    completion_window = 300

    lifecycle {
      delete_after = local.backups.retention
    }

    recovery_point_tags = {
      Role    = "backup"
      Creator = "aws-backups"
    }
  }
}

# Creating and assigning AWS backup IAM roles
resource "aws_iam_role" "backupiamrole" {
  name               = "${var.resource_name_prefix}-backup-role"
  assume_role_policy = file("../scripts/backup-role.json")
}

resource "aws_iam_role_policy_attachment" "backupiamroleattachment" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
  role       = aws_iam_role.backupiamrole.name
}

# Creating backup selection to backup the Jenkins manager.
resource "aws_backup_selection" "cycleappliance-backup-selection" {
  depends_on = [
    aws_instance.jenkins
  ]
  iam_role_arn = aws_iam_role.backupiamrole.arn
  name         = "${var.resource_name_prefix}-backup-selection"
  plan_id      = aws_backup_plan.defaultplan.id

  resources = [
    aws_instance.jenkins.arn
  ]
}

# Creating Jenkins manager instance policy to allow it to deploy agents
resource "aws_iam_policy" "jenkins_mgr_policy" {
  name        = "${var.resource_name_prefix}-mgr-policy"
  path        = "/"
  description = ""
  tags        = merge(local.std_tags, { Name = "${var.resource_name_prefix}-mgr-policy" })
  policy      = file("../scripts/jenkins-mgr-policy.json")
}

# Creating Jenkins manager instance role to allow it to deploy agents
resource "aws_iam_role" "jenkins_mgr_role" {
  name               = "${var.resource_name_prefix}-mgr-policy"
  path               = "/"
  tags               = merge(local.std_tags, { Name = "${var.resource_name_prefix}-mgr-role" })
  assume_role_policy = file("../scripts/jenkins-mgr-role.json")
}

# Attach Jenkins manager policy to role
resource "aws_iam_role_policy_attachment" "jenkins_mgr_roleatt" {
  policy_arn = aws_iam_policy.jenkins_mgr_policy.arn
  role       = aws_iam_role.jenkins_mgr_role.name
}

# Create and attach Jenkins manager instance profile to role
resource "aws_iam_instance_profile" "jenkins_mgr_profile" {
  name = "${var.resource_name_prefix}-mgr-profile"
  role = aws_iam_role.jenkins_mgr_role.name
}

# Lookup latest Ubuntu 22.04 AMI id to use for the Jenkins manager EC2 instance
data "aws_ami" "ubuntu" {
  owners      = ["099720109477"]
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# Create NIC for the Jenkins Manager Instance
resource "aws_network_interface" "nic" {
  subnet_id = data.aws_subnet.sn.id
  security_groups = [
    aws_security_group.jenkins_mgr_sg.id
  ]
  private_ips = ["${var.jenkins_ip}"]
  tags        = merge(local.std_tags, { Name = "${var.resource_name_prefix}-nic" })
}

# Create security group to allow local traffic to Jenkins
resource "aws_security_group" "jenkins_mgr_sg" {
  name   = "${var.resource_name_prefix}-jenkins-mgr-sg"
  vpc_id = data.aws_vpc.vpc.id
  tags   = merge(local.std_tags, { Name = "${var.resource_name_prefix}-jenkins-mgr-sg" })

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = concat([data.aws_vpc.vpc.cidr_block], var.allow_cidrs)
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create security group for the Jenkins agents
resource "aws_security_group" "windows_agents_sg" {
  name   = "${var.resource_name_prefix}-windows-agents-sg"
  vpc_id = data.aws_vpc.vpc.id
  tags   = merge(local.std_tags, { Name = "${var.resource_name_prefix}-windows-agents-sg" })

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [data.aws_vpc.vpc.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Build an EC2 from latest Ubuntu AMI id
resource "aws_instance" "jenkins" {
  depends_on = [
    aws_key_pair.cycle-appliance-ssh-key,
    aws_network_interface.nic,
    data.cloudinit_config.server_config
  ]
  iam_instance_profile = aws_iam_instance_profile.jenkins_mgr_profile.name
  ami                  = data.aws_ami.ubuntu.id
  instance_type        = var.instance_type
  user_data_base64     = data.cloudinit_config.server_config.rendered
  key_name             = aws_key_pair.cycle-appliance-ssh-key.key_name

  network_interface {
    network_interface_id = aws_network_interface.nic.id
    device_index         = 0
  }

  root_block_device {
    volume_size = var.volume_size
  }
  tags = merge(local.std_tags, { Name = "${var.resource_name_prefix}-mgr" })
}
