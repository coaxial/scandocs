#!/usr/bin/env bash
set -euo pipefail

init_date_string() {
  date_string="$(date "+%Y%m%d_%H%M%S")"
}

init_filenames() {
  base_filename="$date_string-$paper_format-"
  filename_pattern="$base_filename%04d.pnm"
  out_filename="$date_string.pdf"
}

vendor_lib_dir="./lib/vendor"
docs_scanned=0
init_date_string
paper_format="a4" # or letter
init_filenames
temp_dir="/tmp"
scans_dir="$HOME/Documents/scans"
DEBUG="${DEBUG:-}"

prompt_insert_pages() {
  prompt="Insert document pages in ADF and press <Enter> to start scanning, s to change paper size, q to quit. [${paper_format}] "
  log_message "$prompt"
  read -r -s -n 1 input
  echo ""

  if [[ $input = "s" ]]; then
    debug_log_message "Paper format was $paper_format"

    if [[ $paper_format = "a4" ]]; then
      paper_format="letter"
    elif [[ $paper_format = "letter" ]]; then
      paper_format="legal"
    else
      paper_format="a4"
    fi

    debug_log_message "Paper format is now $paper_format"
  fi

  if [[ $input = "q" ]]; then
    handle_exit
  fi

  if [[ $input = "" ]]; then
    local _adf_loaded=$(scanimage -d hp5590 -A --format=pnm | grep -Po "adf.*\[\K(\w{2,3})\]" | grep -Eo "\w{2,3}")
    if [[ $_adf_loaded = "yes" ]]; then
      scan_new_doc
    else
      log_message "No document detected in ADF."
    fi
  fi
}

scan_new_doc() {
  init_date_string
  init_filenames
  scan_pages
  assemble_pdf
  move_pdf
  increment_docs_count
}

scan_pages() {
  log_message "Scanning document..."
  # An A4 page is 210x297mm. However, using 297mm confuses the scanner and
  # results in "ghost" pages, so using a slightly higher value and then
  # trimming the resulting scanned image avoids the problem.
  # See https://gitlab.com/sane-project/backends/-/issues/572
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
  pages="${temp_dir}/${base_filename}*.png"
  convert $pages "$temp_dir/$out_filename" 
}

move_pdf() {
  cp "$temp_dir/$out_filename" "$scans_dir/"
  echo "$scans_dir/$out_filename created."
}

handle_exit() {
  log_message "Scanned $docs_scanned documents. Bye!"
  exit 0
}

debug_log_message () {
  if [[ $DEBUG ]]; then
    log_message "DEBUG: $1"
  fi
}

log_message() {
  # output messages to stderr
  echo "[scan ] $1" >&2
}

main() {
  debug_log_message "debug output enabled"
  while true; do
    prompt_insert_pages
  done
}

main
