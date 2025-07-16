#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
DEPLOY_DIR="$SCRIPT_DIR/deployments"

show_header() {
    echo "========================================================="
    echo "          CANOPY VALIDATOR - ONE CLICK INSTALL           "
    echo "                     by @airdropalc                      "
    echo "========================================================="
}

setup_firewall() {
    echo "🔥 Mengkonfigurasi Firewall (UFW)..."
    sudo ufw allow 9001/tcp
    sudo ufw allow 9002/tcp
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp
    sudo ufw allow 22/tcp
    sudo ufw allow 50000/tcp
    sudo ufw allow 40000/tcp
    sudo ufw allow 3000/tcp
    sudo ufw --force enable
    echo "✅ Firewall dikonfigurasi. Status saat ini:"
    sudo ufw status
}

install_dependencies() {
    echo "📦 Menginstal dependensi sistem dan Docker..."
    sudo apt update
    sudo apt install -y ca-certificates curl gnupg lsb-release git make apache2-utils
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    echo "✅ Dependensi dan Docker terinstal."

    echo "🔌 Menginstal Plugin Docker Loki..."
    sudo mkdir -p /var/lib/docker/plugins/tmp
    sudo docker plugin install grafana/loki-docker-driver --alias loki
    echo "✅ Plugin Loki terinstal."
}

initial_canopy_setup() {
    if [ ! -d "$DEPLOY_DIR" ]; then
        echo "📂 Kloning repositori Canopy deployments ke '$DEPLOY_DIR'..."
        git clone https://github.com/canopy-network/deployments.git "$DEPLOY_DIR"
    else
        echo "📂 Direktori '$DEPLOY_DIR' sudah ada."
    fi
    
    cd "$DEPLOY_DIR"
    chmod +x setup.sh
    echo "️⚠️ PENTING: Skrip berikut ini interaktif."
    echo "️Anda akan diminta MEMBUAT PASSWORD dan memberikan NICKNAME. Ikuti instruksi di layar."
    read -p "Tekan [Enter] untuk melanjutkan..."
    ./setup.sh
    echo "✅ Setup awal selesai."
}

configure_monitoring() {
    local MONITOR_DIR="$DEPLOY_DIR/monitoring-stack"
    if [ ! -d "$MONITOR_DIR" ]; then
        echo "❌ Direktori monitoring tidak ditemukan. Jalankan 'Setup Awal Canopy' (opsi 4) terlebih dahulu."
        return 1
    fi
    
    cd "$MONITOR_DIR"
    read -p "📧 Masukkan alamat email Anda (untuk notifikasi SSL): " user_email
    while [ -z "$user_email" ]; do
        echo "Email tidak boleh kosong."
        read -p "📧 Masukkan alamat email Anda: " user_email
    done
    echo "✅ Email diterima: $user_email"

    echo "📄 Membuat file .env..."
    cat <<EOF > .env
# canopy env
DOMAIN=localhost
ACME_EMAIL=${user_email}
# snapshots URLS
SNAPSHOT_1_URL="http://canopy-mainnet-latest-chain-id1.us.nodefleet.net"
SNAPSHOT_2_URL="http://canopy-mainnet-latest-chain-id2.us.nodefleet.net"
# canopy env 
BIN_PATH=/bin/cli
REPO_OWNER=canopy-network
# Grafana
GF_SECURITY_ADMIN_PASSWORD=canopy
GF_SECURITY_ADMIN_USER=admin
GF_USERS_ALLOW_SIGN_UP=false
GF_DATABASE_TYPE=sqlite3
GF_INSTALL_PLUGINS=grafana-clock-panel,grafana-simple-json-datasource
GF_SERVER_DOMAIN=monitoring.\${DOMAIN} 
GF_USERS_DEFAULT_THEME=dark
GF_SMTP_ENABLED=false
GF_SMTP_HOST=smtp.gmail.com:587
GF_SMTP_USER=myadrress@gmail.com
GF_SMTP_PASSWORD=mypassword
GF_SMTP_FROM_ADDRESS=myaddress@gmail.com
EOF
    echo "✅ file .env dibuat."

    echo "📄 Membuat file docker-compose.yaml..."
    cat <<'EOF' > docker-compose.yaml
x-loki:
  &loki-logging
  driver: loki
  options:
    loki-url: "http://localhost:3100/loki/api/v1/push"
    max-size: 5m
    mode: non-blocking
    max-buffer-size: 4m
    loki-retries: '3'
    max-file: '3'
    keep-file: 'false'

services:
  node1:
    container_name: node1
    hostname: node1
    image: canopynetwork/canopy
    build:
      context: ../docker_image
      dockerfile: ./Dockerfile
      network: host
      args:
        EXPLORER_BASE_PATH: '/'
        WALLET_BASE_PATH: '/'
        BUILD_PATH: cmd/cli
        BIN_PATH: $BIN_PATH
        BRANCH: beta-0.1.3
    env_file:
      - .env
    ports:
      - 9001:9001 # TCP P2P
      - 50000:50000
    expose:
      - 50000 # Wallet
      - 50001 # Explorer
      - 50002 # RPC
      - 50003 # Admin RPC
    command: [ "start" ]
    volumes:
      - ../canopy_data/node1:/root/.canopy
      - ../docker_image/entrypoint.sh:/app/entrypoint.sh
    logging: *loki-logging
    deploy:
      resources:
        limits:
          memory: 4G
          cpus: "2.0"

  node2:
    container_name: node2
    hostname: node2
    image: canopynetwork/canopy
    env_file:
      - .env
    ports:
      - 9002:9002 # TCP P2P
      - 40000:40000
    expose:
      - 40000 # Wallet
      - 40001 # Explorer
      - 40002 # RPC
      - 40003 # Admin RPC
    command: [ "start" ]
    volumes:
      - ../canopy_data/node2:/root/.canopy
      - ../docker_image/entrypoint.sh:/app/entrypoint.sh
    logging: *loki-logging
    deploy:
      resources:
        limits:
          memory: 4G
          cpus: "2.0"

  traefik:
    cpus: 2
    mem_limit: 2G
    image: traefik:latest
    container_name: traefik
    restart: always
    env_file: 
      - .env
    ports:
      - 80:80
      - 443:443 
      - 8082 # metrics
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./loadbalancer/traefik.yml:/traefik.yml:ro
      - ./loadbalancer/services/:/etc/traefik/services/:ro
      - ./loadbalancer/certs:/letsencrypt
    logging: *loki-logging

  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    user: root
    volumes:
      - ./monitoring/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
      - ./monitoring/prometheus/data:/prometheus/data
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
    expose:
      - 9090
    restart: always
    logging: *loki-logging

  grafana:
    image: grafana/grafana:latest
    container_name: grafana 
    user: root
    ports:
    - "3000:3000"
    volumes:
      - ./monitoring/grafana/data:/var/lib/grafana
      - ./monitoring/grafana/dashboards:/etc/grafana/dashboards
      - ./monitoring/grafana/provisioning/:/etc/grafana/provisioning/
    env_file: 
      - .env
    restart: always
    logging: *loki-logging

  loki:
    image: grafana/loki:3.4.4
    container_name: loki
    volumes:
      - ./monitoring/loki/config.yaml:/etc/loki/local-config.yaml
      - ./monitoring/loki/data:/data/loki
    expose:
      - 3100
    ports:
      - "3100:3100" 
    command: --config.file=/etc/loki/local-config.yaml
    restart: always
    logging: *loki-logging

  blackbox:
    container_name: blackbox
    image: prom/blackbox-exporter:latest
    privileged: true
    expose:
      - '9115'  
    volumes:
      - ./monitoring/blackbox/blackbox.yml:/etc/blackbox_exporter/config.yml

  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    container_name: cadvisor
    expose:
      - 8080
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:rw
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro

  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter 
    expose:
      - 9100 
    restart: always
    logging: *loki-logging
EOF
    echo "✅ file docker-compose.yaml dibuat."
    echo "✅ Konfigurasi monitoring selesai."
}

