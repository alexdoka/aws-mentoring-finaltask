resource "aws_db_subnet_group" "ghost" {
  name        = "ghost"
  description = "ghost database subnet group"
  subnet_ids  = var.db_nets

  tags = {
    Name = "ghost subnet group"
  }
}

data "aws_ssm_parameter" "rds_password" {
  name = var.db_password_path
}

resource "aws_db_instance" "ghost" {
  allocated_storage      = 20
  storage_type           = "gp2"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t2.micro"
  name                   = "gh_db"
  username               = "gh_user"
  password               = data.aws_ssm_parameter.rds_password.value
  vpc_security_group_ids = [var.mysql_sg]
  db_subnet_group_name   = aws_db_subnet_group.ghost.name
  skip_final_snapshot    = true
}