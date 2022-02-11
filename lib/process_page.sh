#!/usr/bin/env bash

# scanadf passes the image's filename as the first and only argument when
# calling the script
file="$1"
path="$(dirname $file)"
basename="$(basename $file)"
filename="${basename%.*}"
extension="${basename##*.}"
# expected filename format is
# <date_string>-<paper_format>-<page_number>
date_string=$(echo $filename | cut -d"-" -f1)
paper_format=$(echo $filename | cut -d"-" -f2)
page_number=$(echo $filename | cut -d"-" -f3)
vendor_lib_dir="./lib/vendor"
out_filename="$date_string.pdf"
temp_pdf_file="$path/$out_filename"
DEBUG="${DEBUG:-}"

rotate_verso() {
  debug_log_message "rotating page"

  # when scanning duplex using the ADF, the verso page is upside down
  if [[ $((page_number %2)) = 0 ]]; then
    debug_log_message "even page, flipping"
    mogrify -rotate 180 $file
  fi
}

crop_image_to_size() {
  debug_log_message "cropping page"

  # overscanning to avoid "ghost" pages, so image must be trimmed back down to
  # actual paper size
  local _x=$(paper_size_to_px $paper_format $SCAN_RES x)
  local _y=$(paper_size_to_px $paper_format $SCAN_RES y)

  debug_log_message "paper is $paper_format => ${_x}x${_y}px"

  local _crop_offset=0

  # If the page number is even, it means it's the verso, which is upside down.
  # The crop needs to skip the actual bottom of the image, which means the top
  # when upside down.
  # if [ $((page_number %2)) -eq 0 ]; then
  #   local _crop_offset=$(($SCAN_HEIGHT - $_y)) # $SCAN_HEIGHT comes from scanadf
  #   debug_log_message "even page, offsetting crop by Y ${_crop_offset}px"
  # fi

  mogrify -crop ${_x}x${_y}+0+$_crop_offset $file
}

paper_size_to_px() {
  local _format="$1"
  local _dpi="$2"
  local _dimension="$3"

  if [[ $_format = "a4" ]]; then
    local _x_mm=210.0 # mm
    local _y_mm=297.0 # mm
  elif [[ $_format = "letter" ]]; then
    local _x_mm=215.9 # mm
    local _y_mm=279.4 # mm
  elif [[ $_format = "legal" ]]; then
    local _x_mm=215.9 # mm
    local _y_mm=355.6 # mm
  fi

  # scale=0; (px+0.5)/1 is to round up and remove the decimals
  # 1in = 25.4mm
  local _x_px=$(bc <<< "scale=4; inches=${_x_mm}/25.4; px=inches*${_dpi}; scale=0; (px+0.5)/1")
  local _y_px=$(bc <<< "scale=4; inches=${_y_mm}/25.4; px=inches*${_dpi}; scale=0; (px+0.5)/1")

  if [[ $_dimension = "x" ]]; then
    echo $_x_px
  else
    echo $_y_px
  fi
}

deskew_page() {
  debug_log_message "deskewing page"

  # deskew in place
  $vendor_lib_dir/textdeskew $file $file > /dev/null 2>&1 || log_message "Not enough text on page, unable to deskew"
}

clean_page() {
  debug_log_message "cleaning page"

  # clean in place
  $vendor_lib_dir/textcleaner $file $file
}

convert_to_png() {
  debug_log_message "converting page"

  convert $file $path/$filename.png
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

    debug_log_message "copying file after $_stage stage"
    cp "$_orig_file" "${path}/${filename}-${_stage}.${extension}"
  fi
}

main() {
  log_message "Processing page..."

  debug_file_copy $file "00-pnm"

  crop_image_to_size
  debug_file_copy $file "01-crop"

  rotate_verso
  debug_file_copy $file "02-rotate"

  deskew_page
  debug_file_copy $file "03-deskew"

  crop_image_to_size
  debug_file_copy $file "04-crop"

  clean_page
  debug_file_copy $file "05-clean"

  convert_to_png
  debug_file_copy $file "06-png"

  log_message "Done processing page."
}

main
