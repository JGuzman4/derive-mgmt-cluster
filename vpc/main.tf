data "aws_availability_zones" "available" {}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
}

locals {
  private_subnets   = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 4, k)]
  public_subnets    = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k + 48)]
  intra_subnets     = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k + 52)]
  nat_gateway_ips   = try(aws_eip.nat[*].id, [])
  nat_gateway_count = 1
}

resource "aws_default_network_acl" "this" {
  default_network_acl_id = aws_vpc.this.default_network_acl_id

  # subnet_ids is using lifecycle ignore_changes, so it is not necessary to list
  # any explicitly. See https://github.com/terraform-aws-modules/terraform-aws-vpc/issues/736.
  subnet_ids = null

  dynamic "ingress" {
    for_each = var.default_network_acl_ingress
    content {
      action          = ingress.value.action
      cidr_block      = lookup(ingress.value, "cidr_block", null)
      from_port       = ingress.value.from_port
      icmp_code       = lookup(ingress.value, "icmp_code", null)
      icmp_type       = lookup(ingress.value, "icmp_type", null)
      ipv6_cidr_block = lookup(ingress.value, "ipv6_cidr_block", null)
      protocol        = ingress.value.protocol
      rule_no         = ingress.value.rule_no
      to_port         = ingress.value.to_port
    }
  }
  dynamic "egress" {
    for_each = var.default_network_acl_egress
    content {
      action          = egress.value.action
      cidr_block      = lookup(egress.value, "cidr_block", null)
      from_port       = egress.value.from_port
      icmp_code       = lookup(egress.value, "icmp_code", null)
      icmp_type       = lookup(egress.value, "icmp_type", null)
      ipv6_cidr_block = lookup(egress.value, "ipv6_cidr_block", null)
      protocol        = egress.value.protocol
      rule_no         = egress.value.rule_no
      to_port         = egress.value.to_port
    }
  }

  tags = merge(
    { "Name" = var.vpc_name },
    var.tags,
  )

  lifecycle {
    ignore_changes = [subnet_ids]
  }
}

resource "aws_default_route_table" "default" {
  default_route_table_id = aws_vpc.this.default_route_table_id

  tags = merge(
    { "Name" = var.vpc_name },
    var.tags,
  )
}

resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(
    { "Name" = var.vpc_name },
    var.tags,
  )
}

resource "aws_eip" "nat" {
  vpc = true
  tags = merge(
    { "Name" = var.vpc_name },
    var.tags,
  )
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags = merge(
    { "Name" = var.vpc_name },
    var.tags,
  )
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = merge(
    { "Name" = var.vpc_name },
    var.tags,
  )

  depends_on = [aws_internet_gateway.this]
}

resource "aws_route" "private_nat_gateway" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this.id

  timeouts {
    create = "5m"
  }
}

resource "aws_route" "public_internet_gateway" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id

  timeouts {
    create = "5m"
  }
}

resource "aws_route_table" "intra" {
  vpc_id = aws_vpc.this.id
  tags = merge(
    { "Name" = "${var.vpc_name}-intra" },
    var.tags,
  )
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  tags = merge(
    { "Name" = "${var.vpc_name}-private" },
    var.tags,
  )
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags = merge(
    { "Name" = "${var.vpc_name}-public" },
    var.tags,
  )
}

resource "aws_route_table_association" "intra" {
  count          = length(local.intra_subnets)
  subnet_id      = element(aws_subnet.intra[*].id, count.index)
  route_table_id = element(aws_route_table.intra[*].id, 0)
}

resource "aws_route_table_association" "private" {
  count          = length(local.private_subnets)
  subnet_id      = element(aws_subnet.private[*].id, count.index)
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "public" {
  count          = length(local.public_subnets)
  subnet_id      = element(aws_subnet.public[*].id, count.index)
  route_table_id = aws_route_table.public.id
}

resource "aws_subnet" "intra" {
  count = length(local.intra_subnets)

  vpc_id                          = aws_vpc.this.id
  cidr_block                      = local.intra_subnets[count.index]
  availability_zone               = length(regexall("^[a-z]{2}-", element(local.azs, count.index))) > 0 ? element(local.azs, count.index) : null
  availability_zone_id            = length(regexall("^[a-z]{2}-", element(local.azs, count.index))) == 0 ? element(local.azs, count.index) : null
  assign_ipv6_address_on_creation = false

  tags = merge(
    { Name = format("${var.vpc_name}-intra-%s", element(local.azs, count.index)) },
    var.tags,
  )
}
resource "aws_subnet" "private" {
  count = length(local.private_subnets)

  vpc_id                          = aws_vpc.this.id
  cidr_block                      = local.private_subnets[count.index]
  availability_zone               = length(regexall("^[a-z]{2}-", element(local.azs, count.index))) > 0 ? element(local.azs, count.index) : null
  availability_zone_id            = length(regexall("^[a-z]{2}-", element(local.azs, count.index))) == 0 ? element(local.azs, count.index) : null
  assign_ipv6_address_on_creation = false

  tags = merge(
    {
      Name                              = format("${var.vpc_name}-private-%s", element(local.azs, count.index))
      "kubernetes.io/role/internal-elb" = 1
    },
    var.tags,
  )
}
resource "aws_subnet" "public" {
  count = length(local.public_subnets)

  vpc_id                          = aws_vpc.this.id
  cidr_block                      = element(concat(local.public_subnets, [""]), count.index)
  availability_zone               = length(regexall("^[a-z]{2}-", element(local.azs, count.index))) > 0 ? element(local.azs, count.index) : null
  availability_zone_id            = length(regexall("^[a-z]{2}-", element(local.azs, count.index))) == 0 ? element(local.azs, count.index) : null
  map_public_ip_on_launch         = true
  assign_ipv6_address_on_creation = false

  tags = merge(
    {
      Name                     = format("${var.vpc_name}-public-%s", element(local.azs, count.index))
      "kubernetes.io/role/elb" = 1
    },
    var.tags,
  )
}
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  instance_tenancy     = "default"
  enable_dns_hostnames = false
  enable_dns_support   = true

  tags = merge(
    { "Name" = var.vpc_name },
    var.tags,
  )
}
