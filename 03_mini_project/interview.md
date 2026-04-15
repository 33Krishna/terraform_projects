# 🚀 AWS IAM User Management with Terraform — Interview Guide

---

# 📌 1. Project Overview Questions

---

## ❓ Q1: Can you explain your project?

### ✅ Answer:

> This project automates AWS IAM user provisioning using Terraform. User data is stored in a CSV file, which acts as a source of truth. When the CSV or Terraform code changes, a GitHub Actions pipeline is triggered to run Terraform, which creates IAM users, assigns them to groups, attaches policies, and enforces MFA-based security. The system follows a data-driven RBAC approach and ensures idempotent infrastructure provisioning.

---

## 🔁 Follow-up:

**Q:** Why did you use CSV instead of a database?

### ✅ Answer:

> CSV is used as a simple and lightweight simulation of an HR system. In real-world scenarios, this would be replaced by systems like Workday or SAP, but CSV helps demonstrate the same concept of data-driven automation.

---

# 🧠 2. Terraform Concepts

---

## ❓ Q2: What is `for_each` and why did you use it?

### ✅ Answer:

> `for_each` is used to create multiple resources dynamically based on a map or set. I used it to iterate over users parsed from the CSV file and create IAM users dynamically, ensuring scalability and avoiding repetitive code.

---

## 🔁 Follow-up:

**Q:** Why not use `count`?

### ✅ Answer:

> `count` works with indexes, which can cause issues if the order changes. `for_each` uses keys, making it more stable and predictable for resource management.

---

---

## ❓ Q3: What is `csvdecode`?

### ✅ Answer:

> `csvdecode` is a Terraform function that converts CSV file data into a list of maps (objects), allowing us to treat CSV data as structured input for resource creation.

---

---

## ❓ Q4: What is idempotency in Terraform?

### ✅ Answer:

> Idempotency means running the same Terraform configuration multiple times will produce the same result without duplicating resources. Terraform ensures this by maintaining state and comparing desired vs actual infrastructure.

---

# 🔐 3. IAM & Security

---

## ❓ Q5: Why did you use IAM groups instead of attaching policies directly to users?

### ✅ Answer:

> Using groups follows the principle of Role-Based Access Control (RBAC). It simplifies management by assigning permissions at the group level instead of individually, making the system scalable and easier to maintain.

---

## 🔁 Follow-up:

**Q:** What is least privilege?

### ✅ Answer:

> Least privilege means granting only the minimum permissions required to perform a task, reducing security risks.

---

---

## ❓ Q6: How did you enforce MFA?

### ✅ Answer:

> I created an IAM policy that denies all actions unless MFA is enabled. This ensures users cannot access AWS resources without multi-factor authentication.

---

## 🔁 Follow-up:

**Q:** Why not enforce MFA directly via Terraform?

### ✅ Answer:

> Terraform cannot directly enforce MFA setup on users, but it can enforce access restrictions using IAM policies.

---

---

## ❓ Q7: Why are IAM users not preferred in production?

### ✅ Answer:

> IAM users require manual password management and do not scale well. In production, AWS Identity Center (SSO) is preferred for centralized authentication and better security.

---

# ⚙️ 4. CI/CD & Automation

---

## ❓ Q8: How does your automation work?

### ✅ Answer:

> When changes are pushed to GitHub (CSV or Terraform files), GitHub Actions triggers a workflow that runs Terraform commands (`init`, `plan`, `apply`), automating infrastructure updates.

---

## 🔁 Follow-up:

**Q:** Why use CI/CD?

### ✅ Answer:

> CI/CD ensures consistency, reduces manual errors, and enables automated, repeatable infrastructure changes.

---

---

## ❓ Q9: How did you manage AWS credentials in CI/CD?

### ✅ Answer:

> AWS credentials were stored securely using GitHub Secrets and accessed during the workflow execution.

---

## 🔁 Follow-up:

**Q:** Is this secure?

### ✅ Answer:

> It works for learning, but in production, we use IAM roles with OIDC instead of static access keys for better security.

---

# 📊 5. Data-Driven Architecture

---

## ❓ Q10: What do you mean by data-driven infrastructure?

### ✅ Answer:

> Infrastructure decisions are based on input data (CSV), not hardcoded logic. For example, user roles and group memberships are determined dynamically using attributes like department and access level.

---

## 🔁 Follow-up:

**Q:** What are the benefits?

### ✅ Answer:

* Scalability
* Flexibility
* Reduced manual effort
* Easier updates

---

# 🛠️ 6. Troubleshooting Questions

---

## ❓ Q11: Terraform apply fails — what will you check?

### ✅ Answer:

> I would check:

* Syntax errors in `.tf` files
* AWS credentials
* Terraform state issues
* Logs from `terraform plan`

---

---

## ❓ Q12: User not getting correct permissions — why?

### ✅ Answer:

> Possible reasons:

* Group membership logic incorrect
* Policy not attached properly
* Wrong tags or CSV data

---

---

## ❓ Q13: Duplicate user error — what happened?

### ✅ Answer:

> This happens if `for_each` keys are not unique. I fixed it by combining first and last name to ensure uniqueness.

---

# 🌍 7. Real-World Scenario Questions

---

## ❓ Q14: How would you scale this for 1000+ users?

### ✅ Answer:

> I would replace CSV with an HR system, use AWS SSO, modularize Terraform code, and implement CI/CD pipelines for automated provisioning.

---

---

## ❓ Q15: How would you improve security?

### ✅ Answer:

* Enforce MFA
* Use IAM roles instead of users
* Use OIDC instead of access keys
* Apply least privilege policies

---

---

## ❓ Q16: How would you handle multi-account setup?

### ✅ Answer:

> I would use AWS Organizations and AWS Control Tower with SSO for centralized identity and account management.

---

# 🎯 8. Advanced Questions

---

## ❓ Q17: What is Terraform state?

### ✅ Answer:

> Terraform state is a file that tracks the current infrastructure and maps it to the configuration, enabling Terraform to detect changes.

---

---

## ❓ Q18: Why use remote state (S3)?

### ✅ Answer:

> Remote state allows team collaboration, prevents data loss, and enables state locking and versioning.

---

---

## ❓ Q19: What is RBAC?

### ✅ Answer:

> Role-Based Access Control assigns permissions based on roles rather than individual users.

---

# 🧠 FINAL TIP

👉 Always explain your project like this:

1. Problem
2. Solution
3. Tools used
4. Impact

---

# 🚀 PRO INTERVIEW CLOSING LINE

> “This project demonstrates how identity and access management can be automated using Infrastructure as Code, integrating CI/CD pipelines and applying real-world security and scalability practices.”

---