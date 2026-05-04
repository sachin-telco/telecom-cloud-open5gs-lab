#!/bin/bash

set -e

echo "[UPF] Ensuring TUN interface..."
if ! ip link show ogstun &>/dev/null; then
  sudo ip tuntap add dev ogstun mode tun
  sudo ip addr add 10.45.0.1/16 dev ogstun
fi

sudo ip link set ogstun up
sudo sysctl -w net.ipv4.ip_forward=1

echo "[UPF] Restarting container..."
docker rm -f open5gs-upf 2>/dev/null || true

docker run -d \
  --name open5gs-upf \
  --privileged \
  --network host \
  --cap-add NET_ADMIN \
  --cap-add SYS_ADMIN \
  --security-opt seccomp=unconfined \
  -v $(pwd)/lab-components/upf/upf.yaml:/etc/open5gs/upf.yaml \
  --entrypoint "" \
  gradiant/open5gs:2.7.6 \
  sh -c "ip link set ogstun up 2>/dev/null || true; open5gs-upfd -c /etc/open5gs/upf.yaml"

echo "[UPF] Started. Logs:"
sleep 2
docker logs open5gs-upf
