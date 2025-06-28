# Odoo Deployment with Nginx Reverse Proxy and Let's Encrypt SSL

This repository provides a **script-based** solution to deploy **Odoo** with **Nginx** as a reverse proxy and **automated SSL** using **Let's Encrypt**. The deployment is fully automated via simple shell scripts and Docker Compose. The scripts handle the entire process, including the domain configuration, SSL certificate setup, and container management.

## Features

- **Odoo**: Deployed using Docker containers.
- **Nginx**: Configured as a reverse proxy for Odoo.
- **Let's Encrypt SSL**: Automated SSL certificate issuance and renewal.
- **Domain Setup**: Prompts user for domain and email during setup.

## Prerequisites

- **Docker** and **Docker Compose** must be installed on your server.
- A **valid domain name** pointing to your server's IP address.
- **Access to modify DNS settings** for your domain.
- **Email address** for Let's Encrypt registration.

### Install Docker and Docker Compose
