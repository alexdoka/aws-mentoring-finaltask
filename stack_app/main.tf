terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
    null = {
      source = "hashicorp/null"
      version = "3.1.1"
    }    
  }
}

provider "aws" {
  region = "eu-central-1"
  default_tags {
    tags = {
      User    = "Aliaksandr_Dakutovich"
      Project = "CloudX"
    }
  }
}

module "net" {
  source = "../module_net"

  vpc_cidr_block = var.vpc_cidr_block
}

module "sg" {
  source = "../module_sg"

  vpc_cidr_block = var.vpc_cidr_block
  vpc_id         = module.net.vpc_id
}


module "rds" {
  source = "../module_rds"

  db_nets          = module.net.db_nets
  mysql_sg         = module.sg.mysql
  db_password_path = "/finaltask/db-password"
}

module "efs" {
  source = "../module_efs"

  efs_sg       = module.sg.efs
  private_nets = module.net.private_nets
}

module "app" {
  source = "../module_app"

  vpc_id                   = module.net.vpc_id
  alb_sg                   = module.sg.alb
  public_nets              = module.net.public_nets
  private_nets             = module.net.private_nets
  iam_instance_profile_arn = module.sg.aws_iam_instance_profile_arn
  mainrole_arn             = module.sg.mainrole_arn
  ec2_pool_sg              = module.sg.ec2_pool
  rds_endpoint             = module.rds.rds_endpoint
  efs_id                   = module.efs.efs_id
  db_password_path         = "/finaltask/db-password"
}