start_services() {
    if [ ! -d "$DEPLOY_DIR/monitoring-stack" ]; then
        echo "❌ Direktori proyek tidak ditemukan. Jalankan 'Setup Awal Canopy' (opsi 4) terlebih dahulu."
        return 1
    fi
    
    echo "🏁 Menjalankan perintah: sudo make start_with_snapshot"
    echo "--------------------[ AWAL OUTPUT PERINTAH ]--------------------"
    

    if (cd "$DEPLOY_DIR/monitoring-stack" && sudo make start_with_snapshot); then
        echo "--------------------[ AKHIR OUTPUT PERINTAH ]-------------------"
        echo "✅ Perintah 'make' berhasil dijalankan."
        echo "Node Canopy dan monitoring sedang dimulai."
    else
        echo "--------------------[ AKHIR OUTPUT PERINTAH ]-------------------"
        echo "❌ ERROR: Perintah 'make' gagal dijalankan. Silakan periksa output di atas untuk menemukan penyebab errornya."
    fi
}

stop_services() {
    if [ ! -d "$DEPLOY_DIR/monitoring-stack" ]; then
        echo "❌ Direktori proyek tidak ditemukan."
        return 1
    fi

    echo "🛑 Menghentikan semua service..."
    (cd "$DEPLOY_DIR/monitoring-stack" && sudo make stop)
    echo "✅ Semua service telah dihentikan."
}

view_status() {
    echo "🔎 Melihat status kontainer Docker..."
    sudo docker logs node1
}

full_installation() {
    setup_firewall
    install_dependencies
    initial_canopy_setup
    configure_monitoring
    start_services
}

show_menu() {
    clear
    show_header
    echo
    echo "Pilih aksi yang ingin Anda lakukan:"
    echo "1. Instalasi Penuh (Menjalankan semua langkah 2-6)"
    echo "---------------------------------------------------------"
    echo "2. Konfigurasi Firewall"
    echo "3. Instal Dependensi & Docker"
    echo "4. Setup Awal Canopy (Membuat Password & Nickname)"
    echo "5. Konfigurasi Monitoring (Membuat .env & docker-compose)"
    echo "---------------------------------------------------------"
    echo "6. ▶️  Start Services"
    echo "7. 🛑 Stop Services"
    echo "8. 🔎 Lihat Status Kontainer"
    echo "9. 🚪 Keluar"
    echo
}

while true; do
    show_menu
    read -p "Masukkan pilihan Anda (1-9): " choice
    echo

    case $choice in
        1) full_installation ;;
        2) setup_firewall ;;
        3) install_dependencies ;;
        4) initial_canopy_setup ;;
        5) configure_monitoring ;;
        6) start_services ;;
        7) stop_services ;;
        8) view_status ;;
        9) echo "Terima kasih!"; exit 0 ;;
        * ) echo "❌ Pilihan tidak valid. Silakan coba lagi." ;;
    esac
    echo
    read -p "Tekan [Enter] untuk kembali ke menu utama..."
done
