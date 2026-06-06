# Project 14 - Additional Interview Questions

## GitOps with ArgoCD on AWS EKS using Kustomize

> Questions an experienced interviewer would ask beyond the obvious ones —
> focusing on decision-making, trade-offs, and real-world thinking.

---

## Architecture & Design Decisions

**Q: You have ArgoCD running inside the same EKS cluster it is deploying to. What is the risk with this approach and how would you solve it in production?**

This is called a **single-cluster ArgoCD setup**. The risk is a circular dependency — if the cluster goes down, ArgoCD goes down with it, and you lose the ability to recover the cluster using GitOps.

The production pattern is a **hub-spoke model**:

- One dedicated ArgoCD cluster (the hub) — lightweight, rarely touched
- Multiple target clusters (the spokes) — where actual workloads run

ArgoCD on the hub manages all spoke clusters remotely. Even if a spoke goes completely down, ArgoCD is still running and can redeploy everything once the cluster recovers.

In this project, single-cluster is acceptable because it is a dev environment and the goal is demonstrating the GitOps workflow, not production HA.

---

**Q: ArgoCD is watching a public GitHub repo. What are the security concerns and what would you do differently?**

Concerns with a public repo:

- Anyone can see your manifests — namespace names, image names, infrastructure layout
- Secret values should never be in a public repo, but even non-secret config leaks architectural information
- No access control on who can push — in theory anyone could open a PR

What I would do in production:

1. **Private repository** with deploy keys — ArgoCD uses a read-only SSH key to pull
2. **Secrets never in Git** — use External Secrets Operator pulling from AWS Secrets Manager
3. **Branch protection** on `main` — no direct pushes, PRs require review before ArgoCD picks up changes
4. **Webhook instead of polling** — GitHub calls ArgoCD on every push, faster sync and less network noise than polling every 3 minutes

---

**Q: Right now if someone pushes broken manifests to Git, ArgoCD will try to sync and the app will break. How do you prevent bad config from reaching production?**

This is the shift-left problem in GitOps. The answer is a **pre-sync validation pipeline** in CI before anything merges to the branch ArgoCD watches.

What that pipeline would do on every PR:

1. **`kubectl apply --dry-run=server`** — catches invalid Kubernetes YAML
2. **`kustomize build`** — verifies Kustomize renders without errors
3. **Datree or Kubeconform** — validates against Kubernetes schema
4. **OPA/Conftest policies** — custom rules like "no container without resource limits", "no latest tag"
5. **ArgoCD App-of-Apps pattern** — promote changes through dev → staging → prod, each branch ArgoCD watches separately

The key insight: ArgoCD should only ever see config that has already passed validation. Git becomes a quality gate, not just a storage mechanism.

---

## Kubernetes Deep Dives

**Q: The frontend Service is of type LoadBalancer. Every LoadBalancer service creates a separate AWS Classic Load Balancer. If you had 10 services, you would have 10 load balancers. How would you fix this?**

This is a real cost and management problem. The solution is an **Ingress resource** with the **AWS Load Balancer Controller**.

Instead of each Service creating its own LB:

- One Application Load Balancer (ALB) is created
- Ingress rules route traffic to different services based on path or hostname

```yaml
# One ALB handles all routing
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    kubernetes.io/ingress.class: alb
spec:
  rules:
    - host: app.example.com
      http:
        paths:
          - path: /api
            backend:
              service:
                name: backend
                port:
                  number: 8080
          - path: /
            backend:
              service:
                name: frontend
                port:
                  number: 3000
```

Benefits: one LB instead of many, cheaper, SSL termination at one place, path-based routing.

---

**Q: Postgres is running as a single pod with a single PVC. What happens if the EKS node running Postgres goes down?**

The pod will be rescheduled on another node — but the EBS volume cannot follow automatically because EBS volumes are **AZ-locked**. If the pod reschedules to a node in a different AZ, the mount will fail and Postgres will be stuck in Pending state.

This is a known limitation of EBS for database workloads.

Solutions:

1. **Node affinity** — pin Postgres to nodes in a specific AZ so the pod always reschedules to the same AZ where the EBS volume exists
2. **EFS instead of EBS** — EFS is multi-AZ, any node in any AZ can mount it (but higher latency)
3. **RDS** — take the database completely out of Kubernetes, let AWS manage HA, Multi-AZ failover, backups
4. **StatefulSet with regional storage** — use a CSI driver that supports cross-AZ replication

For production database workloads, option 3 (RDS) is the most pragmatic answer.

---

**Q: Your Kustomize `kustomization.yaml` sets `replicas: 2` for the frontend. But someone runs `kubectl scale deployment frontend --replicas=10` directly. What exactly happens and in what order?**

1. `kubectl scale` runs — cluster immediately has 10 replicas, 8 new pods start coming up
2. ArgoCD detects drift within its next reconciliation cycle (default ~3 minutes, or instantly if webhook configured)
3. Because `selfHeal: true` is set, ArgoCD re-applies the Git state
4. Replicas go back to 2, the extra 8 pods are terminated

The key point: the change is **not permanent**. If someone needs more replicas, the correct path is updating `kustomization.yaml`, committing, and pushing. ArgoCD then scales up intentionally with a full audit trail in Git.

---

**Q: You used `storageClassName: gp2` for the Postgres PVC. What is wrong with this and what would you use?**

`gp2` is the older AWS EBS volume type. The problems:

- IOPS are tied to volume size (3 IOPS per GB) — to get more IOPS you have to provision a bigger disk, which costs more
- Burst-based performance — can throttle under sustained load
- More expensive per GB than gp3

