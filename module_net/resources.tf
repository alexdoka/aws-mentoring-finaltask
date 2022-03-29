locals {
  net_prefix = regex("\\d{1,3}.\\d{1,3}.", var.vpc_cidr_block)
}

resource "aws_vpc" "cloudx" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "cloudx"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.cloudx.id

  tags = {
    Name = "cloudx-igw"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "public" {
  count                   = var.number_networks
  vpc_id                  = aws_vpc.cloudx.id
  map_public_ip_on_launch = true
  cidr_block              = "${local.net_prefix}${count.index + 1}.0/24"
  availability_zone_id    = data.aws_availability_zones.available.zone_ids[count.index]

  tags = {
    Name = "public_${count.index + 1}"
  }
}

resource "aws_subnet" "private" {
  count                = var.number_networks
  vpc_id               = aws_vpc.cloudx.id
  cidr_block           = "${local.net_prefix}1${count.index + 1}.0/24"
  availability_zone_id = data.aws_availability_zones.available.zone_ids[count.index]

  tags = {
    Name = "private_${count.index + 1}"
  }
}

resource "aws_subnet" "db" {
  count                = var.number_networks
  vpc_id               = aws_vpc.cloudx.id
  cidr_block           = "${local.net_prefix}2${count.index + 1}.0/24"
  availability_zone_id = data.aws_availability_zones.available.zone_ids[count.index]

  tags = {
    Name = "private_db_${count.index + 1}"
  }
}

resource "aws_route_table" "inet" {
  vpc_id = aws_vpc.cloudx.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "public_rt"
  }
}

resource "aws_route_table_association" "public" {
  count = var.number_networks

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.inet.id
}

resource "aws_eip" "nat_gateway" {
  count = var.number_networks
  vpc   = true
}

resource "aws_nat_gateway" "priv" {
  count         = var.number_networks
  allocation_id = aws_eip.nat_gateway[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "nat-gateway-${count.index + 1}"
  }
}

resource "aws_route_table" "private" {
  count  = var.number_networks
  vpc_id = aws_vpc.cloudx.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.priv[count.index].id
  }

  tags = {
    Name = "private_rt_${count.index + 1}"
  }
}

resource "aws_route_table_association" "private" {
  count = var.number_networks

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}