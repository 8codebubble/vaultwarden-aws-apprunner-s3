#!/bin/bash
# Ensure the data folder exists
while true; do
  rclone sync ${DATA_FOLDER} s3remote:vaultwarden-aws-apprunner-s3-bucket/data-backup \
    --exclude "*.sqlite*" \
    --exclude "*.sqlite3/"
  if [ $? -ne 0 ]; then
    echo "rclone Sync failed. Retrying in 2 minutes..."
  else
    echo "rclone Sync completed successfully."
  fi
  sleep 120 # Sleep for 2 minutes    
done