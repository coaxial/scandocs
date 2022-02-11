#!/usr/bin/env bash

# scanadf passes the image's filename as the first and only argument when
# calling the script
file="$1"
path="$(dirname $file)"
basename="$(basename $file)"
filename="${basename%.*}"
extension="${basename##*.}"
# expected filename format is <date_string>-<page_number>
date_string=$(echo $filename | cut -d"-" -f1)
page_number=$(echo $filename | cut -d"-" -f2)
vendor_lib_dir="./lib/vendor"
out_filename="$date_string.pdf"
temp_pdf_file="$path/$out_filename"
DEBUG="${DEBUG:-}"

debug_notice() {
  if [[ $DEBUG ]]; then
    log_message "Debug output enabled"
  fi
}


rotate_verso() {
  # when scanning duplex using the ADF, the verso page is upside down
  if [ $((page_number %2)) -eq 0 ]; then
    if [[ $DEBUG ]]; then
      log_message "even page, flipping"
    fi
    mogrify -rotate 180 $file
  fi
}

crop_image_to_size() {
  # Found using scanadf ... --verbose and -x 210 -y 297
  # 2481x3508 = A4
  crop_offset=0

  # If the page number is even, it means it's the verso, which is upside down.
  # The crop needs to skip the actual bottom of the image, which means the top
  # when upside down.
  if [ $((page_number %2)) -eq 0 ]; then
    crop_offset=$(($SCAN_HEIGHT -3508)) # $SCAN_HEIGHT comes from scanadf
    if [[ $DEBUG ]]; then
      log_message "even page, offsetting crop by Y $crop_offset px"
    fi
  fi

  mogrify -crop 2481x3508+0+$crop_offset $file
}

deskew_page() {
  # deskew in place
  $vendor_lib_dir/textdeskew $file $file > /dev/null 2>&1 || log_message "Not enough text on page, unable to deskew"
}

clean_page() {
  # clean in place
  $vendor_lib_dir/textcleaner $file $file
}

log_message() {
  echo "[P$page_number] $1"
}

debug_notice
log_message "[P$page_number] Processing page..."
rotate_verso
deskew_page
clean_page
crop_image_to_size
log_message "[P$page_number] Done processing page."
