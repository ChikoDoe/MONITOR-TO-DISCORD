#!/bin/bash

### ====== CONFIG ======
DATA_DIR="/var/log/stb-monitor"
LAST_FILE="$DATA_DIR/last.json"
STATS_FILE="$DATA_DIR/stats.json"
LOGIC_TIME=$(date +%H:%M)
WEBHOOK_URL="ISI_WEBHOOK_WEBHOOK_LU"
IFACE="eth0"
### =====================

mkdir -p "$DATA_DIR"

# Inisialisasi file jika belum ada
if [ ! -f "$STATS_FILE" ]; then
cat <<EOF > $STATS_FILE
{
  "inbound": 0,
  "outbound": 0,
  "cpu_max": 0,
  "cpu_total": 0,
  "cpu_samples": 0
}
EOF
fi

# baca RX/TX saat ini
RX_NOW=$(cat /sys/class/net/$IFACE/statistics/rx_bytes)
TX_NOW=$(cat /sys/class/net/$IFACE/statistics/tx_bytes)

# kalau file last belum ada, buat dulu
if [ ! -f "$LAST_FILE" ]; then
echo "{\"rx\": $RX_NOW, \"tx\": $TX_NOW}" > $LAST_FILE
exit 0
fi

# baca RX/TX sebelumnya
RX_LAST=$(jq '.rx' $LAST_FILE)
TX_LAST=$(jq '.tx' $LAST_FILE)

# hitung selisih
DIFF_RX=$((RX_NOW - RX_LAST))
DIFF_TX=$((TX_NOW - TX_LAST))

# baca stats harian
IN=$(jq '.inbound' $STATS_FILE)
OUT=$(jq '.outbound' $STATS_FILE)
CPU_MAX=$(jq '.cpu_max' $STATS_FILE)
CPU_TOTAL=$(jq '.cpu_total' $STATS_FILE)
CPU_SAMPLES=$(jq '.cpu_samples' $STATS_FILE)

# update data total harian
IN=$((IN + DIFF_RX))
OUT=$((OUT + DIFF_TX))

# CPU usage
CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print 100-$8}')

# update max cpu
if (( $(echo "$CPU > $CPU_MAX" | bc -l) )); then
    CPU_MAX=$CPU
fi

CPU_TOTAL=$(echo "$CPU_TOTAL + $CPU" | bc)
CPU_SAMPLES=$((CPU_SAMPLES + 1))

# simpan stats harian baru
cat <<EOF > $STATS_FILE
{
  "inbound": $IN,
  "outbound": $OUT,
  "cpu_max": $CPU_MAX,
  "cpu_total": $CPU_TOTAL,
  "cpu_samples": $CPU_SAMPLES
}
EOF

# update RX/TX terakhir
echo "{\"rx\": $RX_NOW, \"tx\": $TX_NOW}" > $LAST_FILE

### ========== LAPORAN JAM 00:00 ==========
if [ "$LOGIC_TIME" == "00:00" ]; then
    CPU_AVG=$(echo "scale=2; $CPU_TOTAL / $CPU_SAMPLES" | bc)

    curl -H "Content-Type: application/json" -X POST \
      -d "{
            \"embeds\": [{
              \"title\": \"📊 Daily STB Report\",
              \"color\": 3066993,
              \"fields\": [
                {\"name\": \"Inbound\", \"value\": \"$(echo $IN | numfmt --to=iec)\"},
                {\"name\": \"Outbound\", \"value\": \"$(echo $OUT | numfmt --to=iec)\"},
                {\"name\": \"Max CPU\", \"value\": \"${CPU_MAX}%\"},
                {\"name\": \"Avg CPU\", \"value\": \"${CPU_AVG}%\"}
              ],
              \"timestamp\": \"$(date -Iseconds)\"
            }]
          }" \
      "$WEBHOOK_URL"

    # reset harian
cat <<EOF > $STATS_FILE
{
  "inbound": 0,
  "outbound": 0,
  "cpu_max": 0,
  "cpu_total": 0,
  "cpu_samples": 0
}
EOF
fi
