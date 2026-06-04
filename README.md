# 🚀 Terraform Projects Portfolio
 
> A collection of real-world AWS infrastructure projects built with Terraform -
> covering networking, security, serverless, containers, databases, and cloud governance.
> Each project reflects production-oriented thinking with modular, maintainable code.
 
---
 
## 📂 Projects
 
### 1️⃣ Static Website Hosting on S3
 
Turned an S3 bucket into a globally accessible static website - with a full CI/CD pipeline
that automatically deploys on every push. No servers, no maintenance, no manual uploads.
 
**What makes it interesting:**
- Zero-server architecture - S3 serves the site directly
- CI/CD pipeline triggers on every Git push - code lands live without touching AWS Console
- CloudFront integration for HTTPS and edge caching
👉 [View Project](./01_static_website_hosting)
 
---
 
### 2️⃣ VPC Peering & Transit Gateway
 
Started with two isolated VPCs that couldn't talk to each other - solved it with VPC Peering,
then scaled it to three VPCs using Transit Gateway to show why peering breaks down at scale.
 
**What makes it interesting:**
- Side-by-side comparison: VPC Peering vs Transit Gateway - when to use which
- Demonstrates the N*(N-1)/2 peering problem that Transit Gateway solves
- Pure networking - no shortcuts, built from scratch with route tables and CIDR planning
👉 [View Project](./02_vpc_peering)
 
---
 
### 3️⃣ IAM User Management
 
Automated the entire IAM lifecycle - users, groups, roles, and policies - using Terraform.
The kind of setup that takes an ops team hours to do manually, done in one `terraform apply`.
 
**What makes it interesting:**
- Policy as Code - every permission is version-controlled and reviewable
- CI/CD integration - access changes go through Git, not the AWS Console
- Least-privilege by design - no wildcard permissions
👉 [View Project](./03_iam_user_management)
 
---
 
### 4️⃣ Blue-Green Deployment (Elastic Beanstalk)
 
Solved the "how do you deploy with zero downtime" problem using a Blue-Green strategy on
Elastic Beanstalk. Traffic switches instantly with a CNAME swap - users never see a reload.
 
**What makes it interesting:**
- Zero downtime deployments - old environment stays live until new one is healthy
- Instant rollback - if something breaks, swap back in seconds
- Real deployment strategy used by production teams at scale
👉 [View Project](./04_blue_green_deployment)
 
---
 
### 5️⃣ Serverless Image Processor
 
Built an event-driven image processing pipeline - upload a file to S3, Lambda triggers
automatically, and spits out optimized JPEG, WebP, PNG variants plus thumbnails. No servers running 24/7.
 
**What makes it interesting:**
- Fully event-driven - zero manual intervention after upload
- Generates multiple output formats in a single Lambda execution
- Pay-per-invocation - costs nothing when idle
- Private buckets, CloudWatch logging, IAM scoped to least privilege
👉 [View Project](./05_simple_image_processor)
 
---
 
### 6️⃣ EC2 Provisioners & Bootstrap Automation
 
Went beyond just launching an EC2 instance - automated everything that happens *after* it
starts. File transfers, remote commands, and local scripts all wired through Terraform provisioners.
 
**What makes it interesting:**
- Covers all three provisioner types: `file`, `remote-exec`, `local-exec`
- Server is fully configured and ready the moment Terraform finishes - no manual SSH
- Shows the bridge between infrastructure provisioning and configuration management
👉 [View Project](./06_terraform_provisioner)
 
---
 
### 7️⃣ Production-Style EKS Cluster
 
Provisioned a full Amazon EKS Kubernetes cluster the way it would actually look in a
real company - multi-AZ, private worker nodes, Spot instances, monitoring, GitOps-ready.
 
**What makes it interesting:**
- Private worker nodes - workloads never exposed to the internet
- On-Demand + Spot node groups - significant compute cost reduction
- OIDC / IRSA setup - pods get scoped AWS permissions, no static credentials
- KMS encryption for Kubernetes secrets at rest
- Prometheus + Grafana monitoring stack deployed
- ArgoCD-ready architecture for GitOps workflows
- AWS Load Balancer Controller for production ingress
👉 [View Project](./07_EKS_Cluster)
 
---
 
### 8️⃣ AWS Policy & Governance Automation
 
Built the security and compliance layer that most teams skip - automated governance across
S3, IAM, EBS, and MFA using AWS Config and Terraform. Policy violations are caught automatically.
 
**What makes it interesting:**
- Continuous compliance monitoring with AWS Config - not a one-time audit
- Enforces encryption, MFA, and tagging standards across the account automatically
- S3 hardened with versioning, encryption, and public access blocking
- Demonstrates enterprise-level security practices as code - not console clicks
👉 [View Project](./08_AWS_Policy_Governance)
 
---
 
### 9️⃣ Two-Tier Web App - EC2 + RDS + Secrets Manager
 
Deployed a full 2-tier web application on AWS - Flask on EC2, MySQL on RDS - with zero
hardcoded secrets, private database isolation, and fully automated server bootstrap.
The architecture you'd actually use in a real backend system.
 
**What makes it interesting:**
- RDS lives in a private subnet - no direct internet exposure whatsoever
- Passwords are auto-generated and stored in Secrets Manager - nothing sensitive in code or Git
- NAT Gateway enables secure outbound traffic from private subnet without opening inbound
- EC2 fully bootstraps via `user_data.sh` - Flask installs, credentials inject, systemd starts the app
- 5 reusable Terraform modules: `vpc`, `security_groups`, `secrets`, `rds`, `ec2`
👉 [View Project](./09_2tier_web_app)
 
---

### 🔟 End-to-End AWS Observability - Lambda Monitoring & S3 Security Alerting
 
