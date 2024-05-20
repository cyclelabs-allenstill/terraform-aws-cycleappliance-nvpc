# ---------------------------------------------------------------------------------------------------------------------
# awscanvpc.output.tf AWS Cycle Appliance Existing-VPC
# The output terraform file for deploying the Cycle Appliance to AWS with a new VPC
# ---------------------------------------------------------------------------------------------------------------------

output "jenkins_mgr_private_key" {
  value     = tls_private_key.jenkins_mgr.private_key_pem
  sensitive = true
}

output "jenkins_mgr_public_key" {
  value = tls_private_key.jenkins_mgr.public_key_openssh
}

output "windows_agents_private_key" {
  value     = tls_private_key.windows_agents.private_key_pem
  sensitive = true
}

output "windows_agents_public_key" {
  value = tls_private_key.windows_agents.public_key_openssh
}

output "ec2_public_ip" {
  value = aws_instance.jenkins.public_ip
}

output "ec2_private_ip" {
  value = aws_instance.jenkins.private_ip
}

output "agentadminpassword" {
  value = var.agentadminpassword
}

output "jenkinspassword" {
  value = var.jenkinspassword
}

output "connect_now" {
  value = "terraform output -raw jenkins_mgr_private_key > keys/${var.mgr_ssh_key_name} ; terraform output -raw windows_agents_private_key > keys/${var.agent_ssh_key_name} ; sudo chmod 600 keys/${var.mgr_ssh_key_name} ; ssh -i keys/${var.mgr_ssh_key_name} ubuntu@${var.jenkins_ip}"
}
