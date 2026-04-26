# 🚀 Terraform Projects Portfolio

This repository contains a collection of real-world Terraform projects focused on cloud infrastructure and DevOps practices.

Each project demonstrates a specific concept with production-oriented thinking.

---

## 📂 Projects

### 1️⃣ Static Website Hosting on S3

* Hosten a static website on S3 bucket
* Integrated CI/CD for automated deployment and lot more features. Dive into project folder to know more. 

👉 [View Project](./01_static_website_hosting)

---

### 2️⃣ VPC Peering

* VPC Peering between two VPCs and extends it into 3 VPCs using Transit Gateway for scalable networking.
* Focus: Networking fundamentals and Transit Gateway. Dive into project folder to know more. 

👉 [View Project](./02_vpc_peering)

---

### 3️⃣ IAM User Management

* Managed IAM users and roles using Terraform
* Automated access setup with CI/CD integration. Dive into project folder to know more. 

👉 [View Project](./03_iam_user_management)

---

### 4️⃣ Blue-Green Deployment (Elastic Beanstalk)

* Zero downtime deployment using Blue-Green strategy
* Terraform-based infrastructure provisioning
* CNAME swap for instant traffic switch

👉 [View Project](./04_blue_green_deployment)

---

### 5️⃣ Serverless Image Processor

* Built an automated image processing pipeline using AWS Lambda + S3
* Uploading an image to S3 triggers Lambda automatically
* Generates optimized variants such as JPEG, WebP, PNG, and thumbnails
* Uses Terraform for complete infrastructure provisioning
* Includes CloudWatch logging and secure private buckets

👉 [View Project](./05_simple_image_processor)

---

### 6️⃣ EC2 Provisioners Automation

* Created EC2 instance using Terraform on AWS
* Automated post-deployment tasks using local-exec, remote-exec, and file provisioners
* Focus: Infrastructure provisioning with server bootstrap automation

👉 [View Project](./06_terraform_provisioner)

---

### 7️⃣ EKS Cluster

* Provisioned a production-style Amazon EKS Kubernetes cluster using Terraform with reusable custom modules.
* Built modular infrastructure including VPC, IAM, EKS, and Secrets Manager components.

* Multi-AZ architecture with public/private subnets
* Private worker nodes for secure workloads
* On-Demand + Spot node groups for cost optimization
* IAM Roles + OIDC / IRSA ready setup
* KMS encryption for Kubernetes secrets
* CloudWatch logging enabled
* Deployed workloads using kubectl
* Ingress setup using AWS Load Balancer Controller
* Monitoring stack with Prometheus + Grafana
* GitOps workflow using ArgoCD ready architecture

👉 [View Project](./07_EKS_Cluster)

---

## 🧠 Key Learnings

* Infrastructure as Code (Terraform)
* AWS core services
* Deployment strategies
* Scalable and secure architecture design
* Server provisioning and automation
* Networking and IAM fundamentals

---

## ⚙️ Tools & Technologies

* Terraform
* AWS
* Bash / PowerShell
* Python
* Docker
* Git & GitHub

---

## 📌 Note

These projects focus on understanding real-world cloud infrastructure and DevOps practices.
In production systems, these setups are often integrated with CI/CD pipelines and container-based deployments.

---

⭐ Feel free to explore each project for detailed implementation!
