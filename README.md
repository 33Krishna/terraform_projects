# 🚀 Terraform Projects Portfolio
 
> A collection of real-world AWS infrastructure projects built with Terraform —
> covering networking, security, serverless, containers, databases, and cloud governance.
> Each project reflects production-oriented thinking with modular, maintainable code.
 
---
 
## 📂 Projects
 
### 1️⃣ Static Website Hosting on S3
 
Turned an S3 bucket into a globally accessible static website — with a full CI/CD pipeline
that automatically deploys on every push. No servers, no maintenance, no manual uploads.
 
**What makes it interesting:**
- Zero-server architecture — S3 serves the site directly
- CI/CD pipeline triggers on every Git push — code lands live without touching AWS Console
- CloudFront integration for HTTPS and edge caching
👉 [View Project](./01_static_website_hosting)
 
---
 
### 2️⃣ VPC Peering & Transit Gateway
 
Started with two isolated VPCs that couldn't talk to each other — solved it with VPC Peering,
then scaled it to three VPCs using Transit Gateway to show why peering breaks down at scale.
 
**What makes it interesting:**
- Side-by-side comparison: VPC Peering vs Transit Gateway — when to use which
- Demonstrates the N*(N-1)/2 peering problem that Transit Gateway solves
- Pure networking — no shortcuts, built from scratch with route tables and CIDR planning
👉 [View Project](./02_vpc_peering)
 
---
 
### 3️⃣ IAM User Management
 
Automated the entire IAM lifecycle — users, groups, roles, and policies — using Terraform.
The kind of setup that takes an ops team hours to do manually, done in one `terraform apply`.
 
**What makes it interesting:**
- Policy as Code — every permission is version-controlled and reviewable
- CI/CD integration — access changes go through Git, not the AWS Console
- Least-privilege by design — no wildcard permissions
👉 [View Project](./03_iam_user_management)
 
---
 
### 4️⃣ Blue-Green Deployment (Elastic Beanstalk)
 
Solved the "how do you deploy with zero downtime" problem using a Blue-Green strategy on
Elastic Beanstalk. Traffic switches instantly with a CNAME swap — users never see a reload.
 
**What makes it interesting:**
- Zero downtime deployments — old environment stays live until new one is healthy
- Instant rollback — if something breaks, swap back in seconds
- Real deployment strategy used by production teams at scale
👉 [View Project](./04_blue_green_deployment)
 
---
 
### 5️⃣ Serverless Image Processor
 
Built an event-driven image processing pipeline — upload a file to S3, Lambda triggers
automatically, and spits out optimized JPEG, WebP, PNG variants plus thumbnails. No servers running 24/7.
 
**What makes it interesting:**
- Fully event-driven — zero manual intervention after upload
- Generates multiple output formats in a single Lambda execution
- Pay-per-invocation — costs nothing when idle
- Private buckets, CloudWatch logging, IAM scoped to least privilege
👉 [View Project](./05_simple_image_processor)
 
---
 
### 6️⃣ EC2 Provisioners & Bootstrap Automation
 
Went beyond just launching an EC2 instance — automated everything that happens *after* it
starts. File transfers, remote commands, and local scripts all wired through Terraform provisioners.
 
**What makes it interesting:**
- Covers all three provisioner types: `file`, `remote-exec`, `local-exec`
- Server is fully configured and ready the moment Terraform finishes — no manual SSH
- Shows the bridge between infrastructure provisioning and configuration management
👉 [View Project](./06_terraform_provisioner)
 
---
 
### 7️⃣ Production-Style EKS Cluster
 
Provisioned a full Amazon EKS Kubernetes cluster the way it would actually look in a
real company — multi-AZ, private worker nodes, Spot instances, monitoring, GitOps-ready.
 
**What makes it interesting:**
- Private worker nodes — workloads never exposed to the internet
- On-Demand + Spot node groups — significant compute cost reduction
- OIDC / IRSA setup — pods get scoped AWS permissions, no static credentials
- KMS encryption for Kubernetes secrets at rest
- Prometheus + Grafana monitoring stack deployed
- ArgoCD-ready architecture for GitOps workflows
- AWS Load Balancer Controller for production ingress
👉 [View Project](./07_EKS_Cluster)
 
---
 
### 8️⃣ AWS Policy & Governance Automation
 
Built the security and compliance layer that most teams skip — automated governance across
S3, IAM, EBS, and MFA using AWS Config and Terraform. Policy violations are caught automatically.
 
**What makes it interesting:**
- Continuous compliance monitoring with AWS Config — not a one-time audit
- Enforces encryption, MFA, and tagging standards across the account automatically
- S3 hardened with versioning, encryption, and public access blocking
- Demonstrates enterprise-level security practices as code — not console clicks
👉 [View Project](./08_AWS_Policy_Governance)
 
---
 
### 9️⃣ Two-Tier Web App — EC2 + RDS + Secrets Manager
 
Deployed a full 2-tier web application on AWS — Flask on EC2, MySQL on RDS — with zero
hardcoded secrets, private database isolation, and fully automated server bootstrap.
The architecture you'd actually use in a real backend system.
 
**What makes it interesting:**
- RDS lives in a private subnet — no direct internet exposure whatsoever
- Passwords are auto-generated and stored in Secrets Manager — nothing sensitive in code or Git
- NAT Gateway enables secure outbound traffic from private subnet without opening inbound
- EC2 fully bootstraps via `user_data.sh` — Flask installs, credentials inject, systemd starts the app
- 5 reusable Terraform modules: `vpc`, `security_groups`, `secrets`, `rds`, `ec2`
👉 [View Project](./09_2tier_web_app)
 
---
 
## 🧠 Core Concepts Across Projects
 
| Concept | Projects |
|---|---|
| Modular Terraform | 7, 8, 9 |
| Networking & VPC Design | 2, 7, 9 |
| IAM & Least Privilege | 3, 5, 7, 8 |
| Secrets & Credential Management | 7, 9 |
| CI/CD Integration | 1, 3 |
| Serverless & Event-Driven | 5 |
| Container Orchestration | 7 |
| Zero-Downtime Deployments | 4 |
| Compliance & Governance | 8 |
| Database & Storage | 5, 9 |
 
---
 
## ⚙️ Tools & Technologies
 
**Infrastructure:** Terraform · AWS (EC2, RDS, S3, VPC, EKS, Lambda, IAM, Secrets Manager, Config, Beanstalk)
 
**Application:** Python · Flask · Bash
 
**DevOps:** GitHub Actions · Docker · kubectl · ArgoCD · Prometheus · Grafana
 
---
 
## 📌 About This Portfolio
 
These projects are built with production problems in mind — not just to make things work,
but to make them secure, maintainable, and scalable. Each one tackles a specific real-world
challenge that engineering teams actually face.
 
---
 
⭐ Explore each project folder for architecture diagrams, implementation details, and deployment steps.