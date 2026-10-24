variable "region" {
  description = "Secondary AWS region"
  type        = string
  default     = "us-west-2"
}

variable "primary_region" {
  description = "Primary region containing the source RDS instance"
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
  default = "172.21.0.0/16"
}

variable "azs" {
  type    = list(string)
  default = ["us-west-2a", "us-west-2b"]

  validation {
    condition     = length(var.azs) == 2
    error_message = "Exactly two Availability Zones are required."
  }
}

variable "admin_cidr" {
  description = "CIDR allowed to SSH to application instances in the secondary region"
  type        = string
  default     = "203.0.113.10/32" // edit

  validation {
    condition     = var.admin_cidr != "0.0.0.0/0"
    error_message = "Use a restricted administrator CIDR instead of 0.0.0.0/0."
  }
}

variable "key_name" {
  description = "Existing EC2 key-pair name in the secondary region"
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
  description = "Identifier of the primary RDS database to replicate"
  type        = string
  default     = "kailash-db"
}
