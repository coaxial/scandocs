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
    echo "Debug output enabled"
  fi
}


rotate_verso() {
  # when scanning duplex using the ADF, the verso page is upside down
  if [ $((page_number %2)) -eq 0 ]; then
    if [[ $DEBUG ]]; then
      echo "$page_number is even, flipping"
    fi
    mogrify -rotate 180 $file
  fi
}

crop_image_to_size() {
  # Found using scanadf ... --verbose and -x 210 -y 297
  # 2481x3508 = A4
  mogrify -crop 2481x3508+0+0 $file
}

deskew_page() {
  # deskew in place
  $vendor_lib_dir/textdeskew $file $file > /dev/null 2>&1 || echo "Not enough text, not deskewing"
}

clean_page() {
  # clean in place
  $vendor_lib_dir/textcleaner $file $file
}

debug_notice
echo "[P$page_number] Processing page..."
crop_image_to_size
rotate_verso
deskew_page
clean_page
echo "[P$page_number] Done processing page."
