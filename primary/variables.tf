variable "region" {
  description = "Primary AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "project_name" {
  type    = string
  default = "kailash-3tier-aws"
}

variable "vpc_cidr" {
  type    = string
  default = "172.20.0.0/16"
}

variable "azs" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b"]

  validation {
    condition     = length(var.azs) == 2
    error_message = "Exactly two Availability Zones are required."
  }
}

variable "admin_cidr" {
  description = "CIDR allowed to SSH to the bastion host, for example 203.0.113.10/32"
  type        = string
  default     = "203.0.113.10/32" // edit

  validation {
    condition     = var.admin_cidr != "0.0.0.0/0"
    error_message = "Use a restricted administrator CIDR instead of 0.0.0.0/0."
  }
}

variable "key_name" {
  description = "Existing EC2 key-pair name in the primary region"
  type        = string
  default     = "sri" // edit
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "frontend_ami_id" {
  description = "Optional custom frontend AMI ID"
  type        = string
  default     = null
  nullable    = true
}

variable "backend_ami_id" {
  description = "Optional custom backend AMI ID"
  type        = string
  default     = null
  nullable    = true
}

variable "bootstrap_demo_app" {
  description = "Install a small demo application when custom AMIs are not being used"
  type        = bool
  default     = true
}

variable "frontend_min_size" {
  type    = number
  default = 1
}

variable "frontend_desired_size" {
  type    = number
  default = 1
}

variable "frontend_max_size" {
  type    = number
  default = 4
}

variable "backend_min_size" {
  type    = number
  default = 1
}

variable "backend_desired_size" {
  type    = number
  default = 1
}

variable "backend_max_size" {
  type    = number
  default = 4
}

variable "autoscaling_target_cpu" {
  type    = number
  default = 60
}

variable "db_username" {
  type    = string
  default = "admin"
}

variable "db_password" {
  description = "Primary RDS master password. Keep this in terraform.tfvars or a secret workflow."
  type        = string
  sensitive   = true
  default     = "AdminPass123!" // edit
}

variable "db_name" {
  type    = string
  default = "mydb"
}

variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "backup_retention_days" {
  type    = number
  default = 7
}

variable "backend_port" {
  description = "Port exposed by the backend application"
  type        = number
  default     = 80
}

variable "db_identifier" {
  description = "Identifier for the primary RDS database"
  type        = string
  default     = "kailash-db"
}
