#!/bin/bash

LOG_FILE="/home/judge/webserver/log/access.log"
LOG_DIR="/home/judge/webserver/log"
ROTATE_COUNT=3
MAX_SIZE=300
MIN_SIZE=150

rotate_logs() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Rotating logs..."

    cd "$LOG_DIR" || exit 1

    # Rotate existing compressed logs
    for ((i=ROTATE_COUNT; i>=1; i--)); do
        if [ -f "${LOG_DIR}/compressed.log.${i}.gz" ]; then
            if [ "$i" -eq "$ROTATE_COUNT" ]; then
                echo "$(date '+%Y-%m-%d %H:%M:%S') - Removing ${LOG_DIR}/compressed.log.${i}.gz"
                rm -f "${LOG_DIR}/compressed.log.${i}.gz"
            else
                echo "$(date '+%Y-%m-%d %H:%M:%S') - Renaming compressed.log.${i}.gz to compressed.log.$((i+1)).gz"
                mv "compressed.log.${i}.gz" "compressed.log.$((i+1)).gz"
            fi
        fi
    done

    if [ -f "$LOG_FILE" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Compressing $LOG_FILE to compressed.log.1.gz"
        gzip -c "$LOG_FILE" > "${LOG_DIR}/compressed.log.1.gz"
        > "$LOG_FILE"
        chmod 666 "$LOG_FILE"
    fi

    echo "$(date '+%Y-%m-%d %H:%M:%S') - Log rotation completed."
}

check_and_rotate() {
    if [ -f "$LOG_FILE" ]; then
        FILE_SIZE=$(stat -c%s "$LOG_FILE")
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Current log size: $FILE_SIZE bytes"

        if [ "$FILE_SIZE" -ge "$MAX_SIZE" ]; then
            rotate_logs
        else
            echo "$(date '+%Y-%m-%d %H:%M:%S') - No rotation needed."
        fi
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Log file does not exist."
    fi
}

while true; do
    check_and_rotate
    sleep 0.01
done
