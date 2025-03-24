FROM postgres:11

# Configure apt to accept repository suite name changes and use archive repositories
RUN echo 'APT::Get::AllowReleaseInfoChange "true";' > /etc/apt/apt.conf.d/10-allow-release-change && \
    echo 'Acquire::Check-Valid-Until "false";' >> /etc/apt/apt.conf.d/10-allow-release-change && \
    echo "deb http://archive.debian.org/debian stretch main" > /etc/apt/sources.list && \
    echo "deb http://archive.debian.org/debian-security stretch/updates main" >> /etc/apt/sources.list && \
    # Remove PostgreSQL repositories that no longer exist
    rm -f /etc/apt/sources.list.d/pgdg.list || true

# Install nano
RUN apt-get clean && \
    apt-get update -y && \
    apt-get install -y nano

# Set database name
ENV DB_NAME='smdb'

# Copy configuration
COPY ./services/db/postgres/data/postgresql.conf /etc/postgresql.conf

# Setup secrets
RUN mkdir -p /var/lib/postgresql/secrets/
COPY ./secrets/postgres/* /var/lib/postgresql/secrets/
RUN chmod 600 /var/lib/postgresql/secrets/server_key.pem && \
    chown -R postgres:postgres /var/lib/postgresql/secrets/

# Switch to postgres user
USER postgres
