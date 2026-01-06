#!/bin/bash
#Internet speed test solution hosted on AWS cloud using cloud front 

# Download behined AWS CFN served from S3 and upload to API gateway and reponse comes via lambda fundtion - 200 OK
# Config - both can be http URLs if setup correctly . 

UPLOAD_URL=<"UPLOAD URL">
DOWNLOAD_URL="<Download file" #file path must be given e.g http://<servername.domain.com>/100mb.test
UPLOAD_SIZE_MB=50   # size of test file to upload
ITERATIONS=3        # number of test runs
CSV_FILE="speedtest_results.csv"

# Generate random upload file once
dd if=/dev/urandom bs=1M count=$UPLOAD_SIZE_MB of=/tmp/payload.test >/dev/null 2>&1

# Initialize CSV file with header if not exists
if [ ! -f "$CSV_FILE" ]; then
  echo "timestamp,run,upload_mbps,download_mbps" > "$CSV_FILE"
fi

# Arrays to store results
upload_speeds=()
download_speeds=()

for i in $(seq 1 $ITERATIONS); do
  echo "=== Test Run #$i ==="
  timestamp=$(date +"%Y-%m-%d %H:%M:%S")

  # --- Upload Test ---
  upload_bytes=$(curl -X POST -L -f "$UPLOAD_URL" \
      --data-binary @/tmp/payload.test \
      -o /dev/null -s -w "%{size_upload} %{time_total} %{speed_upload}")
  upload_speed_bps=$(echo $upload_bytes | awk '{print $3}')
  upload_speed_mbps=$(echo "scale=2; $upload_speed_bps/125000" | bc)
  upload_speeds+=($upload_speed_mbps)
  echo "Upload speed: $upload_speed_mbps Mbps"

  # --- Download Test ---
  download_bytes=$(curl -L -f -o /dev/null "$DOWNLOAD_URL" \
      -s -w "%{size_download} %{time_total} %{speed_download}")
  download_speed_bps=$(echo $download_bytes | awk '{print $3}')
  download_speed_mbps=$(echo "scale=2; $download_speed_bps/125000" | bc)
  download_speeds+=($download_speed_mbps)
  echo "Download speed: $download_speed_mbps Mbps"

  # --- Append to CSV ---
  echo "$timestamp,$i,$upload_speed_mbps,$download_speed_mbps" >> "$CSV_FILE"

  echo
done

# --- Stats function without local -n ---
calc_stats() {
  arr=("$@")
  total=0
  min=${arr[0]}
  max=${arr[0]}

  for val in "${arr[@]}"; do
    total=$(echo "$total + $val" | bc)
    comp=$(echo "$val < $min" | bc)
    if [ "$comp" -eq 1 ]; then min=$val; fi
    comp=$(echo "$val > $max" | bc)
    if [ "$comp" -eq 1 ]; then max=$val; fi
  done

  avg=$(echo "scale=2; $total/${#arr[@]}" | bc)
  echo "$avg $min $max"
}

# --- Calculate stats ---
read avg_upload min_upload max_upload <<< $(calc_stats "${upload_speeds[@]}")
read avg_download min_download max_download <<< $(calc_stats "${download_speeds[@]}")

echo "=== Final Results (across $ITERATIONS runs) ==="
echo "Upload:   Avg = $avg_upload Mbps, Min = $min_upload Mbps, Max = $max_upload Mbps"
echo "Download: Avg = $avg_download Mbps, Min = $min_download Mbps, Max = $max_download Mbps"
echo
echo "📄 Results saved to $CSV_FILE"
