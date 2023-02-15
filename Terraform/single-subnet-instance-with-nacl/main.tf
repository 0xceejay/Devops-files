terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "4.54.0"
    }
  }
}

# Configure the AWS provider
provider "aws" {
  region = "us-east-1"
}

# Variables
variable "cidr_block" {}
variable "subnet_cidr_block" {}
variable "home_ip" {}
variable "ssh_key" {}

# Create a VPC
resource "aws_vpc" "new-vpc" {
  cidr_block = var.cidr_block
  tags = {
    "Name" = "single-subnet-vpc"
  }
}

# Create public subnet
resource "aws_subnet" "only_public_subnet" {
  vpc_id = aws_vpc.new-vpc.id
  cidr_block = var.subnet_cidr_block
  availability_zone = "us-east-1a"

  tags = {
    Name = "public-subnet"
  }
}

# Create an internet gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.new-vpc.id

  tags = {
    "Name" = "my_internet_gateway"
  }
}

# Create a route table
resource "aws_route_table" "rtb" {
  vpc_id = aws_vpc.new-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id   
  }

  tags = {
    "Name" = "my-route-table"
  }
}

# Create route table association
resource "aws_route_table_association" "rtba" {
  subnet_id = aws_subnet.only_public_subnet.id
  route_table_id = aws_route_table.rtb.id
}

resource "aws_default_network_acl" "default-acl" {
  default_network_acl_id = aws_vpc.new-vpc.default_network_acl_id

  # Allows inbound HTTP traffic from any IPv4 address
  ingress {
    protocol = "tcp"
    rule_no = 100
    action = "allow"
    cidr_block = "0.0.0.0/0"
    from_port = 80
    to_port = 80
  }

  # Allows inbound HTTPS traffic from any IPv4 address
  ingress {
    protocol = "tcp"
    rule_no = 110
    action = "allow"
    cidr_block = "0.0.0.0/0"
    from_port = 443
    to_port = 443
  }

  # Allows inbound SSH traffic from any personal ip
  ingress {
    protocol = "tcp"
    rule_no = 120
    action = "allow"
    cidr_block = var.home_ip
    from_port = 22
    to_port = 22
  }

  # Allows inbound RDP traffic from personal ip
  ingress {
    protocol = "tcp"
    rule_no = 130
    action = "allow"
    cidr_block = var.home_ip
    from_port = 3389
    to_port = 3389
  }

  # Allows inbound return traffic from hosts on the internet that are responding to requests originating in the subnet
  ingress {
    protocol = "tcp"
    rule_no = 140
    action = "allow"
    cidr_block = "0.0.0.0/0"
    # This range is an example only.
    from_port = 32768
    to_port = 65535
  }


  # Allows outbound HTTP traffic from the subnet to the internet.
  egress {
    protocol = "tcp"
    rule_no = 100
    action = "allow"
    cidr_block = "0.0.0.0/0"
    from_port = 80
    to_port = 80
  }

  # Allows outbound HTTPS traffic from the subnet to the internet.
  egress {
    protocol = "tcp"
    rule_no = 110
    action = "allow"
    cidr_block = "0.0.0.0/0"
    from_port = 443
    to_port = 443
  }

  # Allows outbound responses to clients on the internet (for example, serving webpages to people visiting the web servers in the subnet).
  egress {
    protocol = "tcp"
    rule_no = 120
    action = "allow"
    cidr_block = "0.0.0.0/0"
    # This range is an example only. 
    from_port = 32768
    to_port = 65535
  }

  tags = {
    "Name" = "default-network-acl"
  }
}

# Create ec2 instance on subnet
resource "aws_instance" "my_ec2_instance" {
  # Amazon linux 2
  ami = "ami-0dfcb1ef8550277af"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.only_public_subnet.id
  key_name = var.ssh_key

  tags = {
    "Name" = "my_ec2"
  }
}

# Output vpc id on terminal
output "vpc_id" {
  value = aws_vpc.new-vpc.id
}
