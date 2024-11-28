##### vpc & subnets

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.5.0"

  name = "patient-service-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.3.0/24", "10.0.4.0/24"]

  enable_nat_gateway = true
}

### ecs cluster 

resource "aws_ecs_cluster" "ecs_cluster" {
  name = "patient-service-cluster"
}

### IAM Role

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  ]
}


### SG group

resource "aws_security_group" "ecs_service_sg" {
  name        = "ecs-service-sg"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

### ALB

resource "aws_lb" "application_lb" {
  name               = "patient-service-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ecs_service_sg.id]
  subnets            = module.vpc.public_subnets
}


resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.application_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs_target_group.arn
  }
}

resource "aws_lb_target_group" "ecs_target_group" {
  name        = "ecs-target-group"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"
}

resource "aws_ecs_service" "ecs_service" {
  name            = "patient-service"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.patient_service_task.arn
  desired_count   = 1

  launch_type = "FARGATE"

  network_configuration {
    subnets         = module.vpc.private_subnets
    security_groups = [aws_security_group.ecs_service_sg.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_target_group.arn
    container_name   = "patient-service"
    container_port   = 3000
  }
}

resource "aws_ecs_task_definition" "patient_service_task" {
  family                   = "patient-service-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256" # 0.25 vCPU
  memory                   = "512" # 512 MB
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name  = "patient-service"
      image = "<ECR_REPOSITORY_URL>/patient-service:latest"
      cpu   = 256
      memory = 512
      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/patient-service"
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "ecs_service" {
  name            = "patient-service"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.patient_service_task.arn
  desired_count   = 2

  launch_type = "FARGATE"

  network_configuration {
    subnets         = module.vpc.private_subnets
    security_groups = [aws_security_group.ecs_service_sg.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_target_group.arn
    container_name   = "patient-service"
    container_port   = 3000
  }

  depends_on = [aws_lb_listener.http_listener]
}

