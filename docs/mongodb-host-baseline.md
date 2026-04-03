# MongoDB Host Baseline (Phase 1A)

## Purpose
MongoDB runs on the WSL host for the initial Open5GS local CNF foundation.

## Validated host details
- WSL host IP used by Kubernetes pods: 172.21.70.46
- MongoDB port: 27017

## Current startup model
MongoDB was started manually (not via systemd) with:
sudo mongod --dbpath /var/lib/mongodb --bind_ip 127.0.0.1,172.21.70.46 --port 27017 --fork --logpath /var/log/mongodb/mongod.log

## Validation completed
- Host-side mongosh ping returned: { ok: 1 }
- Kubernetes pod TCP connectivity to 172.21.70.46:27017 succeeded

## Notes
- systemd may show mongod inactive in WSL; current lab uses manual startup.
- WSL IP may change after restart and must be revalidated if connectivity breaks.
