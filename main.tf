provider "aws" {
  region = "us-east-1" # Change to your desired region
}

# VPC Creation
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "MyVPC"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name = "MyIGW"
  }
}

# Public Subnet
resource "aws_subnet" "public_subnet" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true
  tags = {
    Name = "PublicSubnet"
  }
}

# Route Table and Route
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.my_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "PublicRouteTable"
  }
}

resource "aws_route_table_association" "rta" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

# Security Group for Web Server
resource "aws_security_group" "web_sg" {
  name_prefix = "web-sg"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "WebServerSG"
  }
}

# Launch Template
resource "aws_launch_template" "web_lt" {
  name = "web-server-lt"

  instance_type = "t2.micro"
  image_id      = "ami-0c94855ba95c71c99" # Replace with your preferred AMI

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.web_sg.name]
  }

  user_data = <<-EOF
              #!/bin/bash
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              EOF

  tags = {
    Name = "WebServerLT"
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "web_asg" {
  launch_template {
    id      = aws_launch_template.web_lt.id
    version = "$Latest"
  }

  min_size         = 1
  max_size         = 2
  desired_capacity = 1

  vpc_zone_identifier = [aws_subnet.public_subnet.id]
# other configuration settings
  tags = [
    {
      key                 = "Name"
      value               = "WebServer"
      propagate_at_launch = true
    }
  ]
}

# Load Balancer
resource "aws_lb" "web_lb" {
  name               = "web-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web_sg.id]
  subnets            = [aws_subnet.public_subnet.id]

  tags = {
    Name = "WebLoadBalancer"
  }
}

resource "aws_lb_target_group" "web_tg" {
  name     = "web-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.my_vpc.id
}

resource "aws_lb_listener" "web_listener" {
  load_balancer_arn = aws_lb.web_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}

# IAM User
resource "aws_iam_user" "web_user" {
  name = "web-restart-user"
}

resource "aws_iam_policy" "web_restart_policy" {
  name        = "WebRestartPolicy"
  description = "Policy to restart web server"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = ["ec2:RebootInstances"],
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_user_policy_attachment" "attach_policy" {
  user       = aws_iam_user.web_user.name
  policy_arn = aws_iam_policy.web_restart_policy.arn
}
