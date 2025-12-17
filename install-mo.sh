#!/bin/bash

echo "=============================================="
echo "   MoneroOcean Auto Installer (XMRig)"
echo "=============================================="

# USER SETTINGS
WALLET="4A7BsLhYMwFhz5pTULCVK2iV3xeEbjPbn97THYT8dcea1yYUnBTPBkZ3ocTL5w1hjJVAhrkXRB5pXNQwgFAe1fYaJrMgRvN"
WORKER="vps1"
TOKEN="anurag123"
POOL="gulf.moneroocean.stream:10032"

# DETECT CPU THREADS
CPU_THREADS=$(nproc)
# Use 90% of threads
USE_THREADS=$((CPU_THREADS * 90 / 100))
if [ "$USE_THREADS" -lt 1 ]; then USE_THREADS=1; fi

echo "Detected CPU threads: $CPU_THREADS"
echo "Using threads for mining: $USE_THREADS"

# UPDATE & INSTALL DEPENDENCIES
apt update -y
apt install -y git build-essential cmake libuv1-dev libssl-dev libhwloc-dev jq

# Enable hugepages
echo "vm.nr_hugepages=1168" >> /etc/sysctl.conf
sysctl -p

# DOWNLOAD AND BUILD XMRig
mkdir -p /opt/xmrig
cd /opt/xmrig
git clone https://github.com/MoneroOcean/xmrig.git
cd xmrig
mkdir -p build
cd build
cmake ..
make -j$(nproc)

# CREATE CONFIG.JSON
cat > /opt/xmrig/xmrig/build/config.json << EOF
{
    "api": {
        "id": "miner",
        "worker-id": "$WORKER",
        "access-token": "$TOKEN"
    },
    "http": {
        "enabled": true,
        "host": "0.0.0.0",
        "port": 18080,
        "access-token": "$TOKEN",
        "restricted": false
    },
    "autosave": true,
    "cpu": {
        "enabled": true,
        "huge-pages": true,
        "asm": true,
        "threads": $USE_THREADS
    },
    "randomx": {
        "mode": "auto",
        "1gb-pages": false
    },
    "donate-level": 0,
    "pools": [
        {
            "algo": "rx/0",
            "url": "$POOL",
            "user": "$WALLET",
            "pass": "x",
            "keepalive": true,
            "enabled": true,
            "tls": false
        }
    ]
}
EOF

# CREATE SYSTEMD SERVICE
cat > /etc/systemd/system/xmrig.service << EOF
[Unit]
Description=XMRig Miner
After=network.target

[Service]
ExecStart=/opt/xmrig/xmrig/build/xmrig --config=/opt/xmrig/xmrig/build/config.json
Restart=always
Nice=10
CPUWeight=50
MemoryMax=3G

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable xmrig
systemctl restart xmrig

echo "=============================================="
echo "   XMRig Installed & Started"
echo "=============================================="
echo " Dashboard:"
echo "   http://YOUR_SERVER_IP:18080/"
echo " API endpoint:"
echo "   http://YOUR_SERVER_IP:18080/api.json?token=$TOKEN"
echo "=============================================="
echo " To view miner logs: journalctl -u xmrig -f"
