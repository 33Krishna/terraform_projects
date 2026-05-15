# 🎯 Interview Questions — Project 9 (2-Tier Web App)
 
Grouped by topic — from fundamentals to deep architecture decisions.
 
---
 
## 🌐 Networking & VPC
 
**Q1. Why did you place RDS in a private subnet instead of a public one?**
 
Private subnet has no route to the internet via Internet Gateway.
This means even if the security group had an open rule, no one from outside can
reach RDS directly. Defense in depth — two layers of protection: subnet routing
AND security group rules. Public subnet would expose port 3306 to the world.
 
---
 
**Q2. What is a NAT Gateway and why does it need to be in the public subnet?**
 
NAT Gateway allows resources in private subnets to make outbound internet requests
(package installs, AWS API calls) without allowing any inbound connections from the internet.
It must be in the public subnet because it needs a route to the Internet Gateway to forward
traffic out. If placed in the private subnet, it has no outbound path — it becomes useless.
 
---
 
**Q3. What happens if you don't attach a route table to a private subnet?**
 
AWS associates it with the default VPC route table, which may have unintended routes.
The private subnet could accidentally get internet access, or traffic routing becomes
unpredictable. Always explicitly create and associate a private route table — never rely
on defaults in production.
 
---
 
**Q4. Why do you need 2 private subnets in different Availability Zones for RDS?**
 
AWS requires a DB Subnet Group with subnets in at least 2 AZs. This is enforced even
for a Single-AZ RDS instance — AWS needs the flexibility to move the database if the
primary AZ has issues. Without 2 different AZs, `terraform apply` throws an error
during DB Subnet Group creation.
 
---
 
**Q5. What is the difference between `security_groups` and `vpc_security_group_ids` in an EC2 resource?**
 
`security_groups` is for EC2-Classic (legacy, no longer supported for new accounts).
Inside a VPC, you must use `vpc_security_group_ids`. Using the wrong one either
throws an error or silently attaches no security group — leaving EC2 exposed or misconfigured.
 
---
 
## 🔐 Security & Secrets
 
**Q6. How did you avoid hardcoding the database password?**
 
Used Terraform's `random_password` resource to auto-generate a 16-character password
with special characters. Stored it immediately in AWS Secrets Manager using
`aws_secretsmanager_secret_version`. Passed it to RDS and EC2 as a sensitive variable —
it never appears in any file, Git history, or terminal output.
 
---
 
**Q7. What does `sensitive = true` do in Terraform outputs and variables?**
 
It tells Terraform to redact the value in terminal output — printing `<sensitive>`
instead of the actual value during `terraform plan` and `terraform apply`.
It does NOT encrypt the value in state files — for that you need a remote backend
with encryption like S3 + KMS. `sensitive = true` is a display-only protection.
 
---
 
**Q8. Why did you add a random suffix to the Secrets Manager secret name?**
 
AWS Secrets Manager has a 7-day recovery window after deletion. If you destroy
and re-apply with the same secret name, AWS blocks it — the name is reserved
during deletion. A `random_id` suffix generates a unique name every time,
preventing this conflict during development and repeated deployments.
 
---
 
**Q9. What is the principle of least privilege and how did you apply it here?**
 
Least privilege means giving only the minimum permissions required. Applied in two ways:
- DB Security Group allows port 3306 only from the Web SG — not from `0.0.0.0/0`
- EC2 can talk to RDS, but RDS cannot initiate any connection back to EC2
Even if EC2 is compromised, the attacker can only reach RDS on port 3306 — nothing else.
---
 
**Q10. Why is `storage_encrypted = true` important even with a private subnet?**
 
Private subnet prevents network access — but if someone gains access to the underlying
AWS storage hardware, unencrypted data is readable. Encryption at rest ensures data is
protected even if the physical storage is compromised. It is a completely separate layer
of security from network isolation.
 
---
 
## 🏗️ Terraform & Modules
 
**Q11. How does data flow between Terraform modules in this project?**
 
