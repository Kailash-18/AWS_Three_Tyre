terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0, < 7.0"
    }
  }
}
provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = var.project_name
      Owner       = "Kailash Ambadipudi"
      Author      = "Kailash Ambadipudi"
      Environment = var.environment
      RegionRole  = "primary"
      ManagedBy   = "Terraform"
    }
  }
}
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-primary-vpc"
  }
}

resource "aws_subnet" "public" {
  count = 2

  vpc_id                  = aws_vpc.main.id
  cidr_block              = "172.20.${count.index + 1}.0/24"
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-primary-public-${count.index + 1}"
    Tier = "public"
  }
}

resource "aws_subnet" "frontend" {
  count = 2

  vpc_id            = aws_vpc.main.id
  cidr_block        = "172.20.${count.index + 3}.0/24"
  availability_zone = var.azs[count.index]

  tags = {
    Name = "${var.project_name}-primary-frontend-${count.index + 1}"
    Tier = "frontend"
  }
}

resource "aws_subnet" "backend" {
  count = 2

  vpc_id            = aws_vpc.main.id
  cidr_block        = "172.20.${count.index + 5}.0/24"
  availability_zone = var.azs[count.index]

  tags = {
    Name = "${var.project_name}-primary-backend-${count.index + 1}"
    Tier = "backend"
  }
}

resource "aws_subnet" "database" {
  count = 2

  vpc_id            = aws_vpc.main.id
  cidr_block        = "172.20.${count.index + 7}.0/24"
  availability_zone = var.azs[count.index]

  tags = {
    Name = "${var.project_name}-primary-database-${count.index + 1}"
    Tier = "database"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-primary-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-primary-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count = 2

  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.public[count.index].id
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-primary-nat-eip"
  }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "${var.project_name}-primary-nat"
  }

  depends_on = [aws_internet_gateway.main]
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-primary-private-rt"
  }
}

resource "aws_route_table_association" "frontend" {
  count = 2

  route_table_id = aws_route_table.private.id
  subnet_id      = aws_subnet.frontend[count.index].id
}

resource "aws_route_table_association" "backend" {
  count = 2

  route_table_id = aws_route_table.private.id
  subnet_id      = aws_subnet.backend[count.index].id
}

resource "aws_route_table_association" "database" {
  count = 2

  route_table_id = aws_route_table.private.id
  subnet_id      = aws_subnet.database[count.index].id
}
resource "aws_security_group" "bastion" {
  name        = "${var.project_name}-primary-bastion-sg"
  description = "SSH access to the primary bastion host"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from administrator network"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "frontend_alb" {
  name   = "${var.project_name}-primary-frontend-alb-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    description = "HTTP from Internet"
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

resource "aws_security_group" "frontend" {
  name   = "${var.project_name}-primary-frontend-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    description     = "HTTP from frontend ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend_alb.id]
  }

  ingress {
    description     = "SSH from bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "backend_alb" {
  name   = "${var.project_name}-primary-backend-alb-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    description = "HTTP API traffic from Internet"
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

resource "aws_security_group" "backend" {
  name   = "${var.project_name}-primary-backend-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    description     = "Backend application traffic from backend ALB"
    from_port       = var.backend_port
    to_port         = var.backend_port
    protocol        = "tcp"
    security_groups = [aws_security_group.backend_alb.id]
  }

  ingress {
    description     = "SSH from bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "database" {
  name   = "${var.project_name}-primary-database-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    description     = "MySQL only from backend servers"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.backend.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-primary-db-subnet-group"
  subnet_ids = aws_subnet.database[*].id

  tags = {
    Name = "${var.project_name}-primary-db-subnet-group"
  }
}

resource "aws_db_instance" "primary" {
  identifier = var.db_identifier

  engine         = "mysql"
  engine_version = "8.0"
  instance_class = var.db_instance_class

  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  multi_az               = true
  publicly_accessible    = false
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.database.id]

  backup_retention_period = var.backup_retention_days
  copy_tags_to_snapshot   = true
  skip_final_snapshot     = true
  deletion_protection     = false

  tags = {
    Name     = "${var.project_name}-primary-rds"
    DBRole   = "primary"
    DBEngine = "mysql"
  }
}
resource "aws_launch_template" "frontend" {
  name_prefix            = "${var.project_name}-primary-frontend-"
  image_id               = coalesce(var.frontend_ami_id, data.aws_ssm_parameter.al2023_ami.value)
  instance_type          = var.instance_type
  key_name               = var.key_name
  update_default_version = true

  vpc_security_group_ids = [aws_security_group.frontend.id]

  user_data = base64encode(templatefile("${path.module}/frontend-user-data.sh", {
    BOOTSTRAP_DEMO_APP = var.bootstrap_demo_app
  }))

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "${var.project_name}-primary-frontend"
      Tier = "frontend"
    }
  }

  tag_specifications {
    resource_type = "volume"

    tags = {
      Name = "${var.project_name}-primary-frontend-volume"
    }
  }
}

