#!/bin/bash

# ================================
# PASSWORD PROTECTION
# ================================

CORRECT_PASS="custom_addons"

while true; do
    echo -n "Enter password to run this script: "
    read -s USER_PASS
    echo

    if [[ "$USER_PASS" == "$CORRECT_PASS" ]]; then
        echo -e "\e[32mPassword correct. Proceeding...\e[0m"
        break
    else
        echo -e "\e[31mWrong password. Contact admin.\e[0m"
    fi
done

# ================================
# ORIGINAL SCRIPT (unchanged)
# ================================

# Colors
GREEN="\e[32m"
RED="\e[31m"
NC="\e[0m"

###########################################################
# Install dependencies (sudo, nano, dig, nginx, certbot)
###########################################################

echo -e "${GREEN}Updating and checking required packages...${NC}"

apt update -y >/dev/null 2>&1

# Install sudo if missing
if ! command -v sudo &>/dev/null; then
    echo -e "${GREEN}Installing sudo...${NC}"
    apt install -y sudo
fi

# Install nano
if ! command -v nano &>/dev/null; then
    echo -e "${GREEN}Installing nano...${NC}"
    sudo apt install -y nano
fi

# Install dig (dnsutils)
if ! command -v dig &>/dev/null; then
    echo -e "${GREEN}Installing dnsutils (dig)...${NC}"
    sudo apt install -y dnsutils
fi

###########################################################
# Detect restart method (systemctl OR service)
###########################################################

RESTART_CMD=""

if command -v systemctl &>/dev/null; then
    RESTART_CMD="sudo systemctl restart nginx"
elif command -v service &>/dev/null; then
    RESTART_CMD="sudo service nginx restart"
else
    echo -e "${RED}ERROR: Neither systemctl nor service exists. Cannot restart nginx.${NC}"
    exit 1
fi

###########################################################
# Ask for domain(s)
###########################################################

DOMAINS=()

echo "Do you want to use a custom domain? (y/N): "
read USE_DOMAIN

if [[ "$USE_DOMAIN" =~ ^[Yy]$ ]]; then
    while true; do
        echo -n "Enter your domain (example: mysite.com): "
        read DOMAIN

        if [[ -z "$DOMAIN" ]]; then
            echo -e "${RED}Domain cannot be empty.${NC}"
            continue
        fi

        IP=$(dig +short "$DOMAIN")

        if [[ -z "$IP" ]]; then
            echo -e "${RED}Domain does NOT resolve. Fix DNS and try again.${NC}"
            continue
        fi

        echo -e "${GREEN}✔ Domain resolves to: $IP${NC}"
        DOMAINS+=("$DOMAIN")

        echo "Do you want to add another domain? (y/N): "
        read ADD_MORE

        if ! [[ "$ADD_MORE" =~ ^[Yy]$ ]]; then
            break
        fi
    done
else
    echo -e "${GREEN}Using default: localhost${NC}"
    DOMAINS=("localhost")
fi

# Networking suggestion for Docker
if [[ "${DOMAINS[0]}" != "localhost" ]]; then
    echo -e "${GREEN}TIP: For best domain performance in Docker use:${NC}"
    echo -e "${GREEN}docker run --network=host <image>${NC}"
fi

###########################################################
# Install Nginx + Certbot
###########################################################

echo -e "${GREEN}Installing Nginx, Certbot, and dependencies...${NC}"
sudo apt install -y nginx certbot python3-certbot-nginx

###########################################################
# Setup Nginx Reverse Proxy for Odoo
###########################################################

echo -e "${GREEN}Configuring Nginx reverse proxy...${NC}"

NGINX_CONF="/etc/nginx/sites-available/odoo.conf"

sudo bash -c "cat > $NGINX_CONF" <<EOF
server {
    listen 80;
    server_name ${DOMAINS[*]};

    proxy_read_timeout 720s;
    proxy_connect_timeout 720s;
    proxy_send_timeout 720s;
    client_max_body_size 200m;

    location / {
        proxy_pass http://127.0.0.1:8069;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /longpolling/ {
        proxy_pass http://127.0.0.1:8072;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

sudo ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/

sudo nginx -t
eval "$RESTART_CMD"

###########################################################
# SSL Setup (Certbot)
###########################################################

echo -n "Enter your email for SSL notifications: "
read EMAIL

if [[ "${DOMAINS[0]}" != "localhost" ]]; then
    echo -e "${GREEN}Requesting SSL certificate using Certbot...${NC}"

    sudo certbot --nginx -m "$EMAIL" --agree-tos \
        -d "${DOMAINS[*]}" --redirect

else
    echo -e "${RED}Skipping SSL — cannot generate certificates for localhost.${NC}"
fi

###########################################################
# Finish
###########################################################

echo -e "${GREEN}=============================================="
echo -e "Congratulations! Odoo reverse proxy is ready."
echo -e "Access using:"
for d in "${DOMAINS[@]}"; do
    echo -e "➡ http://$d"
done
echo -e "==============================================${NC}"
