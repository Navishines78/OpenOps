terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region = var.region
}

data "external" "my_ip" {
  program = ["bash", "-c", "curl -s https://ipinfo.io/json"]
}

resource "aws_key_pair" "ssh-keys" {
  key_name   = "my-key-pair"
  public_key = file("~/.ssh/my_key_pair.pub")
}

resource "aws_security_group" "allow_my_ip" {
  name        = "allow-my-ip"
  description = "this security_group allows my-ip for SSH and HTTP/S requests"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${data.external.my_ip.result["ip"]}/32"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["${data.external.my_ip.result["ip"]}/32"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["${data.external.my_ip.result["ip"]}/32"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    name = "sg-allow-my-ip"
  }
}

resource "aws_sns_topic" "openops_status" {
  name = "openops-status-topic"
}

resource "aws_sns_topic_subscription" "email_sub" {
  topic_arn                       = aws_sns_topic.openops_status.arn
  protocol                        = "email"
  endpoint                        = var.email_address
  confirmation_timeout_in_minutes = 60
}

# IAM Role for EC2 to Publish to SNS
resource "aws_iam_role" "ec2_role" {
  name = "ec2-openops-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "sns_publish_policy" {
  name = "ec2-sns-publish-policy"
  role = aws_iam_role.ec2_role.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = "sns:Publish",
      Resource = aws_sns_topic.openops_status.arn
    }]
  })
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2-openops-profile"
  role = aws_iam_role.ec2_role.name
}
resource "aws_instance" "temp_instance" {
  ami                         = var.instance_config["ubuntu_instance_22_04"].ami
  instance_type               = var.instance_config["ubuntu_instance_22_04"].instance_type
  key_name                    = aws_key_pair.ssh-keys.key_name
  associate_public_ip_address = true
  security_groups             = [aws_security_group.allow_my_ip.name]
  iam_instance_profile        = aws_iam_instance_profile.ec2_instance_profile.name
  depends_on                  = [aws_sns_topic.openops_status]
  # user_data                   = templatefile("${path.module}/user-data.sh.tmpl", { installation_path = "/home/ubuntu/openops" })
  user_data = templatefile("${path.module}/user-data.sh.tmpl", {
    installation_path = "/home/ubuntu/openops"
    region            = var.region
    sns_topic_arn     = aws_sns_topic.openops_status.arn
  })



  root_block_device {
    volume_size           = var.volume_size
    volume_type           = var.volume_type
    delete_on_termination = true
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'Waiting for OpenOps to complete...'",
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do sleep 5; done",
      "echo 'OpenOps setup completed.'",

      # Install AWS CLI (if needed again)
      "sudo apt-get update -y",
      "sudo apt-get install -y awscli",

      # Get Credentials 
      "INSTALL_DIR=\"/home/ubuntu/openops\"",
      "ENV_FILE=\"$INSTALL_DIR/.env\"",

      "PUBLIC_URL=$(grep '^OPS_PUBLIC_URL=' $ENV_FILE | cut -d= -f2-)",
      "ADMIN_USER=$(grep '^OPS_OPENOPS_ADMIN_EMAIL=' $ENV_FILE | cut -d= -f2-)",
      "ADMIN_PASSWORD=$(grep '^OPS_OPENOPS_ADMIN_PASSWORD=' $ENV_FILE | cut -d= -f2-)",

      # Check HTTP status
      "HTTP_STATUS=$(curl -o /dev/null -s -w \"%%{http_code}\" http://localhost)",

      "if [ \"$HTTP_STATUS\" -eq 200 ]; then",
      # "  MESSAGE=\"✅ OpenOps is up and running on Host:$(hostname)!\\nURL: $PUBLIC_URL\\nUsername: $ADMIN_USER\\nPassword: $ADMIN_PASSWORD\"",
      "  MESSAGE=$(cat <<EOF",
      "✅ OpenOps is up and running on Host: $(hostname)!",
      "URL: $PUBLIC_URL",
      "Username: $ADMIN_USER",
      "Password: $ADMIN_PASSWORD",
      "EOF",
      "  )",
      "  SUBJECT=\"OpenOps Installation: Success\"",
      "else",
      "  MESSAGE=\"❌ OpenOps returned HTTP $HTTP_STATUS on $(hostname). Check logs.\"",
      "  SUBJECT=\"OpenOps Installation: Failure\"",
      "fi",

      # Publish to SNS
      "aws sns publish --region ${var.region} --topic-arn ${aws_sns_topic.openops_status.arn} --message \"$MESSAGE\" --subject \"$SUBJECT\""

    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/my_key_pair")
      host        = self.public_ip
    }
  }
  tags = {
    Name = "temp-instance"
  }
}

