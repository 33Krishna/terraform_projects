# 📚 Project 15 — Concepts Guide
### Terraform Drift Detection & Auto-Remediation

---

## 📋 Table of Contents

1. [Infrastructure Drift](#1-infrastructure-drift)
2. [Terraform State & Remote Backend](#2-terraform-state--remote-backend)
3. [S3 Native State Locking](#3-s3-native-state-locking)
4. [terraform plan -detailed-exitcode](#4-terraform-plan--detailed-exitcode)
5. [GitHub Actions — Workflows & Triggers](#5-github-actions--workflows--triggers)
6. [Multi-Environment Strategy](#6-multi-environment-strategy)
7. [Auto Scaling Group & Launch Template](#7-auto-scaling-group--launch-template)
8. [Application Load Balancer & Target Groups](#8-application-load-balancer--target-groups)
9. [VPC Architecture — Public & Private Subnets](#9-vpc-architecture--public--private-subnets)
10. [NAT Gateway — High Availability Design](#10-nat-gateway--high-availability-design)
11. [Security Groups — Layered Defense](#11-security-groups--layered-defense)
12. [S3 Bucket — Hardening Best Practices](#12-s3-bucket--hardening-best-practices)
13. [GitHub Issues as Audit Trail](#13-github-issues-as-audit-trail)
14. [Slack Webhook Notifications](#14-slack-webhook-notifications)
15. [IMDSv2 — Instance Metadata Security](#15-imdsv2--instance-metadata-security)
16. [Docker on EC2 via user_data.sh](#16-docker-on-ec2-via-user_datash)
17. [ASG Scaling Policies — Conflict Problem](#17-asg-scaling-policies--conflict-problem)
18. [Destroy Workflow — Safety Gates](#18-destroy-workflow--safety-gates)

---

## 1. Infrastructure Drift

### What is it?

Drift = the gap between **what Terraform says should exist** (your `.tf` files + state)
and **what actually exists on AWS** at this moment.

### How does drift happen?

| Cause | Example |
|---|---|
| Manual AWS Console change | Someone adds an inbound rule to a Security Group |
| AWS CLI modification | `aws ec2 authorize-security-group-ingress ...` |
| Another automation tool | A compliance scanner adds tags to resources |
| Accidental deletion | Someone deletes an S3 bucket from console |
| AWS auto-modification | AWS updates a managed resource attribute |

### Why is drift dangerous?

```
Terraform state says:  Security Group → port 80 only
AWS reality says:      Security Group → port 80 + port 22 (0.0.0.0/0) ← OPEN SSH!

Next terraform apply → removes port 22 ✅
But between now and then → your infra has an unauthorized open port ❌
```

### Types of drift

- **Configuration drift** — resource exists but attributes changed (tags, rules, sizes)
- **State drift** — resource deleted manually but Terraform still tracks it in state
- **Addition drift** — new resource added outside Terraform, Terraform doesn't know about it

---

## 2. Terraform State & Remote Backend

### What is Terraform state?

Terraform maintains a `terraform.tfstate` file — a JSON snapshot of every resource
it manages. It maps your HCL code → actual AWS resource IDs.

```json
{
  "resources": [
    {
      "type": "aws_vpc",
      "name": "main",
      "instances": [
        {
          "attributes": {
            "id": "vpc-0abc123",
            "cidr_block": "10.0.0.0/16"
          }
        }
      ]
    }
  ]
}
```

Without state, Terraform wouldn't know `aws_vpc.main` maps to `vpc-0abc123` on AWS.

### Local state vs Remote state

| | Local State | Remote State (S3) |
|---|---|---|
| Storage | `terraform.tfstate` on your machine | S3 bucket |
| Team collaboration | ❌ Conflicts if two people apply | ✅ Shared single source of truth |
| CI/CD pipelines | ❌ No persistent storage between runs | ✅ Persists across GitHub Actions runners |
| Locking | ❌ No locking | ✅ Prevents concurrent modifications |
| Backup | ❌ Single point of failure | ✅ S3 versioning enabled |
| Encryption | ❌ Plaintext on disk | ✅ AES-256 at rest |

### How this project configures it

```hcl
# backend.tf — tells Terraform to use S3
terraform {
  backend "s3" {}  # actual values come from .hcl files at init time
}

# backend-dev.hcl
bucket       = "33Krishna-terraform-state"
key          = "dev/terraform.tfstate"
region       = "us-east-1"
use_lockfile = true
encrypt      = true

# backend-prod.hcl
bucket       = "33Krishna-terraform-state"
key          = "prod/terraform.tfstate"  # separate key = separate state
region       = "us-east-1"
use_lockfile = true
encrypt      = true
```

```bash
# How it's initialized per environment
terraform init -backend-config="backend-dev.hcl"
terraform init -backend-config="backend-prod.hcl"
```

---

## 3. S3 Native State Locking

### The problem without locking

```
Time 10:00 — GitHub Actions Workflow A starts terraform apply
Time 10:01 — GitHub Actions Workflow B also starts terraform apply
Time 10:02 — Both read the same state file
Time 10:05 — Both write different state files → STATE CORRUPTION ❌
```

### Old solution: DynamoDB locking

Previously, teams used a DynamoDB table to store a lock record.
Terraform would write a lock entry before apply, delete it after.
Required maintaining an extra AWS resource.

### New solution: S3 Native Locking (Terraform 1.10.0+)

```hcl
use_lockfile = true  # that's it — no DynamoDB needed
```

**How it works:**

```
terraform apply starts
    ↓
Creates: s3://bucket/dev/terraform.tfstate.tflock
Content: { "ID": "abc123", "Who": "github-actions", "Operation": "Apply" }
    ↓
Another workflow tries to apply
    ↓
Sees .tflock file → fails with "State is locked" error
    ↓
First apply completes → deletes terraform.tfstate.tflock
    ↓
Now second workflow can proceed
```

### Benefits over DynamoDB

| | DynamoDB Locking | S3 Native Locking |
|---|---|---|
| Extra resource needed | ✅ Yes (DynamoDB table) | ❌ No |
| Cost | ~$0.00065/write | Free (S3 PUT) |
| Setup complexity | Higher | Just `use_lockfile = true` |
| Min Terraform version | Any | 1.10.0+ |

---

## 4. terraform plan -detailed-exitcode

### This is the heart of drift detection

Normal `terraform plan` always exits with code 0 (success) even if changes are found.
That makes it useless for automation — you can't tell if drift was found or not.

### Exit codes with `-detailed-exitcode`

| Exit Code | Meaning | Action |
|---|---|---|
| `0` | Success, no changes | Infrastructure in sync ✅ |
| `1` | Error | Plan failed, something is wrong ❌ |
| `2` | Success, changes present | Drift detected ⚠️ |

### How the workflow captures it

```yaml
- name: Terraform Plan (Drift Detection)
  id: plan
  run: |
    set +e                                          # Don't exit on non-zero codes
    terraform plan -detailed-exitcode -no-color > plan_output.txt 2>&1
    EXIT_CODE=$?                                    # Capture the actual exit code
    echo "exitcode=$EXIT_CODE" >> $GITHUB_OUTPUT    # Pass it to next steps
    cat plan_output.txt                             # Show in logs
    exit 0                                          # Step always "succeeds"
```

### Why `set +e` and `exit 0`?

Without `set +e` — bash exits immediately when it sees exit code 2.
Without `exit 0` — GitHub Actions marks the step as failed, stops the workflow.
With both — workflow continues to the remediation logic regardless of exit code.

### Conditional steps based on exit code

```yaml
- name: Auto-Fix Drift
  if: steps.plan.outputs.exitcode == '2'   # Only runs on drift
  run: terraform apply -auto-approve

- name: No Drift
  if: steps.plan.outputs.exitcode == '0'   # Only runs when clean

- name: Terraform Plan Failure
  if: steps.plan.outputs.exitcode == '1'   # Only runs on error
  run: exit 1
```

---

## 5. GitHub Actions — Workflows & Triggers

### Three trigger types used in this project

#### 1. Push trigger

```yaml
on:
  push:
    branches:
      - main   # prod deploy
      - dev    # dev deploy
```

Fires when code is merged/pushed to these branches. Used in `terraform.yml`.

#### 2. Schedule trigger (Cron)

```yaml
on:
  schedule:
    - cron: "*/1 * * * *"  # every 1 minute
```

Cron syntax: `minute hour day month weekday`

| Field | Value | Meaning |
|---|---|---|
| `*/1` | minute | Every 1 minute |
| `*` | hour | Any hour |
| `*` | day | Any day |
| `*` | month | Any month |
| `*` | weekday | Any weekday |

**Important:** Scheduled workflows only run on the **default branch** (main).
Dev environment drift detection requires manual trigger.

#### 3. Manual trigger (workflow_dispatch)

```yaml
on:
  workflow_dispatch:
    inputs:
      environment:
        type: choice
        options: [dev, prod]
      confirmation:
        type: string
        required: true
```

Adds a "Run workflow" button in GitHub Actions UI.
Inputs become selectable fields/text boxes in the UI.

### Artifact passing between jobs

Plan job and Apply job run on **different VMs** — no shared filesystem.
Artifacts bridge this gap:

```yaml
# Job 1: Upload plan
- uses: actions/upload-artifact@v4
  with:
    name: tfplan-dev
    path: tfplan
    retention-days: 5

# Job 2: Download plan (on fresh VM)
- uses: actions/download-artifact@v4
  with:
    name: tfplan-dev
```

### Job dependency

```yaml
terraform-apply:
  needs: terraform-plan                                    # Wait for plan job
  if: github.event_name == 'push'                         # Only on push, not PR
     && needs.terraform-plan.result == 'success'          # Only if plan passed
```

---

## 6. Multi-Environment Strategy

### How one codebase serves two environments

```
Branch: dev  → ENVIRONMENT=dev  → backend-dev.hcl  → s3/.../dev/terraform.tfstate
Branch: main → ENVIRONMENT=prod → backend-prod.hcl → s3/.../prod/terraform.tfstate
```

### Environment detection logic in workflows

```yaml
- name: Determine Environment
  run: |
    if [[ "${{ github.ref_name }}" == "main" ]]; then
      echo "ENVIRONMENT=prod" >> $GITHUB_ENV
    else
      echo "ENVIRONMENT=dev" >> $GITHUB_ENV
    fi
```

### GitHub Environments (for approval gates)

```yaml
jobs:
  terraform-apply:
    environment: ${{ needs.terraform-plan.outputs.environment }}
```

When `environment: prod` is set on a job, GitHub can require:
- Manual reviewer approval before the job runs
- Wait timers
- Environment-specific secrets

This means a prod deployment **pauses and waits** for a human to approve
before `terraform apply` executes — zero accidental prod changes.

### State isolation benefit

```
Dev developer breaks something → only dev/terraform.tfstate affected
Prod is completely untouched   → separate state file, separate AWS resources
```

---

## 7. Auto Scaling Group & Launch Template

### Launch Template

Defines **what** each EC2 instance looks like when it launches:

```hcl
resource "aws_launch_template" "app" {
  image_id      = var.ami_id         # Which OS (Ubuntu 22.04)
  instance_type = var.instance_type  # t2.micro

  vpc_security_group_ids = [
    aws_security_group.app_sg.id,    # Allow ALB → EC2 traffic
    aws_security_group.allow_ssh.id  # SSH access
  ]

  user_data = filebase64("scripts/user_data.sh")  # Bootstrap script

  metadata_options {
    http_tokens = "required"  # IMDSv2 enforced
  }
}
```

### Auto Scaling Group

Defines **how many** instances to run and **where**:

```hcl
resource "aws_autoscaling_group" "app_asg" {
  min_size         = 1  # Never go below 1
  max_size         = 5  # Never go above 5
  desired_capacity = 2  # Start with 2

  vpc_zone_identifier = aws_subnet.private[*].id  # Private subnets only

  target_group_arns = [aws_lb_target_group.app_tg.arn]  # Register with ALB
  health_check_type = "ELB"  # ALB decides if instance is healthy
}
```

### Scaling flow

```
Normal load  → 2 instances running
CPU > 80%    → CloudWatch alarm fires → scale_out policy → +1 instance
CPU < 20%    → CloudWatch alarm fires → scale_in policy  → -1 instance
Max reached  → No more scaling even if CPU is 100%
```

### ELB health check vs EC2 health check

| | EC2 Health Check | ELB Health Check |
|---|---|---|
| What it checks | Is the VM running? | Is the app responding on port 80? |
| Use case | Basic VM monitoring | Production apps |
| When instance replaced | VM crashes | VM up but app crashed |

---

## 8. Application Load Balancer & Target Groups

### ALB components

```
Internet
  ↓
ALB (public subnet, port 80/443)
  ↓
Listener (port 80 → forward)
  ↓
Target Group (tracks healthy EC2 instances)
  ↓
EC2 instances (private subnet, port 80)
```

### Target Group health check

```hcl
health_check {
  path                = "/"    # Hit this URL
  interval            = 30     # Every 30 seconds
  timeout             = 5      # Wait 5s for response
  healthy_threshold   = 2      # 2 consecutive successes = healthy
  unhealthy_threshold = 2      # 2 consecutive failures = unhealthy
}
```

If an instance fails health checks → ALB stops sending traffic to it →
ASG detects unhealthy instance → terminates and replaces it automatically.

### Why ALB over Classic LB?

| Feature | Classic LB | ALB |
|---|---|---|
| Layer | Layer 4 (TCP) | Layer 7 (HTTP/HTTPS) |
| Path-based routing | ❌ | ✅ `/api/*` → backend |
| Host-based routing | ❌ | ✅ `api.domain.com` → backend |
| WebSockets | ❌ | ✅ |
| Cost | Lower | Slightly higher |

---

## 9. VPC Architecture — Public & Private Subnets

### This project's network layout

```
VPC: 10.0.0.0/16
│
├── Public Subnet AZ1: 10.0.1.0/24   ← NAT Gateway 1, ALB node
├── Public Subnet AZ2: 10.0.2.0/24   ← NAT Gateway 2, ALB node
│
├── Private Subnet AZ1: 10.0.11.0/24 ← EC2 instances (app)
└── Private Subnet AZ2: 10.0.12.0/24 ← EC2 instances (app)
```

### Public subnet = has route to Internet Gateway

```hcl
resource "aws_route" "public" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id  # Direct internet
}
```

### Private subnet = has route to NAT Gateway only

```hcl
resource "aws_route" "private" {
  count                  = var.private_subnet_count
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[count.index].id  # Outbound only
}
```

### Why put EC2 in private subnets?

```
Public subnet EC2: Internet → EC2 directly (attackers can reach your instance)
Private subnet EC2: Internet → ALB → EC2 (ALB is the only entry point)
```

EC2 instances in private subnets still have outbound internet via NAT Gateway
(to pull Docker images, run updates) but nobody from the internet can reach them directly.

---

## 10. NAT Gateway — High Availability Design

### Single NAT Gateway problem

```
AZ1: Private Subnet → NAT Gateway (public subnet AZ1) → Internet
AZ2: Private Subnet → same NAT Gateway in AZ1 → Internet

If AZ1 goes down → NAT Gateway gone → AZ2 instances lose internet too ❌
Cross-AZ traffic also costs money
```

### This project: One NAT Gateway per AZ

```hcl
resource "aws_nat_gateway" "main" {
  count         = var.private_subnet_count  # 2 NAT Gateways
  allocation_id = aws_eip.main[count.index].id
  subnet_id     = aws_subnet.public[count.index].id  # One per public subnet
}

resource "aws_route" "private" {
  count          = var.private_subnet_count
  nat_gateway_id = aws_nat_gateway.main[count.index].id  # Each AZ uses its own
}
```

```
AZ1: Private Subnet → NAT GW 1 (AZ1) → Internet ✅
AZ2: Private Subnet → NAT GW 2 (AZ2) → Internet ✅

AZ1 goes down → AZ2 unaffected, has its own NAT GW ✅
No cross-AZ NAT traffic → no extra data transfer cost ✅
```

---

## 11. Security Groups — Layered Defense

### Three security groups in this project

#### ALB Security Group — faces the internet

```hcl
ingress port 80  from 0.0.0.0/0   # HTTP from anywhere ✅
ingress port 443 from 0.0.0.0/0   # HTTPS from anywhere ✅
egress  all      to   0.0.0.0/0   # Forward to EC2
```

#### App Security Group — faces only the ALB

```hcl
ingress port 80  from alb_sg  # Only ALB can reach EC2 on port 80 ✅
ingress port 443 from alb_sg  # Only ALB can reach EC2 on port 443 ✅
egress  all      to 0.0.0.0/0 # EC2 can reach internet (via NAT for Docker pull)
```

Using `security_groups = [aws_security_group.alb_sg.id]` instead of a CIDR block
means EC2 only accepts traffic from the specific ALB — even if ALB IP changes, the rule still works.

#### SSH Security Group — biggest bug in this project

```hcl
ingress port 22 from 0.0.0.0/0  # ❌ ANYONE can SSH into production EC2
```

Production fix: Use AWS SSM Session Manager — no SSH port needed at all.

### Security group chaining

```
User → ALB (0.0.0.0/0 → port 80) → EC2 (alb_sg → port 80) → App
         ↑                              ↑
    Allows internet             Only allows traffic from ALB SG
```

---

## 12. S3 Bucket — Hardening Best Practices

### What this project creates for the app bucket

```hcl
# Versioning — recover from accidental deletes/overwrites
aws_s3_bucket_versioning → status = "Enabled"

# Encryption — data at rest encrypted
aws_s3_bucket_server_side_encryption_configuration → sse_algorithm = "AES256"

# Block all public access — 4 settings, all true
aws_s3_bucket_public_access_block → block_public_acls       = true
                                   → block_public_policy     = true
                                   → ignore_public_acls      = true
                                   → restrict_public_buckets = true

# Ownership controls — object ownership to bucket owner
aws_s3_bucket_ownership_controls → object_ownership = "BucketOwnerPreferred"
```

### The ACL deprecation issue (Bug-03 in this project)

AWS disabled ACL-based access by default in April 2023 for new buckets.
`BucketOwnerEnforced` is now the recommended setting — ACLs ignored completely.

```hcl
# ❌ Old way — ACL resource (deprecated for new accounts)
resource "aws_s3_bucket_acl" "my_bucket" {
  acl = "private"
}

# ✅ New way — ownership controls enforce bucket owner
resource "aws_s3_bucket_ownership_controls" "my_bucket" {
  rule {
    object_ownership = "BucketOwnerEnforced"  # No ACL support
  }
}
```

---

## 13. GitHub Issues as Audit Trail

### Why GitHub Issues for infrastructure events?

Most drift detection tools just log to CloudWatch or Slack — messages get lost.
GitHub Issues give you a **permanent, searchable, commentable record**.

### Automated issue lifecycle

```
Drift detected (exit code 2)
    ↓
Check: Is there already an open issue for this environment?
    ├── YES → Add comment (prevents issue spam)
    └── NO  → Create new issue with:
              - Full terraform plan diff
              - Timestamp
              - Workflow run link
              - Environment label
    ↓
terraform apply runs
    ├── Success → Comment "✅ Remediated" + Close issue
    └── Failure → Comment "❌ Manual fix needed" + Keep open
    ↓
Next run, no drift (exit code 0)
    ↓
Find all open drift issues for environment → Close them all
```

### Deduplication logic

```javascript
const existingIssue = issues.data.find(issue =>
  issue.title.includes(`Terraform Drift Detected [${env}]`)
);

if (existingIssue) {
  // Add comment — don't create duplicate
  await github.rest.issues.createComment({ ... });
} else {
  // First time — create new issue
  await github.rest.issues.create({ ... });
}
```

---

## 14. Slack Webhook Notifications

### How Slack webhooks work

```
GitHub Actions → HTTP POST → Slack Webhook URL → Slack Channel
```

No OAuth, no bot setup — just a URL that accepts JSON payloads.

### Webhook payload structure

```json
{
  "text": "✅ Terraform Drift Auto-Fixed",
  "blocks": [
    {
      "type": "header",
      "text": { "type": "plain_text", "text": "✅ Drift Fixed" }
    },
    {
      "type": "section",
      "text": {
        "type": "mrkdwn",
        "text": "*Environment:* prod\n*Workflow:* <url|View Run>"
      }
    }
  ]
}
```

### Three notification scenarios

| Scenario | Trigger | Message |
|---|---|---|
| Drift fixed | `exitcode == '2'` AND apply success | ✅ Auto-Fixed |
| Auto-fix failed | `exitcode == '2'` AND apply failure | ❌ Manual intervention needed |
| Infrastructure destroyed | After destroy workflow | ✅/❌ Destroy status |

### Secret management

```yaml
env:
  SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}

run: |
  if [ -z "$SLACK_WEBHOOK_URL" ]; then
    echo "Slack not configured, skipping"
    exit 0
  fi
  curl -X POST $SLACK_WEBHOOK_URL -H 'Content-Type: application/json' -d '{...}'
```

URL stored as GitHub Secret — never exposed in logs.
`-z` check ensures workflow doesn't fail if Slack isn't configured.

---

## 15. IMDSv2 — Instance Metadata Security

### What is IMDS?

Instance Metadata Service (IMDS) — an HTTP endpoint at `169.254.169.254` that
every EC2 instance can call to get its own metadata (IAM role credentials, instance ID, etc.)

```bash
# From inside EC2:
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/
# Returns temporary AWS credentials for the instance's IAM role
```

### IMDSv1 vulnerability — SSRF attack

```
Attacker finds SSRF vulnerability in your app
    ↓
App makes HTTP request to: http://169.254.169.254/latest/meta-data/iam/security-credentials/
    ↓
Returns IAM role credentials
    ↓
Attacker now has AWS access with your EC2's IAM permissions ❌
```

This is how the 2019 Capital One breach happened.

### IMDSv2 — session-based, blocks SSRF

```bash
# Step 1: Get session token (requires PUT, SSRF usually does GET)
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

# Step 2: Use token in request
curl -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/
```

SSRF vulnerabilities typically only allow GET requests — the PUT requirement
for IMDSv2 token blocks most SSRF exploits.

### How this project enforces it

```hcl
metadata_options {
  http_endpoint               = "enabled"
  http_tokens                 = "required"  # IMDSv2 mandatory — v1 blocked
  http_put_response_hop_limit = 1           # Blocks container-to-host metadata access
}
```

---

## 16. Docker on EC2 via user_data.sh

### What user_data does

`user_data` is a script that runs **once** when the EC2 instance first boots.
Used to bootstrap the instance — install software, start services.

```bash
#!/bin/bash
apt-get update -y
apt-get install -y docker.io       # Install Docker
systemctl start docker             # Start Docker daemon
systemctl enable docker            # Auto-start on reboot
usermod -aG docker ubuntu          # ubuntu user can run docker without sudo

docker run -d \
  --name django-app \
  --restart always \              # Auto-restart if container crashes
  -p 80:8000 \                    # Map host port 80 → container port 8000
  33Krishna/django-app            # Pull from DockerHub
```

### Port mapping explained

```
Internet → ALB (port 80) → EC2 host (port 80) → Docker container (port 8000) → Django app
                                      ↑
                              -p 80:8000 maps here
```

Django default port is 8000. ALB sends traffic to port 80.
Docker port mapping bridges the gap without changing the app.

### `--restart always` importance

```
EC2 reboots → Docker daemon starts → container auto-starts → app available ✅
Container crashes → Docker detects → automatically restarts container ✅
```

Without `--restart always` — after any reboot or crash, the container stays stopped
and your app goes down until someone manually starts it.

### `filebase64()` in Terraform

```hcl
user_data = filebase64("${path.module}/scripts/user_data.sh")
```

EC2 expects `user_data` as base64-encoded string.
`filebase64()` reads the file and encodes it automatically.

---

## 17. ASG Scaling Policies — Conflict Problem

### Three types of scaling policies

#### Simple Scaling

```hcl
resource "aws_autoscaling_policy" "scale_out" {
  scaling_adjustment = 1               # Add 1 instance
  adjustment_type    = "ChangeInCapacity"
  cooldown           = 300             # Wait 5 min before scaling again
}
```

Triggered by CloudWatch alarm. After scaling, waits `cooldown` seconds before allowing another scale.

#### Target Tracking Scaling

```hcl
resource "aws_autoscaling_policy" "target_tracking" {
  policy_type = "TargetTrackingScaling"
  target_tracking_configuration {
    predefined_metric_type = "ASGAverageCPUUtilization"
    target_value           = 70.0  # Keep CPU around 70%
  }
}
```

AWS manages scaling automatically to maintain the target metric.
Creates its own CloudWatch alarms internally — you don't manage them.

#### The conflict in this project

```
Target Tracking: "I'll manage CPU, scale as needed to keep it at 70%"
Simple Scaling:  CloudWatch alarm fires at 80% CPU → adds instance
Target Tracking: Also fires because CPU > 70% → adds another instance
Result:          Both policies fight each other → unpredictable scaling ❌
```

AWS documentation explicitly warns against mixing these two types.

**Fix:** Pick one. Target Tracking is recommended for most use cases.

---

## 18. Destroy Workflow — Safety Gates

### Why a dedicated destroy workflow?

`terraform destroy` in CI/CD without safety gates = production disaster waiting to happen.
One wrong branch push could wipe your entire infrastructure.

### Three layers of protection

#### Layer 1: Manual trigger only

```yaml
on:
  workflow_dispatch:  # No push, no schedule — humans only
```

Cannot be triggered accidentally by code changes.

#### Layer 2: Typed confirmation

```yaml
inputs:
  confirm_destroy:
    description: 'Type "DESTROY" to confirm'
    required: true
    type: string
```

```yaml
- name: Verify Destroy Confirmation
  run: |
    if [ "${{ inputs.confirm_destroy }}" != "DESTROY" ]; then
      echo "❌ Must type DESTROY exactly"
      exit 1
    fi
```

Case-sensitive exact match. "destroy", "Destroy", "DESTORY" all fail.

#### Layer 3: Environment approval gate

```yaml
environment: ${{ inputs.environment }}
```

If GitHub Environment "prod" is configured with required reviewers,
the workflow pauses here and emails the reviewer for approval.
The reviewer can see the plan before approving.

### Audit trail

Every destroy creates a GitHub Issue:

```
Title: ✅ Infrastructure Destroyed: prod
Body:  Triggered by: @username
       Timestamp: 2025-12-24 14:30:00 UTC
       Destroy output: [full terraform destroy log]
```

This record exists permanently — compliance and forensics purposes.

---

## 🧠 Quick Revision — Key Numbers & Facts

| Topic | Key Fact |
|---|---|
| Drift detection frequency | Every 1 minute (cron `*/1 * * * *`) |
| Exit code for drift | `2` (not 1, not 0) |
| S3 native locking | Terraform 1.10.0+ required |
| NAT Gateways | 2 (one per AZ for HA) |
| ASG sizing | Min: 1, Desired: 2, Max: 5 |
| Scale out threshold | CPU > 80% |
| Scale in threshold | CPU < 20% |
| ALB health check interval | 30 seconds |
| Docker port mapping | Host 80 → Container 8000 |
| State lock file | `terraform.tfstate.tflock` |
| IMDS version enforced | v2 (`http_tokens = "required"`) |
| Destroy confirmation word | `DESTROY` (exact, case-sensitive) |

---

*Project 15 — Terraform Drift Detection & Auto-Remediation*