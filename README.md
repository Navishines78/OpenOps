Ì≥¶ OpenOps EC2 Provisioning with Terraform
This Terraform module automates the deployment of an OpenOps instance on AWS EC2, with restricted SSH/HTTP(S) access based on your public IP. It includes:

Secure key-pair provisioning

Security group rules scoped to your IP

IAM role and instance profile for SNS publishing

Automated OpenOps installation via cloud-init

SNS notification (success/failure) to your email

Ì¥ß Prerequisites
Terraform v1.0+

AWS credentials configured (~/.aws/credentials or environment variables)

An existing SSH key at ~/.ssh/my_key_pair and my_key_pair.pub

Verified email address (used for SNS subscription)

Ì≥Å File Structure
.
‚îú‚îÄ‚îÄ main.tf                  # Main infrastructure code
‚îú‚îÄ‚îÄ variables.tf             # Input variables
‚îú‚îÄ‚îÄ outputs.tf               # Outputs
‚îú‚îÄ‚îÄ user-data.sh.tmpl        # Startup script for OpenOps
‚îî‚îÄ‚îÄ README.md                # You're reading it!

Ì∫Ä Usage
Initialize Terraform:
    terraform init
Review and apply the configuration:
    terraform apply
‚úÖ Confirm the plan and allow time for instance provisioning & OpenOps installation.

Verify SNS Email Subscription:

    Check your email inbox.

    Click the link to confirm the SNS subscription.

Configuration
You can customize variables in terraform.tfvars or via CLI:

region         = "ap-south-2"
email_address  = "your_email@example.com"
volume_size    = 30
volume_type    = "gp3"

Ì≥§ Outputs
After deployment, Terraform provides:

remote_server_public_ip: Public IP of your EC2 instance

local_ip_cidr: CIDR used for your own IP (used in SG)

Ì≥° SNS Notification
At the end of provisioning, the EC2 instance checks if OpenOps is reachable (http://localhost) and sends a status email via AWS SNS:

Example Success Message:
‚úÖ OpenOps is up and running on Host: ip-172-31-6-179!
URL: http://<public-ip>
Username: admin@openops.com
Password: <generated-password>

Ì¥ê Security Notes
Only your current IP is allowed SSH/HTTP/S access via a security group.

You must verify your email for SNS to deliver notifications.

Make sure to rotate your SSH keys periodically and manage access securely.

Ì∑π Clean Up
To destroy all resources created by this configuration:
    terraform destroy

Ì∑† Troubleshooting
SSH Timeout?
Ensure your security group allows port 22 and your IP hasn't changed.

App not reachable?
Check EC2 user-data logs (/var/log/user-data.log) and OpenOps logs in the install path.
