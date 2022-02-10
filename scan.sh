#!/usr/bin/env bash
set -euo pipefail

vendor_lib_dir="./lib/vendor"
docs_scanned=0
pages_scanned=0
page_number=0
uuid=0
date_string="$(date "+%Y%m%d_%H%M%S")"
base_filename="$uuid-$date_string-"
filename_pattern="base_filename%04d.pnm" # not used anymore
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
  init_vars
  scan_page
  clean_pages
  assemble_pdf
  move_pdf
  increment_docs_count
}

init_vars() {
  uuid="$(dbus-uuidgen)"
  date_string="$(date "+%Y%m%d_%H%M%S")"
  base_filename="$uuid-$date_string-"
  filename_pattern="$uuid-$date_string-%04d.pnm"
  out_filename="$date_string.pdf"
  page_number=0
}

scan_page() {
  page_number=$((page_number +1))
  echo "Scanning page $page_number..."

  DEBUG=$DEBUG scanimage \
    --device-name hp5590 \
    --source "ADF Duplex" \
    -x 210.0 -y 297.0 \
    --mode Gray \
    --resolution 300 \
    --output-file "$temp_dir/$base_filename$page_number.pnm" \
    --progress \
    --verbose
  check_pages_left
}

check_pages_left() {
  pages_left=$(scanimage -d hp5590 -A | grep -Po "adf.*\[\K(\w{2,3})\]" | grep -Eo "\w{2,3}")

  if [[ $pages_left = "yes" ]]; then
    scan_page
  fi
}

increment_docs_count() {
  docs_scanned=$((docs_scanned +1))
}

clean_pages() {
  pages=$temp_dir/$base_filename*.pnm
  echo $pages
  # $vendor_lib_dir/textdeskew $file $file > /dev/null 2>&1 || echo "Not enough text, unable to deskew page"
  # $vendor_lib_dir/textcleaner $file $file
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
