#!/bin/bash
# rclone_sync.sh - Script to sync Vaultwarden data to S3 using rclone
rclone --version # Ensure rclone is installed

# Check if rclone is configured
if ! rclone listremotes; then
  echo "Rclone is not configured. Please ensure your rclone configuration is set up correctly."
  exit 1
fi

function sync_to_s3() {
    local source_dir="$1"
    echo "Syncing data from ${source_dir} to S3..."
    rclone sync "${source_dir}" s3remote:${S3_BUCKET_NAME}/data-backup \
        --exclude "*.sqlite*" \
        --exclude "*.sqlite3/" \
        --exclude ".db.sqlite3-litestream/" \
        --exclude "tmp/" \
        --verbose
}

function restore_from_s3() {
    local dest_dir="$1"
    echo "Restoring non-SQLite files from S3 to ${dest_dir}..."
    rclone sync s3remote:${S3_BUCKET_NAME}/data-backup "${dest_dir}" \
        --exclude "*.sqlite*" \
        --exclude "*.sqlite3/" \
        --exclude ".db.sqlite3-litestream/" \
        --exclude "tmp/" \
        --verbose
}

function run_rclone_sync() {
    while true; do
        sync_to_s3 "${DATA_FOLDER}" # Sync data to S3
        if [ $? -ne 0 ]; then
            echo "rclone Sync failed. Retrying in 1 minute..."
        else
            echo "rclone Sync completed successfully."
        fi
        sleep 60 # Sleep for 1 minute
    done
}


