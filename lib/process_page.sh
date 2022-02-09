#!/usr/bin/env bash

# scanadf passes the image's filename as the first and only argument when
# calling the script
file="$1"
path="$(dirname $file)"
basename="$(basename $file)"
filename="${basename%.*}"
extension="${basename##*.}"
# expected filename format is <uuid>-<date_string>-<page_number>
uuid=$(echo $filename | cut -d"-" -f1)
date_string=$(echo $filename | cut -d"-" -f2)
page_number=$(echo $filename | cut -d"-" -f3)
vendor_lib_dir="./lib/vendor"
out_filename="$date_string.pdf"
temp_pdf_file="$path/$out_filename"
DEBUG="${DEBUG:-}"

echo $SCAN_RES
echo $SCAN_WIDTH
echo $SCAN_HEIGHT
echo $SCAN_DEPTH
echo $SCAN_FORMAT
echo $SCAN_FORMAT_ID

debug_notice() {
  if [[ $DEBUG ]]; then
    echo "Debug output enabled"
  fi
}


rotate_verso() {
  # when scanning duplex using the ADF, the verso page is upside down
  if [ $((page_number %2)) -eq 0 ]; then
    if [[ $DEBUG ]]; then
      echo "$page_number is even, flipping"
    fi
    # rotate in-place
    convert -rotate "180" $file $file
  fi
}

deskew_page() {
  # deskew in place
  $vendor_lib_dir/textdeskew $file $file > /dev/null 2>&1 || echo "Not enough text, not deskewing"
}

clean_page() {
  # clean in place
  $vendor_lib_dir/textcleaner $file $file
}

create_or_append_pdf() {
  if [ ! -f "$temp_pdf_file" ]; then
    if [[ $DEBUG ]]; then
      echo "$temp_pdf_file not found, creating it"
    fi
    convert "$file" "$temp_pdf_file" 
  else
    if [[ $DEBUG ]]; then
      echo "$temp_pdf_file found, appending to it"
    fi
    convert "$temp_pdf_file" "$file" "$temp_pdf_file" 
  fi
}

cleanup() {
  if [[ ! $DEBUG ]]; then
    rm "$file"
  fi
}

debug_notice
echo "Processing page $page_number..."
rotate_verso
deskew_page
# create_or_append_pdf
cleanup
echo "Page $page_number added to $temp_pdf_file."
