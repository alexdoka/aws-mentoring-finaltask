output "vpc_id" {
  value = aws_vpc.cloudx.id
}
output "public_nets" {
  value = aws_subnet.public[*].id
}
output "private_nets" {
  value = aws_subnet.private[*].id
}
output "db_nets" {
  value = aws_subnet.db[*].id
}