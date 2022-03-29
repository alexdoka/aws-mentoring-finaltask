locals {
  account_id = data.aws_caller_identity.current.account_id
  region = data.aws_region.current.name
}

resource "aws_lb" "alb" {
  name               = "cloudx-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_sg]
  subnets            = var.public_nets

  tags = {
    Name = "cloudx-alb"
  }
}

data "aws_ami" "amazonlinux" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-kernel-5.10-hvm-2.0*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["137112412989"]
}

resource "aws_launch_template" "ghost" {
  name                   = "ghost"
  update_default_version = true
  iam_instance_profile {
    arn = var.iam_instance_profile_arn
  }

  image_id      = data.aws_ami.amazonlinux.id
  instance_type = var.ec2_type
  key_name      = "ghost-ec2-pool"

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "optional"
  }

  monitoring {
    enabled = false
  }

  vpc_security_group_ids = [var.ec2_pool_sg]

  user_data = base64encode(templatefile("${path.module}/startup.sh", { db_endpoint = var.rds_endpoint }))
}

resource "aws_lb_target_group" "asg" {
  name_prefix = "asg-"
  port        = 2368
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
}


resource "aws_autoscaling_group" "ghost" {
  desired_capacity    = 2
  max_size            = 2
  min_size            = 1
  vpc_zone_identifier = var.private_nets
  target_group_arns   = [aws_lb_target_group.asg.arn]

  launch_template {
    id = aws_launch_template.ghost.id
  }
}

resource "aws_lb_listener" "front" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "forward"
    forward {
      target_group {
        arn    = aws_lb_target_group.asg.arn
        weight = "50"
      }
      target_group {
        arn    = aws_lb_target_group.ecr.arn
        weight = "50"
      }
    }
  }
}


# ========= EKS CLUSTER ================================================================

resource "aws_ecs_cluster" "ghost" {
  name = "ghost"
}

resource "aws_ecs_cluster_capacity_providers" "ghost" {
  cluster_name = aws_ecs_cluster.ghost.name

  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    base              = 0
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

resource "aws_ecr_repository" "ghost" {
  name = "ghost"
  image_scanning_configuration {
    scan_on_push = false
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "null_resource" "docker_registry" {
  # triggers = {
  #   "time" = timestamp()
  # }
  provisioner "local-exec" {
    command     = <<EOS
docker tag ghost:latest ${local.account_id}.dkr.ecr.${local.region}.amazonaws.com/ghost &&
pass=$(aws ecr get-login-password --region ${local.region}) &&
docker login --username AWS --password $pass ${local.account_id}.dkr.ecr.${local.region}.amazonaws.com &&
docker push ${local.account_id}.dkr.ecr.${local.region}.amazonaws.com/ghost
EOS
    interpreter = ["bash", "-c"]
  }
  depends_on = [
    aws_ecr_repository.ghost
  ]  
}

data "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"
}

resource "aws_efs_access_point" "test" {
  file_system_id = var.efs_id
}

resource "aws_ecs_task_definition" "service" {
  family = "ghost-service"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 1024
  # execution_role_arn       = data.aws_iam_role.ecs_task_execution_role.arn
  execution_role_arn       = var.mainrole_arn
  task_role_arn            = var.mainrole_arn
  container_definitions = jsonencode([
    {
      name      = "ghost-svc"
      image     = "${local.account_id}.dkr.ecr.${local.region}.amazonaws.com/ghost:latest"
      cpu       = 256
      memory    = 1024
      essential = true
      environment = [
        {"name": "database__connection__host", "value": var.rds_endpoint},
        {"name": "database__connection__user", "value": "gh_user"},
        {"name": "database__connection__password", "value": "supermegapassword1!"},
        {"name": "database__connection__database", "value": "gh_db"}
        ]
      portMappings = [
        {
          containerPort = 2368
          hostPort      = 2368
        }
      ]
    }
  ])

  # volume {
  #    name = "service-storage"

  #    efs_volume_configuration {
  #      file_system_id          = var.efs_id
  #      root_directory          = "/var/lib/ghost/content"
  #   #    transit_encryption      = "ENABLED"
  #   #    transit_encryption_port = 2999
  #   #    authorization_config {
  #   #      access_point_id = aws_efs_access_point.test.id
  #   #      iam             = "ENABLED"
  #   #    }
  #    }
  #  }

  # placement_constraints {
  #   type       = "memberOf"
  #   expression = "attribute:ecs.availability-zone in tolist(${var.private_nets})"
  # }
}

resource "aws_lb_target_group" "ecr" {
  name_prefix = "ecr-"
  port        = 2368
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"
}


resource "aws_ecs_service" "ecs_module_service" {
  name            = "ecs_service"
  cluster         = "ghost"
  task_definition = "${aws_ecs_task_definition.service.arn}"
  desired_count   = 1

  load_balancer {
    target_group_arn = aws_lb_target_group.ecr.arn
    container_name   = "ghost-svc"
    container_port   = 2368
  }

  network_configuration {
    subnets = var.private_nets
    security_groups = [var.ec2_pool_sg]
    assign_public_ip = false
  }
}