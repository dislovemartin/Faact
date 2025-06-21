#!/bin/bash

# -- Configuration --
PRIMARY_IP="<GCP_USW1_PUBLIC_IP>"
SECONDARY_IP="<GCP_USW2_PUBLIC_IP>"
WG_PEER_KEY="<GCP_SERVER_PUBLIC_KEY>" # THE PUBLIC KEYS OF THE TWO SERVERS CAN BE DIFFERENT, BUT FOR SIMPLIFICATION, IT IS SET TO THE SAME HERE.
PING_COUNT=5
LOSS_THRESHOLD=3 # If more than 3 packets are lost, it is considered a malfunction.

# -- Script --
CURRENT_ENDPOINT=$(wg show wg0 endpoints | awk '{print $2}' | cut -d: -f1)

# Detect the master node
ping -c $PING_COUNT $PRIMARY_IP > /tmp/ping_primary.log
LOSS_COUNT=$(grep -o 'packet loss' /tmp/ping_primary.log | wc -l) # More robust way to count packet loss

if [ $LOSS_COUNT -ge $LOSS_THRESHOLD ]; then
  # Master node failure, check whether it is currently in the master node
  if [ "$CURRENT_ENDPOINT" == "$PRIMARY_IP" ]; then
    echo "Primary endpoint $PRIMARY_IP failed. Switching to $SECONDARY_IP."
    # Switch to the backup node
    wg set wg0 peer $WG_PEER_KEY endpoint $SECONDARY_IP:51820
  fi
else
  # Master node recovery, check whether it is currently in the backup node
  if [ "$CURRENT_ENDPOINT" == "$SECONDARY_IP" ]; then
    echo "Primary endpoint $PRIMARY_IP is back online. Switching back."
    # Cut back to the master node
    wg set wg0 peer $WG_PEER_KEY endpoint $PRIMARY_IP:51820
  fi
fi
