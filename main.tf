# Initialize Terraform
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

# Configure the AWS provider
provider "aws" {
  region = "us-east-1"
}

# Creating a VPC
resource "aws_vpc" "proj-vpc" {
  cidr_block = "10.0.0.0/16"
}

# Create an Internet Gateway
resource "aws_internet_gateway" "proj-ig" {
  vpc_id = aws_vpc.proj-vpc.id
  tags = {
    Name = "gateway1"
  }
}

# Setting up the route table
resource "aws_route_table" "proj-rt" {
  vpc_id = aws_vpc.proj-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.proj-ig.id
  }

  tags = {
    Name = "rt1"
  }
}

# Setting up the subnet
resource "aws_subnet" "proj-subnet" {
  vpc_id            = aws_vpc.proj-vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"  # Use a valid availability zone

  tags = {
    Name = "subnet1"
  }
}

# Associating the subnet with the route table
resource "aws_route_table_association" "proj-rt-sub-assoc" {
  subnet_id      = aws_subnet.proj-subnet.id
  route_table_id = aws_route_table.proj-rt.id
}

# Creating a Security Group
resource "aws_security_group" "proj-sg" {
  name        = "proj-sg"
  description = "Enable web traffic for the project"
  vpc_id      = aws_vpc.proj-vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP traffic"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS traffic"
  }
 ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Replace with your Jenkins server IP
  }

  ingress {
    from_port   = 65000
    to_port     = 65000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow traffic on port 65000"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "proj-sg1"
  }
}

# Creating a new network interface
resource "aws_network_interface" "proj-ni" {
  subnet_id       = aws_subnet.proj-subnet.id
  private_ips     = ["10.0.1.10"]
  security_groups  = [aws_security_group.proj-sg.id]
}

# Attaching an Elastic IP to the network interface
resource "aws_eip" "proj-eip" {
  vpc                   = true
  network_interface     = aws_network_interface.proj-ni.id
  associate_with_private_ip = "10.0.1.10"
}

# Creating an Ubuntu EC2 instance
resource "aws_instance" "Prod-Server" {
  ami               = "ami-0a0e5d9c7acc336f1"  # Ensure this is a valid AMI for us-east-1
  instance_type     = "t2.micro"
  availability_zone = "us-east-1a"  # Use a valid availability zone
  key_name          = "Key-Pair-Jenkins"

  network_interface {
    device_index          = 0
    network_interface_id  = aws_network_interface.proj-ni.id
  }

  user_data = <<-EOF
    #!/bin/bash
    sudo apt-get update -y
  EOF

  tags = {
    Name = "Prod-Server"
  }
}
