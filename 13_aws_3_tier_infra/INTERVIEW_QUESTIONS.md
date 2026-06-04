# Project 13 — Interviewer's Perspective: Beyond the Concepts

> These are questions an interviewer asks to separate someone who **built it** from someone who **understands it**.  
> Every answer here shows depth, tradeoff thinking, and production awareness.

---

## 🔴 Category 1: Design Decisions (Did you think, or just follow a tutorial?)

---

### Q1. Why did you put the Frontend in a private subnet? The ALB is already public — isn't that enough protection?

**Answer:**

The ALB being public doesn't mean the EC2 instances behind it should be. If frontend instances were in a public subnet with public IPs, an attacker could bypass the ALB entirely and hit the instances directly — skipping WAF rules, rate limiting, and access logs.

Placing frontend EC2s in a private subnet means there is no direct route from the internet to those instances. The only way in is through the ALB. This is defense-in-depth — even if the ALB is misconfigured, the instances are not reachable.

---

### Q2. Your backend retrieves DB credentials from Secrets Manager at instance launch time via user data. What's the problem with this approach?

**Answer:**

The problem is that credentials are fetched **once at launch** and baked into the running Docker container as environment variables. If Secrets Manager rotates the password later, the running container still has the old credentials — it won't pick up the new ones until the instance is recycled or the container is restarted.

The correct production approach is to either:
- Fetch credentials at **application startup** (inside the Go code using the AWS SDK), not at the OS level
- Or use a **sidecar pattern** that periodically refreshes credentials and signals the app

This way rotation is seamless and doesn't require instance replacement.

---

### Q3. You have an Internal ALB between frontend and backend. But frontend instances need to know the Internal ALB's DNS to make API calls. How does the frontend know that URL?

**Answer:**

The Internal ALB's DNS name is passed to the frontend EC2 at launch via the **user data script**, injected as an environment variable — for example `BACKEND_URL=http://internal-alb-dns.elb.amazonaws.com`. Terraform outputs the Internal ALB DNS and passes it into the frontend launch template's user data.

This is why hardcoding backend IPs would be a bad idea — ASG instances get new IPs every launch. The ALB DNS is stable even as backend instances scale in and out.

---

### Q4. Both your ASGs use CPU as the scaling metric. What's wrong with that for a web application?

**Answer:**

CPU is a lagging indicator. By the time CPU hits 70%, users are already experiencing degraded performance — requests are queuing, latency is spiking. The new instance takes another 3-5 minutes to launch, pass health checks, and receive traffic.

Better metrics for a web application:
- **ALB Request Count per Target** — scales proactively based on incoming traffic
- **ALB Target Response Time** — scales when latency degrades
- **Custom application metrics** — queue depth, active connections

For this project CPU was simple and sufficient, but in production I'd switch to request-based scaling with a predictive scaling policy for known traffic patterns.

---

### Q5. Your architecture has no caching layer. Where would you add it and why?

**Answer:**

Two places:

**1. Between Backend and RDS — ElastiCache (Redis)**  
Repeated reads like fetching all goals for a user hit the DB every time. Redis would cache those results with a TTL. This reduces RDS load, improves latency from ~10ms DB query to ~1ms cache hit, and allows RDS to handle fewer connections.

**2. Between ALB and Frontend — CloudFront**  
Static assets (HTML, CSS, JS) don't need to be served from EC2 every time. CloudFront would cache them at edge locations, reducing load on frontend instances and improving global latency.

For this project it was unnecessary given the simple workload, but this is the standard next step.

---

## 🟠 Category 2: Failure Scenarios (What breaks, and do you know it?)

---

### Q6. What happens if the Secrets Manager API is down when a new backend instance launches?

**Answer:**

The user data script fails silently or with an error — the Docker container never starts with the correct DB credentials. The instance launches, passes the EC2 health check (instance is running), but the application is broken. If ASG health check type is `EC2`, this instance gets added to the backend target group and receives traffic — returning 500 errors to users.

**How to handle it:**
- Set health check type to `ELB` — ALB pings the `/health` endpoint, instance only joins the pool when the app is actually healthy
- Add retry logic in the user data script for the Secrets Manager call
- Use Secrets Manager **VPC endpoint** to avoid going over the internet — more reliable, lower latency

---

### Q7. A backend instance is returning 500 errors for 30% of requests. How does your architecture detect and handle this?

**Answer:**

The Internal ALB runs health checks every 30 seconds against each backend instance. If an instance fails 3 consecutive health checks (configurable), the ALB marks it as unhealthy and stops routing traffic to it — requests go to the remaining healthy instances.

The ASG then detects the unhealthy instance (if ELB health check type is set) and replaces it with a fresh one.

