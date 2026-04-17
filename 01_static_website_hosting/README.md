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