resource "aws_launch_template" "backend" {
  name_prefix            = "${var.project_name}-primary-backend-"
  image_id               = coalesce(var.backend_ami_id, data.aws_ssm_parameter.al2023_ami.value)
  instance_type          = var.instance_type
  key_name               = var.key_name
  update_default_version = true

  vpc_security_group_ids = [aws_security_group.backend.id]

  user_data = base64encode(templatefile("${path.module}/backend-user-data.sh", {
    BOOTSTRAP_DEMO_APP = var.bootstrap_demo_app
    BACKEND_PORT       = var.backend_port
  }))

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "${var.project_name}-primary-backend"
      Tier = "backend"
    }
  }

  tag_specifications {
    resource_type = "volume"

    tags = {
      Name = "${var.project_name}-primary-backend-volume"
    }
  }
}
resource "aws_autoscaling_group" "frontend" {
  name_prefix         = "${var.project_name}-primary-frontend-asg-"
  min_size            = var.frontend_min_size
  desired_capacity    = var.frontend_desired_size
  max_size            = var.frontend_max_size
  vpc_zone_identifier = aws_subnet.frontend[*].id

  health_check_type         = "ELB"
  health_check_grace_period = 300
  default_instance_warmup   = 180
  target_group_arns         = [aws_lb_target_group.frontend.arn]

  launch_template {
    id      = aws_launch_template.frontend.id
    version = aws_launch_template.frontend.latest_version
  }

  instance_refresh {
    strategy = "Rolling"

    preferences {
      min_healthy_percentage = 50
      instance_warmup        = 180
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-primary-frontend"
    propagate_at_launch = true
  }

  tag {
    key                 = "Owner"
    value               = "Kailash Ambadipudi"
    propagate_at_launch = true
  }

  tag {
    key                 = "ManagedBy"
    value               = "Terraform"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "frontend_cpu" {
  name                   = "${var.project_name}-primary-frontend-cpu"
  autoscaling_group_name = aws_autoscaling_group.frontend.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = var.autoscaling_target_cpu
  }
}

resource "aws_autoscaling_group" "backend" {
  name_prefix         = "${var.project_name}-primary-backend-asg-"
  min_size            = var.backend_min_size
  desired_capacity    = var.backend_desired_size
  max_size            = var.backend_max_size
  vpc_zone_identifier = aws_subnet.backend[*].id

  health_check_type         = "ELB"
  health_check_grace_period = 300
  default_instance_warmup   = 180
  target_group_arns         = [aws_lb_target_group.backend.arn]

  launch_template {
    id      = aws_launch_template.backend.id
    version = aws_launch_template.backend.latest_version
  }

  instance_refresh {
    strategy = "Rolling"

    preferences {
      min_healthy_percentage = 50
      instance_warmup        = 180
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-primary-backend"
    propagate_at_launch = true
  }

  tag {
    key                 = "Owner"
    value               = "Kailash Ambadipudi"
    propagate_at_launch = true
  }

  tag {
    key                 = "ManagedBy"
    value               = "Terraform"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "backend_cpu" {
  name                   = "${var.project_name}-primary-backend-cpu"
  autoscaling_group_name = aws_autoscaling_group.backend.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = var.autoscaling_target_cpu
  }
}
resource "aws_lb_target_group" "frontend" {
  name     = "kailash-p-fe-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name = "${var.project_name}-primary-frontend-tg"
  }
}

resource "aws_lb" "frontend" {
  name               = "kailash-p-frontend-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.frontend_alb.id]
  subnets            = aws_subnet.public[*].id

  tags = {
    Name = "${var.project_name}-primary-frontend-alb"
  }
}

resource "aws_lb_listener" "frontend" {
  load_balancer_arn = aws_lb.frontend.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

resource "aws_lb_target_group" "backend" {
  name     = "kailash-p-be-tg"
  port     = var.backend_port
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name = "${var.project_name}-primary-backend-tg"
  }
}

resource "aws_lb" "backend" {
  name               = "kailash-p-backend-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.backend_alb.id]
  subnets            = aws_subnet.public[*].id

  tags = {
    Name = "${var.project_name}-primary-backend-alb"
  }
}

resource "aws_lb_listener" "backend" {
  load_balancer_arn = aws_lb.backend.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
}
resource "aws_cloudfront_distribution" "frontend" {
  enabled         = true
  is_ipv6_enabled = true
  comment         = "${var.project_name} frontend distribution"

  origin {
    domain_name = aws_lb.frontend.dns_name
    origin_id   = "primary-frontend-alb"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id       = "primary-frontend-alb"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]

    cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84f2e3b5"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name = "${var.project_name}-cloudfront"
  }
}
data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_instance" "bastion" {
  ami                         = data.aws_ssm_parameter.al2023_ami.value
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  associate_public_ip_address = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    encrypted = true
  }

  tags = {
    Name = "${var.project_name}-primary-bastion"
    Tier = "management"
  }
}

output "frontend_alb_dns_name" {
  description = "Primary frontend ALB DNS name"
  value       = aws_lb.frontend.dns_name
}

output "backend_alb_dns_name" {
  description = "Primary backend ALB DNS name"
  value       = aws_lb.backend.dns_name
}

output "primary_rds_endpoint" {
  description = "Primary RDS endpoint"
  value       = aws_db_instance.primary.address
}

output "primary_rds_arn" {
  description = "Primary RDS ARN used by the secondary read replica"
  value       = aws_db_instance.primary.arn
}

output "bastion_public_ip" {
  description = "Primary bastion public IP"
  value       = aws_instance.bastion.public_ip
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.frontend.domain_name
}
