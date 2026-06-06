# Project 14 - Interview Q&A

## GitOps with ArgoCD on AWS EKS using Kustomize

---

## 1. GitOps Fundamentals

**Q: GitOps kya hota hai? Traditional deployment se kaise alag hai?**

Traditional deployment mein engineer manually `kubectl apply` ya `helm install` run karta hai. Koi track nahi ki cluster mein exactly kya chal raha hai. Agar koi galti se kuch delete kare ya patch kare — pata bhi nahi chalta.

GitOps mein Git repository = single source of truth. Jo bhi Git mein likha hai, wahi cluster mein hona chahiye. Ek controller (ArgoCD) continuously Git aur cluster compare karta rehta hai — difference milte hi auto-fix.

|                    | Traditional           | GitOps       |
| ------------------ | --------------------- | ------------ |
| Deployment trigger | Manual command        | Git commit   |
| Audit trail        | Log files (agar hain) | Git history  |
| Rollback           | Manual, error-prone   | `git revert` |
| Drift detection    | None                  | Automatic    |

---

**Q: GitOps ke 4 core principles kya hain?**

1. **Declarative** — "kya chahiye" define karo, "kaise karo" system decide karta hai
2. **Versioned** — har change Git mein tracked, immutable history
3. **Pulled automatically** — agent khud Git se pull karta hai (push nahi hota cluster mein)
4. **Continuously reconciled** — controller hamesha desired vs actual compare karta hai, drift milte hi fix

---

**Q: GitOps mein "drift" kya hota hai?**

Drift = Git mein jo likha hai aur cluster mein jo actually chal raha hai — unke beech ka difference.

Example: Git mein `replicas: 2` hai, lekin kisi ne manually `kubectl scale deployment frontend --replicas=5` run kar diya. Ab cluster "drifted" hai.

ArgoCD yeh detect karta hai aur `selfHeal: true` hone pe automatically `replicas: 2` pe wapas le aata hai.

---

## 2. ArgoCD

**Q: ArgoCD kya hai aur kaise kaam karta hai?**

ArgoCD ek Kubernetes-native GitOps controller hai. Yeh cluster ke andar hi run karta hai aur continuously ek Git repo ko watch karta hai.

Working:

1. ArgoCD Application CRD define karo — "is repo ke is path ko is namespace mein deploy karo"
2. ArgoCD har ~3 minutes pe Git repo poll karta hai (ya webhook se instant)
3. Git ka desired state aur cluster ka actual state compare karta hai
4. Difference hai? → `kubectl apply` effectively run karta hai
5. ArgoCD UI mein "Synced / OutOfSync / Healthy / Degraded" status dikhta hai

---

**Q: ArgoCD Application manifest mein kya hota hai? Har field explain karo.**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: 3tier-app
  namespace: argocd # ArgoCD khud argocd namespace mein rehta hai
spec:
  project: default # ArgoCD project — RBAC ke liye
  source:
    repoURL: https://github.com/... # Kahan se manifests lo
    targetRevision: main # Kaunsi branch/tag
    path: 3tire-configs # Repo ke andar kaunsa folder
  destination:
    server: https://kubernetes.default.svc # Same cluster
    namespace: 3tirewebapp-dev # Kahan deploy karo
  syncPolicy:
    automated:
      prune: true # Git se resource delete → cluster se bhi delete
      selfHeal: true # Manual change → ArgoCD revert karega
    syncOptions:
      - CreateNamespace=true # Namespace exist nahi → bana do
```

---

**Q: `prune: true` aur `selfHeal: true` mein kya fark hai?**

- `prune: true` — Git se koi resource **delete** karo, ArgoCD cluster se bhi delete karega. Bina iske, Git se delete karne ke baad bhi cluster mein resource rahega (orphaned).

- `selfHeal: true` — Koi **manually** cluster change kare (`kubectl edit`, `kubectl scale`), ArgoCD detect karega aur Git wali state pe wapas le aayega.

Dono milke ensure karte hain: cluster ka state = Git ka state. Always.

---

**Q: ArgoCD ko EKS mein kaise install kiya?**

Terraform se do steps mein:

```hcl
# Step 1: Namespace banao
resource "kubernetes_namespace_v1" "argocd" {
  metadata { name = "argocd" }
}

# Step 2: Official install.yaml download karke apply karo
data "http" "argocd_manifest" {
  url = "https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"
}

