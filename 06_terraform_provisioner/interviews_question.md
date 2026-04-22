# Project 06 — Provisioners Interview Questions

## 📌 Basic Level Questions

### 1. What are Terraform Provisioners?

Provisioners are used to execute scripts or commands on local machine or remote server after resource creation or before destruction.

---

### 2. Why do we use Provisioners in Terraform?

Used when infrastructure create hone ke baad extra configuration karna ho:

- package install
- script run
- file copy
- notification trigger

---

### 3. What are the types of Provisioners in Terraform?

- local-exec
- remote-exec
- file

---

### 4. Difference between local-exec and remote-exec?

| local-exec | remote-exec |
|-----------|------------|
| Runs on local machine | Runs on remote server |
| No SSH needed | SSH/WinRM needed |
| Used for local automation | Used for server setup |

---

### 5. What does file provisioner do?

Copies files from local machine to remote server.

---

# 📌 Intermediate Level Questions

### 6. When do Provisioners run?

Mostly during:

- resource creation
- resource destroy (if configured)

Not on every apply.

---

### 7. Do Provisioners run on terraform plan?

No.

Only apply lifecycle pe run hote hain.

---

### 8. If provisioner code changes, will it run automatically?

No.

Resource recreate karna padega.

---

### 9. How to re-run a Provisioner?

```bash
terraform taint aws_instance.demo
terraform apply
or
terraform apply -replace=aws_instance.demo
```
---
### 10. What is tainted resource?

Terraform marks resource for destroy + recreate on next apply.

---
### 11. What happens if Provisioner fails?

By default:

resource creation fail
resource tainted
next apply recreate karega

---
### 12. What is on_failure in provisioner?

Controls failure behavior.

on_failure = continue

Options:

fail (default)
continue

## 📌 SSH / Connection Questions

### 13. Why connection block is needed?

Required for:

remote-exec
file provisioner

To connect remote server.

---
### 14. What fields are used in connection block?
```
connection {
 type = "ssh"
 user = "ubuntu"
 private_key = file("key.pem")
 host = self.public_ip
}
```
---
### 15. Difference between self.public_ip and hardcoded IP?

self.public_ip dynamically created resource ka IP use karta hai.

---
### 16. If remote-exec fails due to timeout?

Possible reasons:

EC2 booting not complete
SSH blocked in Security Group
Wrong key pair
Wrong username
No public IP

---
## 📌 Real Time Scenario Questions

### 17. Real world use case of local-exec?

update inventory file
webhook trigger
Slack notification
DNS update

---
### 18. Real world use case of remote-exec?
install nginx
install docker
create users
start services

---
### 19. Real world use case of file provisioner?
upload script
upload config
SSL certificate copy

---
### 20. Have you used Provisioners in production?

Best answer:

Used in learning/lab environments. In production prefer:

user_data
cloud-init
HashiCorp Packer
Ansible
Amazon Web Services Systems Manager

---
## 📌 Advanced Questions

### 21. Why Terraform docs say Provisioners are last resort?

Because:

not idempotent
difficult debugging
dependency issues
SSH reliance
brittle automation

---
### 22. Why user_data better than remote-exec?
Native EC2 feature
Runs at boot
No SSH needed
Better for autoscaling

---
### 23. Can Provisioners be used with autoscaling groups?

Not ideal.
Because instances dynamic hote hain.

Use:
Launch template user_data
AMI baking

---
### 24. Can Provisioners run on destroy?

Yes.
when = destroy

---
### 25. Security concerns with Provisioners?
private key exposure
passwords in scripts
open SSH ports
sensitive logs

---
## 📌 Practical Project Questions
### 26. Explain your Terraform Provisioner project.

I created EC2 on Amazon Web Services using Terraform and demonstrated:

local-exec for local commands
remote-exec for package installation
file provisioner for uploading script and executing remotely

---
### 27. What challenge did you face?

SSH timeout
wrong user (ubuntu/ec2-user)
SG port 22 blocked
PEM permission issue

---
### 28. How did you fix SSH issue?
opened port 22
used correct key pair
correct username
added timeout

---
### 29. If company asks production-grade setup instead of provisioners?

I would use:

Packer baked AMI
user_data
CI/CD pipeline
Ansible
SSM Run Command
---

## 📌 HR + Experience Style Question
### 30. Why did you build this project?

To understand not only infrastructure creation but also post-deployment automation using Terraform.