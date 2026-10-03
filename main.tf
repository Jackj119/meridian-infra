terraform {
  required_version = ">= 1.6.0"

  # Local state for now. Migrate to a remote backend (e.g. S3) before sharing
  # this environment with a team.
  backend "local" {
    path = "terraform.tfstate"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

# When use_localstack is true, calls go to LocalStack with dummy credentials
# and the skip_* flags stop the provider from validating them against real AWS.
# When false (as in CI), the provider uses the standard AWS credential chain.
provider "aws" {
  region     = var.region
  access_key = var.use_localstack ? "test" : null
  secret_key = var.use_localstack ? "test" : null

  skip_credentials_validation = var.use_localstack
  skip_metadata_api_check     = var.use_localstack
  skip_requesting_account_id  = var.use_localstack

  # LocalStack serves S3 at localhost:4566, not <bucket>.s3.amazonaws.com.
  s3_use_path_style = var.use_localstack

  dynamic "endpoints" {
    for_each = var.use_localstack ? [1] : []
    content {
      ec2 = var.localstack_endpoint
      s3  = var.localstack_endpoint
      sts = var.localstack_endpoint
      iam = var.localstack_endpoint
    }
  }

  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "opentofu"
    }
  }
}

locals {
  name_prefix = "meridian-${var.environment}"
}

data "aws_availability_zones" "available" {
  state = "available"
}

# Latest Amazon Linux 2023 AMI (Free Tier eligible).
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ---------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${local.name_prefix}-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.name_prefix}-igw"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.name_prefix}-public"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${local.name_prefix}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# No inbound rules by default; add ingress (e.g. SSH from your IP) as needed.
resource "aws_security_group" "instance" {
  name        = "${local.name_prefix}-instance-sg"
  description = "Security group for the ${var.environment} EC2 instance"
  vpc_id      = aws_vpc.main.id

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-instance-sg"
  }
}

# ---------------------------------------------------------------------------
# Compute
# ---------------------------------------------------------------------------

resource "aws_instance" "app" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.instance.id]

  # Require IMDSv2.
  metadata_options {
    http_tokens = "required"
  }

  # Free Tier includes 30 GB of EBS; keep the root volume small.
  root_block_device {
    volume_size = 8
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name = "${local.name_prefix}-app"
  }
}

# ---------------------------------------------------------------------------
# Storage
# ---------------------------------------------------------------------------

# S3 bucket names are globally unique, so append a random suffix.
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "main" {
  bucket = "${local.name_prefix}-${random_id.bucket_suffix.hex}"

  tags = {
    Name = "${local.name_prefix}-bucket"
  }
}

resource "aws_s3_bucket_public_access_block" "main" {
  bucket = aws_s3_bucket.main.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
