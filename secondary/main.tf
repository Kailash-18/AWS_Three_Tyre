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
      RegionRole  = "secondary"
      ManagedBy   = "Terraform"
    }
  }
}

provider "aws" {
  alias  = "primary"
  region = var.primary_region
}
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-secondary-vpc"
  }
}

resource "aws_subnet" "public" {
  count = 2

  vpc_id                  = aws_vpc.main.id
  cidr_block              = "172.21.${count.index + 1}.0/24"
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-secondary-public-${count.index + 1}"
    Tier = "public"
  }
}

resource "aws_subnet" "frontend" {
  count = 2

  vpc_id            = aws_vpc.main.id
  cidr_block        = "172.21.${count.index + 3}.0/24"
  availability_zone = var.azs[count.index]

  tags = {
    Name = "${var.project_name}-secondary-frontend-${count.index + 1}"
    Tier = "frontend"
  }
}

resource "aws_subnet" "backend" {
  count = 2

  vpc_id            = aws_vpc.main.id
  cidr_block        = "172.21.${count.index + 5}.0/24"
  availability_zone = var.azs[count.index]

  tags = {
    Name = "${var.project_name}-secondary-backend-${count.index + 1}"
    Tier = "backend"
  }
}

resource "aws_subnet" "database" {
  count = 2

  vpc_id            = aws_vpc.main.id
  cidr_block        = "172.21.${count.index + 7}.0/24"
  availability_zone = var.azs[count.index]

  tags = {
    Name = "${var.project_name}-secondary-database-${count.index + 1}"
    Tier = "database"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-secondary-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-secondary-public-rt"
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
    Name = "${var.project_name}-secondary-nat-eip"
  }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "${var.project_name}-secondary-nat"
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
    Name = "${var.project_name}-secondary-private-rt"
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
resource "aws_security_group" "frontend_alb" {
  name   = "${var.project_name}-secondary-frontend-alb-sg"
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
  name   = "${var.project_name}-secondary-frontend-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    description     = "HTTP from frontend ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend_alb.id]
  }

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

resource "aws_security_group" "backend_alb" {
  name   = "${var.project_name}-secondary-backend-alb-sg"
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
  name   = "${var.project_name}-secondary-backend-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    description     = "Backend application traffic from backend ALB"
    from_port       = var.backend_port
    to_port         = var.backend_port
    protocol        = "tcp"
    security_groups = [aws_security_group.backend_alb.id]
  }

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

resource "aws_security_group" "database" {
  name   = "${var.project_name}-secondary-database-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    description     = "MySQL from secondary backend servers"
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
data "aws_db_instance" "primary" {
  provider               = aws.primary
  db_instance_identifier = var.db_identifier
}

resource "aws_db_subnet_group" "replica" {
  name       = "${var.project_name}-secondary-db-subnet-group"
  subnet_ids = aws_subnet.database[*].id

  tags = {
    Name = "${var.project_name}-secondary-db-subnet-group"
  }
}

resource "aws_db_instance" "replica" {
  identifier = "${var.db_identifier}-replica"

  engine         = "mysql"
  instance_class = "db.t3.micro"

  replicate_source_db = data.aws_db_instance.primary.db_instance_arn

  db_subnet_group_name   = aws_db_subnet_group.replica.name
  vpc_security_group_ids = [aws_security_group.database.id]
  publicly_accessible    = false

  storage_encrypted = true

  backup_retention_period = var.backup_retention_days
  copy_tags_to_snapshot   = true
  skip_final_snapshot     = true
  deletion_protection     = false

  tags = {
    Name   = "${var.project_name}-secondary-read-replica"
    DBRole = "read-replica"
  }
}
data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_launch_template" "frontend" {
  name_prefix            = "${var.project_name}-secondary-frontend-"
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
      Name = "${var.project_name}-secondary-frontend"
      Tier = "frontend"
    }
  }

  tag_specifications {
    resource_type = "volume"

    tags = {
      Name = "${var.project_name}-secondary-frontend-volume"
    }
  }
}

resource "aws_launch_template" "backend" {
  name_prefix            = "${var.project_name}-secondary-backend-"
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
      Name = "${var.project_name}-secondary-backend"
      Tier = "backend"
    }
  }

  tag_specifications {
    resource_type = "volume"

    tags = {
      Name = "${var.project_name}-secondary-backend-volume"
    }
  }
}
resource "aws_autoscaling_group" "frontend" {
  name_prefix         = "${var.project_name}-secondary-frontend-asg-"
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
    value               = "${var.project_name}-secondary-frontend"
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
  name                   = "${var.project_name}-secondary-frontend-cpu"
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
  name_prefix         = "${var.project_name}-secondary-backend-asg-"
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
    value               = "${var.project_name}-secondary-backend"
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
  name                   = "${var.project_name}-secondary-backend-cpu"
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
  name     = "kailash-s-fe-tg"
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
    Name = "${var.project_name}-secondary-frontend-tg"
  }
}

resource "aws_lb" "frontend" {
  name               = "kailash-s-frontend-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.frontend_alb.id]
  subnets            = aws_subnet.public[*].id

  tags = {
    Name = "${var.project_name}-secondary-frontend-alb"
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
  name     = "kailash-s-be-tg"
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
    Name = "${var.project_name}-secondary-backend-tg"
  }
}

resource "aws_lb" "backend" {
  name               = "kailash-s-backend-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.backend_alb.id]
  subnets            = aws_subnet.public[*].id

  tags = {
    Name = "${var.project_name}-secondary-backend-alb"
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

output "frontend_alb_dns_name" {
  description = "Secondary frontend ALB DNS name"
  value       = aws_lb.frontend.dns_name
}

output "backend_alb_dns_name" {
  description = "Secondary backend ALB DNS name"
  value       = aws_lb.backend.dns_name
}

output "read_replica_endpoint" {
  description = "Secondary RDS read replica endpoint"
  value       = aws_db_instance.replica.address
}
