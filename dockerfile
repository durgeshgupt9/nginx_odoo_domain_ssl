FROM webkulodoo/odoo:16.0
WORKDIR /opt/odoo-custom-addons
USER root
LABEL maintainer="durgeshgupt"
# RUN apt update && apt upgrade -y && apt install sudo -y && apt install systemctl -y

COPY . .

VOLUME ["/opt/odoo-custom-addons"]
EXPOSE 80
EXPOSE 8069
EXPOSE 443

# Create a wrapper entrypoint to run your script BEFORE Odoo starts
RUN echo '#!/bin/bash\n\
set -e\n\
# Run your interactive script\n\
bash /app/data/nginx.sh\n\
echo ">>> Running Odoo ENTRYPOINT..."\n\
exec /entrypoint.sh "$@"\n' > /entrypoint-wrapper.sh && \
    chmod +x /entrypoint-wrapper.sh

# Override ENTRYPOINT to our wrapper
ENTRYPOINT ["/entrypoint-wrapper.sh"]

# CMD remains same as in base
CMD ["odoo"]
