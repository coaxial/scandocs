#!/usr/bin/env bash

# scanadf passes the image's filename as the first and only argument when
# calling the script
file="$1"
path="$(dirname "$file")"
basename="$(basename "$file")"
filename="${basename%.*}"
extension="${basename##*.}"
# expected filename format is
# <date_string>-<paper_format>-<page_number>-<processing options>
paper_format=$(echo "$filename" | cut -d"-" -f2)
page_number=$(echo "$filename" | cut -d"-" -f3)
processing=$(echo "$filename" | cut -d"-" -f4)
clean=$(echo "$filename" | cut -d"-" -f5)
vendor_lib_dir="./lib/vendor"
DEBUG="${DEBUG:-}"

rotate_verso() {
  debug_log_message "rotating page"

  local _normalized_page_number
  # shellcheck disable=SC2001
  _normalized_page_number="$(echo "$page_number" | sed 's/^0*//')"
  # when scanning duplex using the ADF, the verso page is upside down
  if [[ $((_normalized_page_number %2)) = 0 ]]; then
    debug_log_message "even page, flipping"
    mogrify -rotate 180 "$file"
  fi
}

crop_image_to_size() {
  debug_log_message "cropping page"

  # overscanning to avoid "ghost" pages, so image must be trimmed back down to
  # actual paper size
  # $SCAN_RES set by scanadf
  local _x
  _x=$(paper_size_to_px "$paper_format" "$SCAN_RES" x)
  local _y
  _y=$(paper_size_to_px "$paper_format" "$SCAN_RES" y)

  debug_log_message "paper is $paper_format => ${_x}x${_y}px"

  local _crop_offset=0

  # detect if image is landscape and crop it accordingly
  local _w
  _w=$(identify -format "%w" "$file")
  local _h
  _h=$(identify -format "%h" "$file")

  if [[ $_h < $_w ]]; then
    debug_log_message "landscape page detected"
    local _tmp_x=$_x
    _x=$_y
    _y=$_tmp_x
  fi

  mogrify -crop "${_x}x${_y}+0+$_crop_offset" "$file"
}

paper_size_to_px() {
  local _format="$1"
  local _dpi="$2"
  local _dimension="$3"
  local _x_mm
  local _y_mm

  if [[ $_format = "a4" ]]; then
    _x_mm=210.0 # mm
    _y_mm=297.0 # mm
  elif [[ $_format = "letter" ]]; then
    _x_mm=215.9 # mm
    _y_mm=279.4 # mm
  elif [[ $_format = "legal" ]]; then
    _x_mm=215.9 # mm
    _y_mm=355.6 # mm
  fi

  # scale=0; (px+0.5)/1 is to round up and remove the decimals
  # 1in = 25.4mm
  local _x_px
  _x_px=$(bc <<< "scale=4; inches=${_x_mm}/25.4; px=inches*${_dpi}; scale=0; (px+0.5)/1")
  local _y_px
  _y_px=$(bc <<< "scale=4; inches=${_y_mm}/25.4; px=inches*${_dpi}; scale=0; (px+0.5)/1")

  if [[ $_dimension = "x" ]]; then
    echo "$_x_px"
  else
    echo "$_y_px"
  fi
}

deskew_page() {
  if [[ $processing = "nodeskew" ]]; then
    debug_log_message "no deskewing requested, skipping"
  else
    debug_log_message "deskewing page"

    # deskew in place
    $vendor_lib_dir/textdeskew "$file" "$file" > /dev/null 2>&1 || log_message "Not enough text on page, unable to deskew"
  fi
}

clean_page() {
  if [[ $clean = "noclean" ]]; then
    debug_log_message "no cleaning requested, skipping"
  else
    debug_log_message "cleaning page"

    # clean in place
    $vendor_lib_dir/textcleaner "$file" "$file"
  fi
}

convert_to_png() {
  debug_log_message "converting page"

  pnmtopng "$file" > "$path/$filename.png"
}

log_message() {
  # output messages to stderr
  echo "[p$page_number] $1" >&2
}

debug_log_message () {
  if [[ $DEBUG ]]; then
    log_message "DEBUG: $1"
  fi
}

debug_file_copy() {
  if [[ $DEBUG ]]; then
    local _orig_file="$1"
    local _stage="$2"

    debug_log_message "writing debug file after $_stage stage"
    cp "$_orig_file" "${path}/${filename}-${_stage}.${extension}"
  fi
}

main() {
  log_message "Processing page..."

  debug_file_copy "$file" "00-pnm"

  crop_image_to_size
  debug_file_copy "$file" "01-crop"

  rotate_verso
  debug_file_copy "$file" "02-rotate"

  clean_page
  debug_file_copy "$file" "03-clean"

  deskew_page
  debug_file_copy "$file" "04-deskew"

  crop_image_to_size
  debug_file_copy "$file" "05-crop"

  convert_to_png
  debug_file_copy "$file" "06-png"

  log_message "Done processing page."
}

main
