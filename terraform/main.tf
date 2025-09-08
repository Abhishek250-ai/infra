locals {
  name_prefix = "clinic"
}

# VPC
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  tags = { Name = "${local.name_prefix}-vpc" }
}

# Public subnets
resource "aws_subnet" "public" {
  for_each = toset(var.public_subnets_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value
  map_public_ip_on_launch = true
  tags = { Name = "${local.name_prefix}-public-${substr(each.value, 0, 6)}" }
}

# Private subnets
resource "aws_subnet" "private" {
  for_each = toset(var.private_subnets_cidrs)
  vpc_id     = aws_vpc.main.id
  cidr_block = each.value
  tags = { Name = "${local.name_prefix}-private-${substr(each.value, 0, 6)}" }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = { Name = "${local.name_prefix}-igw" }
}

# Public route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "${local.name_prefix}-public-rt" }
}

resource "aws_route_table_association" "public_assoc" {
  for_each = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# Security Groups
resource "aws_security_group" "alb_sg" {
  name   = "${local.name_prefix}-alb-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    description = "HTTP"
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
  tags = { Name = "${local.name_prefix}-alb-sg" }
}

resource "aws_security_group" "ecs_sg" {
  name   = "${local.name_prefix}-ecs-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
    description     = "Allow ALB -> ECS"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${local.name_prefix}-ecs-sg" }
}

# ALB
resource "aws_lb" "alb" {
  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = values(aws_subnet.public)[*].id
  tags = { Name = "${local.name_prefix}-alb" }
}

# Target Groups
resource "aws_lb_target_group" "patient_tg" {
  name     = "${local.name_prefix}-patient-tg"
  port     = var.container_port
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  target_type = "ip"
  health_check {
    path                = "/"
    protocol            = "HTTP"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200-399"
  }
}

resource "aws_lb_target_group" "appointment_tg" {
  name     = "${local.name_prefix}-appointment-tg"
  port     = var.container_port
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  target_type = "ip"
  health_check {
    path                = "/"
    protocol            = "HTTP"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200-399"
  }
}

# Listener (HTTP)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Not Found"
      status_code  = "404"
    }
  }
}

# Listener rules
resource "aws_lb_listener_rule" "patient_rule" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100
  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.patient_tg.arn
  }
  condition {
    path_pattern {
      values = ["/patient*", "/patient/*"]
    }
  }
}

resource "aws_lb_listener_rule" "appointment_rule" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 110
  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.appointment_tg.arn
  }
  condition {
    path_pattern {
      values = ["/appointment*", "/appointment/*"]
    }
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "cluster" {
  name = "${local.name_prefix}-ecs-cluster"
}

# IAM Roles for ECS tasks
data "aws_iam_policy_document" "ecs_task_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_task_role" {
  name               = "${local.name_prefix}-ecs-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${local.name_prefix}-ecs-exec-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json
}

resource "aws_iam_role_policy_attachment" "exec_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Task Definitions (patient)
resource "aws_ecs_task_definition" "patient" {
  family                   = "patient-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "patient"
      image     = var.patient_image
      essential = true
      portMappings = [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        }
      ]
      healthCheck = {
        command = ["CMD-SHELL", "curl -f http://localhost:${var.container_port}/ || exit 1"]
        interval = 30
        timeout = 5
        retries = 2
        startPeriod = 10
      }
    }
  ])
}

# Task Definitions (appointment)
resource "aws_ecs_task_definition" "appointment" {
  family                   = "appointment-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "appointment"
      image     = var.appointment_image
      essential = true
      portMappings = [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        }
      ]
      healthCheck = {
        command = ["CMD-SHELL", "curl -f http://localhost:${var.container_port}/ || exit 1"]
        interval = 30
        timeout = 5
        retries = 2
        startPeriod = 10
      }
    }
  ])
}

# ECS Services
resource "aws_ecs_service" "patient" {
  name            = "patient-svc"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.patient.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"
  network_configuration {
    subnets         = values(aws_subnet.private)[*].id
    security_groups = [aws_security_group.ecs_sg.id]
    assign_public_ip = false
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.patient_tg.arn
    container_name   = "patient"
    container_port   = var.container_port
  }
  depends_on = [aws_lb_listener.http]
}

resource "aws_ecs_service" "appointment" {
  name            = "appointment-svc"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.appointment.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"
  network_configuration {
    subnets         = values(aws_subnet.private)[*].id
    security_groups = [aws_security_group.ecs_sg.id]
    assign_public_ip = false
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.appointment_tg.arn
    container_name   = "appointment"
    container_port   = var.container_port
  }
  depends_on = [aws_lb_listener.http]
}
