/**
 * # VPC Module
 *
 * Creates a production-ready VPC with public/private subnets, NAT gateways,
 * Internet gateway, and VPC endpoints for secure AWS service access.
 *
 * Security features:
 * - Multi-AZ subnets for high availability
 * - NAT gateways for private subnet egress
 * - VPC endpoints for S3 and DynamoDB (Gateway endpoints - no data charges)
 * - DNS hostnames and resolution enabled
 * - VPC Flow Logs integration ready
 */

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  # Calculate subnet CIDRs
  # Public: first az_count /24 blocks
  # Private: next az_count /24 blocks  
  # Database: next az_count /24 blocks
  public_subnets = [
    for i, az in local.azs :
    cidrsubnet(var.vpc_cidr, var.subnet_newbits, i)
  ]

  private_subnets = [
    for i, az in local.azs :
    cidrsubnet(var.vpc_cidr, var.subnet_newbits, i + var.az_count)
  ]

  database_subnets = var.create_database_subnets ? [
    for i, az in local.azs :
    cidrsubnet(var.vpc_cidr, var.subnet_newbits, i + (var.az_count * 2))
  ] : []

  # NAT gateway count based on configuration
  nat_gateway_count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(local.azs)) : 0
}

# -----------------------------------------------------------------------------
# VPC
# -----------------------------------------------------------------------------

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name = var.name
  })
}

# -----------------------------------------------------------------------------
# Internet Gateway
# -----------------------------------------------------------------------------

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${var.name}-igw"
  })
}

# -----------------------------------------------------------------------------
# Public Subnets
# -----------------------------------------------------------------------------

resource "aws_subnet" "public" {
  count = length(local.azs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.public_subnets[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = var.map_public_ip_on_launch

  tags = merge(var.tags, {
    Name = "${var.name}-public-${local.azs[count.index]}"
    Tier = "public"
  })
}

# -----------------------------------------------------------------------------
# Private Subnets
# -----------------------------------------------------------------------------

resource "aws_subnet" "private" {
  count = length(local.azs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = local.private_subnets[count.index]
  availability_zone = local.azs[count.index]

  tags = merge(var.tags, {
    Name = "${var.name}-private-${local.azs[count.index]}"
    Tier = "private"
  })
}

# -----------------------------------------------------------------------------
# Database Subnets (isolated)
# -----------------------------------------------------------------------------

resource "aws_subnet" "database" {
  count = var.create_database_subnets ? length(local.azs) : 0

  vpc_id            = aws_vpc.main.id
  cidr_block        = local.database_subnets[count.index]
  availability_zone = local.azs[count.index]

  tags = merge(var.tags, {
    Name = "${var.name}-database-${local.azs[count.index]}"
    Tier = "database"
  })
}

resource "aws_db_subnet_group" "database" {
  count = var.create_database_subnets ? 1 : 0

  name        = var.name
  description = "Database subnet group for ${var.name}"
  subnet_ids  = aws_subnet.database[*].id

  tags = merge(var.tags, {
    Name = "${var.name}-db-subnet-group"
  })
}

# -----------------------------------------------------------------------------
# Elastic IPs for NAT Gateways
# -----------------------------------------------------------------------------

resource "aws_eip" "nat" {
  count  = local.nat_gateway_count
  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.name}-nat-eip-${count.index + 1}"
  })

  depends_on = [aws_internet_gateway.main]
}

# -----------------------------------------------------------------------------
# NAT Gateways
# -----------------------------------------------------------------------------

resource "aws_nat_gateway" "main" {
  count = local.nat_gateway_count

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(var.tags, {
    Name = "${var.name}-nat-${local.azs[count.index]}"
  })

  depends_on = [aws_internet_gateway.main]
}

# -----------------------------------------------------------------------------
# Route Tables
# -----------------------------------------------------------------------------

# Public route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${var.name}-public-rt"
  })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private route tables
resource "aws_route_table" "private" {
  count = var.single_nat_gateway ? 1 : length(local.azs)

  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = var.single_nat_gateway ? "${var.name}-private-rt" : "${var.name}-private-rt-${local.azs[count.index]}"
  })
}

resource "aws_route" "private_nat" {
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(local.azs)) : 0

  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[var.single_nat_gateway ? 0 : count.index].id
}

resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[var.single_nat_gateway ? 0 : count.index].id
}

# Database route tables (no internet access)
resource "aws_route_table" "database" {
  count = var.create_database_subnets ? 1 : 0

  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${var.name}-database-rt"
  })
}

resource "aws_route_table_association" "database" {
  count = var.create_database_subnets ? length(local.azs) : 0

  subnet_id      = aws_subnet.database[count.index].id
  route_table_id = aws_route_table.database[0].id
}

# -----------------------------------------------------------------------------
# VPC Endpoints (Gateway - no charges)
# -----------------------------------------------------------------------------

resource "aws_vpc_endpoint" "s3" {
  count = var.enable_s3_endpoint ? 1 : 0

  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids = concat(
    [aws_route_table.public.id],
    aws_route_table.private[*].id,
    var.create_database_subnets ? aws_route_table.database[*].id : []
  )

  tags = merge(var.tags, {
    Name = "${var.name}-s3-endpoint"
  })
}

resource "aws_vpc_endpoint" "dynamodb" {
  count = var.enable_dynamodb_endpoint ? 1 : 0

  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids = concat(
    [aws_route_table.public.id],
    aws_route_table.private[*].id,
    var.create_database_subnets ? aws_route_table.database[*].id : []
  )

  tags = merge(var.tags, {
    Name = "${var.name}-dynamodb-endpoint"
  })
}
