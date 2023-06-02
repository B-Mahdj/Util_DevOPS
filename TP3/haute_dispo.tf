# Déclaration du fournisseur AWS
provider "aws" {
  region = "us-east-1"
}

# Création du VPC
resource "aws_vpc" "web_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "WebVpc"
  }
}

# Création des subnets publics
resource "aws_subnet" "web_public_1" {
  vpc_id                  = aws_vpc.web_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "WebPublic-1"
  }
}

resource "aws_subnet" "web_public_2" {
  vpc_id                  = aws_vpc.web_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
  tags = {
    Name = "WebPublic-2"
  }
}

# Création des subnets privés
resource "aws_subnet" "web_private_1" {
  vpc_id                  = aws_vpc.web_vpc.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "us-east-1a"
  tags = {
    Name = "WebPrivate-1"
  }
}

resource "aws_subnet" "web_private_2" {
  vpc_id                  = aws_vpc.web_vpc.id
  cidr_block              = "10.0.4.0/24"
  availability_zone       = "us-east-1b"
  tags = {
    Name = "WebPrivate-2"
  }
}

# Création des routes
resource "aws_route_table" "web_public_route" {
  vpc_id = aws_vpc.web_vpc.id
}

resource "aws_route" "web_public_route_internet" {
  route_table_id         = aws_route_table.web_public_route.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.web_igw.id
}

resource "aws_route_table_association" "web_public_route_association_1" {
  subnet_id      = aws_subnet.web_public_1.id
  route_table_id = aws_route_table.web_public_route.id
}

resource "aws_route_table_association" "web_public_route_association_2" {
  subnet_id      = aws_subnet.web_public_2.id
  route_table_id = aws_route_table.web_public_route.id
}

resource "aws_route_table" "web_private_route" {
  vpc_id = aws_vpc.web_vpc.id
}

resource "aws_route_table_association" "web_private_route_association_1" {
  subnet_id      = aws_subnet.web_private_1.id
  route_table_id = aws_route_table.web_private_route.id
}

resource "aws_route_table_association" "web_private_route_association_2" {
  subnet_id      = aws_subnet.web_private_2.id
  route_table_id = aws_route_table.web_private_route.id
}

# Création de l'Internet Gateway
resource "aws_internet_gateway" "web_igw" {
  vpc_id = aws_vpc.web_vpc.id
}

# Création du Load Balancer
resource "aws_lb" "web_lb" {
  name               = "web-lb"
  internal           = false
  load_balancer_type = "application"
  subnets            = [aws_subnet.web_public_1.id, aws_subnet.web_public_2.id]
}

# Création du Launch Configuration
resource "aws_launch_configuration" "web_lc" {
  name          = "web-lc"
  image_id      = "WebApp-11_05_2023-07_55"
  instance_type = "t2.micro"

  security_groups = [
    aws_security_group.web_sg.id,
  ]

  lifecycle {
    create_before_destroy = true
  }
}

# Création du Security Group
resource "aws_security_group" "web_sg" {
  name        = "web-sg"
  description = "Security group for web instances"

  vpc_id = aws_vpc.web_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Création de l'Auto Scaling Group
resource "aws_autoscaling_group" "web_asg" {
  name                      = "web-asg"
  min_size                  = 2
  max_size                  = 4
  desired_capacity          = 2
  launch_configuration      = aws_launch_configuration.web_lc.name
  vpc_zone_identifier       = [aws_subnet.web_private_1.id, aws_subnet.web_private_2.id]
  health_check_type         = "ELB"
  health_check_grace_period = 300
  target_group_arns         = [aws_lb_target_group.web_tg.arn]

  tag {
    key                 = "Name"
    value               = "WebServer"
    propagate_at_launch = true
  }
}

# Création du Target Group
resource "aws_lb_target_group" "web_tg" {
  name        = "web-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.web_vpc.id
  target_type = "instance"
}

# Association du Target Group avec le Load Balancer
resource "aws_lb_target_group_attachment" "web_tg_attachment_1" {
  target_group_arn = aws_lb_target_group.web_tg.arn
  target_id        = aws_instance.web_instances[0].id
  port             = 80
}

resource "aws_lb_target_group_attachment" "web_tg_attachment_2" {
  target_group_arn = aws_lb_target_group.web_tg.arn
  target_id        = aws_instance.web_instances[1].id
  port             = 80
}

# Création des instances EC2
resource "aws_instance" "web_instances" {
  count                  = 2
  ami                    = "WebApp-11_05_2023-07_55"
  instance_type          = "t2.micro"
  security_groups        = [aws_security_group.web_sg.id]
  subnet_id              = aws_subnet.web_private_1.id
  associate_public_ip_address = false
  key_name               = "Keypair_Nat_JumpHost"

  lifecycle {
    create_before_destroy = true
  }
}
