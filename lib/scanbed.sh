#!/usr/bin/env bash
set -euo pipefail

DEBUG="${DEBUG:-}"

# arguments:
# device
# x
# y
# mode
# resolution
# filename_pattern

device="$1"
x="$2"
y="$3"
mode="$4"
resolution="$5"
filename_pattern="$6"
genverso="no"

current_page_number=1
exit_req=0
x_px=0
y_px=0

debug_log_message () {
  if [[ $DEBUG ]]; then
    log_message "DEBUG: $1"
  fi
}

log_message() {
  # output messages to stderr
  echo "[flatb] $1" >&2
}

show_prompt() {
  local prompt="<Enter> to scan next page, v to toggle verso scanning, q to exit. [generate-verso: $genverso]"
  log_message "$prompt"
  read -r -s -n 1 input

  if [[ $input = "" ]]; then
    scan_page
  elif [[ $input = "v" ]]; then
    genverso=yes
  elif [[ $input = "q" ]]; then
    exit_req=1
  fi
}

scan_page() {
  local filename
  # we want the format specifier in $filename_pattern to be interpreted by
  # printf
  # shellcheck disable=SC2059
  filename=$(printf "$filename_pattern" "$current_page_number")

  scanimage \
    --device-name "$device" \
    -x "$x" -y "$y" \
    --mode "$mode" \
    --resolution "$resolution" \
    --format pnm \
    --progress \
  > "$filename"

  process_page "$filename"

  ((current_page_number++))

  if [[ $genverso = "yes" ]]; then
    debug_log_message "inserting blank verso"

    mm_to_px
    local whitepage_filename
    # we want the format specifier in $filename_pattern to be interpreted by
    # printf
    # shellcheck disable=SC2059
    whitepage_filename=$(printf "$filename_pattern" "$current_page_number")
    convert -size ${x_px}x${y_px} xc:white "$whitepage_filename"
    process_page "$whitepage_filename"
    ((current_page_number++))
  fi
}

mm_to_px() {
  x_px=$(bc <<< "scale=4; inches=${x}/25.4; px=inches*${resolution}; scale=0; (px+0.5)/1")
  y_px=$(bc <<< "scale=4; inches=${y}/25.4; px=inches*${resolution}; scale=0; (px+0.5)/1")
}

process_page() {
  SCAN_RES=$resolution ./lib/process_page.sh "$1"
}

while [[ $exit_req = 0 ]]; do
  show_prompt
done
