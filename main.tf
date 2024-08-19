variable "ssh_ingress_cidr" {
  description = "CIDR block for SSH ingress"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.xlarge"
}

variable "root_volume_size" {
  description = "Size of the EC2 root volume in GB"
  type        = number
  default     = 50
}

variable "key_pair_name" {
  description = "Name of the AWS key pair to use"
  type        = string
}

variable "resource_prefix" {
  description = "Value to prefix resources with"
  type        = string
}

provider "aws" {
}

# Data source for latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_key_pair" "existing" {
  key_name = var.key_pair_name
}

resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow inbound SSH traffic from specific IP"

  ingress {
    description = "SSH from specific IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_ingress_cidr]
  }

  ingress {
    description = "HTTP for kURL proxy"
    from_port   = 8800
    to_port     = 8800
    protocol    = "tcp"
    cidr_blocks = [var.ssh_ingress_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_ssh_specific_ip"
  }
}

resource "aws_s3_bucket" "kots" {
  bucket        = "${var.resource_prefix}-kots"
  force_destroy = true
}

resource "aws_iam_policy" "ec2_s3_policy" {
  name        = "EC2S3Policy"
  path        = "/"
  description = "IAM policy for EC2 and S3 access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeVolumes",
          "ec2:DescribeSnapshots",
          "ec2:CreateTags",
          "ec2:CreateVolume",
          "ec2:CreateSnapshot",
          "ec2:DeleteSnapshot"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:PutObject",
          "s3:AbortMultipartUpload",
          "s3:ListMultipartUploadParts"
        ]
        Resource = [
          "${aws_s3_bucket.kots.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.kots.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role" "ec2_s3_access_role" {
  name = "EC2S3AccessRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "s3_policy_attach" {
  policy_arn = aws_iam_policy.ec2_s3_policy.arn
  role       = aws_iam_role.ec2_s3_access_role.name
}

resource "aws_iam_instance_profile" "ec2_s3_profile" {
  name = "EC2S3Profile"
  role = aws_iam_role.ec2_s3_access_role.name
}

resource "aws_instance" "vm" {
  ami                  = data.aws_ami.amazon_linux_2.id
  instance_type        = var.instance_type
  key_name             = data.aws_key_pair.existing.key_name
  iam_instance_profile = aws_iam_instance_profile.ec2_s3_profile.name

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp2"
  }

  vpc_security_group_ids = [aws_security_group.allow_ssh.id]

  tags = {
    Name = "${var.resource_prefix}-vm"
  }
}

output "kots_app" {
  description = "KOTS admin console"
  value       = "http://${aws_instance.vm.public_ip}:8800"
}

# Output for SSH access
output "ssh_command" {
  description = "SSH command to connect to the EC2 instance"
  value       = "ssh -i <path_to>.pem ec2-user@${aws_instance.vm.public_ip}"
}

output "ssh_tunnel" {
  description = "Access the app via SSH tunnel"
  value       = "ssh -i <path_to>.pem -L 8800:localhost:8800 ec2-user@${aws_instance.vm.public_ip}"
}
