provider "aws" {
  region     = var.region
  access_key = var.access_key
  secret_key = var.secret_key
}

# Create VPC
resource "aws_vpc" "tutorial_vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"
  enable_dns_support = true
  tags = {
    Name = "tutorial vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.tutorial_vpc.id
  tags = {
    Name = "IGW Tutorial"
  }
}

# Route Table public
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.tutorial_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "public route table"
  }
}

# Route Table private
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.tutorial_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.natgw.id
  }
  tags = {
    Name = "private-route-table"
  }
}


# Create Subnet Public
resource "aws_subnet" "tutorial_public_subnet" {
  vpc_id     = aws_vpc.tutorial_vpc.id
  cidr_block = "10.0.0.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "Tutorial Public Subnet"
  }
}


# Create Subnet Private - Will be created 2 subnets because of variable list
resource "aws_subnet" "tutorial_private_subnet" {
  count = length(var.subnet_prefix)
  vpc_id     = aws_vpc.tutorial_vpc.id
  cidr_block = var.subnet_prefix[count.index].cidr_block
  availability_zone = var.subnet_prefix[count.index].availability_zone
  tags = {
    Name = var.subnet_prefix[count.index].name
  }
}


# Associate Route Table Public with Subnet Public
resource "aws_route_table_association" "rtb_public_associate" {
  subnet_id      = aws_subnet.tutorial_public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

# Associate Route Table Private with Subnet Private
resource "aws_route_table_association" "rtb_private_associate" {
  count          =  length(var.subnet_prefix) 
  subnet_id      =  element(aws_subnet.tutorial_private_subnet.*.id, count.index)
  route_table_id =  aws_route_table.private_route_table.id
}


# Create Security Group Web Application
resource "aws_security_group" "tutorial_securitygroup" {
  name        = "tutorial-securitygroup"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.tutorial_vpc.id
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
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
    Name = "tutorial-securitygroup"
  }
}


# # Create a network interface with an ip in the subnet that was created
# resource "aws_network_interface" "web_server_nic" {
#   subnet_id       = aws_subnet.tutorial_public_subnet.id
#   private_ips     = ["10.0.0.50"]
#   security_groups = [aws_security_group.allow_web.id]
# }


# Create EIP
resource "aws_eip" "eipNatGat" {
   depends_on  = [aws_internet_gateway.igw]
}

# NAT Gateway
resource "aws_nat_gateway" "natgw" {
  allocation_id = aws_eip.eipNatGat.id
  subnet_id     = aws_subnet.tutorial_public_subnet.id
  tags = {
    Name = "gw NAT"
  }
}

# /* resource "aws_instance" "my-first-websever" {
#   ami = "ami-047a51fa27710816e"
#   #   ami = data.aws_ami.ubuntu.id
#   instance_type = "t2.micro"
#   tags = {
#     Name = "web-server"
#   }
# } */


output "IpPublic" {

  value = aws_eip.eipNatGat.public_ip
  
}