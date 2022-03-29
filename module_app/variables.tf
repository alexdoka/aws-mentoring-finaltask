variable "vpc_id" {}
variable "alb_sg" {}
variable "public_nets" {}
variable "private_nets" {}
variable "iam_instance_profile_arn" {}
variable "mainrole_arn" {
  
}
variable "ec2_type" {
  default = "t2.micro"
}
variable "ec2_pool_sg" {}
variable "rds_endpoint" {}
variable "efs_id" {}
variable "db_password_path" {}
