# AWS WAFv2 Web Access Control List (Web ACL) for Application Protection

resource "aws_wafv2_web_acl" "main" {
  name        = "${var.project_name}-web-acl"
  description = "WAFv2 Web ACL protecting 3-tier architecture with rate limiting and AWS Managed Rules"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  # Rate limiting rule: block IPs that exceed 1000 requests per 5 minutes
  rule {
    name     = "RateLimitRule"
    priority = 1

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 1000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-rate-limit-metric"
      sampled_requests_enabled   = true
    }
  }

  # AWS Managed Rule: Common Rule Set (OWASP Top 10 protection)
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-common-ruleset-metric"
      sampled_requests_enabled   = true
    }
  }

  # AWS Managed Rule: Known Bad Inputs
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 3

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-bad-inputs-metric"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-web-acl-summary"
    sampled_requests_enabled   = true
  }

  tags = {
    Name = "${var.project_name}-web-acl"
    Tier = "security"
  }
}

# Associate WAFv2 with Primary Frontend Application Load Balancer
resource "aws_wafv2_web_acl_association" "frontend_alb" {
  resource_arn = aws_lb.frontend.arn
  web_acl_arn  = aws_wafv2_web_acl.main.arn
}