CloudWatch would also surface the spike in `HTTPCode_Target_5XX_Count` on the Internal ALB — a CloudWatch Alarm would fire and notify via SNS.

The gap: if the 500s are intermittent (not consistent enough to fail health checks), the instance stays in rotation. That's where distributed tracing (X-Ray) and per-request error logging in CloudWatch Logs Insights becomes important.

---

### Q8. Your RDS is single-AZ in dev. A dev team member accidentally deletes a row from the goals table. How do you recover?

**Answer:**

RDS automated backups run daily at 03:00 UTC with 7-day retention. I would:

1. Identify approximately when the deletion happened from CloudWatch RDS logs or application logs
2. Use **Point-in-Time Recovery (PITR)** — RDS supports restoring to any second within the retention window using transaction logs
3. PITR creates a **new RDS instance** — it doesn't restore in-place
4. Either promote that instance as the new primary, or query it to extract just the deleted rows and insert them back

This is why I enabled automated backups even in dev — mistakes happen, and RDS logs every transaction.

---

### Q9. Your NAT Gateway is in a single AZ in dev. Backend instances are in both AZ-a and AZ-b. What's the actual failure risk?

**Answer:**

If AZ-a's NAT Gateway fails and backend instances in AZ-b try to reach the internet (Secrets Manager, Docker Hub, CloudWatch), their traffic is routed to AZ-a's NAT Gateway via the route table — that route is now dead.

AZ-b backend instances would:
- Fail to pull updated Docker images
- Fail to reach Secrets Manager at launch
- Fail to send logs to CloudWatch

In dev this is acceptable — it's a cost tradeoff (~$32/month per NAT Gateway). In production `single_nat_gateway = false` means each AZ has its own NAT Gateway, and AZ-b's route table points to AZ-b's NAT. Full isolation.

---

## 🟡 Category 3: Terraform Depth (IaC or just config files?)

---

### Q10. How do you handle changes to the Launch Template — for example, updating the Docker image version? Does ASG automatically pick it up?

**Answer:**

No — updating the Launch Template creates a new **version** of it, but existing running instances are not replaced automatically. The ASG keeps running the old instances with the old template version.

To roll out the new image, I would trigger an **Instance Refresh**:

```bash
aws autoscaling start-instance-refresh \
  --auto-scaling-group-name dev-goal-tracker-backend-asg \
  --preferences '{"MinHealthyPercentage": 50}'
```

This replaces instances in a rolling fashion — launches new ones with the new template, waits for them to be healthy, terminates old ones. `MinHealthyPercentage: 50` means at least half the capacity stays healthy during the refresh.

In a proper CI/CD pipeline, this command would be the final step after a successful image push.

---

### Q11. Your `terraform.tfvars` contains Docker Hub credentials. How do you handle this securely?

**Answer:**

`terraform.tfvars` is in `.gitignore` — it never gets committed. This is the minimum requirement.

But storing credentials in a flat file is still not ideal. Better approaches:

1. **Environment variables** — Terraform reads `TF_VAR_dockerhub_password` automatically, no file needed
2. **AWS Secrets Manager or SSM Parameter Store** — store the token there, retrieve it in Terraform using a `data` source
3. **CI/CD system secrets** — GitHub Actions Secrets, injected at pipeline runtime as environment variables

For a team or production setup, option 3 is standard — no human ever sees the credentials, the pipeline injects them.

---

### Q12. If someone runs `terraform destroy` by mistake, how long would it take to fully recover?

**Answer:**

Recovery steps and estimated time:

| Step | Time |
|------|------|
| `terraform apply` — VPC, SGs, IAM, Secrets | ~3 min |
| RDS instance creation | ~8 min |
| ASG instances launch + Docker pull + health check pass | ~5 min |
| ALB health checks stabilize | ~2 min |
| **Total** | **~18-20 min** |

The data problem is the real issue — RDS is destroyed and **data is gone** unless:
- Automated backups exist (they do — 7 day retention)
- But backup restoration to a new instance takes additional time and requires a DNS/endpoint update

This is why in production:
- Enable **RDS deletion protection** (`deletion_protection = true`) — Terraform can't destroy it without disabling this first
- Enable **termination protection** on critical EC2s
- Use **Terraform Sentinel** or **OPA policies** to block destructive operations in prod

---

## 🟢 Category 4: Real-World Gaps (Honest self-awareness wins interviews)

---

### Q13. This project has no CI/CD pipeline. Walk me through what a production pipeline would look like for this application.

**Answer:**

