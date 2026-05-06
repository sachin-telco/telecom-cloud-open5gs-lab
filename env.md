## 💻 Environment Context

This setup is built on a **personal laptop (WSL + Docker + KIND)** for **targeted 5G core + DevOps learning**.

### Key Characteristics

* Single-node Kubernetes (KIND)
* Mixed networking (WSL ↔ Docker ↔ Kubernetes)
* External UPF running on host
* RAN simulated via UERANSIM

⚠️ Note:
This is **not production-grade networking**, and certain limitations exist:

* SCTP exposure challenges
* Pod network not directly reachable from host
* NodePort behavior differs from cloud environments

---

## 🔗 Collaboration & Portability Strategy

GitHub is used as a **communication layer across systems/laptops**, not just version control.

### Purpose:

* Share infra state across multiple machines
* Track debugging progress
* Maintain reproducible setup
* Store network mappings & configs

---

## 📂 Live Debug Tracking Approach

We maintain a **living document** that is continuously updated.

### File:

```bash
Deployment_reference.md
```

### Sections to Update Regularly:

* Current pod/service state
* Config changes (gnb, amf, upf)
* Errors observed
* Commands executed
* Working vs broken paths

---

## 🧾 Logging Strategy (Recommended)

### 1. Manual Snapshot Logs

After every major step:

```bash
kubectl get pods -n telecom -o wide >> logs/state.log
kubectl get svc -n telecom >> logs/state.log
```

---

### 2. Component Logs

#### AMF

```bash
kubectl logs -n telecom deployment/open5gs-amf >> logs/amf.log
```

#### SMF

```bash
kubectl logs -n telecom deployment/open5gs-smf >> logs/smf.log
```

#### UPF (host)

```bash
docker logs open5gs-upf >> logs/upf.log
```

#### gNB

```bash
sudo ./build/nr-gnb -c config/my-gnb.yaml | tee logs/gnb.log
```

---

### 3. Structured Debug Notes

Always log in this format:

```text
[DATE]
Action:
Result:
Observation:
Next Step:
```

---

## 🔄 Git Workflow (Recommended)

### Option A (Simple & Effective)

```bash
git add .
git commit -m "debug: AMF SCTP connectivity attempt"
git push
```

---

### Option B (Cleaner for Logs)

Add logs but avoid clutter:

```bash
logs/*.log
```

👉 Either:

* commit selectively
* OR push only summaries in MD

---

## 🚀 Suggested Workflow Going Forward

1. Perform change
2. Capture output
3. Update MD file
4. Push to GitHub
5. Continue debugging from any machine

---

## 🌐 External Tool Integration (Future)

This repo can later be used by:

* Dashboards (Grafana-like)
* Parsing scripts (Python)
* Automation pipelines (CI/CD)
* Observability experiments

---

## 🧠 Key Principle

👉 Treat this like a **real telecom lab notebook**

Not:
"I tried something"

But:
"I executed → observed → concluded → iterated"

