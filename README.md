Odoo 18 Deployment with Docker, Nginx, PostgreSQL & SSL
------------------------------------------------------------
This repository provides a production-ready deployment setup for Odoo 18 using Docker Compose, PostgreSQL, and Nginx with domain and SSL (Let's Encrypt) support.

Features
Odoo 18 deployed via Docker

PostgreSQL as backend database

Nginx as reverse proxy with SSL (Let's Encrypt)

Domain support (via Nginx virtual host config)

Cron job for automatic SSL certificate renewal

Requirements
Before starting, make sure the following are installed and configured:

Docker & Docker Compose

A domain name pointed to your server IP (A record)

Ports 80 and 443 open on your firewall (for HTTP/HTTPS)

Basic knowledge of Docker and Odoo

Setup & Deployment
1. Clone the Repository

git clone https://github.com/durgeshgupt9/nginx_odoo_domain_ssl.git
cd nginx_odoo_domain_ssl
2. Run Installation Scripts
Run the setup scripts to configure and launch the services:


bash nginx_domain_odoo.sh
These scripts will:

Create a folder: nginx-odoo-setup-docker/

Copy necessary configs: docker-compose.yml, odoo.conf, Nginx files

Launch Docker containers for Odoo, PostgreSQL, and Nginx

Setup SSL certificates using Certbot (Let's Encrypt)

Directory Structure

nginx-odoo-setup-docker/
├── addons/                    
├── config/odoo.conf           
├── docker-compose.yml         
├── nginx/
│   └── conf.d/                
└── certbot/                  
Manual Docker Commands
Start all services:


cd nginx-odoo-setup-docker
docker-compose up -d
Stop services:


docker-compose down
View Odoo logs:


docker logs -f odoo18-app
SSL & Domain Configuration
Nginx is configured as a reverse proxy for Odoo.

SSL is installed using Certbot with Let's Encrypt.

Certificates are stored in /etc/letsencrypt (inside container or mounted volume).

Make sure your domain is correctly pointing to the server IP before running the setup.

Auto-Renewal of SSL Certificates
A cron job is added to automatically renew SSL certificates.

You can verify the cron job:


crontab -l
It typically runs this command:


0 3 * * * docker exec nginx-certbot certbot renew --quiet --deploy-hook "nginx -s reload"
You can test SSL renewal manually:


docker exec nginx-certbot certbot renew --dry-run
Configuration Files
Odoo Config: nginx-odoo-setup-docker/config/odoo.conf

Docker Compose: nginx-odoo-setup-docker/docker-compose.yml

Nginx Config: nginx-odoo-setup-docker/nginx/conf.d/yourdomain.conf

Addons Directory: nginx-odoo-setup-docker/addons/

Troubleshooting
Check Odoo container logs:


docker logs odoo18-app
Ensure PostgreSQL container is running and has proper volume permissions.

Verify domain is correctly configured and accessible via HTTPS.

Confirm Certbot successfully obtained the SSL certificate:


docker exec nginx-certbot certbot certificates