resource "kubectl_manifest" "argocd" {
  for_each = {
    for doc in split("---", data.http.argocd_manifest.response_body) :
    sha256(doc) => doc if trimspace(doc) != ""
  }
  yaml_body = each.value
  override_namespace = "argocd"
}
```

`sha256(doc)` as key — kyunki `for_each` ko unique key chahiye, aur content hash stable aur unique hota hai.

---

**Q: ArgoCD server ko LoadBalancer kyun banana pada? Terraform mein directly kyun nahi kiya?**

ArgoCD apna `argocd-server` service `ClusterIP` type se banata hai by default. Hum chahte the ki DevOps team browser se access kare — isliye `LoadBalancer` type chahiye.

Problem: ArgoCD ka service resource already `kubectl_manifest` se create ho chuka tha. Usse Terraform `kubernetes` provider se override karna complex tha (resource conflict).

Quick fix: `null_resource` + `local-exec` provisioner se `kubectl patch` run kiya.

```hcl
resource "null_resource" "patch_argocd_service" {
  provisioner "local-exec" {
    command = "kubectl patch svc argocd-server -n argocd -p '{\"spec\": {\"type\": \"LoadBalancer\"}}' || true"
  }
}
```

`|| true` — agar already patched hai toh command fail na ho.

**Production mein kya karta?** ArgoCD ka official Helm chart use karta aur `values.yaml` mein `server.service.type: LoadBalancer` set karta. Helm se install → no patching needed.

---

## 3. Kustomize

**Q: Kustomize kya hai? Helm se kaise alag hai?**

Dono Kubernetes manifest management tools hain, lekin approach alag hai:

|                    | Kustomize                        | Helm                      |
| ------------------ | -------------------------------- | ------------------------- |
| Approach           | Patch existing YAMLs             | Templating ({{ }} syntax) |
| Learning curve     | Low                              | Higher                    |
| Built into kubectl | Yes (`kubectl apply -k`)         | No (separate install)     |
| Use case           | Overlay/patch existing manifests | Package + distribute apps |
| Original files     | Untouched                        | Template mein embedded    |

Kustomize philosophy: "Original YAML ko touch mat karo, upar se patch lagao."

---

**Q: Is project mein Kustomize ne kya kiya? `kustomization.yaml` explain karo.**

```yaml
namespace: 3tirewebapp-dev # Sab resources is namespace mein jaayenge

resources: # Kaunsi files include karni hain
  - namespace.yaml
  - secret.yaml
  - postgres.yaml
  - backend.yaml
  - frontend.yaml

images: # Image tags centrally manage karo
  - name: 33Krishna/frontend
    newTag: v2 # frontend.yaml mein tag override ho jaata hai
  - name: postgres
    newTag: "15"

replicas: # Replicas centrally manage karo
  - name: frontend
    count: 2 # frontend.yaml mein replicas: 1 tha → 2 ho gaya

commonAnnotations: # Sab resources pe yeh annotation lagega
  app.kubernetes.io/version: "1.0"
```

**GitOps loop:** Naya image build hua → sirf `kustomization.yaml` mein `newTag` update karo → commit → push → ArgoCD detects → pods roll out. Koi individual YAML touch nahi karna.

---

**Q: Kustomize rendered output kaise dekhte hain?**

```bash
kubectl kustomize manifests/
# Ya
kubectl apply -k manifests/ --dry-run=client
```

Yeh dikhata hai ki actually kya apply hoga — debugging ke liye useful.

---

## 4. Kubernetes Concepts

**Q: Is project mein kaun kaun se Service types use hue aur kyun?**

| Service         | Type                   | Reason                                                            |
| --------------- | ---------------------- | ----------------------------------------------------------------- |
| `frontend`      | LoadBalancer           | Users bahar se access karte hain → AWS Classic LB create hota hai |
| `backend`       | ClusterIP              | Sirf frontend pod access karta hai, bahar se nahi                 |
| `postgres`      | ClusterIP              | Sirf backend pod access karta hai, bahar se bilkul nahi           |
| `argocd-server` | LoadBalancer (patched) | DevOps team UI access kare                                        |

**Security principle:** Minimum exposure. Jo bahar se access nahi hona chahiye, usse ClusterIP rakho.

---

**Q: ConfigMap aur Secret mein kya fark hai? Dono ko Deployment mein kaise use kiya?**

- `ConfigMap` — non-sensitive config (DB host, port, flags)
- `Secret` — sensitive config (passwords, usernames) — base64 encoded store hota hai

```yaml
# ConfigMap se
env:
  - name: DB_HOST
    valueFrom:
      configMapKeyRef:
        name: backend-config
        key: DB_HOST

  # Secret se
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: postgres-credentials-from-kv
        key: POSTGRES_PASSWORD
