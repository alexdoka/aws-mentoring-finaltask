resource "aws_efs_file_system" "efs" {
  creation_token   = "efs"
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"
  tags = {
    Name = "EFS"
  }
}

resource "aws_efs_mount_target" "efs-mt" {
  count           = length(var.private_nets)
  file_system_id  = aws_efs_file_system.efs.id
  subnet_id       = var.private_nets[count.index]
  security_groups = [var.efs_sg]
}