provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "dev_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.env}-vpc"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.dev_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "${var.env}-public-subnet"
  }
}

resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.${var.env}-vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "${var.env}-private-subnet"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.${var.env}-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.dev_igw.id
  }

  tags = {
    Name = "${var.env}-public-rt"
  }
}

resource "aws_route_table_association" "public_rt_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_internet_gateway" "dev_igw" {
  vpc_id = aws_vpc.${var.env}-vpc.id

  tags = {
    Name = "${var.env}-igw"
  }
}

resource "aws_instance" "web" {
  ami           = "ami-041e2ea9402c46c32"
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.public_subnet.id
  associate_public_ip_address = true

  tags = {
    Name = "${var.env}-WebServer"
  }
}

resource "aws_instance" "mysql" {
  count         = 3
  ami           = "ami-041e2ea9402c46c32"
  instance_type = "t3.small"
  subnet_id     = aws_subnet.private_subnet.id
  associate_public_ip_address = false

  tags = {
    Name = "${var.env}-MySQLServer-${count.index + 1}"
  }
}

resource "aws_vpc_peering_connection" "peer" {
  vpc_id        = aws_vpc.${var.env}-vpc.id
  peer_vpc_id   = var.peer_vpc_id
  auto_accept   = true

  tags = {
    Name = "${var.env}-peering"
  }
}

resource "aws_route" "peer_route" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = var.peer_cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
}