```

---

**Q: Liveness Probe aur Readiness Probe mein kya fark hai?**

|                       | Liveness Probe             | Readiness Probe                   |
| --------------------- | -------------------------- | --------------------------------- |
| Question              | "Container zinda hai?"     | "Container traffic le sakta hai?" |
| Fail hone pe          | Container restart          | Service se temporarily remove     |
| Use case              | Deadlock/hang detect karna | Startup complete hone tak wait    |
| `initialDelaySeconds` | 30s (startup time do)      | 5s (jaldi check karo)             |

Backend mein dono `/health` endpoint hit karte hain. Agar app hang ho jaye — liveness restart karega. Agar app start ho rahi ho — readiness traffic rokegi jab tak ready nahi.

---

**Q: Postgres ke liye `strategy: Recreate` kyun use kiya? `RollingUpdate` kyun nahi?**

`RollingUpdate` mein purana pod band hone se pehle naya pod start hota hai. Database ke liye yeh problem hai:

- PVC ka `accessMode: ReadWriteOnce` — sirf ek node ek waqt pe mount kar sakta hai
- Agar do postgres pods simultaneously same PVC mount karne ki koshish karein → conflict/corruption

`Recreate` mein: pehle purana pod completely band → phir naya start. Safe for stateful apps.

---

**Q: PVC, PV, aur EBS ka relationship kya hai?**

```
Application (Postgres Pod)
    ↓ uses
PVC (PersistentVolumeClaim) — "mujhe 5Gi storage chahiye, ReadWriteOnce"
    ↓ binds to
PV (PersistentVolume) — actual storage representation in K8s
    ↓ backed by
EBS Volume — actual AWS disk

StorageClass: gp2 → EBS CSI Driver automatically EBS volume banata hai
```

Pod delete ho → PVC remains → data safe. Pod wapas aaya → same PVC mount → data wapas.

---

**Q: `subPath: postgres` volumeMount mein kyun use kiya?**

```yaml
volumeMounts:
  - name: postgres-storage
    mountPath: /var/lib/postgresql/data
    subPath: postgres # ← yeh kyun?
```

PostgreSQL `PGDATA` directory ke andar direct mount se issue aata hai — postgres initialization fail hoti hai agar root directory pehle se exist kare. `subPath` ek subdirectory (`postgres/`) create karta hai andar — clean initialization hoti hai.

---

## 5. Terraform Concepts

**Q: Is project mein itne saare providers kyun use kiye?**

| Provider     | Kyun                                              |
| ------------ | ------------------------------------------------- |
| `aws`        | VPC, EKS, IAM, EBS banane ke liye                 |
| `kubernetes` | K8s namespace resource banane ke liye             |
| `kubectl`    | Raw YAML apply karne ke liye (ArgoCD install)     |
| `http`       | ArgoCD install.yaml URL se download karne ke liye |
| `null`       | Shell command run karne ke liye (kubectl patch)   |

`kubernetes` provider structured resources ke liye better hai. `kubectl` provider raw YAML ke liye — ArgoCD ka install.yaml 300+ resources ka ek bada file hai jo `kubernetes` provider se handle nahi hota.

---

**Q: Providers mein `exec` block kyun use kiya? Static token kyun nahi diya?**

```hcl
exec {
  command = "aws"
  args    = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
}
```

EKS tokens **short-lived** hote hain (15 minutes expire). Static token dena possible nahi. Har API call se pehle `aws eks get-token` run hota hai jo fresh temporary token return karta hai. Yahi proper AWS IAM authentication hai Kubernetes ke saath.

---

**Q: IRSA kya hai? EBS CSI Driver ke liye kyun zaruri tha?**

IRSA = IAM Roles for Service Accounts

Problem: EBS CSI Driver pod ko AWS API call karni hoti hai (EBS volumes create/attach/delete). Pehle yeh node ka IAM role use hota tha — matlab sab pods ko wahi permissions milti thi.

IRSA solution:

```
K8s Service Account → OIDC Token → AWS STS → IAM Role assume
```

Sirf `ebs-csi-controller-sa` service account yeh specific IAM role assume kar sakta hai. Baaki sab pods ko EBS permissions nahi milti. Pod-level least privilege.

---

**Q: `enable_cluster_creator_admin_permissions = true` kyun set kiya?**

EKS module v20+ mein by default Terraform apply karne wale IAM user/role ko cluster access nahi milta. Yeh flag set karne se jo IAM identity `terraform apply` run karti hai, usse automatically cluster admin access milta hai — warna `kubectl` commands fail hoti.

---

**Q: Application namespace Terraform mein comment out kyun kiya?**

```hcl
# resource "kubernetes_namespace_v1" "app" { ... }
# Commenting out to avoid stuck namespace during destroy
```

`terraform destroy` ke waqt problem: ArgoCD us namespace mein resources deploy kar chuka hota hai. Terraform namespace delete karne ki koshish karta hai, lekin ArgoCD ke resources hain andar — stuck ho jaata hai finalizers ki wajah se.

Solution: Namespace ko ArgoCD manage kare (`CreateNamespace=true` syncOption se) — Terraform ke scope se bahar. Destroy clean hota hai.

---

## 6. Security & Production Gaps

**Q: Is project mein kya production-ready nahi hai?**

1. **Plain secrets in Git** — `secret.yaml` mein hardcoded credentials. Production mein: AWS Secrets Manager + External Secrets Operator
2. **`single_nat_gateway = true`** — cost saving hai, lekin single point of failure. Production: one NAT Gateway per AZ
3. **`null_resource` for patching** — fragile, not idempotent properly. Production: ArgoCD Helm chart with values
4. **Classic Load Balancer** — outdated. Production: AWS ALB Ingress Controller + single Ingress resource
5. **`storageClassName: gp2`** — gp3 better performance aur 20% cheaper hai
6. **No resource quotas on namespace** — production mein namespace-level limits honi chahiye

---

**Q: Secrets ko properly handle karne ke liye kya karta?**

External Secrets Operator pattern:

```
AWS Secrets Manager (actual secret store)
    ↓
