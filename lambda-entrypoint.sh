#!/bin/bash
set -e

# AWS Lambda runtime requires initialization
echo "Starting Vaultwarden Lambda container..."

# Ensure required directories exist
mkdir -p $DATA_FOLDER

# Restore SQLite database from S3 if available
litestream restore -if-replica-exists ${DATA_FOLDER}/db.sqlite3 &
LITESTREAM_PID=$!



# Start Litestream in background for continuous replication
litestream replicate -config /etc/litestream.yml &

# Sanitiy check
pwd
ls -la
ls ./web-vault -la

# Start Vaultwarden as a background process (or in the foreground if it supports a graceful shutdown signal)
/vaultwarden/vaultwarden &
VAULTWARDEN_PID=$!

# Function to handle shutdown and final snapshot.
function shutdown() {
  echo "Received shutdown signal. Stopping Vaultwarden..."
  kill -SIGTERM $VAULTWARDEN_PID
  wait $VAULTWARDEN_PID
  echo "Vaultwarden stopped."

  echo "Creating final Litestream snapshot of ${DATA_FOLDER}/db.sqlite3..."
  # This command forces a snapshot, ensuring that WAL segments and final data are saved to S3.
  litestream snapshot -db ${DATA_FOLDER}/db.sqlite3

  echo "Stopping Litestream..."
  kill -SIGTERM $LITESTREAM_PID
  wait $LITESTREAM_PID

  exit 0
}

# Trap termination signals so we can run the shutdown function.
trap shutdown SIGTERM SIGINT

# Wait for Vaultwarden to exit (the container stays alive while Vaultwarden is running)
wait $VAULTWARDEN_PID