`gp3` is the correct choice:

- IOPS and throughput are configurable **independently** of volume size
- Baseline 3000 IOPS and 125 MB/s throughput at no extra cost
- About 20% cheaper than gp2 for the same storage size

Fix in this project: change `storageClassName: gp2` to `gp3` in the PVC manifest and ensure the EKS cluster has a `gp3` StorageClass defined or set as default.

---

## Terraform Specific

**Q: You used a `null_resource` with `local-exec` to patch the ArgoCD service. Why is this considered bad practice and what are the specific problems with it?**

Several problems:

1. **Not idempotent by default** — if Terraform runs again, the `null_resource` may or may not re-run depending on triggers. The patch may or may not happen again.

2. **State drift** — Terraform has no idea what `kubectl patch` actually did. If someone manually undoes the patch, `terraform plan` will show no changes because Terraform does not track it.

3. **Local dependency** — requires `aws` CLI and `kubectl` installed on whatever machine runs Terraform. Breaks in a CI environment that does not have these tools.

4. **`sleep 10` is fragile** — hardcoded wait. On a slow cluster or slow API server, 10 seconds may not be enough.

The correct approach: install ArgoCD via its official Helm chart and set `server.service.type: LoadBalancer` in the Helm values. Terraform's Helm provider tracks this properly as managed state.

---

**Q: Terraform manages the ArgoCD install, but ArgoCD manages the application deployments. What happens when you run `terraform destroy`?**

This is a real ordering problem. When `terraform destroy` runs:

1. Terraform tries to delete `kubectl_manifest.app_deployment` (the ArgoCD Application CRD)
2. ArgoCD detects the Application was deleted and with `prune: true` starts deleting all app resources (frontend, backend, postgres pods, PVCs, namespace)
3. Meanwhile Terraform also tries to delete the `argocd` namespace and all ArgoCD resources
4. Race condition — ArgoCD is being destroyed while it is still trying to clean up the app

The namespace issue is also why the app namespace (`3tirewebapp-dev`) was commented out of Terraform — if Terraform owns the namespace and tries to delete it while ArgoCD-managed resources are still inside, it gets stuck on namespace finalizers forever.

Clean destroy sequence:

1. Delete the ArgoCD Application first and wait for app resources to be pruned
2. Then destroy ArgoCD itself
3. Then destroy EKS and VPC

In production, destroy workflows have explicit ordering scripts, not just `terraform destroy`.

---

## Observability & Operations

**Q: The application is deployed and running. How would you know if something is wrong? What observability is missing from this project?**

What is missing:

1. **No metrics collection** — no Prometheus scraping application metrics (request rate, error rate, latency)
2. **No log aggregation** — logs exist in pods but are lost when pods restart. No CloudWatch Logs or ELK/Loki
3. **No alerting** — no CloudWatch Alarms or PagerDuty integration
4. **No tracing** — no distributed tracing to see a request flow through frontend → backend → postgres
5. **No ArgoCD notifications** — no Slack/email alert when sync fails or app goes Degraded
6. **No resource monitoring** — no alerts if a node is at 90% memory

What I would add for production:

- **Prometheus + Grafana** (already shown in Project 7) for metrics and dashboards
- **Fluent Bit → CloudWatch Logs** for log aggregation
- **ArgoCD Notifications Controller** — Slack alert on sync failure
- **Kubernetes Dashboard or Lens** for visual cluster state
- **kube-state-metrics** for pod/deployment/node level metrics

---

**Q: How would you handle a rollback if a bad deployment goes out through ArgoCD?**

Because Git is the source of truth, rollback is a Git operation — not a Kubernetes operation.

Option 1 — **Git revert** (recommended):

```bash
git revert <bad-commit-hash>
git push origin main
# ArgoCD detects the revert commit and syncs the old state back
```

This is the correct GitOps approach — the rollback itself is a commit, so it is audited and visible.

Option 2 — **ArgoCD UI rollback**:

- ArgoCD keeps history of previous synced states
- You can click "Rollback" in the UI to a previous Git SHA
- This puts the app "OutOfSync" (cluster is at old state, Git is at new state)
- Fine as a quick fix, but you must follow up with a Git revert to bring them back in sync

Option 3 — **ArgoCD CLI**:

```bash
argocd app rollback 3tier-app <history-id>
```

The important nuance: ArgoCD rollback via UI/CLI creates a temporary state mismatch between Git and cluster. A proper rollback always ends with Git matching cluster.

---

## One Conceptual Question

**Q: GitOps solves deployment consistency. But the application container images are not in Git — only the tags are. If someone pushes a new image with the same tag (like `latest`), ArgoCD will never know. How do you handle this?**

This is the **mutable tag problem** and it is a known GitOps anti-pattern.

The rule: **never use mutable tags in GitOps**. `latest` should be banned.

The correct pattern:

- Every image build gets a unique immutable tag — git commit SHA or build number: `33Krishna/frontend:a3f8c12`
- CI pipeline builds image, tags it, pushes it
- CI pipeline then opens a PR (or directly commits) to update the image tag in `kustomization.yaml`
- PR gets reviewed and merged
- ArgoCD picks up the new tag and deploys

Tools like **Argo Image Updater** can automate the "update the tag in Git" step — it watches a container registry and automatically commits the new tag to the GitOps repo when a new image is pushed.

This way the full deployment trail lives in Git: who pushed what image, when it was deployed, what commit triggered it.
