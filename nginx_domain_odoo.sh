#!/bin/bash

# --- Added feature: Ask for domain or default to localhost ---
REQUIRED_TOOLS=("systemctl" "nano" "sudo")

echo "Checking required tools..."
apt update && apt upgrade -y
for tool in "${REQUIRED_TOOLS[@]}"; do
  if ! command -v "$tool" &>/dev/null; then
    echo "$tool is NOT installed."
    echo "$tool is installing....."
    apt install "$tool" -y
  else
    :
  fi
done
read -p "Enter domain (leave blank to use localhost): " DOMAIN
DOMAIN=${DOMAIN:-localhost}

# --- Added feature: Ask for Odoo version (default: 17) ---
read -p "Enter Odoo version (e.g., 17, 18) [default: 17]: " ODOO_VERSION
ODOO_VERSION=${ODOO_VERSION:-17}

# --- Added feature: Set PostgreSQL version based on Odoo version ---
if [ "$ODOO_VERSION" == "17" ]; then
  POSTGRES_VERSION="15"
elif [ "$ODOO_VERSION" == "18" ]; then
  POSTGRES_VERSION="16"
else
  echo "Unsupported Odoo version, defaulting PostgreSQL version to 15."
  POSTGRES_VERSION="15"
fi

# --- Added feature: Ask if user wants to set up Nginx ---
read -p "Do you want to set up Nginx? [y/n]: " SETUP_NGINX
SETUP_NGINX=${SETUP_NGINX,,}  # lowercase

PROJECT_DIR="nginx-odoo-setup-docker"
mkdir -p "$PROJECT_DIR" && cd "$PROJECT_DIR"

echo "Creating folder structure..."
mkdir -p addons config
if [ "$SETUP_NGINX" == "y" ]; then
  mkdir -p nginx/conf.d nginx/logs
fi

echo "Writing docker-compose.yml..."
cat > docker-compose.yml <<EOF
version: "3.8"

services:
  db:
    image: postgres:$POSTGRES_VERSION
    container_name: odoo${ODOO_VERSION}-db
    restart: unless-stopped
    environment:
      POSTGRES_DB: odoo
      POSTGRES_USER: odoo
      POSTGRES_PASSWORD: odoo
    volumes:
      - odoo${ODOO_VERSION}-db-data:/var/lib/postgresql/data

  odoo:
    image: odoo:$ODOO_VERSION
    container_name: odoo${ODOO_VERSION}-app
    user: "0:0"
    depends_on:
      - db
    restart: unless-stopped
    environment:
      HOST: db
      USER: odoo
      PASSWORD: odoo
    command: >
      bash -c "
      sleep 5 &&
      if [ ! -f /var/lib/odoo/.created ]; then
        echo 'Creating initial Odoo database...' &&
        odoo -c /etc/odoo.conf -d auto_db --db_host=db --db_user=odoo --db_password=odoo --init base --without-demo=all --stop-after-init &&
        touch /var/lib/odoo/.created;
      fi &&
      echo 'Starting Odoo server...' &&
      odoo -c /etc/odoo.conf"
    volumes:
      - odoo${ODOO_VERSION}-web-data:/var/lib/odoo
      - ./addons:/mnt/extra-addons
      - ./config/odoo.conf:/etc/odoo.conf
    ports:
      - "8069:8069"
EOF

if [ "$SETUP_NGINX" == "y" ]; then
cat >> docker-compose.yml <<EOF

  nginx:
    image: nginx:latest
    container_name: odoo${ODOO_VERSION}-nginx
    depends_on:
      - odoo
    ports:
      - "80:80"
    volumes:
      - ./nginx/conf.d:/etc/nginx/conf.d:ro
      - ./nginx/logs:/var/log/nginx
EOF
fi

cat >> docker-compose.yml <<EOF

volumes:
  odoo${ODOO_VERSION}-db-data:
  odoo${ODOO_VERSION}-web-data:
EOF

echo "Writing Odoo config..."
cat > config/odoo.conf <<EOF
[options]
addons_path = /mnt/extra-addons
data_dir = /var/lib/odoo
admin_passwd = admin
xmlrpc_port = 8069
longpolling_port = 8072
db_host = db
db_port = 5432
db_user = odoo
db_password = odoo
EOF

if [ "$SETUP_NGINX" == "y" ]; then
  echo "Writing Nginx config..."
  cat > nginx/conf.d/odoo.conf <<EOF
server {
  listen 80;
  server_name $DOMAIN;

  access_log /var/log/nginx/access.log;
  error_log /var/log/nginx/error.log;

  location / {
    proxy_pass http://odoo${ODOO_VERSION}-app:8069;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
  }

  location ~* /web/static/ {
    proxy_cache_valid 200 90m;
    proxy_buffering on;
    expires 864000;
    proxy_pass http://odoo${ODOO_VERSION}-app:8069;
  }

  location /longpolling {
    proxy_pass http://odoo${ODOO_VERSION}-app:8072;
  }
}
EOF

  touch nginx/logs/access.log nginx/logs/error.log
fi

chmod -R 755 addons config nginx 2>/dev/null

echo "Starting Docker containers..."
docker-compose up -d

# --- Added feature: SSL check and optional renewal ---
if [ "$SETUP_NGINX" == "y" ] && [ "$DOMAIN" != "localhost" ]; then
  echo "Checking SSL certificate for $DOMAIN..."
  if ! openssl s_client -connect "$DOMAIN:443" -servername "$DOMAIN" < /dev/null 2>/dev/null | openssl x509 -noout -checkend 86400 > /dev/null; then
    echo "SSL certificate is expired or not found for $DOMAIN."

    read -p "Do you want to issue/renew the SSL certificate using certbot? [y/n]: " RENEW_SSL
    if [ "$RENEW_SSL" == "y" ]; then
      echo "Installing certbot (if not present)..."
      sudo apt install -y certbot

      echo "Checking if port 80 is in use..."
      if lsof -i :80 >/dev/null; then
        echo "Port 80 is in use. Temporarily stopping Docker containers..."
        docker-compose down
        echo "Port 80 freed."
      fi

      echo "Running certbot to issue certificate..."
      sudo certbot certonly --standalone -d "$DOMAIN"

      echo "Restarting Docker containers..."
      docker-compose up -d

      read -p "Set up auto-renewal via cron? [y/n]: " SETUP_CRON
      if [ "$SETUP_CRON" == "y" ]; then
        read -p "Enter auto-renewal check period in days (e.g., 30): " RENEW_PERIOD
        CRON_CMD="certbot renew --quiet && docker-compose exec nginx nginx -s reload"
        (crontab -l 2>/dev/null; echo "0 0 */$RENEW_PERIOD * * $CRON_CMD") | crontab -
        echo "Cron job added to check and renew SSL every $RENEW_PERIOD days."
      fi
    fi
  else
    echo "SSL certificate is valid."
  fi
fi


echo ""
echo "Setup complete!"
echo "Access Odoo at: http://$DOMAIN:80"
echo "Master Password: admin"