External Secrets Operator (K8s mein installed)
    ↓
ExternalSecret CRD (Git mein safe — sirf reference hai, value nahi)
    ↓
K8s Secret (automatically create/sync hota hai)
    ↓
Pod uses it
```

Git mein sirf ExternalSecret manifest hota hai jisme secret ka **name** hota hai — actual value AWS Secrets Manager mein rehti hai. Secure aur GitOps-compatible dono.

---

## 7. Scenario-Based Questions

**Q: Koi developer ne directly `kubectl scale deployment frontend --replicas=5` run kar diya. Kya hoga?**

ArgoCD `selfHeal: true` hai. ArgoCD next reconciliation cycle pe (seconds mein) detect karega ki Git mein `replicas: 2` hai lekin cluster mein 5 hain. Automatically `replicas: 2` pe wapas le aayega. Developer ka manual change revert ho jaayega.

**Moral:** GitOps mein cluster change karna hai toh Git mein karo. Direct kubectl se kiya toh ArgoCD revert karega.

---

**Q: New image deploy karna hai frontend ka. Kya steps hain?**

```bash
# 1. New image build aur push
docker build -t 33Krishna/frontend:v3 .
docker push 33Krishna/frontend:v3

# 2. kustomization.yaml update karo
# images:
#   - name: 33Krishna/frontend
#     newTag: v3   ← change karo

# 3. Commit aur push
git add manifests/kustomization.yaml
git commit -m "feat: bump frontend to v3"
git push origin main

# 4. ArgoCD detects change → syncs → rolling update starts
# Watch karo:
kubectl get pods -n 3tirewebapp-dev -w
```

Terraform touch nahi karna. `kubectl apply` manually nahi karna. Sirf Git.

---

**Q: ArgoCD UI mein "OutOfSync" dikha raha hai. Debug kaise karoge?**

```bash
# 1. ArgoCD CLI se diff dekho
argocd app diff 3tier-app

# 2. Application status check
kubectl get application 3tier-app -n argocd -o yaml

# 3. Events dekho
kubectl describe application 3tier-app -n argocd

# 4. Manually sync karo aur errors dekho
argocd app sync 3tier-app

# 5. Specific resource ka status
kubectl get pods -n 3tirewebapp-dev
kubectl describe pod <pod-name> -n 3tirewebapp-dev
```

Common reasons: image pull error, resource quota exceeded, PVC pending, secret missing.

---

**Q: Postgres pod crash kar raha hai. Kaise debug karoge?**

```bash
# 1. Pod status
kubectl get pods -n 3tirewebapp-dev

# 2. Crash reason
kubectl describe pod <postgres-pod> -n 3tirewebapp-dev
# Events section mein dekho

# 3. Logs
kubectl logs -f deployment/postgres -n 3tirewebapp-dev
kubectl logs -f deployment/postgres -n 3tirewebapp-dev --previous  # crashed container ke logs

# 4. PVC status check (storage issue?)
kubectl get pvc -n 3tirewebapp-dev
kubectl describe pvc postgres-pvc -n 3tirewebapp-dev

# 5. Secret exist karta hai?
kubectl get secret postgres-credentials-from-kv -n 3tirewebapp-dev
```

Common causes: EBS CSI driver not ready (PVC Pending), wrong secret key name, insufficient memory limits.
