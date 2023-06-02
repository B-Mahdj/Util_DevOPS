# Set the AWS provider with the desired region
provider "aws" {
  region = var.aws_region
}

# Define variables for the CIDRs of the VPC and subnets
variable "aws_region" {
  default = "us-east-1"
}

variable "vpc_cidr" {
  default = "172.16.0.0/16"
}

variable "public_subnet_cidr" {
  default = "172.16.1.0/24"
}

variable "private_subnet_cidr" {
  default = "172.16.2.0/24"
}

variable "instance_type" {
  default = "t2.micro"
}

########################
# Network
########################
# Create the VPC
resource "aws_vpc" "tp_devops_vpc" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = "TP_DevOps"
  }
}

# Create the public subnet
resource "aws_subnet" "tp_devops_public_subnet" {
  vpc_id                  = aws_vpc.tp_devops_vpc.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true
  tags = {
    Name = "TP_DevOps_Public"
  }
}

# Create the private subnet
resource "aws_subnet" "tp_devops_private_subnet" {
  vpc_id            = aws_vpc.tp_devops_vpc.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = "${var.aws_region}a"
  tags = {
    Name = "TP_DevOps_Private"
  }
}

# Create an internet gateway
resource "aws_internet_gateway" "tp_devops_igw" {
  vpc_id = aws_vpc.tp_devops_vpc.id
  tags = {
    Name = "TP_DevOps"
  }
}

# Create a route table for the public subnets
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.tp_devops_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.tp_devops_igw.id
  }
  tags = {
    Name = "TP_DevOps_Public"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.tp_devops_public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_security_group" "public" {
  name_prefix = "public-"
  vpc_id      = aws_vpc.tp_devops_vpc.id

  # allow SSH access from your IP
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["81.65.90.58/32"]
  }
  
  # allow external access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "public"
  }
}

########################
# Instances
########################
data "aws_ami" "webapp_ami" {
  most_recent = true
  owners      = ["self"]  
  filter {
    name   = "name"
    values = ["WebApp-11_05_2023-07_55"] # Name of the AMI to use 
  }
}

# Create a web server instance
resource "aws_instance" "web_server" {
  ami                         = data.aws_ami.webapp_ami.id
  instance_type               = var.instance_type
  key_name                    = "vockey"
  iam_instance_profile        = "LabInstanceProfile"
  subnet_id                   = aws_subnet.tp_devops_public_subnet.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.public.id]
  tags = {
    Name = "WebServer"
  }
  user_data = <<-EOT
#!/bin/bash
snap start amazon-ssm-agent
EOT
  user_data_replace_on_change = true
}
