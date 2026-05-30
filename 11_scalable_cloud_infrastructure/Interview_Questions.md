# Project 11 — Interview Questions & Answers
## High Available/Scalable Infrastructure Deployment

---

## 🏗️ Architecture & Design

**Q1. Walk me through your architecture. Why did you choose this design?**

The architecture has a VPC with public and private subnets across two Availability Zones. An Application Load Balancer sits in the public subnets and receives all incoming traffic. EC2 instances running Django in Docker are placed in private subnets — they are never directly exposed to the internet. Two NAT Gateways allow those private instances to reach the internet for outbound calls like pulling Docker images. An Auto Scaling Group manages the EC2 instances dynamically based on CPU load.

I chose this design because it eliminates every single point of failure. If one AZ goes down, the other handles traffic. If one instance becomes unhealthy, the ALB stops sending it traffic and ASG replaces it.

---

**Q2. Why did you use two NAT Gateways instead of one?**

One NAT Gateway would be a single point of failure. If that NAT Gateway's AZ goes down, all private instances in both AZs lose outbound internet access even if the instances themselves are healthy. By placing one NAT Gateway per AZ and routing each private subnet through its own NAT, both AZs remain fully independent. This is what true High Availability means — no shared dependency that can take everything down.

---

**Q3. Why are EC2 instances in private subnets? What is the benefit?**

Security. If instances were in public subnets, anyone on the internet could attempt to connect to them directly. In private subnets, the only way to reach an EC2 instance is through the ALB. The ALB's security group only accepts traffic on port 80 and 443, and the EC2 security group only accepts traffic coming from the ALB security group. This is called least privilege — every layer only allows exactly what is needed, nothing more.

---

**Q4. What is the difference between a public subnet and a private subnet in your setup?**

A public subnet has a route to the Internet Gateway, which means resources in it can be reached directly from the internet and can reach the internet directly. The ALB and NAT Gateways live here.

A private subnet has no route to the Internet Gateway. Its route table points outbound traffic to a NAT Gateway instead. So instances can initiate outbound connections like pulling Docker images, but no one from the internet can initiate a connection to them. EC2 instances live here.

---

## ⚖️ Load Balancer

**Q5. What does the Application Load Balancer do in this project?**

It serves three purposes. First, it is the single entry point — users hit one DNS name and the ALB handles the rest. Second, it distributes traffic across all healthy EC2 instances in the target group so no single instance gets overloaded. Third, it performs health checks every 30 seconds. If an instance fails two consecutive health checks, the ALB stops sending it traffic until it recovers. This means user requests never hit a broken instance.

---

**Q6. What is a Target Group and why is it needed?**

A Target Group is a logical group of EC2 instances that the ALB forwards traffic to. The ALB does not talk to instances directly — it talks to a target group. The ASG registers each new instance into this target group automatically when it launches. The health check lives on the target group, not the ALB itself. So the Target Group is the bridge between the ALB and the actual EC2 instances.

---

**Q7. Your ALB listener is only on port 80. What would you add in production?**

I would add an HTTPS listener on port 443 with an SSL certificate from AWS Certificate Manager. The port 80 listener would then redirect all HTTP traffic to HTTPS instead of forwarding it. This ensures all traffic between users and the ALB is encrypted. Between ALB and EC2 instances inside the VPC, HTTP is acceptable since it is internal traffic on a private network.

---

## 📈 Auto Scaling

**Q8. Explain your scaling strategy. Why did you use both simple scaling and target tracking?**

Simple scaling policies (scale_out and scale_in) are triggered by CloudWatch alarms — CPU above 80% adds one instance, CPU below 20% removes one. These are reactive and predictable.

Target tracking policy keeps average CPU around 70% by automatically calculating how many instances are needed. It is more intelligent than simple scaling because it does not just add or remove a fixed number — it looks at the actual gap between current and target CPU and acts accordingly.

