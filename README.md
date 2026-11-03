# Kailash Ambadipudi — Multi-Region AWS 3-Tier Infrastructure

AWS infrastructure project for a **3-tier application deployed across two different AWS regions**.

## Architecture

```text
                         INTERNET / USERS
                                |
                           CloudFront
                                |
                 +--------------+--------------+
                 |                             |
             US-EAST-1                     US-WEST-2
              PRIMARY                       SECONDARY
                 |                             |
          Frontend ALB                   Frontend ALB
                 |                             |
          Frontend ASG                   Frontend ASG
          Private Subnets                Private Subnets
                 |                             |
          Backend ALB                    Backend ALB
                 |                             |
          Backend ASG                    Backend ASG
          Private Subnets                Private Subnets
                 |                             |
          Multi-AZ RDS  <--- replication ---> RDS Read Replica
```

### Tiers

- **Presentation tier:** Public Application Load Balancer + frontend Auto Scaling Group.
- **Application tier:** Backend/API Application Load Balancer + backend Auto Scaling Group.
- **Database tier:** Private Multi-AZ MySQL RDS in the primary region and a cross-region read replica in the secondary region.

## AWS Services

- Amazon VPC
- Internet Gateway
- NAT Gateway
- Application Load Balancer
- EC2 Launch Templates
- EC2 Auto Scaling Groups
- Target Tracking Auto Scaling
- Amazon RDS for MySQL
- Cross-region RDS Read Replica
- Bastion Host
- AWS CloudFront
- AWS WAFv2 (Web Application Firewall with rate limiting & OWASP rules)
- Amazon Route 53 (Multi-region health checks & failover)
- Amazon CloudWatch (Metric alarms for RDS CPU, storage, and ALB 5XX)
- AWS Systems Manager public AMI parameter
- Terraform & GitHub Actions CI Pipeline


## Deployment Order

1. Deploy `primary/` first.
2. Verify that the primary RDS instance is available.
3. Deploy `secondary/` second. The secondary stack reads the primary RDS instance ARN and creates the cross-region replica.

### 1. Primary region

```bash
cd primary
cp terraform.tfvars.example terraform.tfvars
```

Set your real AWS key-pair name, administrator CIDR, and database password.

Then:

```bash
terraform fmt
terraform init
terraform validate
terraform plan
terraform apply
```

### 2. Secondary region

```bash
cd ../secondary
cp terraform.tfvars.example terraform.tfvars
```

Set the secondary key-pair name and administrator CIDR.

Then:

```bash
terraform fmt
terraform init
terraform validate
terraform plan
terraform apply
```