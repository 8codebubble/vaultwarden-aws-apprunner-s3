#!/bin/bash
set -e

source "$(dirname "$0")/rclone_sync.sh" # Load rclone functions

# Sanity check
if [ -z "$DATA_FOLDER" ]; then
  echo "DATA_FOLDER environment variable is not set. Please set it to the Vaultwarden data directory."
  exit 1
fi
echo "Current working directory:"
pwd # Print current working directory

ls -la

# AWS Lambda runtime requires initialization
echo "Starting Vaultwarden Lambda container..."

# Ensure required directories exist
mkdir -p $DATA_FOLDER

# Restore non-SQLite files from S3
echo "Restoring non-SQLite files from S3..."
restore_from_s3 "${DATA_FOLDER}" 

# Ensure the data directory is writable
ls -la ${DATA_FOLDER}

# Start the rclone sync process in background
echo "Starting rclone sync process..."
run_rclone_sync &
RCLONE_PID=$!
# Check if rclone sync process started successfully
if [ -z "$RCLONE_PID" ]; then
    echo "Failed to start rclone sync process"
    exit 1
fi


# Restore SQLite database from S3 if available
echo "Restoring SQLite database from S3..."
# This will restore the database if it exists, or do nothing if it doesn't.
litestream restore -if-replica-exists ${DATA_FOLDER}/db.sqlite3
LITESTREAM_PID=$!

# Start Litestream in background for continuous replication
echo "Starting Litestream for continuous replication..."
litestream replicate -config /etc/litestream.yml &


# Start Vaultwarden as a background process (or in the foreground if it supports a graceful shutdown signal)
/vaultwarden/vaultwarden &
VAULTWARDEN_PID=$!

# Function to handle shutdown and final snapshot.
function shutdown() {
  set +e  # Don't exit on error during shutdown
  echo "Received shutdown signal. Stopping Vaultwarden..."
  kill -SIGTERM $VAULTWARDEN_PID
  wait $VAULTWARDEN_PID
  echo "Vaultwarden stopped."

  echo "Stopping rclone sync process..."
  # Sync the data folder to S3, excluding SQLite files
  # This ensures that the latest state of the data folder is saved.
  # Note: This will not include the SQLite database file, as it is handled by Litestream.
  kill -SIGTERM $RCLONE_PID
  # Wait for rclone to finish
  echo "Waiting for rclone sync script to be stopped..."
  wait $RCLONE_PID

  echo "Starting final non sqlite data synced to S3."
  if ! sync_to_s3 "${DATA_FOLDER}"; then
        echo "Warning: Final sync failed"
    fi   
  echo "Finished final non sqlite data synced to S3."

  echo "Stopping Litestream..."
  kill -SIGTERM $LITESTREAM_PID
  #wait $LITESTREAM_PID
  timeout 30 tail --pid=$LITESTREAM_PID -f /dev/null # Wait for Litestream to exit gracefully

  exit 0
}

# Trap termination signals so we can run the shutdown function.
trap shutdown SIGTERM SIGINT SIGHUP

# Wait for Vaultwarden to exit (the container stays alive while Vaultwarden is running)
wait $VAULTWARDEN_PID
echo "Vaultwarden has exited. Stopping Litestream and rclone sync processes...THE END"

