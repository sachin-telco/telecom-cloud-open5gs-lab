# Open5GS Kubernetes Lab — Deployment Reference
> Version-locked reference for all components, paths, configs, and lessons learned.
> Maintained alongside the telecom-cloud-open5gs-lab repository.

---

## Environment

| Component | Detail |
|---|---|
| Host OS | Windows 11 + WSL2 |
| WSL2 Distro | Ubuntu (kernel 6.6.87.2-microsoft-standard-WSL2) |
| Kubernetes | KinD v1.35.1 |
| Cluster name | `telecom-lab-control-plane` |
| KinD node IP | `172.18.0.2` (Docker bridge — may vary) |
| WSL2 host IP | `172.21.70.46` (changes on reboot — verify with `hostname -I`) |
| CNI | kindnet (KinD default) |

---

## Image Registry

| Component | Image | Version |
|---|---|---|
| Open5GS NFs | `docker.io/gradiant/open5gs` | `2.7.6` |
| Open5GS WebUI | `docker.io/gradiant/open5gs-webui` | `2.7.0` |
| MongoDB | `mongo` | (latest at deployment time) |

---

## Critical Image Facts — gradiant/open5gs:2.7.6

These facts are non-obvious and caused multiple debugging sessions:

**Binary path:** `/opt/open5gs/bin/open5gs-<nf>d`
- NOT in `/usr/bin/` — always use full path or ensure PATH includes `/opt/open5gs/bin`

**Default config path:** `/opt/open5gs/etc/open5gs/<nf>.yaml`
- NOT `/etc/open5gs/` — all ConfigMap mounts must use `/opt/open5gs/etc/open5gs/<nf>.yaml`

**MongoDB URI:** Set via environment variable `DB_URI=mongodb://mongo/open5gs`
- This env var overrides any `db_uri` value in the config file
- Must be overridden in deployment spec with correct URI
- Correct URI: `mongodb://mongodb.default.svc.cluster.local/open5gs`

**WebUI process port:** `9999` (not 3000 as the service originally defined)
- The Node.js server binds to 9999
- Service targetPort must be 9999

---

## Kubernetes Namespaces

| Namespace | Contents |
|---|---|
| `telecom` | All Open5GS NFs, UERANSIM (planned) |
| `default` | MongoDB |
| `kube-system` | Kubernetes system pods |

---

## MongoDB

| Detail | Value |
|---|---|
| Namespace | `default` |
| Service name | `mongodb` |
| Full DNS | `mongodb.default.svc.cluster.local` |
| Port | `27017` |
| Database | `open5gs` |
| Full URI | `mongodb://mongodb.default.svc.cluster.local/open5gs` |

---

## Open5GS Network Functions — Deployment Reference

All NFs run in the `telecom` namespace. All SBI communication uses HTTP/2 on port 7777.

### NRF (Network Repository Function)
- **Role:** Central registry — all NFs register here and discover each other
- **Service name:** `open5gs-nrf`
- **SBI URI used by others:** `http://open5gs-nrf:7777`
- **Config mount:** `/opt/open5gs/etc/open5gs/nrf.yaml`
- **MongoDB:** No

### SCP (Service Communication Proxy)
- **Role:** Indirect communication proxy between NFs (used by this image by default)
- **Service name:** `open5gs-scp`
- **Config mount:** `/opt/open5gs/etc/open5gs/scp.yaml`
- **MongoDB:** No

### AMF (Access and Mobility Management Function)
- **Role:** UE registration, authentication coordination, mobility management
- **Service name:** `open5gs-amf`
- **Ports:** SBI 7777, NGAP 38412/SCTP (connects to gNB)
- **Config mount:** `/opt/open5gs/etc/open5gs/amf.yaml`
- **MongoDB:** No
- **Key config:** PLMN (MCC/MNC), TAC, supported slices (S-NSSAI)

### SMF (Session Management Function)
- **Role:** PDU session establishment, PFCP control of UPF
- **Service name:** `open5gs-smf`
- **Ports:** SBI 7777, PFCP 8805/UDP, GTP-C 2123/UDP, GTP-U 2152/UDP
- **Config mount:** `/opt/open5gs/etc/open5gs/smf.yaml`
- **MongoDB:** No
- **Key config:** PFCP client must point to UPF IP, DNS servers, session subnet
- **Critical:** PFCP server must bind to `0.0.0.0` inside pod — never to node IP

### UPF (User Plane Function)
- **Role:** User data forwarding, GTP-U tunnel termination, TUN interface management
- **Deployment:** Docker on WSL2 host with `--network host` — NOT in Kubernetes
- **Why not in K8s:** Requires kernel TUN device (`/dev/net/tun`) and `ioctl` access blocked inside nested KinD containers
- **Docker command:** `bash lab-components/upf/start-upf.sh`
- **Config file:** `lab-components/upf/upf.yaml`
- **PFCP port:** `8805/UDP` on `172.21.70.46`
- **GTP-U port:** `2152/UDP`
- **TUN interface:** `ogstun` at `10.45.0.1/16`
- **Must restart after:** Every WSL2 reboot

