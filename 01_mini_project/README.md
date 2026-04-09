# Static Website Hosting (Mini Project 01)

## 🎯 Project Overview

This mini project demonstrates how to deploy a static website on AWS using Terraform. We'll create a complete static website hosting solution using S3 for storage and CloudFront for global content delivery.

## 🏗️ Architecture

```
Internet → CloudFront Distribution → S3 Bucket (Static Website)
```

![Architecture](./images/architecture.png)
![Architecture](./images/adv_architecture.png)

## ⚙️ How It Works

1. User requests the website.
2. Route53 (DNS) routes the request to CloudFront.
3. CloudFront checks cache:
   - If cached → returns response.
   - If not cached → fetches from S3.
4. S3 bucket is private and only accessible via CloudFront (OAC).
5. CloudFront caches content based on TTL.
6. HTTPS is enabled using AWS Certificate Manager.

### Components:
- **S3 Bucket**: Hosts static website files (HTML, CSS, JS)
- **CloudFront Distribution**: Global CDN for fast content delivery
- **Public Access Configuration**: Allows public reading of website files

## 📁 Project Structure

```
project/
├── main.tf           # Main Terraform configuration
├── variables.tf      # Input variables
├── outputs.tf        # Output values
├── provider.tf       # Provider configuration
├── backend.tf        # Backend configuration
├── env/              # Environment-specific variables
│   ├── dev.tfvars    # Development environment variables
│   ├── staging.tfvars# Staging environment variables
│   └── prod.tfvars   # Production environment variables
├── www/                # Website source files
│   ├── index.html      # Main HTML page
│   ├── style.css       # Stylesheet
│   └── script.js       # JavaScript functionality
└── .github/workflows/  # CI/CD pipeline configurations
    ├── deploy.yml      # CI/CD pipeline for automatic deployments
    └── destroy.yml     # CI/CD pipeline for automatic destruction

```

## 🚀 Features

### Website Features:
- **Modern Responsive Design**: Works on desktop and mobile
- **Dark/Light Theme Toggle**: Switch between themes (saves preference)
- **Interactive Elements**: Click counter, status updates
- **AWS Branding**: Professional layout showcasing AWS services
- **Animations**: Smooth transitions and loading effects

### Infrastructure Features:
- **S3 Static Website Hosting**: Reliable file storage and serving
- **CloudFront CDN**: Global content delivery with HTTPS
- **Proper MIME Types**: Correct content-type headers for all files
- **Public Access**: Secure public read access configuration

## 🛠️ Prerequisites

1. **AWS CLI** configured with appropriate credentials
2. **Terraform** installed (version 1.0+)
3. **AWS Account** with sufficient permissions for:
   - S3 bucket creation and management
   - CloudFront distribution creation
   - IAM policies for S3 public access

## 📋 Deployment Steps

### 1. Initialize Terraform
```bash
cd terraform_projects/01_mini_project
terraform init
```

### 2. Review the Plan
```bash
terraform plan
```

### 3. Deploy Infrastructure
```bash
terraform apply
```
Type `yes` when prompted to confirm deployment.

### 4. Access Your Website
After deployment completes, Terraform will output the CloudFront URL:
```
website_url = "https://d3ownwzlqfpss.cloudfront.net"
```

## 📊 Resources Created

| Resource Type | Purpose | Count |
|---------------|---------|-------|
| S3 Bucket | Website hosting | 1 |
| S3 Bucket Policy | Public read access | 1 |
| S3 Objects | Website files (HTML, CSS, JS) | 3 |
| CloudFront Distribution | Global CDN | 1 |
| and More | and More | and More |

## 🔧 Configuration Details

### S3 Configuration:
- **Bucket naming**: Auto-generated with prefix `my-static-website-`
- **Website hosting**: Enabled with `index.html` as default
- **Public access**: Configured for read-only public access
- **Content types**: Proper MIME types for web files

### CloudFront Configuration:
- **Origin**: S3 bucket regional domain
- **Caching**: Standard web caching (1 hour default TTL)
- **HTTPS**: Automatic redirect from HTTP to HTTPS
- **Global**: Available worldwide (PriceClass_100)

## ⚙️ Results

![output](./images/output.png)
![infrastructure](./images/infra_result.png)

## 🧹 Cleanup

To destroy all resources and avoid charges:
```bash
terraform destroy
```
Type `yes` when prompted to confirm destruction.

## 📚 Learning Objectives

After completing this project, you should understand:
- ✅ How to configure S3 for static website hosting
- ✅ Setting up CloudFront distributions
- ✅ Managing S3 bucket policies and public access
- ✅ Terraform file provisioning with `for_each`
- ✅ Proper MIME type configuration for web assets
- ✅ AWS CDN concepts and caching strategies


---

## 🧠 Key Learnings

- Infrastructure as Code (Terraform)
- CDN caching strategies and TTL tuning
- Secure cloud architecture (OAC, private S3)
- CI/CD automation with GitHub Actions
- Multi-environment deployment strategy

## 🔗 Useful Links

