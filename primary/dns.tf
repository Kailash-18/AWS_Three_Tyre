# Amazon Route 53 Multi-Region Latency & Failover Routing

variable "domain_name" {
  description = "Root domain name for application DNS (e.g., example.com)"
  type        = string
  default     = "example.com"
}

# Route 53 Health Check for Primary Frontend ALB
resource "aws_route53_health_check" "primary_frontend" {
  fqdn              = aws_lb.frontend.dns_name
  port              = 80
  type              = "HTTP"
  resource_path     = "/"
  failure_threshold = 3
  request_interval  = 30

  tags = {
    Name = "${var.project_name}-primary-alb-health-check"
    Tier = "networking"
  }
}

# Output health check ID for Route 53 failover integration
output "primary_health_check_id" {
  description = "Route 53 Health Check ID for primary region ALB"
  value       = aws_route53_health_check.primary_frontend.id
}

output "waf_acl_arn" {
  description = "WAFv2 Web ACL ARN"
  value       = aws_wafv2_web_acl.main.arn
}
