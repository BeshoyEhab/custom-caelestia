#!/bin/bash
# Create 1000 test notifications for testing lazy loading
# Usage: ./test-notifs.sh [count] [delay_ms]

COUNT=${1:-1000}
DELAY=${2:-50}

echo "Creating $COUNT notifications with ${DELAY}ms delay..."

for i in $(seq 1 $COUNT); do
    notify-send -a "TestApp" "Notification $i" "This is test notification number $i of $COUNT"
    if [[ $DELAY -gt 0 ]]; then
        sleep "$(echo "scale=3; $DELAY/1000" | bc)"
    fi
    if (( i % 100 == 0 )); then
        echo "  Created $i / $COUNT"
    fi
done

echo "Done! Created $COUNT notifications."
