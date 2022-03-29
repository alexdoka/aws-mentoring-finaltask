output "ec2_pool" {
  value = aws_security_group.ec2_pool.id
}
output "fargate_pool" {
  value = aws_security_group.fargate_pool.id
}
output "mysql" {
  value = aws_security_group.mysql.id
}
output "efs" {
  value = aws_security_group.efs.id
}
output "alb" {
  value = aws_security_group.alb.id
}
output "vpc_endpoint" {
  value = aws_security_group.vpc_endpoint.id
}
output "aws_iam_instance_profile_arn" {
  value = aws_iam_instance_profile.mailrole_profile.arn
}
output "mainrole_arn" {
  value = aws_iam_role.mainrole.arn
}

