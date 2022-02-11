#!/usr/bin/env bash
set -euo pipefail

vendor_lib_dir="./lib/vendor"
docs_scanned=0
uuid=0
date_string="$(date "+%Y%m%d_%H%M%S")"
base_filename="$uuid-$date_string-"
filename_pattern="base_filename%04d.pnm"
out_filename="$date_string.pdf"
temp_dir="/tmp"
scans_dir="$HOME/Documents/scans"
DEBUG="${DEBUG:-}"

# 0. Prompt insert doc pages to ADF
# 1. scan doc with adf duplex and scanadf
# 2. for each page:
#   - rotate even pages 180 degrees
#   - clean text 
# 3. after all pages cleaned:
#   - concat pnm to one pdf
#   - name $(date "+%Y%m%d_%H%M%S").pdf 
# 4. Prompt new doc or quit

prompt_insert_pages() {
  prompt="Insert document pages in ADF and press any key to start scanning, q to quit. "
  read -r -p "$prompt" -s -n 1 input
  echo ""
  if [[ $input = "q" ]]; then
    handle_exit
  fi
  scan_new_doc
}

scan_new_doc() {
  init_uuid
  init_date_string
  init_filenames
  scan_pages
  assemble_pdf
  move_pdf
  increment_docs_count
}

init_uuid() {
  uuid="$(dbus-uuidgen)"
}

init_date_string() {
  date_string="$(date "+%Y%m%d_%H%M%S")"
}

init_filenames() {
  base_filename="$uuid-$date_string-"
  filename_pattern="$uuid-$date_string-%04d.pnm"
  out_filename="$date_string.pdf"
}

scan_pages() {
  echo "Scanning document..."
  DEBUG=$DEBUG scanadf \
    --device-name hp5590 \
    --source "ADF Duplex" \
    -x 210.0 -y 297.0 \
    --mode Gray \
    --resolution 300 \
    --scan-script ./lib/process_page.sh \
    --script-wait \
    --output-file "$temp_dir/$filename_pattern" \
    --progress \
    --verbose
}

increment_docs_count() {
  docs_scanned=$((docs_scanned +1))
}

assemble_pdf() {
  pages="$temp_dir/$base_filename\*.pnm"
  echo $pages
  convert $pages "$temp_dir/$out_filename" 
}

move_pdf() {
  mv "$temp_dir/$out_filename" "$scans_dir/"
  echo "$scans_dir/$out_filename created."
}

handle_exit() {
  echo "Scanned $docs_scanned documents."
  exit 0
}

while true; do
  prompt_insert_pages
done