Each module exposes outputs. The root `main.tf` passes those outputs as inputs to
dependent modules. Example: `vpc` module outputs `vpc_id` → root passes it as
`module.vpc.vpc_id` → `security_groups` module receives it as `var.vpc_id`.
No module talks directly to another — everything flows through root `main.tf`.
 
---
 
**Q12. What is `templatefile()` and how did you use it?**
 
`templatefile()` reads a file and replaces `${variable}` placeholders with actual values
at plan time. Used it to inject `db_host`, `db_username`, `db_password`, and `db_name`
into `user_data.sh` — the bash script that runs when EC2 first starts. This means the
Flask app has real database credentials baked in before it even boots.
 
---
 
**Q13. Why did you use `depends_on = [module.rds]` in the EC2 module?**
 
Terraform infers dependencies from variable references — but RDS takes 5-10 minutes to
reach `available` state after the resource is marked created. Without `depends_on`,
EC2 starts booting and `user_data.sh` tries to connect to RDS before it is ready.
`depends_on` forces EC2 to wait until the entire RDS module finishes before starting.
 
---
 
**Q14. What is the difference between `terraform.tfvars` and `variables.tf`?**
 
`variables.tf` declares what variables exist — their name, type, description, and optional default.
`terraform.tfvars` provides actual values for those variables for a specific environment.
You commit `variables.tf` to Git. You never commit `terraform.tfvars` if it has sensitive values.
Think of `variables.tf` as the schema and `terraform.tfvars` as the data.
 
---
 
**Q15. What does `data "aws_ami"` do and why is it better than hardcoding an AMI ID?**
 
`data` blocks query existing AWS resources instead of creating new ones. `aws_ami` with
`most_recent = true` always fetches the latest Ubuntu AMI automatically. Hardcoding an
AMI ID breaks when AWS deprecates it or when you switch regions — AMI IDs are
region-specific. Using `data` keeps the configuration always current and portable.
 
---
 
## ⚙️ Application & Bootstrap
 
**Q16. What is `user_data.sh` and when does it run?**
 
`user_data.sh` is a bash script that AWS runs automatically as root when an EC2 instance
first starts — before anyone SSHs in. It installs packages, writes application files,
and starts services. It runs exactly once at first boot. If it fails silently, the app
will not work — which is why `set -e` is critical, stopping execution on the first error.
 
---
 
**Q17. Why did you configure the Flask app as a systemd service?**
 
If Flask runs as a plain process, it stops when the terminal session ends or when EC2
reboots. Systemd manages it as a background service with `Restart=always` —
if Flask crashes, systemd automatically restarts it after 10 seconds.
`WantedBy=multi-user.target` ensures it starts automatically on every boot.
 
---
 
**Q18. Why does the Flask app have retry logic for database connections?**
 
EC2 finishes booting and runs `user_data.sh` faster than RDS becomes available.
RDS provisioning takes 5-10 minutes. Without retry logic, Flask tries to connect once,
fails, and crashes — even though RDS will be ready shortly. The retry loop tries 5 times
with a 3-second gap, giving RDS enough time to become available.
 
---
 
## 💰 Cost & Production Thinking
 
**Q19. What resources in this project cost money and what should you do after testing?**
 
- **NAT Gateway** — ~$0.045/hour + data charges. Runs 24/7.
- **RDS db.t3.micro** — ~$0.017/hour. Not free-tier eligible in all regions.
- **EC2 t3.micro** — free tier eligible for 750 hours/month in first year.
- **Secrets Manager** — $0.40/secret/month.
Always run `terraform destroy` after testing. NAT Gateway and RDS together
can cost $40-50/month if left running unattended.
 
---
 
**Q20. How would you make this architecture highly available for production?**
 
- Add a second EC2 instance in a different AZ behind an Application Load Balancer
- Enable RDS Multi-AZ — automatic failover to standby replica in another AZ
- Use Auto Scaling Group instead of a single EC2 instance
- Enable RDS automated backups with a retention period
- Move Terraform state to S3 + DynamoDB for team collaboration and state locking
- Replace `user_data.sh` with a proper configuration management tool like Ansible
---