### AUSF (Authentication Server Function)
- **Role:** Runs 5G-AKA / EAP-AKA' authentication algorithms
- **Service name:** `open5gs-ausf`
- **Config mount:** `/opt/open5gs/etc/open5gs/ausf.yaml`
- **MongoDB:** No
- **Depends on:** UDM (for subscriber keys)

### UDM (Unified Data Management)
- **Role:** Subscriber profile frontend — IMSI, auth keys, allowed slices
- **Service name:** `open5gs-udm`
- **Config mount:** `/opt/open5gs/etc/open5gs/udm.yaml`
- **MongoDB:** No (reads through UDR)
- **Depends on:** UDR

### UDR (Unified Data Repository)
- **Role:** Raw database access layer — bridge between SBI world and MongoDB
- **Service name:** `open5gs-udr`
- **Config mount:** `/opt/open5gs/etc/open5gs/udr.yaml`
- **MongoDB:** Yes — requires `DB_URI` env var override
- **Env var required:** `DB_URI: mongodb://mongodb.default.svc.cluster.local/open5gs`

### PCF (Policy Control Function)
- **Role:** QoS policy management — bandwidth, priority, PCC rules per session
- **Service name:** `open5gs-pcf`
- **Config mount:** `/opt/open5gs/etc/open5gs/pcf.yaml`
- **MongoDB:** Yes — requires `DB_URI` env var override
- **Env var required:** `DB_URI: mongodb://mongodb.default.svc.cluster.local/open5gs`

### NSSF (Network Slice Selection Function)
- **Role:** Selects network slice for UE based on requested S-NSSAI
- **Service name:** `open5gs-nssf`
- **Config mount:** `/opt/open5gs/etc/open5gs/nssf.yaml`
- **MongoDB:** No
- **Key config:** `nsi` must be nested under `nssf.sbi.client` — not at top level

### WebUI
- **Role:** Web dashboard for subscriber management
- **Image:** `gradiant/open5gs-webui:2.7.0` (separate from core image)
- **Service name:** `open5gs-webui`
- **Process port:** `9999` (Node.js server)
- **Service type:** NodePort — external port `30007`
- **Access (WSL2):** `http://172.18.0.2:30007`
- **Access (port-forward):** `kubectl port-forward -n telecom deployment/open5gs-webui 9999:9999`
- **Default credentials:** Created manually — no auto-seed in this image
- **MongoDB:** Yes — `DB_URI` env var set in deployment

---

## Config Key Reference — Common Mistakes

| NF | Wrong key | Correct key | Notes |
|---|---|---|---|
| UDR | `db_uri:` inside `udr:` block | `db_uri:` at root level | Top-level key, before `logger:` |
| UDR | `db: uri:` nested | `DB_URI` env var | Env var overrides file |
| PCF | same as UDR | same as UDR | Identical pattern |
| SMF | `pfcp.client: - address:` bare list | `pfcp.client.upf: - address:` | Must be under `upf:` key |
| SMF | `pfcp.server.address: 172.18.0.2` | `pfcp.server.address: 0.0.0.0` | Pod cannot bind to node IP |
| NSSF | `nssf.nsi:` top level | `nssf.sbi.client.nsi:` | Nested under sbi.client |
| All | Mount to `/etc/open5gs/<nf>.yaml` | Mount to `/opt/open5gs/etc/open5gs/<nf>.yaml` | Correct path for this image |

---

## PLMN and Slice Configuration

| Parameter | Value |
|---|---|
| MCC | `999` |
| MNC | `70` |
| PLMN | `99970` |
| TAC | `1` |
| SST | `1` |
| SD | `000001` |
| DNN | `internet` |
| UE subnet | `10.45.0.0/16` |
| UE gateway | `10.45.0.1` (ogstun) |
| DNS | `8.8.8.8`, `8.8.4.4` |
| MTU | `1400` |

---

## Test Subscriber

Added directly to MongoDB (WebUI add button not available in v2.7.0):

| Field | Value |
|---|---|
| IMSI | `999700000000001` |
| K (subscriber key) | `465B5CE8B199B49FAA5F0A2EE238A6BC` |
| OPc | `E8ED289DEBA952E4283B54E88E6183CA` |
| AMF | `8000` |
| DNN | `internet` |
| SST | `1` |

Add subscriber command:
```bash
kubectl exec -n default deployment/mongodb -- mongosh open5gs --eval '
db.subscribers.insertOne({
  "imsi": "999700000000001",
  "security": {
    "k": "465B5CE8B199B49FAA5F0A2EE238A6BC",
    "op": null,
    "opc": "E8ED289DEBA952E4283B54E88E6183CA",
    "amf": "8000",
    "sqn": NumberLong(0)
  },
  "ambr": {
    "downlink": { "value": 1, "unit": 3 },
    "uplink": { "value": 1, "unit": 3 }
  },
  "slice": [{
    "sst": 1,
    "default_indicator": true,
    "session": [{
      "name": "internet",
      "type": 3,
      "ambr": {
        "downlink": { "value": 1, "unit": 3 },
        "uplink": { "value": 1, "unit": 3 }
      },
      "qos": {
        "index": 9,
        "arp": {
          "priority_level": 8,
          "pre_emption_capability": 1,
          "pre_emption_vulnerability": 1
        }
      }
    }]
  }],
  "access_restriction_data": 32,
  "subscriber_status": 0,
  "operator_determined_barring": 0,
  "network_access_mode": 0,
  "subscribed_rau_tau_timer": 12,
  "__v": 0
})'
```

