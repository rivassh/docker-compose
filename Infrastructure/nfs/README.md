# NFS Server

Lightweight NFS server using Docker.

## Setup

```bash
# Create export directory
mkdir -p exports/infra

# Start NFS server
docker compose up -d
```

## Mount from client

```bash
# Get NFS server IP, then mount
sudo mount -t nfs <NFS_SERVER_IP>:/exports/infra /mnt/nfs
```

## Persistent data

The `./exports/infra` directory on the host is mounted into the container. Data persists across container restarts.
