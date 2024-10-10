#!/bin/bash

WORK_DIR="$HOME/nexus"
PROXY_FILE="proxies.txt"
DOCKER_COMPOSE_FILE="$WORK_DIR/docker-compose.yaml"
GIT_REPO="https://github.com/nexus-xyz/network-api.git"

if ! command -v docker &> /dev/null; then
    echo "Docker is not installed. Please install Docker first."
    exit 1
fi

if ! docker compose version &> /dev/null; then
    echo "Docker Compose V2 is not available. Please ensure Docker Compose V2 is installed and enabled."
    exit 1
fi

mkdir -p "$WORK_DIR"

cat > "$WORK_DIR/Dockerfile" <<EOF
FROM rust:latest
WORKDIR /app
RUN apt-get update && apt-get install -y build-essential libssl-dev curl pkg-config git
RUN git clone $GIT_REPO .
WORKDIR /app/clients/cli
RUN cargo build --release
CMD ["cargo", "run", "--release", "--bin", "prover", "--", "beta.orchestrator.nexus.xyz"]
EOF

echo "Dockerfile created at $WORK_DIR/Dockerfile"

echo "Creating docker-compose.yaml with proxies..."
echo "version: '3'" > "$DOCKER_COMPOSE_FILE"
echo "services:" >> "$DOCKER_COMPOSE_FILE"

if [ ! -f "$PROXY_FILE" ]; then
    echo "Proxy file not found: $PROXY_FILE"
    exit 1
fi

counter=1
while IFS=: read -r ip port user pass; do
    ip=$(echo "$ip" | tr -d '\n' | tr -d '\r')
    port=$(echo "$port" | tr -d '\n' | tr -d '\r')
    user=$(echo "$user" | tr -d '\n' | tr -d '\r')
    pass=$(echo "$pass" | tr -d '\n' | tr -d '\r')

    container_name="nexus_service_$counter"

    cat >> "$DOCKER_COMPOSE_FILE" <<EOF
  $container_name:
    image: lamhungkl211/network-api:latest
    environment:
      - HTTP_PROXY=http://$user:$pass@$ip:$port
      - HTTPS_PROXY=http://$user:$pass@$ip:$port
    restart: always
EOF

    counter=$((counter + 1))
done < "$PROXY_FILE"

echo "Docker Compose file created at $DOCKER_COMPOSE_FILE"

cd "$WORK_DIR"
if ! docker compose up -d; then
    echo "Failed to start Docker containers with Docker Compose."
    exit 1
fi

echo "Nexus services setup with proxies is complete!"

echo "Checking RAM usage of Docker containers..."
docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}"
