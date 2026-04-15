# Phase 1B - UPF Integration (Checkpoint)

## Architecture
- Control Plane: Kubernetes (AMF, SMF, NRF, SCP)
- User Plane: External UPF (host-based)

## Key Learnings
- UPF requires host networking (TUN, GTP-U)
- Kubernetes not suitable for UPF without advanced setup
- PFCP used between SMF and UPF (port 8805)

## Network Setup
- ogstun: 10.45.0.1/16
- UPF Host IP: <your-ip> (e.g., 172.21.70.46)

## Status
- UPF running via nohup
- SMF configured with external UPF
- PFCP connectivity expected (verification pending)

## Next Step
- Integrate UERANSIM (UE + gNB simulation)
- Validate PDU session establishment
