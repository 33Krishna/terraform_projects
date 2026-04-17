# AWS Blue-Green Deployment (Elastic Beanstalk) – Interview Q&A

## 1. What is Blue-Green Deployment?

**Answer:**
Blue-Green Deployment is a release strategy where two identical environments are maintained:

* **Blue** → Current production
* **Green** → New version

Traffic is switched from Blue to Green once the new version is verified, ensuring zero downtime and easy rollback.

---

## 2. Why use Blue-Green Deployment?

**Answer:**

* Zero downtime deployments
* Instant rollback capability
* Safe testing in production-like environment
* Reduces deployment risk

---

## 3. How does Blue-Green Deployment work in AWS Elastic Beanstalk?

**Answer:**

* Two environments (Blue and Green) are created
* Each runs a different application version
* AWS performs a **CNAME swap** to redirect traffic
* Users are routed to the new environment instantly

---

## 4. What is CNAME Swap?

**Answer:**
CNAME Swap is a DNS-level switch in Elastic Beanstalk that swaps URLs between two environments, redirecting production traffic without redeploying applications.

---

## 5. What is the role of S3 in this project?

**Answer:**
S3 stores application version artifacts (ZIP files). Elastic Beanstalk pulls these versions from S3 during deployment.

---

## 6. Why are two environments required instead of updating one?

**Answer:**
Updating a single environment can cause downtime or failures.
Two environments allow:

* Testing before release
* Instant rollback
* No impact on live users

---

## 7. What is the difference between Blue-Green and Rolling Deployment?

**Answer:**

| Feature      | Blue-Green | Rolling |
| ------------ | ---------- | ------- |
| Environments | Two        | One     |
| Downtime     | None       | Minimal |
| Rollback     | Instant    | Slow    |
| Cost         | Higher     | Lower   |

---

## 8. Why is DeploymentPolicy = Rolling not aligned with Blue-Green?

**Answer:**
Rolling deployment updates instances within the same environment, whereas Blue-Green uses two separate environments.
Using both together is redundant.

---

## 9. What are the disadvantages of Blue-Green Deployment?

**Answer:**

* Higher cost (duplicate infrastructure)
* More resource usage
* Requires environment synchronization

---

## 10. How would you implement this in a real production system?

**Answer:**

* Use CI/CD pipeline (GitHub Actions, Jenkins, etc.)
* Automate build and deployment
* Use Docker containers
* Replace Beanstalk with ECS/EKS for better control
* Automate traffic switching

---

## 11. What is the role of Auto Scaling in this setup?

**Answer:**
Auto Scaling ensures that application instances scale based on load, maintaining performance and availability in both environments.

---

## 12. How do you rollback in Blue-Green Deployment?

**Answer:**
Rollback is done by swapping the environments again (CNAME swap), instantly routing traffic back to the previous version.

---

## 13. What improvements would you suggest for this project?

**Answer:**

* Add CI/CD pipeline
* Replace manual scripts with automation
* Use Docker for packaging
* Move to ECS/EKS for production-grade setup

---

## 14. Is Elastic Beanstalk commonly used in large-scale production?

**Answer:**
Not widely in large-scale systems.
Most companies prefer:

* Kubernetes (EKS, GKE)
* ECS
* Custom infrastructure

---

## 15. What problem does Blue-Green Deployment solve?

**Answer:**
It solves deployment risk by ensuring:

* No downtime
* Safe testing
* Quick rollback

---

## 16. How does Terraform help in this project?

**Answer:**
Terraform provides Infrastructure as Code (IaC), allowing:

* Automated provisioning
* Reproducibility
* Version-controlled infrastructure

---

## 17. What is the main limitation of this project setup?

**Answer:**

* Manual deployment steps
* No CI/CD integration
* Higher cost due to duplicate environments

---

## 18. How would you explain this project in an interview (short answer)?

**Answer:**
“I implemented a Blue-Green Deployment strategy using AWS Elastic Beanstalk and Terraform, where two identical environments run different versions of an application. I used S3 for version storage and performed zero-downtime deployments using CNAME swap, ensuring safe rollout and instant rollback.”

---
