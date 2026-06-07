# 🎯 Project 15 — Interview Q&A
### Terraform Drift Detection & Auto-Remediation

---

## 📋 Table of Contents

- [🟢 Beginner — Conceptual Understanding](#-beginner--conceptual-understanding)
- [🟡 Intermediate — Implementation Details](#-intermediate--implementation-details)
- [🔴 Advanced — Design Decisions & Trade-offs](#-advanced--design-decisions--trade-offs)
- [⚡ Rapid Fire — Quick Answers](#-rapid-fire--quick-answers)

---

## 🟢 Beginner — Conceptual Understanding

---

**Q1. What is infrastructure drift and why is it a problem?**

**A.**
Infrastructure drift is the gap between what your Terraform code defines as the desired state and what is actually running on AWS at any given moment.

It becomes a problem for several reasons. First, it creates a security risk — if someone manually opens a port like SSH on port 22 to 0.0.0.0/0, that change bypasses your code review and approval process entirely. Second, it breaks the principle of infrastructure as code — if your code no longer reflects reality, you cannot trust it for disaster recovery or environment replication. Third, it causes unpredictable behavior on the next `terraform apply` — Terraform may try to revert those manual changes and disrupt running services if not handled carefully.

Real-world example: a developer manually increases an EC2 instance type from t2.micro to t2.large for debugging. The next Terraform apply reverts it back to t2.micro — and the developer wonders why performance dropped again.

---

**Q2. How does this project detect drift?**

**A.**
The project uses a GitHub Actions scheduled workflow that runs every minute. The core of detection is the command:

```bash
terraform plan -detailed-exitcode
```

The `-detailed-exitcode` flag changes the behavior of `terraform plan` to return three distinct exit codes instead of just 0 or 1:

- Exit code `0` — plan succeeded, no changes needed, infrastructure is in sync
- Exit code `1` — plan failed due to an error (bad config, API failure, etc.)
- Exit code `2` — plan succeeded and detected changes, meaning drift exists

The workflow captures this exit code and uses it to conditionally trigger auto-remediation. If exit code is 2, it runs `terraform apply -auto-approve` to restore the desired state.

---

**Q3. What is Terraform state and why is it important?**

**A.**
Terraform state is a JSON file (`terraform.tfstate`) that maps your HCL resource definitions to actual cloud resource IDs. For example, it records that `aws_vpc.main` corresponds to `vpc-0abc1234def` on AWS.

Without state, Terraform would have no way to know which real resources it manages. Every `terraform apply` would try to create everything from scratch, resulting in duplicate resources and conflicts.

In this project, state is stored remotely in an S3 bucket instead of locally. This is critical for two reasons — first, GitHub Actions runners are ephemeral, meaning there is no persistent filesystem between workflow runs. Second, remote state allows multiple people or workflows to share the same state file safely, with locking to prevent concurrent modifications from corrupting it.

---

**Q4. What is the difference between `terraform plan` and `terraform apply`?**

**A.**
`terraform plan` is a dry run. It reads your configuration files, queries the current state from the backend, refreshes actual resource attributes from AWS, and generates an execution plan showing exactly what will be created, modified, or destroyed. It makes no changes to any infrastructure.

`terraform apply` executes that plan. It provisions, modifies, or destroys resources on AWS and updates the state file to reflect the new reality.

In this project, the CI/CD workflow separates them intentionally — the Plan job runs first and uploads a binary plan artifact. The Apply job downloads that exact artifact and applies it. This ensures the plan reviewed by a human is the exact same plan executed — no surprises between the two steps.

---

**Q5. Why are EC2 instances placed in private subnets instead of public subnets?**

**A.**
Private subnets have no direct route to the internet — their route table points to a NAT Gateway, not an Internet Gateway. This means no one from the internet can initiate a connection to an EC2 instance in a private subnet.

The Application Load Balancer sits in the public subnet and is the only entry point for external traffic. It forwards valid requests to the EC2 instances in the private subnets. This creates a layered security model — even if an attacker knows the EC2 instance's private IP, they cannot reach it directly.

The instances still have outbound internet access through the NAT Gateway, which they need to pull Docker images from DockerHub and install updates. NAT Gateway allows outbound-initiated traffic but blocks all inbound-initiated connections.

---

**Q6. What is a NAT Gateway and why does this project use two of them?**

**A.**
A NAT Gateway enables instances in a private subnet to initiate outbound connections to the internet while preventing the internet from initiating inbound connections to those instances. It sits in a public subnet and translates private IPs to its own public Elastic IP for outbound traffic.

This project uses two NAT Gateways — one per Availability Zone — for high availability. If you use a single NAT Gateway in AZ1 and AZ1 experiences an outage, all instances in both AZs lose outbound internet access. With one NAT Gateway per AZ, each AZ is self-sufficient. An AZ1 outage only affects AZ1 instances — AZ2 continues working independently through its own NAT Gateway.

There is also a cost benefit — inter-AZ data transfer is charged by AWS. With a single NAT Gateway, traffic from AZ2 to the internet crosses into AZ1, incurring cross-AZ data transfer fees. With per-AZ NAT Gateways, each AZ's traffic stays local.

---

## 🟡 Intermediate — Implementation Details

---

**Q7. Walk me through what happens step by step when drift is detected in this project.**

**A.**
Here is the complete flow from trigger to resolution:

**Step 1 — Trigger:** The GitHub Actions cron scheduler fires every minute on the main branch (production environment).

**Step 2 — Setup:** The workflow checks out code, determines the environment is `prod` based on branch name, configures AWS credentials from GitHub Secrets, installs Terraform 1.10.3, and runs `terraform init` with the production backend config.

**Step 3 — Detection:** `terraform plan -detailed-exitcode` runs. Terraform queries AWS APIs to compare actual resource state against the state file and desired configuration. It returns exit code 2 if any difference exists.

**Step 4 — Issue creation:** A GitHub Actions script checks if there is already an open GitHub Issue for the `prod` environment with the `drift-detection` label. If yes, it adds a comment with the new plan diff. If no, it creates a new issue with the full plan output, timestamp, environment tag, and a link to the workflow run.

**Step 5 — Auto-remediation:** `terraform apply -auto-approve` runs. Terraform acquires the S3 state lock, executes the changes to restore desired state, updates the state file, and releases the lock.

**Step 6 — Notification:** A Slack message is sent via webhook with the outcome — either success or failure.

**Step 7 — Issue closure:** If apply succeeded, the workflow finds the open drift issue and posts a comment confirming remediation, then closes it. If apply failed, the issue stays open for manual intervention.

---

**Q8. Why does the drift detection workflow use `set +e` and `exit 0` around the terraform plan command?**

**A.**
By default, bash exits immediately when any command returns a non-zero exit code — this is the `set -e` behavior that is implicitly active. Similarly, GitHub Actions marks a step as failed if it exits with a non-zero code and stops the workflow.

The problem is that `terraform plan -detailed-exitcode` intentionally exits with code 2 when it detects changes. This is not an error — it is meaningful signal that drift was found. Without special handling, both bash and GitHub Actions would treat exit code 2 as a failure and stop execution before the auto-remediation steps run.

`set +e` disables the bash exit-on-error behavior, allowing the script to continue after the exit code 2 from terraform plan. The exit code is then captured into a variable using `$?` and passed to subsequent steps via `$GITHUB_OUTPUT`.

`exit 0` at the end of the step ensures GitHub Actions considers the step successful, allowing the workflow to continue to conditional remediation steps that check `if: steps.plan.outputs.exitcode == '2'`.

---

**Q9. How does S3 native state locking work and why is it better than DynamoDB locking?**

**A.**
S3 native state locking, introduced in Terraform 1.10.0, uses a `.tflock` file stored in the same S3 bucket as the state file. When a Terraform operation starts, it creates `terraform.tfstate.tflock` with a JSON payload containing the lock ID, operation type, and who acquired it. Before any other operation can proceed, it checks for this lock file's existence. If the lock exists, the operation fails with a "state is locked" error. When the operation completes, the lock file is deleted.

Compared to DynamoDB locking, S3 native locking has three advantages. First, it eliminates an extra AWS resource to provision and maintain — no DynamoDB table, no table configuration, no IAM permissions for DynamoDB. Second, it reduces cost — S3 PUT operations for lock files are essentially free at this scale, while DynamoDB has read/write capacity unit costs. Third, it simplifies setup — `use_lockfile = true` in the backend config is the only change needed.

The trade-off is the minimum Terraform version requirement of 1.10.0. Projects on older Terraform versions must still use DynamoDB.

---

**Q10. How does the project handle multiple environments from the same Terraform codebase?**

**A.**
The project uses environment-specific backend configuration files — `backend-dev.hcl` and `backend-prod.hcl`. These files specify different S3 keys for the state file:

- Dev: `dev/terraform.tfstate`
- Prod: `prod/terraform.tfstate`

At initialization time, the workflow passes the appropriate backend config:

```bash
terraform init -backend-config="backend-${ENVIRONMENT}.hcl"
```

The environment is determined by branch name — the `main` branch maps to prod and any other branch maps to dev. This means dev and prod have completely separate state files, separate AWS resources with environment-specific naming via the `environment` variable, and separate drift detection runs that never interfere with each other.

GitHub Environments add another layer — the Apply job declares `environment: prod` for main branch deployments, enabling required reviewer approvals before any production changes are applied.

---

**Q11. Explain the ALB and Target Group relationship in this project.**

**A.**
The Application Load Balancer, Target Group, and Listener work together as three distinct components.

The ALB is the entry point — it sits in the public subnets, has a public DNS name, and accepts incoming HTTP traffic on port 80. It holds the security group that allows internet traffic.

The Listener is attached to the ALB and defines what to do with incoming traffic. In this project, the listener on port 80 has a default action of `forward` to the Target Group.

The Target Group is a logical group of EC2 instances that should receive traffic. It defines the health check — hitting the `/` path on port 80 every 30 seconds, requiring 2 consecutive successes to mark an instance healthy and 2 failures to mark it unhealthy. The Auto Scaling Group registers its instances with this Target Group automatically via `target_group_arns`.

The flow is: User request → ALB → Listener evaluates rules → forwards to Target Group → Target Group selects a healthy registered instance → request reaches EC2.

Using `health_check_type = "ELB"` on the ASG means the ASG trusts the ALB's health assessment — if the ALB marks an instance unhealthy because the app is not responding, the ASG terminates and replaces that instance even if the EC2 VM itself is technically running.

---

**Q12. What is IMDSv2 and why is it enforced in this project?**

**A.**
IMDS stands for Instance Metadata Service — an HTTP endpoint at `169.254.169.254` accessible only from within an EC2 instance. Applications and the AWS SDK use it to retrieve temporary IAM credentials, instance ID, region, and other metadata without needing static credentials.

IMDSv1 had a critical vulnerability — any HTTP GET request to that endpoint returned credentials. This meant Server-Side Request Forgery (SSRF) vulnerabilities in web applications could be exploited to steal IAM credentials. The attacker tricks the app into making a request to `169.254.169.254/latest/meta-data/iam/security-credentials/` and returns the credentials to the attacker. This is exactly how the Capital One breach occurred in 2019.

IMDSv2 requires a session token obtained via a PUT request before any metadata can be retrieved. SSRF vulnerabilities typically only allow GET requests — the PUT requirement blocks most SSRF exploits from reaching the metadata service.

In this project, IMDSv2 is enforced at the Launch Template level:

```hcl
metadata_options {
  http_tokens                 = "required"  # IMDSv1 requests rejected
  http_put_response_hop_limit = 1           # Blocks container-to-host metadata access
}
```

`http_put_response_hop_limit = 1` means the token response will not traverse more than one network hop — preventing containers running on the EC2 from accessing the host's metadata service.

---

**Q13. Why does the destroy workflow require typing "DESTROY" as confirmation?**

**A.**
The confirmation requirement is a deliberate friction mechanism modeled after production engineering best practices. It serves two purposes.

First, it prevents accidental destruction. In GitHub Actions, `workflow_dispatch` shows a UI with dropdowns and text fields. Someone could select the wrong environment or click run without reading the confirmation field — the exact string match "DESTROY" ensures they have consciously read and typed the confirmation.

Second, it creates intent accountability. GitHub logs who triggered the workflow, what inputs were provided, and when. Combined with the GitHub Issue created after destruction that records the actor and timestamp, there is a complete audit trail of who destroyed what and when — critical for compliance and post-incident reviews.

The validation in the workflow exits with code 1 if the confirmation does not match exactly, including case sensitivity. "destroy", "Destroy", "DELETE" all fail. This small gate has prevented many accidental infrastructure wipeouts in real teams.

---

## 🔴 Advanced — Design Decisions & Trade-offs

---

**Q14. The project has a drift detection interval of 1 minute. What are the trade-offs of this choice and how would you change it for production?**

**A.**
A 1-minute interval is appropriate for a demonstration — it makes drift detection visible quickly for demo purposes. However, it has real trade-offs for a production system.

On the cost side, each workflow run initializes Terraform, downloads the AWS provider (~400MB), and makes multiple AWS API calls to refresh resource state. At 1440 runs per day, this creates significant GitHub Actions minutes consumption and AWS API call volume. AWS enforces API rate limits per service — frequent terraform plan runs across multiple environments could hit EC2 or ELB describe limits.

On the noise side, some resources naturally drift and re-sync within minutes — for example, ASG instances being replaced during a scaling event. A 1-minute interval might detect this mid-transition drift and attempt remediation before the ASG completes its own self-healing, potentially causing conflicts.

For production, I would use one of these approaches based on risk tolerance. For a security-focused environment, 5 to 15 minutes is a reasonable compromise — fast enough to catch unauthorized changes before they cause damage, slow enough to avoid API throttling. For standard operations, daily scheduled runs at off-peak hours (say 8 AM UTC) combined with event-driven triggers — running drift detection after any CloudTrail event that modifies a resource — provides better signal-to-noise ratio than time-based polling.

---

**Q15. There is a conflict between Target Tracking and Simple Scaling policies in this project. How would you fix it and why?**

**A.**
The project defines both a Target Tracking policy targeting 70% CPU and Simple Scaling policies triggered by CloudWatch alarms at 80% (scale out) and 20% (scale in) CPU thresholds.

This creates a conflict because Target Tracking manages its own CloudWatch alarms internally and scales proactively to maintain the target metric. When CPU rises above 70%, Target Tracking is already adding instances. The Simple Scaling CloudWatch alarm at 80% also fires — now two policies are simultaneously adding instances. The cooldown period on Simple Scaling (300 seconds) does not apply to Target Tracking, so you get unpredictable, overlapping scaling actions.

AWS documentation explicitly states that mixing Target Tracking with Simple or Step Scaling on the same metric causes conflicts and should be avoided.

The fix is to remove the Simple Scaling policies and their associated CloudWatch alarms entirely, keeping only the Target Tracking policy:

```hcl
# Remove these completely:
# aws_autoscaling_policy.scale_out
# aws_autoscaling_policy.scale_in
# aws_cloudwatch_metric_alarm.high_cpu
# aws_cloudwatch_metric_alarm.low_cpu

# Keep only this:
resource "aws_autoscaling_policy" "target_tracking" {
  policy_type = "TargetTrackingScaling"
  target_tracking_configuration {
    predefined_metric_type = "ASGAverageCPUUtilization"
    target_value           = 70.0
  }
}
```

Target Tracking is the superior choice here — it scales both in and out automatically, responds faster than alarm-based scaling, and handles the cooldown logic internally.

---

**Q16. The SSH security group allows 0.0.0.0/0 on port 22. How would you fix this in a production-grade setup?**

**A.**
Allowing port 22 from 0.0.0.0/0 in production is a critical security vulnerability — it exposes your EC2 instances to brute force attacks, credential stuffing, and any SSH zero-day vulnerabilities.

There are three progressively better approaches.

The minimum fix is to restrict the CIDR to your known IP ranges — your office IP or VPN CIDR. This reduces exposure but still requires maintaining and rotating access lists as IPs change.

A better approach is to use a bastion host. All SSH access goes through a single hardened jump host with strict security controls, audit logging enabled, and MFA enforced. EC2 instances in the private subnet allow SSH only from the bastion's security group ID, not from any CIDR.

The best approach — and the one I would recommend for production — is to eliminate SSH entirely and use AWS Systems Manager Session Manager. SSM provides shell access to EC2 instances through the AWS console or CLI without any open inbound ports. It uses the instance's IAM role to authenticate, logs all session activity to CloudWatch and S3, supports MFA via IAM policies, and works for instances with no public IP and no SSH key. The `allow_ssh` security group and the SSH port 22 rule would be removed entirely from the Launch Template. The only change needed is attaching the `AmazonSSMManagedInstanceCore` IAM policy to the EC2 instance role.

---

**Q17. How would you extend this project to detect drift across 50 AWS accounts in an enterprise setting?**

**A.**
Single-account drift detection does not scale to enterprise environments. I would redesign it using three approaches.

First, use AWS Organizations and a central management account with cross-account IAM roles. Instead of storing AWS credentials as GitHub Secrets per account, create an IAM role in each member account that trusts the CI/CD account. The GitHub Actions workflow assumes these roles dynamically using OIDC federation — no long-lived access keys at all.

Second, replace the 1-minute cron with event-driven detection using AWS CloudTrail and EventBridge. Every API call that modifies infrastructure generates a CloudTrail event. EventBridge rules filter for mutating API calls (not Describe or List) and trigger a Lambda function that queues a drift detection run for the affected account and resource. This is more efficient than polling — you only run terraform plan when you know a change happened.

Third, centralize state and reporting. All state files live in a central S3 bucket in the management account with cross-account access. Drift detection results feed into a central DynamoDB table or CloudWatch dashboard showing drift status across all 50 accounts. Critical drift events (security group changes, IAM policy changes) trigger PagerDuty alerts, while informational drift (tag changes) creates GitHub Issues for review.

At this scale, I would also consider adopting dedicated drift detection tools like Driftctl or Terraform Cloud's drift detection feature, which are purpose-built for this problem and handle the multi-account complexity natively.

---

**Q18. The GitHub Issues created by drift detection include the full terraform plan output. What is a security concern with this and how would you address it?**

**A.**
Terraform plan output can contain sensitive information — resource ARNs, IP addresses, security group IDs, subnet CIDRs, and in some cases partial values of secrets if a provider outputs them in the plan. GitHub Issues on a public repository would expose this information to anyone on the internet. Even on a private repository, GitHub Issues are visible to all repository collaborators, which may be a broader audience than appropriate for sensitive infrastructure details.

I would address this at two levels.

At the plan output level, use `-var-file` to separate sensitive values from the plan, use `sensitive = true` on Terraform variables that contain credentials, and configure the AWS provider to redact sensitive outputs. Terraform 1.4+ supports sensitive output values that are replaced with `(sensitive value)` in plan output.

At the notification level, instead of including the full plan in the GitHub Issue body, store the sanitized plan output in S3 with a pre-signed URL that expires in 24 hours, and link to it from the issue. This way the plan details are accessible to authorized personnel but not permanently embedded in the issue history. Alternatively, post the detailed plan to a private Slack channel visible only to the DevOps team, and put only a summary (number of resources changed, resource types affected) in the GitHub Issue.

For highly sensitive environments, move the audit trail entirely out of GitHub and into a dedicated SIEM or compliance tool like Splunk or AWS Security Hub.

---

## ⚡ Rapid Fire — Quick Answers

---

**Q. What does `terraform init -reconfigure` do?**

**A.** It reinitializes the backend without prompting for migration confirmation. Used when the backend configuration has changed or you want to switch environments. `-reconfigure` discards the existing backend configuration and sets up fresh from the provided config file.

---

**Q. What is the difference between `continue-on-error: true` and `set +e` in GitHub Actions?**

**A.** `continue-on-error: true` is a GitHub Actions step property — it marks the step as successful in the workflow UI even if the command fails, and allows subsequent steps to run. `set +e` is a bash shell option — it prevents bash from exiting on command failure within a shell script. They operate at different levels. `continue-on-error` controls workflow execution; `set +e` controls shell execution within a step's run block.

---

**Q. Why is `terraform_wrapper: false` set in the Setup Terraform step?**

**A.** The Terraform wrapper script added by `hashicorp/setup-terraform` wraps the terraform binary and intercepts stdout/stderr for GitHub Actions annotations. This can interfere with capturing exit codes correctly — the wrapper may return its own exit code instead of terraform's. Setting `terraform_wrapper: false` uses the raw terraform binary directly, ensuring `$?` captures terraform's actual exit code, which is critical for the `-detailed-exitcode` drift detection logic.

---

**Q. What is `filebase64()` in Terraform and why is it used for user_data?**

**A.** `filebase64()` reads a file from disk and returns its contents as a base64-encoded string. AWS EC2 requires `user_data` to be base64-encoded when passed through the API. `filebase64()` handles this encoding automatically. The alternative would be `base64encode(file("path"))` which does the same thing in two functions.

---

**Q. What happens if two GitHub Actions workflows try to run `terraform apply` on the same environment simultaneously?**

**A.** The first workflow to start acquires the S3 lock by creating the `.tflock` file. The second workflow, when it runs `terraform init` or `terraform apply`, detects the existing lock file and fails with a "Error acquiring the state lock" message. It will not proceed. Once the first workflow completes and deletes the lock file, the second workflow can be re-run manually. This prevents state corruption from concurrent modifications.

---

**Q. What is the `random_id` resource used for in s3.tf?**

**A.** S3 bucket names must be globally unique across all AWS accounts worldwide. Using a static name like `terraform-day15-prod-bucket` would fail if anyone else has already created a bucket with that name. `random_id` generates a random 4-byte hex string (8 hex characters) that is appended to the bucket name — `terraform-day15-prod-bucket-a1b2c3d4`. The random ID is stored in state, so it remains stable across subsequent applies and does not generate a new ID every time.

---

**Q. Why does the drift detection workflow use `-reconfigure` in `terraform init` instead of a plain `terraform init`?**

**A.** Scheduled GitHub Actions workflows run on ephemeral Ubuntu runners — each run starts with a completely fresh environment. There is no existing `.terraform` directory or cached backend configuration from previous runs. The `-reconfigure` flag tells Terraform to initialize the backend fresh from the provided `.hcl` file without looking for or prompting about any previous backend configuration. Without it, Terraform might prompt interactively for migration confirmation, which would hang the automated workflow.

---

**Q. What is `propagate_at_launch = true` in the ASG tag block?**

**A.** It instructs the Auto Scaling Group to copy the specified tag to every EC2 instance it launches. Without this, the ASG itself would have the `Name = "app-instance"` tag but the individual EC2 instances would not. With it, every instance launched by the ASG automatically receives `Name = "app-instance"` — making them identifiable in the AWS console, CloudWatch, and Cost Explorer without manual tagging.

---

**Q. If someone manually deletes a resource that Terraform manages, what happens on the next drift detection run?**

**A.** `terraform plan -detailed-exitcode` would return exit code 2. During the plan phase, Terraform refreshes state by querying AWS APIs and finds the resource no longer exists. It generates a plan showing the resource needs to be created (not modified — created from scratch). The auto-remediation step then runs `terraform apply` which recreates the deleted resource with all its original configuration. The state file is updated to reflect the new resource ID. A GitHub Issue is created documenting the drift event.

---

*Project 15 — Terraform Drift Detection & Auto-Remediation*  
*Total Questions: 18 detailed + 8 rapid fire = 26 questions*