# 🎯 Interview Preparation – VPC Peering Project (Advanced)

## 📌 Project Explanation

**Q: Explain your project**

**Answer:**

> I implemented a multi-VPC architecture on AWS using Terraform. Initially, I created two VPCs in different regions and connected them using VPC Peering to enable private communication.
> Then I enhanced the architecture by introducing a private subnet with a NAT Gateway for secure outbound internet access.
> I also added VPC Flow Logs for monitoring, Transit Gateway for scalable multi-VPC connectivity, and simulated a Site-to-Site VPN for hybrid cloud architecture.

---

## 🌐 Networking Concepts

### Q: Why did you use VPC Peering?

**Answer:**

> VPC Peering is used to enable private communication between two VPCs using private IP addresses without going over the public internet.

---

### Q: What are limitations of VPC Peering?

**Answer:**

> VPC Peering is non-transitive, meaning if VPC A is connected to B and B is connected to C, A cannot communicate with C. It also does not scale well for large architectures.

---

### Q: Why Transit Gateway?

**Answer:**

> Transit Gateway solves scalability issues by acting as a central hub for multiple VPCs. It supports transitive routing and simplifies network management.

---

## 🔐 Security & Architecture

### Q: Why private subnet + NAT Gateway?

**Answer:**

> Private subnets improve security by preventing direct internet access. NAT Gateway allows instances in private subnets to access the internet securely for updates and package installation.

---

### Q: Why NAT Gateway in public subnet?

**Answer:**

> NAT Gateway must be in a public subnet because it requires access to the Internet Gateway to route outbound traffic.

---

### Q: What is Bastion Host?

**Answer:**

> A Bastion Host is a public EC2 instance used to securely access private instances inside a VPC.

---

## 📊 Monitoring

### Q: What is VPC Flow Logs?

**Answer:**

> VPC Flow Logs capture information about IP traffic going to and from network interfaces. It is useful for monitoring, debugging, and security analysis.

---

## 🔐 Hybrid Cloud

### Q: What is VPN in your project?

**Answer:**

> I implemented a simulated Site-to-Site VPN to demonstrate hybrid connectivity between an on-premise network and AWS using an encrypted tunnel.

---

## 🛠️ Troubleshooting Scenarios

### Q: EC2 cannot ping another EC2

**Answer:**

> I check security groups to ensure ICMP is allowed, verify route tables, check NACL rules, and confirm the peering connection is active.

---

### Q: VPC Peering not working

**Answer:**

> I verify that CIDR blocks do not overlap, ensure the peering connection is active, and check route tables in both VPCs.

---

### Q: Private EC2 has no internet access

**Answer:**

> I check NAT Gateway configuration, verify the private route table points to NAT, and ensure Internet Gateway is attached.

---

### Q: SSH not working

**Answer:**

> I check security group rules for port 22, verify key pair, confirm public IP or bastion access, and validate routing.

---

### Q: Flow Logs not showing data

**Answer:**

> I check IAM role permissions, ensure log group exists, and confirm traffic is flowing.

---

### Q: VPN not connecting

**Answer:**

> I verify customer gateway IP, check tunnel configuration, validate routing, and ensure both sides are configured.

---

## 🧠 Real-World Scenarios

### Q: Company has multiple VPCs, what will you use?

**Answer:**

> I would use Transit Gateway for scalable and centralized connectivity.

---

### Q: Secure database access from office

**Answer:**

> I would place the database in a private subnet and use VPN for secure access from the office network.

---

### Q: How do you debug network issues?

**Answer:**

> I use VPC Flow Logs, check route tables, verify security groups, and test connectivity using ping or curl.

# 🔥 Advanced Interview Questions – AWS VPC Peering & Networking

## 🧠 Deep Networking Concepts

### Q: What happens if VPC CIDR blocks overlap?

**Answer:**

> VPC Peering will not work if CIDR blocks overlap because routing becomes ambiguous. AWS does not allow peering between overlapping CIDR ranges.

---

### Q: Difference between Security Group and NACL?

**Answer:**

> Security Groups are stateful, meaning return traffic is automatically allowed.
> NACLs are stateless, meaning both inbound and outbound rules must be explicitly allowed.

---

### Q: What is Stateful vs Stateless?

**Answer:**

> Stateful means response traffic is automatically allowed (Security Groups).
> Stateless means both directions must be explicitly allowed (NACLs).

---

### Q: How does routing work in VPC?

**Answer:**

> Routing in VPC is controlled by route tables. Each subnet is associated with a route table that determines how traffic is directed.

