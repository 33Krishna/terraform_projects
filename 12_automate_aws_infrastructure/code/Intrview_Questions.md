# Project 12 — Terraform Multi-Environment CI/CD
## Interview Questions & Answers

> **Format:** Real-world scenario-based questions with production-depth answers.
> **Covers:** Terraform, AWS, CI/CD, Security, Networking, Auto Scaling.

---

## Table of Contents

1. [Terraform & State Management](#1-terraform--state-management)
2. [CI/CD Pipeline & GitHub Actions](#2-cicd-pipeline--github-actions)
3. [AWS Networking (VPC, Subnets, NAT)](#3-aws-networking)
4. [Auto Scaling & Load Balancing](#4-auto-scaling--load-balancing)
5. [Security](#5-security)
6. [Multi-Environment Strategy](#6-multi-environment-strategy)
7. [Troubleshooting & Incident Scenarios](#7-troubleshooting--incident-scenarios)
8. [Design & Architecture Decisions](#8-design--architecture-decisions)

---

## 1. Terraform & State Management

---

### Q1. Your team has 5 engineers all working on the same Terraform codebase. Two engineers run `terraform apply` at the same time. What happens, and how does your project prevent this?

**Answer:**

Without state locking, two simultaneous `terraform apply` runs would both read the same state file, each compute a diff, and then both write back — causing state corruption. Resources could be duplicated, deleted, or left in an inconsistent state that Terraform can no longer reconcile. This is a real incident I've seen documented in post-mortems at companies that started with local state.

In this project, I've solved it using **S3 native locking** via `use_lockfile = true` in `backend.tf`. This is a Terraform 1.10+ feature that creates a `.tflock` file directly in S3 alongside the state. When Engineer A starts an apply, Terraform writes a lock file. When Engineer B runs apply simultaneously, Terraform detects the lock and immediately fails with:

```
Error: Error acquiring the state lock
```

The lock is automatically released when the apply completes or fails. If the process crashes mid-apply, you can force-unlock using `terraform force-unlock <lock-id>` — but this should only be done after confirming the previous process is truly dead.

Previously, teams needed a separate DynamoDB table for locking, which added cost and setup complexity. The S3 native approach eliminates that dependency entirely.

---

### Q2. You ran `terraform apply` against production. Ten minutes later, someone manually changed the security group rules directly in the AWS Console. How would you detect and fix this?

**Answer:**

This is called **configuration drift** — when the actual infrastructure diverges from the Terraform state. It's one of the most common real-world problems in IaC-managed environments.

**Detection:**

```bash
terraform plan -var-file=prod.tfvars -detailed-exitcode
```

The exit codes tell the story:
- `0` → No drift, infrastructure matches state
- `1` → Error
- `2` → Drift detected — plan shows changes

In this project, you can also add a **scheduled drift detection workflow** using GitHub Actions cron:

```yaml
on:
  schedule:
    - cron: '0 8 * * 1-5'  # Every weekday at 8 AM
```

This runs a plan automatically and alerts the team if drift is found.

**Remediation options:**

1. **Re-apply Terraform** — `terraform apply` will revert the manual change back to IaC-defined state. This is the right answer in most cases.
2. **Import the change** — If the manual change was intentional and good, update the Terraform code to reflect it, then `terraform apply`. Never leave manual changes untracked.
3. **Never** leave drift unaddressed — manual changes create a false sense of security and make the next `terraform apply` unpredictable.

The root cause fix is IAM: restrict who can directly modify production resources in the console. If everything must go through Terraform, drift can't happen.

---

### Q3. In your project, all three environments (dev, test, prod) use the same Terraform code. How do you ensure a bug in the Terraform code doesn't simultaneously destroy all three environments?

**Answer:**

This is solved through **Terraform workspace isolation** combined with a **branch-based promotion strategy**.

Each environment has:
- Its own Terraform workspace (`dev`, `test`, `prod`)
- Its own state file in S3: `s3://bucket/env:/dev/...`, `s3://bucket/env:/prod/...`
- Its own `.tfvars` file with environment-specific values
- Its own VPC CIDR to prevent IP conflicts

The promotion flow is sequential, not simultaneous:

```
Feature branch → dev branch → test branch → main (prod)
```

Each step requires a Pull Request and a passing pipeline. Production additionally requires **manual approval** from a reviewer before `terraform apply` runs. So a bug would surface in dev first, fail the plan/apply, and never reach test or prod.

The state isolation is the critical safety net — even if the same code is applied to all three simultaneously (which the pipeline prevents), a corrupt state in dev cannot affect prod because they are completely separate state files.

---

### Q4. What is the risk of using `version = "$Latest"` in your Launch Template, and when would you change it?

**Answer:**

Using `$Latest` means every new version of the Launch Template is immediately used for new EC2 instances launched by the Auto Scaling Group. This introduces a **silent rollout risk**.

**The scenario:** You update the Launch Template — change the AMI ID, modify user data, adjust instance type — and save it as v2. The moment the ASG needs to launch a new instance (scale-out event or instance replacement), it picks up v2 automatically. If v2 has a bug — a broken bootstrap script, wrong AMI for the region — new instances will fail health checks, and your application capacity degrades silently.

**In a production system**, I would change this to use `$Default` — a specific version that you explicitly promote:

```hcl
version = "$Default"
```

The workflow becomes:
1. Create new Launch Template version
2. Test it (deploy to dev, verify instances are healthy)
3. Run `aws ec2 modify-launch-template --default-version 2` to promote it
4. Now ASG picks up the new version on next scale event

This gives you **explicit control over rollout** rather than implicit auto-upgrade. In this project I kept `$Latest` for demo simplicity, but in a real production deployment I'd switch to `$Default` immediately.

---

## 2. CI/CD Pipeline & GitHub Actions

---

### Q5. Walk me through exactly what happens from the moment a developer pushes a commit to the `dev` branch until the infrastructure is updated in AWS.

**Answer:**

Here's the complete flow:

**Step 1 — Push triggers the workflow**
The `terraform.yml` workflow fires on `push` to `dev`. Two jobs run: `terraform-plan` first, then `terraform-apply`.

**Step 2 — terraform-plan job**
```
Checkout code
→ Setup Terraform 1.13.3 (pinned version, reproducibility)
→ Setup TFLint → tflint --init → tflint -f compact
   (catches unused variables, provider-specific rule violations)
→ Trivy IaC scan
   (scans for HIGH/CRITICAL security misconfigurations)
→ terraform init
   (downloads AWS + random providers, connects to S3 backend)
→ terraform fmt -check
   (fails if code is not properly formatted — enforces style)
→ terraform validate
   (syntax and logic validation without AWS API calls)
→ Set environment variables: WORKSPACE=dev, VAR_FILE=dev.tfvars
→ terraform workspace select dev
→ terraform plan -var-file=dev.tfvars -out=tfplan
   (creates a binary plan artifact)
→ Upload artifact: tfplan-dev to GitHub Actions storage
```

**Step 3 — terraform-apply job**
```
needs: terraform-plan  (only runs if plan succeeded)
if: github.event_name == 'push'  (skips on PRs)
environment: dev  (no approval required for dev)

→ Checkout + Terraform init (fresh runner, re-initialize)
→ Set environment variables again (different runner, no inheritance)
→ terraform workspace select dev
→ Download artifact: tfplan-dev
→ terraform apply -auto-approve tfplan
   (applies the EXACT binary plan from plan job — no drift between plan and apply)
```

**The key design choice:** The binary plan file is uploaded and downloaded between jobs. This guarantees that what was planned is exactly what gets applied — no possibility of infrastructure changing between the plan and apply steps.

**Total time:** Approximately 6-8 minutes for dev (NAT Gateway creation is the bottleneck).

---

### Q6. Why does your `terraform-apply` job re-run `terraform init` when it already ran in the `terraform-plan` job?

**Answer:**

Because each job runs on a **fresh, ephemeral GitHub Actions runner**. The two jobs do not share filesystem state — they run on completely separate virtual machines.

When `terraform-plan` completes, its runner is discarded. The `.terraform/` directory, downloaded providers, and initialized backend — all gone. The `terraform-apply` job spins up a new runner that starts with a clean slate.

This is why the apply job has its own full initialization sequence:

```yaml
- name: Terraform Init
  run: terraform init
- name: Set Environment Variables   # re-set, because env vars also don't persist
- name: Select Terraform Workspace  # re-select workspace
- name: Download Plan Artifact      # only the binary tfplan survives via artifact storage
```

The **only thing that persists** between jobs is what's explicitly saved as an artifact. That's why we upload `tfplan` in the plan job and download it in the apply job — it's the one piece of state we need to carry forward.

This is actually a **security feature**: it forces every job to re-authenticate, re-initialize, and re-validate its environment. Nothing is trusted from a previous job's context.

---

### Q7. A developer on your team opens a Pull Request. The Trivy scan finds a HIGH severity issue but the pipeline still shows green. What's the problem and how do you fix it?

**Answer:**

The problem is this line in `terraform.yml`:

```yaml
- name: Run Trivy vulnerability scanner in IaC mode
  uses: aquasecurity/trivy-action@master
  with:
    exit-code: "0"    # ← THIS is the issue
    severity: "CRITICAL,HIGH"
```

`exit-code: "0"` tells Trivy to **always exit successfully**, regardless of what it finds. Trivy will scan, print the findings in the pipeline logs, and then return exit code 0 — which GitHub Actions interprets as success. The pipeline turns green even with a CRITICAL vulnerability.

This essentially makes the security scan **decorative** — it's theater, not enforcement.

**The fix:**

```yaml
exit-code: "1"
```

With this change, any CRITICAL or HIGH finding causes Trivy to exit with code 1, which fails the pipeline step, blocks the PR from being merged, and forces the developer to fix the issue first.

**Why was it "0" in this project?** Intentionally, for demo purposes — specifically to demonstrate Demo 2 (Security Scanning in Action) where we *want* the pipeline to show the finding without blocking the demo. In a real production pipeline, this must be `"1"` from day one.

This is a common misconfiguration I've seen in real teams — the security tool is installed but not actually enforcing anything. The fix is a one-character change.

---

### Q8. Your production deployment is stuck in "Waiting for approval" in GitHub Actions. The on-call engineer who is the designated reviewer is unreachable. What do you do?

**Answer:**

This is a real operational scenario that every team eventually faces. The right answer depends on whether there's a **break-glass procedure** defined in advance.

**Immediate steps:**

1. **Check if the deployment is actually urgent.** Is this a hotfix for a production incident, or a routine feature? If it's not urgent, wait. The approval gate exists for a reason.

2. **Find an alternate reviewer.** GitHub Environment protection rules allow multiple reviewers. If the team was set up correctly, there should be at least 2-3 designated reviewers for the prod environment. Go to GitHub → Settings → Environments → prod → Required reviewers.

3. **If it's a genuine emergency (production is down):**
   - Escalate to the engineering manager or team lead
   - They can either approve directly in GitHub or temporarily modify the environment protection rules to remove the reviewer requirement
   - Document the override in an incident report
   - Re-enable protection rules immediately after

4. **Root cause fix:** After the incident, add more reviewers to the prod environment. A single point of approval is itself a risk. Standard practice is 2-3 reviewers with a "any one of them can approve" policy.

The deeper lesson: **protection rules are only as good as the team's processes around them.** Technical gates need human backup procedures.

---

## 3. AWS Networking

---

### Q9. Your EC2 instances are in private subnets. A developer asks why Nginx can still download packages during instance startup if there's no direct internet access. Explain the complete traffic path.

**Answer:**

Great question — this is exactly the kind of thing that confuses people until they see the full picture.

The instances are in **private subnets**, which means they have no public IP and no direct route to the internet. But they *can* reach the internet for outbound traffic through the **NAT Gateway**, which sits in the public subnet.

Here's the complete path when the `user_data.sh` script runs `apt-get install nginx`:

```
EC2 (private subnet: 10.0.11.0/24)
  → Private route table: 0.0.0.0/0 → NAT Gateway
  → NAT Gateway (public subnet: 10.0.1.0/24)
  → NAT Gateway has an Elastic IP (public IP)
  → Internet Gateway
  → Internet (apt.ubuntu.com, nginx package servers)
  → Response returns through the same path
```

The **NAT Gateway performs source NAT** — it replaces the EC2's private IP with its own Elastic IP for outbound packets, and maintains a connection table to route response packets back to the correct EC2 instance.

**Why not just put instances in public subnets?**
If EC2 instances have public IPs, they're directly reachable from the internet — any port that's accidentally open becomes an attack surface. Private subnets + NAT Gateway means:
- Inbound: Only the ALB can reach EC2 (enforced by security groups)
- Outbound: EC2 can reach internet through NAT
- Attack surface: Dramatically reduced

This is the **2-tier architecture** principle: public tier (ALB) absorbs internet traffic, private tier (EC2) is isolated from direct internet exposure.

---

### Q10. This project deploys 2 NAT Gateways instead of 1. Why? What's the cost vs reliability tradeoff?

**Answer:**

In `vpc.tf`:
```hcl
resource "aws_nat_gateway" "main" {
  count         = var.public_subnet_count   # = 2
  allocation_id = aws_eip.main[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
}
```

One NAT Gateway per public subnet — so 2 total, one in each Availability Zone.

**Why 2?**

If you use a single NAT Gateway (in AZ-a), and AZ-a goes down — all instances in the private subnet of AZ-b now have no internet access. They can't pull updates, call external APIs, or communicate with AWS services. This is a **hidden single point of failure**.

With 2 NAT Gateways:
- Private subnet in AZ-a routes through NAT Gateway in AZ-a
- Private subnet in AZ-b routes through NAT Gateway in AZ-b
- If AZ-a fails completely, AZ-b instances are completely unaffected

This matches how the route tables are configured:
```hcl
resource "aws_route" "private" {
  count                  = var.private_subnet_count   # each private subnet...
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[count.index].id  # ...has its own NAT
}
```

**The cost tradeoff:**
- NAT Gateway costs ~$35/month each → 2 NAT Gateways = ~$70/month
- Plus data processing charges (~$0.045/GB)
- Single NAT = half the cost, but single point of failure

**Production decision:** For a revenue-generating service, $35/month extra for true HA is almost always worth it. For a cost-sensitive demo or dev environment, you'd use a single NAT — or skip it entirely and put instances in public subnets (acceptable for dev, never for prod).

---

## 4. Auto Scaling & Load Balancing

---

### Q11. Your application is experiencing a sudden traffic spike. Walk me through exactly how your infrastructure responds, from the CloudWatch alarm firing to new instances serving traffic.

**Answer:**

Here's the complete timeline:

**T+0: Traffic spike begins**
CPU utilization on existing instances starts climbing above normal baseline.

**T+4 min: CloudWatch alarm fires**
```hcl
evaluation_periods = "2"
period             = "120"   # 2-minute windows
threshold          = "80"    # CPU > 80%
```
CloudWatch evaluates CPU every 120 seconds. After 2 consecutive periods above 80% (4 minutes total), the `high_cpu` alarm transitions to ALARM state.

**T+4 min: Scaling policy triggers**
The alarm's `alarm_actions` points to `aws_autoscaling_policy.scale_out.arn`. This policy fires:
```hcl
scaling_adjustment = 1
adjustment_type    = "ChangeInCapacity"
cooldown           = 300
```
ASG desired capacity increments by 1.

**T+4-5 min: EC2 instance launch**
ASG uses the Launch Template to launch a new instance in one of the private subnets. The instance boots, cloud-init runs `user_data.sh`, Nginx installs and starts.

**T+5-7 min: Health check grace period**
```hcl
health_check_grace_period = 300
```
For 5 minutes, the ASG ignores health check failures — giving the instance time to bootstrap without being immediately terminated.

**T+7-8 min: ALB health check passes**
The Target Group health check polls port 80 every 30 seconds:
```hcl
healthy_threshold   = 2    # 2 consecutive successes = healthy
interval            = 30
```
After 2 successful HTTP 200 responses, the instance is marked `healthy` and ALB starts routing traffic to it.

**T+8 min: New capacity serving traffic**
The new instance is now in rotation. Load is distributed across all healthy instances.

**After spike subsides:**
When CPU drops below 20% for 2 evaluation periods, the `low_cpu` alarm fires `scale_in` policy, reducing capacity by 1. The 300-second cooldown prevents thrashing.

---

### Q12. A developer reports that after a deployment, some users are getting `503 Service Unavailable` from the ALB for about 3-4 minutes, then it resolves. What's happening and how do you fix it?

**Answer:**

This is a classic **health check grace period** issue during rolling deployments, and it's one of the most common complaints about ALB + ASG setups.

**What's happening:**

When the ASG launches new instances (due to a deployment or scaling event), the instances take time to bootstrap — OS init, `user_data.sh` execution, Nginx startup. During this time, the instance is registered with the Target Group but Nginx isn't yet responding.

The ALB's health check:
```hcl
interval            = 30   # checks every 30s
unhealthy_threshold = 2    # 2 failures = unhealthy
```

The instance gets 2 failed health checks → marked `unhealthy` → removed from rotation. Meanwhile, if the old instances were already terminated (aggressive replacement policy), you have a gap in capacity → `503`.

**Fixes:**

1. **Increase health check grace period** — give instances more time to bootstrap before health checks start:
   ```hcl
   health_check_grace_period = 600  # 10 minutes instead of 5
   ```

2. **Use a proper readiness check** — instead of checking `/` which returns immediately, check a health endpoint that only returns 200 when the app is fully initialized:
   ```hcl
   path = "/health"  # custom endpoint that checks DB connection, etc.
   ```

3. **Bake the AMI** — the root cause is slow bootstrap. If Nginx is pre-installed in the AMI, `user_data.sh` just needs to configure and start it — cutting bootstrap time from 3-4 minutes to 30-60 seconds. This is the production approach.

4. **Use lifecycle hooks** — ASG lifecycle hooks let you pause instance launch at `autoscaling:EC2_INSTANCE_LAUNCHING`, run custom validation, then signal completion. This ensures instances are truly ready before receiving traffic.

---

## 5. Security

---

### Q13. Explain the security group architecture in this project. Why is it more secure than just opening port 80 on EC2 instances directly to the internet?

**Answer:**

The project uses a **security group chain** — each layer only trusts traffic from the layer above it.

```
Internet (0.0.0.0/0)
    ↓ port 80, 443
[ALB Security Group]  ← open to internet on 80/443
    ↓ port 80, 443
[App Security Group]  ← ONLY accepts traffic from ALB SG
    ↓
[EC2 Instances]       ← never directly reachable from internet
```

The critical part is this in `security_groups.tf`:
```hcl
resource "aws_security_group" "app_sg" {
  ingress {
    from_port       = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]  # ← SG reference, not CIDR
  }
}
```

**Why SG reference instead of CIDR (`0.0.0.0/0`)?**

If you used `cidr_blocks = ["0.0.0.0/0"]` on EC2, any IP on the internet could try to connect to port 80 directly — bypassing the ALB entirely. This means:
- WAF rules (if any) are bypassed
- ALB access logs miss direct traffic
- Any accidental port opening is immediately exploitable

With SG-to-SG reference, only resources that are *members of the ALB security group* can reach EC2 on port 80. Even if an attacker knows the EC2's IP (they don't — it's in a private subnet with no public IP), they cannot connect because they're not the ALB.

**The defense-in-depth layers:**
1. EC2 in private subnet — no public IP, unreachable from internet by default
2. App SG — only accepts traffic from ALB SG
3. ALB SG — only accepts HTTP/HTTPS from internet
4. NAT Gateway — EC2 can make outbound requests but nothing can initiate inbound

This is the **principle of least privilege** applied at the network layer.

---

### Q14. What is IMDSv2 and why did you enforce it in the Launch Template? Give a real attack scenario that IMDSv2 prevents.

**Answer:**

**IMDS (Instance Metadata Service)** is a local endpoint available on every EC2 instance at `http://169.254.169.254/latest/meta-data/`. It returns instance metadata — IAM role credentials, instance ID, network configuration, user data, etc.

In this Launch Template:
```hcl
metadata_options {
  http_tokens                 = "required"   # enforces IMDSv2
  http_put_response_hop_limit = 1
}
```

**The attack scenario IMDSv1 enables:**

Imagine your Nginx instance is running a web application that has an **SSRF (Server-Side Request Forgery)** vulnerability. An attacker crafts a URL like:
```
https://yourapp.com/fetch?url=http://169.254.169.254/latest/meta-data/iam/security-credentials/my-role
```

With IMDSv1, this works — the app fetches the metadata URL, returns the IAM role's temporary credentials (AccessKeyId, SecretAccessKey, SessionToken) in the response. The attacker now has full AWS credentials for whatever permissions that EC2 role has. This exact attack has been used in several major cloud breaches.

**Why IMDSv2 prevents this:**

IMDSv2 requires a **two-step session-oriented request**:
1. First, make a PUT request to get a session token (requires a TTL header)
2. Then use that token in subsequent GET requests

SSRF vulnerabilities typically only allow GET requests. The PUT-first requirement breaks the attack chain. Additionally, `http_put_response_hop_limit = 1` means the request cannot be forwarded through any proxy or container layer — it must originate directly from the EC2 instance network interface.

This is why AWS has been pushing IMDSv2 as a mandatory standard, and why Terraform best practices enforce it.

---

## 6. Multi-Environment Strategy

---

### Q15. Why does this project use Terraform workspaces for environment isolation instead of separate repositories or separate state files with different keys?

**Answer:**

There are three common patterns for multi-environment Terraform, each with tradeoffs:

**Option A: Separate repositories** (one repo per environment)
- `terraform-infra-dev`, `terraform-infra-prod`
- Problem: Code drift between repos. Dev gets a fix, someone forgets to apply it to prod. You end up with different infrastructure in different environments — defeating the purpose.

**Option B: Separate directories** (one folder per environment)
```
/environments/dev/main.tf
/environments/prod/main.tf
```
- Problem: Code duplication. Same resource definitions in 3 places. A change requires updating all 3.

**Option C: Workspaces** (this project's approach)
- Same code, different workspace = different state, different variable values
- `terraform workspace select prod && terraform apply -var-file=prod.tfvars`
- State isolation: `s3://bucket/env:/dev/...` vs `s3://bucket/env:/prod/...`

**Why workspaces win here:**

- **Single source of truth** — one codebase, guaranteed consistency across environments
- **State isolation** — workspaces create completely separate state files, no cross-contamination
- **Variable-driven differences** — `dev.tfvars`, `test.tfvars`, `prod.tfvars` handle all environment-specific config (CIDR ranges, instance counts, etc.)
- **Automated by CI/CD** — the pipeline detects the branch and selects the correct workspace automatically

**The one tradeoff:** Workspaces are not suitable when environments have fundamentally different architectures (e.g., prod has RDS Multi-AZ but dev has no RDS at all). In that case, directories or separate repos make more sense. This project's environments are architecturally identical — only scale and CIDR differ — making workspaces the right choice.

---

### Q16. The prod environment VPC uses CIDR `10.2.0.0/16`, test uses `10.1.0.0/16`, dev uses `10.0.0.0/16`. Is this just organizational preference, or is there a technical reason?

**Answer:**

Both — but the technical reason is the more important one.

**The technical reason: VPC Peering and future connectivity**

In a production system, you often need environments to communicate. Common scenarios:
- A shared services VPC (logging, monitoring, bastion hosts) that all environments connect to
- A staging environment that needs to pull from a shared artifact store
- Direct Connect or VPN linking corporate network to AWS

VPC Peering and Transit Gateway require **non-overlapping CIDR ranges**. If dev and prod both used `10.0.0.0/16`, you could never peer them — routing would be ambiguous (which VPC does `10.0.1.50` belong to?).

By assigning non-overlapping CIDRs from the start:
- `10.0.0.0/16` → dev
- `10.1.0.0/16` → test  
- `10.2.0.0/16` → prod

You preserve the option to add VPC peering, Transit Gateway, or shared services VPCs at any point without redesigning the network.

**The organizational reason:**

It makes debugging and log analysis much easier. When you see IP `10.2.14.52` in a log, you immediately know it's a prod instance in a private subnet. You never have to ask "which environment is this?" — the IP tells you.

This is a small architectural decision made early that prevents significant pain later. IP address space planning is one of those things that's almost impossible to change after the fact without rebuilding the network.

---

## 7. Troubleshooting & Incident Scenarios

---

### Q17. You wake up to a PagerDuty alert: the ALB is returning 503 for 100% of requests in production. Walk me through your exact troubleshooting steps.

**Answer:**

**First 2 minutes — establish scope:**

```bash
# Is ALB up?
aws elbv2 describe-load-balancers --names app-load-balancer-production

# Are there any healthy targets?
TG_ARN=$(aws elbv2 describe-target-groups \
  --query "TargetGroups[?contains(TargetGroupName,'app-tg-production')].TargetGroupArn" \
  --output text)
aws elbv2 describe-target-health --target-group-arn $TG_ARN
```

**Scenario A: All targets show `unhealthy`**

This is the most common cause. Next step:
```bash
# Are instances even running?
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names app-asg-production \
  --query "AutoScalingGroups[0].Instances"
```

If instances exist but are unhealthy:
```bash
# SSH via SSM (no SSH key needed if SSM agent is installed)
aws ssm start-session --target i-xxxxxxxxxxxx

# Check nginx
sudo systemctl status nginx
sudo tail -100 /var/log/nginx/error.log
sudo tail -100 /var/log/cloud-init-output.log
```

**Scenario B: Targets healthy but still 503**

Security group issue — something changed the SG rules:
```bash
aws ec2 describe-security-groups \
  --filters "Name=tag:Name,Values=app-security-group-production"
```

Check: Does the App SG still allow inbound from ALB SG? If someone manually removed the rule, add it back and immediately investigate who made the change via CloudTrail.

**Scenario C: Recent deployment caused this**

```bash
# Check scaling activities
aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name app-asg-production --max-records 10

# Check if new Launch Template version has issues
aws ec2 describe-launch-template-versions \
  --launch-template-name app-launch-template
```

If a bad deployment is the cause, the fastest fix is to roll back the Launch Template to the last known good version and trigger an instance refresh:
```bash
aws autoscaling start-instance-refresh \
  --auto-scaling-group-name app-asg-production \
  --preferences '{"MinHealthyPercentage": 50}'
```

**Parallel action throughout:** Keep the incident channel updated every 5 minutes. Even "still investigating" updates prevent stakeholder panic and prevent multiple engineers from working the same problem independently.

---

### Q18. Your `terraform apply` fails midway through a production deployment — it created the new ALB but failed before updating the ASG. Terraform state is now partially updated. What do you do?

**Answer:**

This is one of the scarier Terraform scenarios, but it's manageable.

**Immediate assessment — don't panic and don't run anything blindly:**

```bash
# See exactly what Terraform thinks exists
terraform workspace select prod
terraform state list

# Check the actual state of the ALB that was created
terraform state show aws_lb.app_lb
```

**Understand what happened:**

Terraform applies resources in dependency order. If the ALB was created (state updated) but ASG update failed (state NOT updated for that resource), then:
- The new ALB exists in AWS ✓
- The state file reflects the new ALB ✓
- The ASG is still pointing to the old configuration
- Traffic may be going to an ALB that isn't connected to the current ASG

**The fix — re-run apply:**

```bash
terraform plan -var-file=prod.tfvars
# Review carefully — should show only the remaining changes
terraform apply -var-file=prod.tfvars
```

Terraform is **idempotent** — it will see that the ALB already exists (in state) and skip it, then apply only the ASG changes that failed. This is the designed recovery mechanism.

**If the plan shows unexpected destroy/recreate:**

This could happen if the partial failure left resources in an inconsistent state that Terraform can't reconcile. Options:
1. `terraform import` to bring existing resources into state
2. `terraform state rm` to remove the resource from state and let Terraform treat it as new
3. Manual fix in AWS + `terraform refresh` to sync state

**Prevention for the future:**
- Always have a `terraform plan -destroy` reviewed before major changes
- Use `terraform apply -target` for incremental rollouts of complex changes
- Enable S3 versioning on state bucket — you can restore previous state if needed

---

## 8. Design & Architecture Decisions

---

### Q19. Why is the S3 bucket code in `s3.tf` completely commented out? Isn't that a gap in the architecture?

**Answer:**

Yes, it's an intentional gap — and being honest about it in an interview is actually a strength.

The original S3 bucket configuration was designed to handle:
- Application static assets
- ALB access logs

However, I made the decision to comment it out for a specific reason: **this is an infrastructure repository, not an application repository.** The principle of Separation of Concerns means this repo should manage compute and networking, while static assets belong to the application layer.

Additionally, ALB access log delivery to S3 requires specific bucket policies and the correct AWS service principal for your region. Getting that right without actually testing it end-to-end would have meant shipping broken code. I chose to comment it out rather than ship untested infrastructure that would fail silently.

**What I would do in a real production system:**

```hcl
resource "aws_s3_bucket" "alb_logs" {
  bucket = "alb-logs-${var.environment}-${random_id.suffix.hex}"
}

resource "aws_s3_bucket_policy" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  policy = data.aws_iam_policy_document.alb_logs.json
}

# Enable ALB access logging
resource "aws_lb" "app_lb" {
  access_logs {
    bucket  = aws_s3_bucket.alb_logs.bucket
    enabled = true
  }
}
```

ALB access logs are critical for security forensics and traffic analysis in production — I would definitely enable them before go-live.

---

### Q20. If this infrastructure needed to serve 10x more traffic than it currently handles, what would you change in the Terraform code?

**Answer:**

Good question — this is about understanding the **scaling ceiling** of the current architecture.

**Changes I'd make, in order of impact:**

**1. Instance type upgrade**
```hcl
# variables.tf
variable "instance_type" {
  default = "t3.large"  # or c5.xlarge for CPU-intensive workloads
}
```
`t2.micro` uses burstable CPU — fine for dev, but CPU credits get exhausted under sustained load. Move to a fixed-performance instance family.

**2. Increase ASG limits**
```hcl
# prod.tfvars
min_size         = 4    # ensure baseline capacity
max_size         = 20   # allow significant scale-out
desired_capacity = 4
```

**3. Tune the target tracking policy**
The current target tracking maintains 70% CPU. At 10x traffic, you want more headroom:
```hcl
target_value = 50.0  # scale earlier, don't wait until 70%
```

**4. Add ALB sticky sessions (if the app needs it)**
For stateful applications, sticky sessions prevent session loss during scale-in events.

**5. Multi-region consideration**
At 10x traffic, you're likely also thinking about latency for global users. Route 53 with latency-based routing + replica infrastructure in a second region (e.g., eu-west-1) would be the next architectural step.

**6. Replace NAT Gateway with NAT instance (cost optimization)**
At high traffic, NAT Gateway data processing charges become significant. A NAT instance on a larger EC2 gives more control — though at the cost of managing it yourself.

**7. Separate the database tier**
The current architecture has no RDS. At 10x traffic, the application probably needs a proper database tier with read replicas, not just compute scaling.

The Terraform code is already parameterized well enough that most of these changes are `tfvars` updates — not code rewrites. That's good architecture.

---

*End of Interview Q&A*

---

> **Tip for interviews:** When answering, always tie your answer back to specific lines of code or specific decisions in the project. Saying "I used `use_lockfile = true` in `backend.tf` because..." is 10x more credible than a generic explanation of state locking. You built this — own every decision.