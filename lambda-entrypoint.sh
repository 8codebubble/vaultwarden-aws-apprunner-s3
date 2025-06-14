#!/bin/bash
set -e

# AWS Lambda runtime requires initialization
echo "Starting Vaultwarden Lambda container..."

# Ensure required directories exist
mkdir -p $DATA_FOLDER

rclone --version
# Check if rclone is configured
if ! rclone listremotes; then
  echo "Rclone is not configured. Please ensure your rclone configuration is set up correctly."
  exit 1
fi

# Restore non-SQLite files from S3
echo "Restoring non-SQLite files from S3..."
rclone sync s3remote:vaultwarden-aws-apprunner-s3-bucket/data-backup ${DATA_FOLDER} \
  --exclude "*.sqlite*" \
  --exclude "*.sqlite3/"

# Ensure the data directory is writable
ls -la ${DATA_FOLDER}

# Create sync cron job to sync data to S3 every 10 minutes
echo "Creating cron job for s3 sync"
#(crontab -l 2>/dev/null; echo "*/10 * * * * rclone sync ${DATA_FOLDER} s3remote:vaultwarden-aws-apprunner-s3-bucket --exclude \"*.sqlite*\"") | crontab -
rclone_sync.sh &
RCLONE_PID=$!


# Restore SQLite database from S3 if available
echo "Restoring SQLite database from S3..."
# This will restore the database if it exists, or do nothing if it doesn't.
litestream restore -if-replica-exists ${DATA_FOLDER}/db.sqlite3 &
LITESTREAM_PID=$!

echo "Waiting for Litestream restore to complete..."
wait $LITESTREAM_PID

# Ensure the SQLite database is owned by the correct user
#chown root:root ${DATA_FOLDER}/db.sqlite3

# Start Litestream in background for continuous replication
litestream replicate -config /etc/litestream.yml &

# Sanity check
pwd
ls -la

# Start Vaultwarden as a background process (or in the foreground if it supports a graceful shutdown signal)
/vaultwarden/vaultwarden &
VAULTWARDEN_PID=$!

# Function to handle shutdown and final snapshot.
function shutdown() {
  echo "Received shutdown signal. Stopping Vaultwarden..."
  kill -SIGTERM $VAULTWARDEN_PID
  wait $VAULTWARDEN_PID
  echo "Vaultwarden stopped."

  echo "Syncing data to S3..."
  # Sync the data folder to S3, excluding SQLite files
  # This ensures that the latest state of the data folder is saved.
  # Note: This will not include the SQLite database file, as it is handled by Litestream.
  kill -SIGTERM $RCLONE_PID
  wait $RCLONE_PID
  rclone sync ${DATA_FOLDER} s3remote:vaultwarden-aws-apprunner-s3-bucket/data-backup \
    --exclude "*.sqlite*" \
    --exclude "*.sqlite3/"

  echo "Stopping Litestream..."
  kill -SIGTERM $LITESTREAM_PID
  wait $LITESTREAM_PID

  exit 0
}

# Trap termination signals so we can run the shutdown function.
trap shutdown SIGTERM SIGINT

# Wait for Vaultwarden to exit (the container stays alive while Vaultwarden is running)
wait $VAULTWARDEN_PID