---

### Q: What is local route in route table?

**Answer:**

> The local route allows communication within the VPC CIDR block. It is automatically created and cannot be removed.

---

## 🌐 Advanced Peering Questions

### Q: Can VPC Peering work across regions?

**Answer:**

> Yes, VPC Peering supports cross-region connections, but it may incur additional latency and cost.

---

### Q: Can VPC Peering use public IPs?

**Answer:**

> No, VPC Peering only uses private IP addresses for communication.

---

### Q: What is edge-to-edge routing limitation?

**Answer:**

> Resources like VPN, NAT, or Internet Gateway in one VPC cannot be used by another VPC through peering.

---

## 🔐 Security & Access

### Q: Why not allow 0.0.0.0/0 in security groups?

**Answer:**

> It exposes resources to the internet, increasing security risk. It should be restricted to specific IP ranges.

---

### Q: How to secure SSH access?

**Answer:**

> Use restricted IP ranges, bastion host, or VPN instead of allowing access from anywhere.

---

### Q: What is least privilege principle?

**Answer:**

> Grant only the minimum permissions required to perform a task.

---

## ⚙️ Terraform Specific Questions

### Q: Why use variables in Terraform?

**Answer:**

> Variables make the configuration reusable, flexible, and easier to maintain.

---

### Q: Difference between .tfvars and variables.tf?

**Answer:**

> variables.tf defines variables, while terraform.tfvars provides their values.

---

### Q: What is provider alias?

**Answer:**

> Provider alias allows using multiple configurations of the same provider, such as multiple AWS regions.

---

### Q: What is depends_on?

**Answer:**

> It explicitly defines resource dependencies to control creation order.

---

### Q: What happens if depends_on is not used?

**Answer:**

> Terraform may still infer dependencies, but in complex cases it can lead to race conditions or failures.

---

### Q: What is Terraform state?

**Answer:**

> Terraform state stores the current state of infrastructure and helps track resource changes.

---

### Q: Why use remote backend (S3)?

**Answer:**

> To store state remotely, enable collaboration, and avoid local state conflicts.

---

## 📊 Monitoring & Debugging

### Q: How do you monitor VPC traffic?

**Answer:**

> Using VPC Flow Logs, CloudWatch, and other monitoring tools.

---

### Q: What is ACCEPT and REJECT in flow logs?

**Answer:**

> ACCEPT means traffic is allowed, REJECT means traffic is blocked.

---

### Q: How to debug network latency?

**Answer:**

> Use tools like ping, traceroute, and analyze flow logs.

---

## 🌐 NAT & Internet

### Q: Difference between NAT Gateway and Internet Gateway?

**Answer:**

> Internet Gateway allows direct internet access, while NAT Gateway allows outbound-only internet access for private instances.

---

### Q: Can private EC2 have public IP?

**Answer:**

> No, if it has a public IP, it is considered part of a public subnet.

---

### Q: What happens if NAT Gateway fails?

**Answer:**

> Private instances lose internet access. High availability requires NAT in multiple AZs.

---

## 🔐 VPN & Hybrid

### Q: Difference between Site-to-Site VPN and Client VPN?

**Answer:**

> Site-to-Site connects networks, Client VPN connects individual users.

---

### Q: What is Customer Gateway?

**Answer:**

> It represents the on-premise device in a VPN connection.

---

### Q: What is Virtual Private Gateway?

**Answer:**

> It is the AWS side of the VPN connection attached to a VPC.

---

## 🧠 Design & Architecture

### Q: When to use VPC Peering vs Transit Gateway?

**Answer:**

> Use VPC Peering for small setups and Transit Gateway for scalable multi-VPC architectures.

---

### Q: How would you design highly available architecture?

**Answer:**

> Use multiple AZs, load balancers, auto-scaling, and redundant NAT Gateways.

---

### Q: How do you secure production architecture?

**Answer:**

> Use private subnets, restrict access, implement IAM roles, enable logging, and use VPN or bastion.

---

## 💀 Edge Case Questions

### Q: What if route table is correct but still no connectivity?

**Answer:**

> Check security groups, NACLs, instance OS firewall, and VPC peering status.

---

### Q: What if ping works but HTTP doesn’t?

**Answer:**

> Check application service, port (80/443), and security group rules.

---

### Q: What if Terraform apply fails?

**Answer:**

> Check error logs, validate syntax, verify AWS limits, and debug resource dependencies.

---

## 🚀 Final Tip

> Always explain with real-world scenarios and troubleshooting steps to stand out in interviews.
