#!/bin/sh

# Variables
INSTALL_DIR="/root/tuic"
CONFIG_FILE="$INSTALL_DIR/config.json"
SERVICE_FILE="/etc/systemd/system/tuic.service"
IP_V4=$(curl -s ipinfo.io | grep -Po 'ip[^0-9]*"\K[^"]*')

# Function to print characters with delay
print_with_delay() {
    text="$1"
    delay="$2"
    for ((i = 0; i < ${#text}; i++)); do
        echo -n "${text:$i:1}"
        sleep $delay
    done
    echo
}

#GENERATE LINK func
construct_tuic_url() {
    local url="tuic://$1:$2@$3:$4/?congestion_control=$5&udp_relay_mode=native&alpn=h3%2Cspdy%2F3.1&allow_insecure=1#TUIC_$6"
    echo "$url"
}

# Introduction animation
echo ""
echo ""
print_with_delay "tuic-oneclick by 5urrea1ist | @panjaho1 | Special Thanks to @iSegaro and @NamelessGhoul" 0.1
echo ""
echo ""

# Install required packages
sudo apt-get update > /dev/null 2>&1
sudo apt-get install -y nano net-tools uuid-runtime curl > /dev/null 2>&1

# Check for an existing installation
if [[ -d $INSTALL_DIR && -f $SERVICE_FILE ]]; then
    echo "Tuic already installed. Choose an option:"
    echo ""
    echo ""
    echo "1. Reinstall"
    echo ""
    echo "2. Modify"
    echo ""
    echo "3. Uninstall"
    echo ""
    read -p "Enter your choice (1/2/3): " choice

    case $choice in
    1)
        echo "Reinstalling..."
        sudo systemctl stop tuic
        sudo systemctl disable tuic > /dev/null 2>&1
        rm -rf $INSTALL_DIR
        rm -f $SERVICE_FILE
        ;;
    2)
        sudo systemctl stop tuic
        rm $INSTALL_DIR/config.json
        read -p "Enter new listen port (or press enter to randomize between 10000 and 65535): " PORT
        echo ""
        [[ -z "$PORT" ]] && PORT=$((RANDOM % 55536 + 10000))
        echo ""
        read -p "Enter password (or press enter to generate one): " PASSWORD
        echo ""
        if [[ -z "$PASSWORD" ]]; then
            PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)
            echo "Generated Password: $PASSWORD"
        fi
        echo ""
        read -p "Enter new UUID(Leave blank for generating a new one): " UUID
        echo ""
        if [ -z "$UUID" ]; then
            UUID=$(uuidgen)
            echo "Generated UUID: $UUID"
        fi 
        echo ""
        read -p "Choose your congestion_control [bbr/cubic/new_reno] (Default is bbr): " CON_CO
        if [ -z "$CON_CO" ]; then
            CON_CO="bbr"
        fi
        echo ""

        cat <<EOL > config.json
{
  "server": "[::]:$PORT",
  "users": {
    "$UUID": "$PASSWORD"
  },
  "certificate": "$INSTALL_DIR/ca.crt",
  "private_key": "$INSTALL_DIR/ca.key",
  "congestion_control": "$CON_CO",
  "alpn": ["h3", "spdy/3.1"],
  "udp_relay_ipv6": true,
  "zero_rtt_handshake": false,
  "dual_stack": true,
  "auth_timeout": "3s",
  "task_negotiation_timeout": "3s",
  "max_idle_time": "10s",
  "max_external_packet_size": 1500,
  "send_window": 16777216,
  "receive_window": 8388608,
  "gc_interval": "3s",
  "gc_lifetime": "15s",
  "log_level": "warn"
}
EOL

        sudo systemctl start tuic

        SHARE_LINK_IPV4=$(construct_tuic_url "$UUID" "$PASSWORD" "$IP_V4" "$PORT" "$CON_CO" IPV4)

        echo ""
        echo ""
        echo "Share link IPv4: $SHARE_LINK_IPV4"
        echo ""
        echo ""
        exit 0
        ;;
            
    3)
        sudo systemctl stop tuic
        sudo systemctl disable tuic > /dev/null 2>&1
        rm -rf $INSTALL_DIR
        rm -f $SERVICE_FILE
        echo "Uninstalled successfully!"
        exit 0
        ;;
    *)
        echo "Invalid choice!"
        exit 1
        ;;
    esac
