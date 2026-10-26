terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.70.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

# Networking Block
resource "aws_vpc" "inference_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_internet_gateway" "inference_igw" {
  vpc_id = aws_vpc.inference_vpc.id
  tags = {
    Name = "${var.project_name}-igw"
  }
}

resource "aws_subnet" "inference_subnet" {
  vpc_id                  = aws_vpc.inference_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.project_name}-subnet"
  }
}

resource "aws_route_table" "inference_route_table" {
  vpc_id = aws_vpc.inference_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.inference_igw.id
  }
  tags = {
    Name = "${var.project_name}-route-table"
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.inference_subnet.id
  route_table_id = aws_route_table.inference_route_table.id
}

resource "aws_security_group" "inference_sg" {
  name        = "${var.project_name}-sg"
  description = "Outbound egress security rules for batch workers"
  vpc_id      = aws_vpc.inference_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${var.project_name}-sg" }
}


# s3
resource "aws_s3_bucket" "data_bucket" {
  bucket = "${var.project_name}-data-bucket"
  tags = {
    Name = "${var.project_name}-data-bucket"
  }
}

resource "aws_s3_bucket" "model_bucket" {
  bucket = "${var.project_name}-model-bucket"
  tags = {
    Name = "${var.project_name}-model-bucket"
  }
}

# identity and policies
resource "aws_iam_role" "batch_execution_role" {
  name = "${var.project_name}-batch-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "batch.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "batch_execution_role_policy" {
  role       = aws_iam_role.batch_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBatchServiceRole"
}

resource "aws_iam_role" "batch_task_execution_role" {
  name = "${var.project_name}-batch-task-execution-role"
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
}

resource "aws_iam_role_policy_attachment" "batch_task_execution_role_policy" {
  role       = aws_iam_role.batch_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "batch_job_role" {
  name = "${var.project_name}-batch-job-role"
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
}

resource "aws_iam_policy" "s3_worker_policy" {
  name        = "${var.project_name}-s3-policy"
  description = "Allows framework containers to manage files in data and weight buckets"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
        Resource = [
          aws_s3_bucket.data_bucket.arn,
          "${aws_s3_bucket.data_bucket.arn}/*",
          aws_s3_bucket.model_bucket.arn,
          "${aws_s3_bucket.model_bucket.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "batch_job_role_policy" {
  role       = aws_iam_role.batch_job_role.name
  policy_arn = aws_iam_policy.s3_worker_policy.arn
}

resource "aws_ecr_repository" "inference_repo" {
  name                 = "${var.project_name}-inference"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "inference_repo" {
  repository = aws_ecr_repository.inference_repo.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}

// batch infra
resource "aws_batch_compute_environment" "inference_compute_env" {
  name         = "${var.project_name}-compute-env"
  type         = "MANAGED"
  service_role = aws_iam_role.batch_execution_role.arn

  compute_resources {
    type               = "FARGATE_SPOT"
    min_vcpus          = 0
    max_vcpus          = 16
    subnets            = [aws_subnet.inference_subnet.id]
    security_group_ids = [aws_security_group.inference_sg.id]
  }
}

resource "aws_batch_job_queue" "inference_queue" {
  name     = "${var.project_name}-job-queue"
  state    = "ENABLED"
  priority = 1
  compute_environment_order {
    order               = 1
    compute_environment = aws_batch_compute_environment.inference_compute_env.arn
  }
}

resource "aws_batch_job_definition" "inference_job" {
  name                  = "${var.project_name}-job-definition"
  type                  = "container"
  platform_capabilities = ["FARGATE"]

  retry_strategy {
    attempts = 3
  }

  timeout {
    attempt_duration_seconds = 3600
  }

  container_properties = jsonencode({
    image                        = "${aws_ecr_repository.inference_repo.repository_url}:${var.image_tag}"
    fargatePlatformConfiguration = { platformVersion = "LATEST" }
    resourceRequirements = [
      { type = "VCPU", value = var.container_vcpu },
      { type = "MEMORY", value = var.container_memory }
    ]
    executionRoleArn     = aws_iam_role.batch_task_execution_role.arn
    jobRoleArn           = aws_iam_role.batch_job_role.arn
    networkConfiguration = { assignPublicIp = "ENABLED" }

    # Environment boundaries injected right into the running code
    environment = [
      { name = "MODEL_BUCKET", value = aws_s3_bucket.model_bucket.id },
      { name = "INPUT_BUCKET", value = aws_s3_bucket.data_bucket.id }
    ]
  })
}
