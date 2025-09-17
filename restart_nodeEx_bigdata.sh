#!/bin/bash

# Daftar server, container, dan user
declare -A servers
declare -A users

# Server dan container yang menggunakan user 'bigdata'
servers["svr-portal"]="10.52.128.28"
servers["svr-backend"]="10.52.224.29"
servers["svr-services"]="10.52.224.33"
servers["svr-database"]="10.52.224.32"
servers["svr-storageMinIo"]="10.52.224.31"
servers["svr-toolsBigdata"]="10.52.224.30"

# Server lainnya dengan user yang berbeda
servers["sysadmin-vm"]="10.52.224.20"
servers["mm-s2t-01"]="10.52.224.13"
servers["mm-s2t-02"]="10.52.224.14"
servers["mm-processing"]="10.52.224.15"
servers["mm-db"]="10.52.224.16"
servers["mm-storageMinIo"]="10.52.224.17"
servers["mm-media-broadcasting"]="10.52.224.18"

# User untuk masing-masing server
users["svr-portal"]="bigdata"
users["svr-backend"]="bigdata"
users["svr-services"]="bigdata"
users["svr-database"]="bigdata"
users["svr-storageMinIo"]="bigdata"
users["svr-toolsBigdata"]="bigdata"

users["sysadmin-vm"]="sysadmin"
users["mm-s2t-01"]="s2t"
users["mm-s2t-02"]="s2t"
users["mm-processing"]="ubuntu"
users["mm-db"]="ubuntu"
users["mm-storageMinIo"]="ubuntu"
users["mm-media-broadcasting"]="ubuntu"

# Loop untuk restart semua container
for CONTAINER_NAME in "${!servers[@]}"; do
  SERVER_IP=${servers[$CONTAINER_NAME]}
  USER=${users[$CONTAINER_NAME]}
  
  # Restart container di server yang sesuai
  echo "Restarting container '$CONTAINER_NAME' pada server '$SERVER_IP' dengan user '$USER'..."
  ssh $USER@$SERVER_IP "docker restart $CONTAINER_NAME"

  if [[ $? -eq 0 ]]; then
    echo "Container '$CONTAINER_NAME' berhasil di-restart pada '$SERVER_IP'."
  else
    echo "Gagal me-restart container '$CONTAINER_NAME' pada '$SERVER_IP'."
  fi
done
