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
