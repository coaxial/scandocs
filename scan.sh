#!/usr/bin/env bash
set -euo pipefail
shopt -s globstar nullglob

DEBUG="${DEBUG:-}"

debug_log_message () {
  if [[ $DEBUG ]]; then
    log_message "DEBUG: $1"
  fi
}

log_message() {
  # output messages to stderr
  echo "[scan ] $1" >&2
}

init_date_string() {
  date_string="$(date "+%Y%m%d_%H%M%S")"
}

init_filenames() {
  base_filename="$date_string-$paper_format-"
  if [[ $processing != "" ]]; then
    filename_pattern="$base_filename%04d-${processing}.pnm"
  else
    filename_pattern="$base_filename%04d.pnm"
  fi
  out_filename="$date_string.pdf"

  debug_log_message "using filename pattern: $filename_pattern"
}

debug_log_message "debug output enabled"
docs_scanned=0
init_date_string
paper_format="a4" # or letter
processing=""
init_filenames
temp_dir="/tmp"
scans_dir="$HOME/Documents/scans"
source="adf"

prompt_insert_pages() {
  local _prompt="Insert document and press <Enter> to start scanning, d to toggle deskewing on/off, s to change paper size, o to change source, q to quit. [${paper_format}] [${source}] [${processing}] "
  log_message "$_prompt"
  read -r -s -n 1 input
  echo ""

  if [[ $input = "d" ]]; then
    debug_log_message "processing was $processing"

    if [[ $processing = "" ]]; then
      processing="nodeskew"
    elif [[ $processing = "nodeskew" ]]; then
      processing=""
    fi

    debug_log_message "processing is now $processing"
  fi

  if [[ $input = "s" ]]; then
    debug_log_message "paper format was $paper_format"

    if [[ $paper_format = "a4" ]]; then
      paper_format="letter"
    elif [[ $paper_format = "letter" ]]; then
      paper_format="legal"
    else
      paper_format="a4"
    fi

    debug_log_message "paper format is now $paper_format"
  fi

  if [[ $input = "o" ]]; then
    debug_log_message "source was $source"

    if [[ $source = "adf" ]]; then
      source="flatbed"
    else
      source="adf"
    fi

    debug_log_message "source is now $source"
  fi

  if [[ $input = "q" ]]; then
    handle_exit
  fi

  if [[ $input = "" ]]; then
    local _adf_loaded
    _adf_loaded=$(scanimage -d hp5590 -A --format=pnm | grep -Po "adf.*\[\K(\w{2,3})\]" | grep -Eo "\w{2,3}")

    if [[ ($source = "adf" && $_adf_loaded = "yes") || $source = "flatbed" ]]; then
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
  set_scan_area
  local _res=300

  debug_log_message "paper format is $paper_format, scanning ${x}x${y}mm"

  if [[ $source = "adf" ]]; then
    log_message "Scanning document with ADF..."
    # An A4 page is 210x297mm. However, using 297mm confuses the scanner and
    # results in "ghost" pages, so using a slightly higher value and then
    # trimming the resulting scanned image avoids the problem.
    # See https://gitlab.com/sane-project/backends/-/issues/572
    DEBUG=$DEBUG scanadf \
      --device-name hp5590 \
      --source "ADF Duplex" \
      -x "$x" -y "$y" \
      --mode Gray \
      --resolution "$_res" \
      --scan-script ./lib/process_page.sh \
      --script-wait \
      --output-file "$temp_dir/$filename_pattern"
  elif [[ $source = "flatbed" ]]; then
    DEBUG=$DEBUG ./lib/scanbed.sh hp5590 "$x" "$y" "Gray" "$_res" "$temp_dir/$filename_pattern"
  fi
}

set_scan_area() {
  if [[ $paper_format = "a4" ]]; then
    _x_mm=210.0 # mm
    _y_mm=297.0 # mm
  elif [[ $paper_format = "letter" ]]; then
    _x_mm=215.889 # mm
    _y_mm=279.4 # mm
  elif [[ $paper_format = "legal" ]]; then
    _x_mm=215.889 # mm
    _y_mm=355.6 # mm
  fi

  x=$_x_mm
  if [[ $source = "adf" ]]; then
    # the scanned area needs to be larger than the page or it will insert ghost
    # pages with the ADF duplex
    y=$(bc <<< "scale=1; $_y_mm + 23")
  else
    y=$_y_mm
  fi
}

increment_docs_count() {
  docs_scanned=$((docs_scanned +1))
}

assemble_pdf() {
  pages="${temp_dir}/${base_filename}*.png"

  # count number of matching docs to avoid errors when no pages scanned
  local pages_array
  # we *want* to split on space
  # shellcheck disable=SC2206
  pages_array=( $pages )
  local pages_count=${#pages_array[@]}
  debug_log_message "$pages_count pages found"

  if [[ $pages_count -gt 0 ]]; then
    debug_log_message "assembling pdf at $temp_dir/$out_filename"
    convert "$pages" "$temp_dir/$out_filename" 
  else
    debug_log_message "no pages, skipping pdf assembly"
  fi
}

move_pdf() {
  local temp_pdf
  temp_pdf="$temp_dir/$out_filename"

  if [ -f "$temp_pdf" ]; then
    debug_log_message "temp_pdf found at $temp_pdf"
    cp "$temp_pdf" "$scans_dir/"
    log_message "$scans_dir/$out_filename created."
  else
    debug_log_message "no temp_pdf found at $temp_pdf"
    log_message "no PDF created."
  fi
}

handle_exit() {
  log_message "Scanned $docs_scanned documents. Bye!"
  exit 0
}

main() {
  while true; do
    prompt_insert_pages
  done
}

main
