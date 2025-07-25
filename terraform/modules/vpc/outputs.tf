output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "VPC CIDR block"
  value       = aws_vpc.this.cidr_block
}

output "private_subnets" {
  description = "Private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "public_subnets" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "database_subnets" {
  description = "Database subnet IDs"
  value       = aws_subnet.database[*].id
}

output "elasticache_subnets" {
  description = "ElastiCache subnet IDs"
  value       = aws_subnet.elasticache[*].id
}

output "intra_subnets" {
  description = "Intra subnet IDs"
  value       = aws_subnet.intra[*].id
}

output "internet_gateway_id" {
  description = "Internet Gateway ID"
  value       = try(aws_internet_gateway.this[0].id, null)
}

output "nat_gateway_ids" {
  description = "NAT Gateway IDs"
  value       = aws_nat_gateway.this[*].id
}

output "nat_public_ips" {
  description = "NAT Gateway public IPs"
  value       = aws_eip.nat[*].public_ip
}

output "private_route_table_ids" {
  description = "Private route table IDs"
  value       = aws_route_table.private[*].id
}

output "public_route_table_ids" {
  description = "Public route table IDs"
  value       = aws_route_table.public[*].id
}

output "database_route_table_ids" {
  description = "Database route table IDs"
  value       = aws_route_table.database[*].id
}

output "elasticache_route_table_ids" {
  description = "ElastiCache route table IDs"
  value       = aws_route_table.elasticache[*].id
}

output "intra_route_table_ids" {
  description = "Intra route table IDs"
  value       = aws_route_table.intra[*].id
}

output "s3_vpc_endpoint_id" {
  description = "S3 VPC Endpoint ID"
  value       = try(aws_vpc_endpoint.s3[0].id, null)
}