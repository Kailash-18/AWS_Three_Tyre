# CloudWatch Alarms & Observability for Primary Region

resource "aws_cloudwatch_metric_alarm" "rds_cpu_high" {
  alarm_name          = "${var.project_name}-primary-rds-high-cpu"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Alarm when primary RDS CPU exceeds 80% for 10 minutes"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.primary.identifier
  }

  tags = {
    Name = "${var.project_name}-primary-rds-high-cpu"
    Tier = "database"
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_free_storage_low" {
  alarm_name          = "${var.project_name}-primary-rds-low-storage"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 5000000000 # 5 GB in bytes
  alarm_description   = "Alarm when primary RDS free storage space is below 5 GB"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.primary.identifier
  }

  tags = {
    Name = "${var.project_name}-primary-rds-low-storage"
    Tier = "database"
  }
}

resource "aws_cloudwatch_metric_alarm" "frontend_alb_5xx" {
  alarm_name          = "${var.project_name}-primary-frontend-alb-5xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "Alarm when primary frontend ALB encounters more than 10 5XX errors"

  dimensions = {
    LoadBalancer = aws_lb.frontend.arn_suffix
  }

  tags = {
    Name = "${var.project_name}-primary-frontend-alb-5xx"
    Tier = "presentation"
  }
}

resource "aws_cloudwatch_metric_alarm" "backend_alb_5xx" {
  alarm_name          = "${var.project_name}-primary-backend-alb-5xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "Alarm when primary backend ALB encounters more than 10 5XX errors"

  dimensions = {
    LoadBalancer = aws_lb.backend.arn_suffix
  }

  tags = {
    Name = "${var.project_name}-primary-backend-alb-5xx"
    Tier = "application"
  }
}