Built a production-grade observability stack for two real scenarios most teams skip -
knowing when your Lambda pipeline is breaking, and knowing when someone is poking around
your S3 buckets. Logs flow in, patterns get detected, alarms fire, emails land - all automated.
 
**What makes it interesting:**
- Two independent monitoring systems in one project: operational + security observability
- 13 CloudWatch Alarms across 3 severity tiers - Critical, Performance, and Log-based
  each routed to a separate SNS topic so the right person gets the right alert
- CloudWatch Metric Filters extract custom business metrics directly from Lambda logs -
  processing time, success rate, image size - not just what AWS gives you out of the box
- CloudTrail data events stream into CloudWatch Logs and get scanned for AccessDenied errors
  and restricted prefix access - suspicious S3 activity triggers an email in under 60 seconds
- IAM Condition blocks restrict CloudWatch metric publishing to a project-specific namespace -
  least privilege applied beyond just actions and resources
- 9 reusable Terraform modules with clean input/output contracts - swap variables, redeploy
  against any environment or function
👉 [View Project](./10_end_to_end_observability)

---

1️⃣1️⃣ **High Available/Scalable Infrastructure Deployment**
Built a production-grade, multi-AZ infrastructure that handles traffic spikes automatically and never goes down from a single failure - Django in Docker, private EC2 instances, and a self-healing ASG behind an ALB.

**What makes it interesting:**
- Multi-AZ deployment - one AZ goes down, the other keeps serving traffic without interruption
- Auto Scaling Group scales from 1 to 5 instances based on CPU - no manual intervention ever
- EC2 instances live in private subnets - only reachable through the ALB, never directly from internet
- Two NAT Gateways, one per AZ - true HA with no shared outbound dependency
- CloudWatch alarms trigger scaling at 80% CPU, scale back in at 20% - cost stays controlled
- IMDSv2 enforced on all instances - SSRF attacks blocked at the metadata layer
👉 [View Project](./11_high_available_scalable_infra)

---

1️⃣2️⃣ Production AWS Infrastructure - Terraform Multi-Environment CI/CD
Built a production-grade 2-tier AWS infrastructure with a complete CI/CD pipeline - 
three isolated environments (dev, test, prod), automated security scanning, and a 
manual approval gate before anything touches production. The kind of setup real 
engineering teams actually use.

**What makes it interesting:**

Three fully isolated environments from one codebase - Terraform workspaces keep 
dev, test, and prod state completely separate, different VPC CIDRs, different 
scaling configs, zero cross-contamination
Every PR triggers automated security scanning - TFLint catches code quality issues, 
Trivy scans for CRITICAL/HIGH misconfigurations before a single resource is created
Production deployments require human approval - pipeline pauses, waits for a 
reviewer to sign off, then applies the exact same plan artifact that was reviewed - 
no surprises
S3 native state locking - no DynamoDB table needed, concurrent applies are blocked 
at the backend level
Multi-AZ high availability - 2 NAT Gateways, ALB distributing across AZs, ASG with 
target tracking + CloudWatch alarms for dynamic scaling
Dedicated destroy workflow - manual trigger only, type "DESTROY" to confirm, 
protected by the same approval gate as production

👉 [View Project](./12_multi_environment_cicd_pipeline)

---

1️⃣3️⃣ **Goal Tracker - AWS 3-Tier Infrastructure**
Built a production-grade, highly available 3-tier application on AWS - Node.js frontend,
Go backend API, and PostgreSQL database - each tier isolated in its own private subnets
across two AZs, provisioned entirely with modular Terraform and containerized with Docker.

**What makes it interesting:**
- True 3-tier isolation - frontend, backend, and database each live in separate private subnets with zero cross-tier access except through scoped Security Group rules
- Two load balancers - External ALB for internet traffic, Internal ALB for frontend-to-backend communication - backend is never directly exposed
- Auto Scaling Groups on both tiers - Frontend scales 2→4, Backend scales 2→6 instances on CPU - each tier scales independently based on its own load
- DB credentials never touch the codebase - Secrets Manager auto-generates a 32-char password, backend fetches it at runtime via IAM role, no plaintext anywhere
- Bastion host + SSM dual access - traditional SSH jump and Session Manager both available, full audit trail via CloudTrail
- 9 reusable Terraform modules: `vpc`, `alb`, `bastion`, `frontend-asg`, `backend-asg`, `rds`, `iam`, `secrets`, `security_groups` - swap variables, redeploy any environment
- Local docker-compose stack included - full 3-tier app runs offline for development without touching AWS

👉 [View Project](./13_aws_3_tier_infra)
 
## 🧠 Core Concepts Across Projects
 
| Concept | Projects |
|---|---|
| Modular Terraform | 7, 8, 9, 10, 13 |
| Networking & VPC Design | 2, 7, 9, 13 |
| IAM & Least Privilege | 3, 5, 7, 8, 10, 13 |
| Secrets & Credential Management | 7, 9, 13 |
| CI/CD Integration | 1, 3, 12 |
| Serverless & Event-Driven | 5, 10 |
| Container Orchestration | 7, 13 |
| Zero-Downtime Deployments | 4 |
| Compliance & Governance | 8 |
| Database & Storage | 5, 9 |
 
---
 
## ⚙️ Tools & Technologies
 
**Infrastructure:** Terraform · AWS
 
**Application:** Node.js · Go · Python · Bash
 
**DevOps:** GitHub Actions · Docker · kubectl · ArgoCD · Prometheus · Grafana
 
---
 
## 📌 About This Portfolio
 
These projects are built with production problems in mind - not just to make things work,
but to make them secure, maintainable, and scalable. Each one tackles a specific real-world
challenge that engineering teams actually face.
 
---
 
⭐ Explore each project folder for architecture diagrams, implementation details, and deployment steps.