In practice, target tracking handles normal fluctuations smoothly. The simple scaling alarms act as safety triggers for extreme spikes that target tracking might be slower to react to.

---

**Q9. Why is health_check_grace_period set to 300 seconds?**

When a new EC2 instance launches, it needs time to run the user_data script — install Docker, pull the Django image, start the container. This takes roughly 2-3 minutes. If the ASG starts health checking immediately, it will see the instance as unhealthy and terminate it before it even finishes starting up. The 300 second grace period tells the ASG to wait 5 minutes before checking health, giving the instance enough time to become ready.

---

**Q10. What happens step by step when traffic suddenly spikes?**

1. Multiple users hit the app at the same time
2. CPU utilization across EC2 instances rises
3. CloudWatch collects CPU metrics every 120 seconds
4. After 2 consecutive periods above 80%, the high_cpu alarm triggers
5. The scale_out policy fires — ASG desired capacity increases by 1
6. ASG launches a new EC2 instance in one of the private subnets using the launch template
7. user_data.sh runs — Docker installs, Django container starts
8. After 300 seconds grace period, ALB health check passes
9. Instance joins the target group and starts receiving traffic
10. If CPU is still high after cooldown period of 300 seconds, the alarm triggers again and another instance launches — up to the max of 5

---

## 🔒 Security

**Q11. Walk me through your security group design.**

Three main security groups work together. The ALB security group allows inbound traffic from the internet on ports 80 and 443 — this is the only thing exposed to the internet. The EC2 app security group only allows inbound traffic from the ALB security group, not from any IP address. This means even if someone knows an EC2 instance's private IP, they cannot reach it unless they are coming through the ALB. The SSH security group is a TODO in production — in a real setup it would be restricted to a specific bastion host IP or removed entirely in favor of AWS Systems Manager Session Manager.

---

**Q12. What is IMDSv2 and why did you enforce it?**

IMDS is the Instance Metadata Service — a way for EC2 instances to get information about themselves like IAM role credentials, instance ID, etc. IMDSv1 was unauthenticated, meaning any process on the instance could query it. This was exploited in the Capital One breach through an SSRF vulnerability. IMDSv2 requires a session token before metadata can be accessed, making SSRF attacks much harder. Setting `http_tokens = required` enforces IMDSv2 only, which is a security best practice AWS itself recommends.

---

## 🏗️ Terraform & IaC

**Q13. Why use Terraform instead of creating this manually in the AWS Console?**

Three reasons. Reproducibility — running terraform apply twice in different AWS accounts gives identical infrastructure. This is impossible to guarantee with manual clicks. Version control — the entire infrastructure is in Git, so you can see exactly what changed, when, and why. Destroy and rebuild — terraform destroy tears down everything cleanly in the right order. Manually deleting AWS resources in the wrong order often causes dependency errors.

---

**Q14. What does the count meta-argument do in your vpc.tf?**

Instead of writing a separate resource block for each subnet, count lets you create multiple identical resources with one block. `count = 2` creates two subnets. `count.index` gives you 0 and 1, which you use to pick the right CIDR block and AZ from the variable lists. So `element(var.public_subnet_cidrs, count.index)` gives `10.0.1.0/24` for the first subnet and `10.0.2.0/24` for the second. It keeps the code DRY — Don't Repeat Yourself.

---

**Q15. If you had to improve this architecture, what would you add?**

Several things. First, HTTPS on the ALB with ACM certificate. Second, a WAF (Web Application Firewall) in front of the ALB to block common attacks like SQL injection and XSS. Third, RDS in a separate private subnet for the database instead of running it inside the app container. Fourth, CloudWatch dashboards and SNS alerts to notify on alarms instead of just triggering scaling. Fifth, replacing the SSH security group with AWS Systems Manager Session Manager so no port 22 is open anywhere. These would take this from production-ready to enterprise-grade.

---

*Total Questions: 15 | Topics: Architecture, Networking, ALB, ASG, Security, Terraform*