```
Developer pushes code to GitHub
        ↓
GitHub Actions: CI Pipeline
├── Run unit tests (Go test, Node test)
├── Run security scan (Trivy for container vulnerabilities)
├── Build Docker image
├── Push to ECR with git SHA tag (not just "latest")
└── (On failure: notify Slack, stop pipeline)
        ↓
GitHub Actions: CD Pipeline (on merge to main)
├── Terraform plan — post output as PR comment
├── Terraform apply (if approved)
├── Trigger ASG Instance Refresh (backend, then frontend)
├── Wait for refresh completion
└── Run smoke tests against ALB URL
        ↓
Production traffic shifts to new instances
```

Key point: tagging images with **git SHA** instead of `latest` means every deployment is traceable and rollback is `docker pull image:previous-sha`.

---

### Q14. Your application has no HTTPS. A user's goal data is sent over plain HTTP. What's the exact risk and how do you fix it?

**Answer:**

HTTP traffic is unencrypted in transit. On a public network (coffee shop WiFi, ISP), an attacker can perform a **man-in-the-middle attack** and read or modify the requests — seeing the user's goals, or injecting malicious responses.

**Fix:**
1. Request a free SSL certificate from **AWS Certificate Manager (ACM)** — auto-renews
2. Add an HTTPS listener (Port 443) to the External ALB with that certificate
3. Add an HTTP → HTTPS redirect rule on Port 80
4. ALB terminates TLS — backend communication stays on HTTP internally (within VPC, acceptable)

This is a 30-minute Terraform change and there's no reason not to do it even in dev.

---

### Q15. The database schema has only two columns — `id` and `goal_name`. How would schema migrations be handled as the application evolves?

**Answer:**

Currently there's no migration strategy — the `init.sql` runs once when the container starts locally. In production this breaks down immediately when you need to add a column or index.

The proper approach:
- Use a migration tool like **Flyway** or **golang-migrate**
- Migrations are versioned SQL files: `V1__init.sql`, `V2__add_user_id.sql`
- Run migrations as a **pre-deployment step** in the CI/CD pipeline before the new application version starts
- Migrations are **forward-only** and never modify existing migrations

This ensures the schema and application code version are always in sync, and rollback is handled by a down-migration script.

---

## 🔵 Category 5: Security Deep Dive

---

### Q16. An attacker gets shell access to a frontend EC2 instance. What can they do in your architecture?

**Answer:**

From the frontend instance, the attacker can:

**Can do:**
- Read the `BACKEND_URL` environment variable — knows the Internal ALB DNS
- Make API calls to the backend (Port 8080) — same as the frontend app does
- Reach the internet via NAT Gateway (download tools, exfiltrate data)
- Access AWS metadata endpoint `169.254.169.254` — get the EC2 instance role credentials

**Cannot do:**
- Reach RDS directly — frontend SG has no rule to RDS SG on Port 5432
- Access Secrets Manager — IAM role only allows backend, not frontend
- SSH to backend instances (unless bastion key is on this instance)

**The critical risk is the metadata endpoint.** The instance role credentials retrieved from `169.254.169.254` can be used outside AWS to call any AWS API the role permits — including CloudWatch, SSM, and ECR.

**Mitigation:** Enable **IMDSv2** (Instance Metadata Service v2) which requires a session token — prevents SSRF attacks from reading metadata.

---

### Q17. How would you detect if someone is running a cryptocurrency miner on one of your EC2 instances?

**Answer:**

Several detection layers:

1. **CloudWatch CPU Alarm** — a miner pegs CPU at 100% continuously. An alarm for sustained high CPU (>80% for 15+ minutes) would fire.

2. **AWS GuardDuty** — specifically detects `CryptoCurrency:EC2/BitcoinTool.B` finding type — identifies instances communicating with known mining pool endpoints.

3. **VPC Flow Logs** — unusual outbound traffic patterns to unknown IPs on non-standard ports.

4. **CloudTrail** — if the attacker used compromised IAM credentials to launch new instances for mining, CloudTrail would log the `RunInstances` API call from an unusual IP.

GuardDuty is the fastest detection — it's a managed threat detection service that correlates multiple signals automatically. For this project it's not enabled (cost), but in production it's the first thing I'd turn on.

---

## Final Scoring Criteria (What Interviewers Actually Evaluate)

| Signal | Weak Answer | Strong Answer |
|--------|-------------|---------------|
| **Tradeoffs** | "I used X because it's good" | "I used X over Y because of A, but in production I'd use Y" |
| **Failure awareness** | "It works" | "Here's what breaks and how I'd detect it" |
| **Production gaps** | Defensive | "Here are 5 things I'd add before going live" |
| **Security depth** | "I used security groups" | Explains what an attacker can still do |
| **IaC maturity** | "I wrote Terraform" | Explains state, modules, drift, and destroy protection |

---

*The goal isn't a perfect architecture. The goal is showing you understand **why** every decision was made and **what it costs you**.*