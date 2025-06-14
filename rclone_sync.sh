#!/bin/bash
# Ensure the data folder exists
while true; do
  rclone sync ${DATA_FOLDER} s3remote:vaultwarden-aws-apprunner-s3-bucket --exclude "*.sqlite*"
  sleep 120 # Sleep for 2 minutes
done