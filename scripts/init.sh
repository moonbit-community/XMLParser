#!/bin/bash

download_url="https://www.w3.org/XML/Test/xmlts20130923.zip"

target_dir="resource"

if [ ! -d "$target_dir" ]; then
  mkdir -p "$target_dir"
fi

echo "Download ${download_url} ..."
if command -v wget >/dev/null 2>&1; then
  wget "$download_url" -O xmlts20130923.zip
elif command -v curl >/dev/null 2>&1; then
  curl -fsSL "$download_url" -o xmlts20130923.zip
else
  echo "Neither wget nor curl found, cannot download the test suite."
  exit 1
fi

if [ $? -ne 0 ]; then
  echo "Download failed!"
  exit 1
fi

echo "zip ${target_dir} ..."
unzip xmlts20130923.zip -d "$target_dir"


if [ $? -ne 0 ]; then
  echo "zip failed"
  exit 1
fi

# 删除压缩包
rm xmlts20130923.zip
