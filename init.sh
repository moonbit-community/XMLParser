#!/bin/bash

download_url="https://www.w3.org/XML/Test/xmlts20130923.zip"

target_dir="resource"

if [ ! -d "$target_dir" ]; then
  mkdir -p "$target_dir"
fi

echo "Download ${download_url} ..."
wget "$download_url" -O xmlts20130923.zip

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
