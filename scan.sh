#!/usr/bin/env bash
set -euo pipefail

vendor_lib_dir="./lib/vendor"
docs_scanned=0
date_string="$(date "+%Y%m%d_%H%M%S")"
base_filename="$date_string-"
filename_pattern="base_filename%04d.pnm"
out_filename="$date_string.pdf"
temp_dir="/tmp"
scans_dir="$HOME/Documents/scans"
DEBUG="${DEBUG:-}"

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
  init_date_string
  init_filenames
  scan_pages
  assemble_pdf
  move_pdf
  increment_docs_count
}

init_date_string() {
  date_string="$(date "+%Y%m%d_%H%M%S")"
}

init_filenames() {
  base_filename="$date_string-"
  filename_pattern="$date_string-%04d.pnm"
  out_filename="$date_string.pdf"
}

scan_pages() {
  echo "Scanning document..."
  # An A4 page is 210x297mm. However, using 297mm confuses the scanner and
  # results in "ghost" pages, so using a slightly higher value and then
  # trimming the resulting scanned image avoids the problem.
  DEBUG=$DEBUG scanadf \
    --device-name hp5590 \
    --source "ADF Duplex" \
    -x 210.0 -y 320.0 \
    --mode Gray \
    --resolution 300 \
    --scan-script ./lib/process_page.sh \
    --script-wait \
    --output-file "$temp_dir/$filename_pattern"
}

increment_docs_count() {
  docs_scanned=$((docs_scanned +1))
}

assemble_pdf() {
  pages="$temp_dir/$base_filename*.pnm"
  convert $pages "$temp_dir/$out_filename" 
}

move_pdf() {
  cp "$temp_dir/$out_filename" "$scans_dir/"
  echo "$scans_dir/$out_filename created."
}

handle_exit() {
  echo "Scanned $docs_scanned documents. Bye!"
  exit 0
}

while true; do
  prompt_insert_pages
done