---

## WebUI Admin Account Creation

The `gradiant/open5gs-webui` image does not auto-seed a default admin. Create manually:

```bash
kubectl exec -n telecom deployment/open5gs-webui -- \
  node -e "
const mongoose = require('mongoose');
const Account = require('/opt/open5gs-webui/server/models/account');
mongoose.connect('mongodb://mongodb.default.svc.cluster.local:27017/open5gs');
mongoose.connection.once('open', function() {
  Account.register(new Account({ username: 'admin', roles: ['admin'] }), '1423', function(err) {
    if (err) console.log('Error:', err);
    else console.log('Admin account created successfully');
    mongoose.connection.close();
  });
});
"
```

Credentials: `admin` / `1423`

---

## Post-Reboot Startup Checklist

Every time WSL2 restarts, run these in order:

```bash
# 1. Start Docker (if not auto-started)
sudo service docker start

# 2. Start KinD cluster
docker start telecom-lab-control-plane

# 3. Wait for API server
sleep 15 && kubectl get nodes

# 4. Start UPF (always manual)
cd ~/telecom-cloud-open5gs-lab
bash lab-components/upf/start-upf.sh

# 5. Restart SMF (picks up PFCP connection to UPF)
kubectl rollout restart deployment open5gs-smf -n telecom

# 6. Verify all pods running
kubectl get pods -n telecom
kubectl get pods -n default | grep mongo

# 7. Verify PFCP association
kubectl logs -n telecom deployment/open5gs-smf | grep -i "pfcp\|assoc" | tail -5
docker logs open5gs-upf 2>&1 | grep -i "assoc" | tail -5

# 8. (Optional) Start WebUI port-forward
kubectl port-forward -n telecom deployment/open5gs-webui 9999:9999 &
```

---

## Repo Structure

```
telecom-cloud-open5gs-lab/
├── k8s/
│   └── base/
│       └── open5gs/
│           ├── amf/        (deployment.yaml, configmap.yaml, service.yaml)
│           ├── smf/
│           ├── nrf/
│           ├── scp/
│           ├── ausf/
│           ├── udm/
│           ├── udr/
│           ├── pcf/
│           ├── nssf/
│           ├── upf/        (manifest kept for reference — not used, UPF runs via Docker)
│           └── webui/
├── lab-components/
│   └── upf/
│       ├── upf.yaml        (UPF config for Docker deployment)
│       └── start-upf.sh   (TUN setup + docker run script)
├── docs/
│   ├── phase1b-upf-integration.md
│   └── DEPLOYMENT_REFERENCE.md   (this file)
└── README.md
```

---

## Git Checkpoints

| Tag / Commit | Description |
|---|---|
| `v0.2-upf-integration` | Phase 1B: External UPF integration completed |
| Phase 2 complete (planned) | Full 5G core + UERANSIM UE attach |

---

## Key Lessons Learned

| Session | Issue | Root Cause | Fix |
|---|---|---|---|
| Day 1 | SMF CrashLoopBackOff | `pfcp.client` was bare list, not `upf:` map | Add `upf:` key under `pfcp.client` |
| Day 1 | SMF crash — UPF hostname not resolved | Open5GS v2.7.6 resolves hostname at startup | Deploy UPF first or use IP |
| Day 1 | UPF TUN error in K8s pod | `ioctl` blocked inside KinD nested container | Run UPF via Docker `--network host` |
| Day 1 | SMF crash — `No smf.dns` | v2.7.6 requires `dns:` field | Add `dns: [8.8.8.8, 8.8.4.4]` |
| Day 1 | PFCP not associating | SMF binding `0.0.0.0` worked, UPF responded | Fixed by correct bind address |
| Day 2 | SMF crash after reboot | PFCP server bound to node IP `172.18.0.2` | Always bind to `0.0.0.0` in pods |
| Day 2 | UDR/PCF `unknown key db_uri` | Key placed inside NF block, not root level | Move `db_uri:` to root of YAML |
| Day 2 | UDR/PCF still using `mongodb://mongo` | `DB_URI` env var in image overrides config file | Override `DB_URI` in deployment spec |
| Day 2 | Config changes not taking effect | Pods mounting to `/etc/open5gs/` not read | Binary reads `/opt/open5gs/etc/open5gs/` |
| Day 2 | NSSF crash — `unknown key nsi` | `nsi` placed at `nssf:` level | Must be under `nssf.sbi.client.nsi` |
| Day 2 | WebUI login failing | No default admin account in this image | Create via Node.js script in container |