- [AWS S3 Static Website Hosting Guide](https://docs.aws.amazon.com/AmazonS3/latest/userguide/WebsiteHosting.html)
- [CloudFront Documentation](https://docs.aws.amazon.com/cloudfront/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

## 🎉 Enhancements Implemented (Production-Ready Setup)

This project has been extended beyond the basic setup and now includes production-grade features:

- ✅ **Custom Domain Integration (Route 53 Ready)**  
  Infrastructure is prepared to support custom domains via Route 53.

- ✅ **HTTPS with AWS Certificate Manager (ACM)**  
  Secure HTTPS configuration using ACM (default CloudFront SSL used for now).

- ✅ **CI/CD Pipeline with GitHub Actions**  
  Automatic deployment triggered on code push:
  - Terraform init & apply
  - CloudFront cache invalidation

- ✅ **Multiple Environments (Dev, Staging, Prod)**  
  Environment-based deployments using `.tfvars`:
  - Separate infrastructure per environment
  - Branch-based deployment strategy

- ✅ **Advanced CloudFront Configuration**  
  - Custom error pages (404 handling)
  - Security headers (XSS protection, frame options, etc.)
  - Optimized caching (TTL)

- ✅ **Secure Infrastructure Design**  
  - Private S3 bucket (no public access)
  - Access controlled via CloudFront (OAC)

- ✅ **Terraform Remote Backend (S3)**  
  - Centralized state management
  - Ready for team collaboration

---

🚀 This project now reflects a **real-world production-grade DevOps setup** using AWS and Terraform.

---
**Note**: This project uses CloudFront's default domain. For production websites, consider using a custom domain with Route 53 and ACM for SSL certificates.

## 🎤 Interview Questions & Answers Related to this project

### 🔹 Q1: Can you explain your project?

I built a production-ready static website hosting system using AWS and Terraform.

The website is hosted on an S3 bucket, which is kept private for security. CloudFront is used as a CDN to deliver content globally with low latency.

I used Terraform to automate the entire infrastructure, making it reproducible and version-controlled.

Additionally, I implemented a CI/CD pipeline using GitHub Actions, which automatically deploys changes whenever code is pushed.

---

### 🔹 Q2: Explain the architecture

The architecture follows this flow:

User → CloudFront → S3

CloudFront serves content from edge locations. If content is cached, it returns immediately; otherwise, it fetches from S3.

The S3 bucket is private and only accessible via CloudFront using Origin Access Control (OAC).

---

### 🔹 Q3: Why did you use for_each?

I used `for_each` to dynamically create multiple resources based on a collection.

In my project, it is used to upload multiple files from the `www` folder to S3 automatically, avoiding manual configuration.

Compared to `count`, `for_each` is more flexible and stable when working with maps and sets.

---

### 🔹 Q4: Why use S3 backend for Terraform?

I used an S3 backend to store Terraform state remotely.

This helps prevent state loss, enables team collaboration, and ensures consistency between local and CI/CD environments.

It can also be extended with DynamoDB for state locking.

---

### 🔹 Q5: What does lifecycle create_before_destroy do?

It ensures that a new resource is created before the old one is destroyed.

This avoids downtime during updates and helps maintain service availability.

---

### 🔹 Q6: What is CloudFront?

CloudFront is a CDN that improves performance by caching content at edge locations.

It reduces latency, improves load times, and minimizes direct requests to the origin server.

---

### 🔹 Q7: Why keep S3 private?

The S3 bucket is kept private to prevent direct public access.

Access is controlled via CloudFront using OAC, which improves security and ensures all requests pass through the CDN layer.

---

### 🔹 Q8: Why do we use cache invalidation?

Cache invalidation removes outdated content from CloudFront.

Since CloudFront caches data, users might see old content. Invalidating ensures fresh content is served.

---

### 🔹 Q9: Explain your CI/CD pipeline

The CI/CD pipeline is implemented using GitHub Actions.

Flow:
- Code is pushed to GitHub
- GitHub Actions triggers Terraform
- Infrastructure is updated automatically
- CloudFront cache is invalidated

---

### 🔹 Q10: Why use GitHub Secrets?

GitHub Secrets securely store sensitive credentials like AWS keys.

This prevents exposing secrets in code and ensures secure CI/CD operations.

---

### 🔹 Q11: Website not updating after deployment – what will you do?

This is likely due to CloudFront caching.

Solution:
- Perform cache invalidation
- Verify S3 object updates
- Check TTL settings

---

### 🔹 Q12: How do you debug CI/CD failures?

- Check GitHub Actions logs
- Verify AWS credentials
- Run Terraform plan locally
- Identify failing step and fix errors

---

### 🔹 Q13: Why multi-environment setup?

Multi-environment setup ensures safe deployments.

- Dev → testing
- Staging → pre-production validation
- Prod → live environment

It reduces risk and improves reliability.

---

### 🔹 Q14: Can your system handle high traffic?

Yes, the system is scalable.

- CloudFront handles global traffic via edge locations
- S3 scales automatically
- Caching reduces load on origin

This makes the system highly scalable and cost-efficient.