fi
    
# Download and extract
mkdir -p $INSTALL_DIR
# Detect Architecture
ARCH=$(uname -m)
PACKAGE_NAME="tuic-server-1.0.0"

case "$ARCH" in
    "x86_64")
        PACKAGE_NAME="${PACKAGE_NAME}-x86_64-unknown-linux-gnu"
        ;;
    "armv7l")
        PACKAGE_NAME="${PACKAGE_NAME}-armv7-unknown-linux-gnueabi"
        ;;
    "aarch64")
        PACKAGE_NAME="${PACKAGE_NAME}-aarch64-unknown-linux-gnu"
        ;;
    "i686")
        PACKAGE_NAME="${PACKAGE_NAME}-i686-unknown-linux-gnu"
        ;;
    *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

LATEST_RELEASE_URL="https://github.com/EAimTY/tuic/releases/download/tuic-server-1.0.0/${BINARY_NAME}"

curl -sL ${LATEST_RELEASE_URL} -o "$INSTALL_DIR/tuic-server"

chmod 755 "$INSTALL_DIR/tuic-server"

# Create config.json
echo ""
read -p "Enter listen port (or press enter to randomize between 10000 and 65535): " PORT
echo ""
[[ -z "$PORT" ]] && PORT=$((RANDOM % 55536 + 10000))
echo ""
read -p "Enter password (or press enter to generate one): " PASSWORD
echo ""
if [[ -z "$PASSWORD" ]]; then
    PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)
    echo "Generated Password: $PASSWORD"
fi
echo ""
read -p "Enter new UUID(Leave blank for generating a new one): " UUID
echo ""
if [ -z "$UUID" ]; then
    UUID=$(uuidgen)
    echo "Generated UUID: $UUID"
fi 

echo ""

read -p "Choose your congestion_control [bbr/cubic/new_reno] (Default is bbr): " CON_CO
if [ -z "$CON_CO" ]; then
    CON_CO="bbr"
fi

# Generate keys
openssl ecparam -genkey -name prime256v1 -out "$INSTALL_DIR/ca.key"
openssl req -new -x509 -days 36500 -key "$INSTALL_DIR/ca.key" -out "$INSTALL_DIR/ca.crt"  -subj "/CN=bing.com"

cat > $CONFIG_FILE <<EOL
{
  "server": "[::]:$PORT",
  "users": {
    "$UUID": "$PASSWORD"
  },
  "certificate": "$INSTALL_DIR/ca.crt",
  "private_key": "$INSTALL_DIR/ca.key",
  "congestion_control": "$CON_CO",
  "alpn": ["h3", "spdy/3.1"],
  "udp_relay_ipv6": true,
  "zero_rtt_handshake": false,
  "dual_stack": true,
  "auth_timeout": "3s",
  "task_negotiation_timeout": "3s",
  "max_idle_time": "10s",
  "max_external_packet_size": 1500,
  "send_window": 16777216,
  "receive_window": 8388608,
  "gc_interval": "3s",
  "gc_lifetime": "15s",
 "log_level": "warn"
}
EOL

# Create systemd service file
cat > /etc/systemd/system/tuic.service <<EOL
[Unit]
Description=tuic service
Documentation=TUIC v5
After=network.target nss-lookup.target

[Service]
User=root
WorkingDirectory=/root/tuic
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
ExecStart=/root/tuic/tuic-server -c /root/tuic/config.json
Restart=on-failure
RestartSec=10
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOL

# Reload systemd, enable and start the service
sudo systemctl daemon-reload
sudo systemctl enable tuic > /dev/null 2>&1
sudo systemctl start tuic

# Modified share link output
SHARE_LINK_IPV4=$(construct_tuic_url "$UUID" "$PASSWORD" "$IP_V4" "$PORT" "$CON_CO" IPV4)

echo ""
echo ""
echo "Share link IPv4: $SHARE_LINK_IPV4"
echo ""
echo ""