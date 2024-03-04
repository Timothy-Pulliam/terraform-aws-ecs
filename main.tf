terraform {
  # Terraform Version
  required_version = ">= 1.7.4"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  #   Uncomment after creating the backend, then run `terraform init`
  #   backend "s3" {
  #     bucket         = "tfstate-12345678"
  #     key            = "infra/terraform.tfstate"
  #     region         = "us-east-1"
  #     dynamodb_table = "terraform-state-locks"
  #     encrypt        = true
  #   }
}

# Configure the AWS Provider
provider "aws" {
  region = var.region
}

resource "aws_vpc" "this" {
  cidr_block = "10.0.0.0/16"

  # DNS support within the VPC
  # second available IP is dedicated to AWS DNS
  # (i.e. 10.0.0.2/16)
  enable_dns_support = true

  # setting to true requires enable_dns_support=true
  enable_dns_hostnames = true

  tags = {
    Name = "vpc-${var.app_name}"
    env  = "dev"
  }
}


resource "aws_subnet" "this" {
  vpc_id     = aws_vpc.this.id
  cidr_block = "10.0.0.0/24"
  # should instances in this subnet get a 
  # public IP by default?
  map_public_ip_on_launch = false

  tags = {
    Name = "snet-${var.app_name}"
    env  = "dev"
  }
}

resource "aws_security_group" "allow_https_in" {
  name        = "allow-https-inbound-sg"
  description = "Allow HTTPS inbound"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.this.cidr_block] # Replace with your Fargate tasks' subnet CIDR or use security group id
  }

  # Because of stateful nature of security groups, all response traffic is
  # automatically allowed. But here's how you'd explicitly write it
  #   egress {
  #     from_port   = 0
  #     to_port     = 0
  #     protocol    = "-1"
  #     cidr_blocks = ["0.0.0.0/0"]
  #   }

  tags = {
    Name = "allow-https-inbound-sg"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "ig-navikun-dev"
    env  = "dev"
  }
}

# Amazon ECS tasks hosted on Fargate using version 1.4.0 or later require both the com.amazonaws.region.ecr.dkr 
# and com.amazonaws.region.ecr.api Amazon ECR VPC endpoints and the Amazon S3 gateway endpoint.
# https://repost.aws/knowledge-center/ecs-fargate-pull-container-error
# VPC Endpoint for ECR API
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.this.id]
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.allow_https_in.id]

  tags = {
    Name = "ecr-api-endpoint"
  }
}

# VPC Endpoint for ECR Docker Registry
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.this.id]
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.allow_https_in.id]

  tags = {
    Name = "ecr-dkr-endpoint"
  }
}

resource "aws_vpc_endpoint" "s3_endpoint" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_vpc.this.default_route_table_id]

  tags = {
    Name = "s3-endpoint"
  }
}

resource "aws_vpc_endpoint" "cloudwatch_endpoint" {
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.region}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.this.id]
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.allow_https_in.id]

  tags = {
    Name = "cloudwatch-endpoint"
  }
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${var.app_name}"
  retention_in_days = 365
  skip_destroy      = var.cloudwatch_skip_destroy
}

resource "aws_service_discovery_http_namespace" "this" {
  name        = var.app_name
  description = ""
}

resource "aws_ecs_cluster" "this" {
  name = var.app_name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  configuration {
    execute_command_configuration {
      logging = "DEFAULT"
      #   log_configuration {
      #     cloud_watch_encryption_enabled = false # default false
      #     cloud_watch_log_group_name     = aws_cloudwatch_log_group.this.name
      #   }
    }
  }

  service_connect_defaults {
    # Select the namespace to specify a group of services that make 
    # up your application. You can overwrite this 
    # value at the service level.
    namespace = aws_service_discovery_http_namespace.this.arn
  }

  tags = {
    env     = "dev"
    service = var.app_name
  }
}

resource "aws_iam_role" "ecs_task_execution_role_attachment" {
  name        = "ecsTaskExecutionRole"
  description = "Provides access to other AWS service resources that are required to run Amazon ECS tasks"
  assume_role_policy = jsonencode({
    "Version" : "2008-10-17",
    "Statement" : [
      {
        "Sid" : "",
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "ecs-tasks.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_attachment" {
  role       = aws_iam_role.ecs_task_execution_role_attachment.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# pod == ecs task, deployment == ecs service
resource "aws_ecs_task_definition" "this" {
  family                   = var.app_name
  requires_compatibilities = ["FARGATE"]
  # If using Fargate launch type, you must use awsvpc
  network_mode       = "awsvpc"
  cpu                = 1024 # MB
  memory             = 2048
  execution_role_arn = aws_iam_role.ecs_task_execution_role_attachment.arn
  container_definitions = jsonencode(
    [
      {
        "name" : var.app_name,
        "image" : var.docker_image_uri,
        "cpu" : 0,
        "portMappings" : [
          {
            "name" : "http",
            "containerPort" : 8080,
            "hostPort" : 8080,
            "protocol" : "tcp",
            "appProtocol" : "http"
          }
        ],
        "essential" : true,
        "environment" : [],
        "environmentFiles" : [],
        "mountPoints" : [],
        "volumesFrom" : [],
        "ulimits" : [],
        "logConfiguration" : {
          "logDriver" : "awslogs",
          "options" : {
            "awslogs-create-group" : "true",
            "awslogs-group" : "/ecs/${var.app_name}",
            "awslogs-region" : var.region,
            "awslogs-stream-prefix" : "ecs"
          },
          "secretOptions" : []
        },
        "healthCheck" : {
          "command" : [
            "CMD-SHELL, curl -f http://localhost:8080/ || exit 1"
          ],
          "interval" : 30,
          "timeout" : 5,
          "retries" : 3
        }
      }
    ]
  )
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }
}

resource "aws_security_group" "ecs_service_sg" {
  name        = "${var.app_name}-ecs-service-sg"
  description = "Security group for containerized ECS Service app"
  vpc_id      = aws_vpc.this.id

  # Allow inbound HTTPS (443) from the Fargate tasks' subnet or security group
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.this.cidr_block] # Replace with your Fargate tasks' subnet CIDR or use security group id
  }

  #   Optional: Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ECS Service Security Group"
  }
}

# pod == ecs task, deployment == ecs service
resource "aws_ecs_service" "this" {
  name            = var.app_name
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  # If using Fargate or awsvpc network mode, do not specify this role.
  #   iam_role        = aws_iam_role.foo.arn
  #   depends_on      = [aws_iam_role_policy.foo]

  #   ordered_placement_strategy {
  #     type  = "binpack"
  #     field = "cpu"
  #   }

  network_configuration {
    subnets          = [aws_subnet.this.id]
    security_groups  = [aws_security_group.ecs_service_sg.id]
    assign_public_ip = true
  }

  #   load_balancer {
  #     # for Application Load Balancer
  #     target_group_arn = aws_lb_target_group.foo.arn
  #     container_name   = var.app_name # (as it appears in a container definition)
  #     container_port   = 8080
  #   }

  # Not valid with Fargate launch type
  #   placement_constraints {
  #     type = "memberOf"
  #     # Cluster Query Language expression 
  #     expression = "attribute:ecs.availability-zone in [us-east-1a, us-east-1b]"
  #   }
}
