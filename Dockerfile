# Builder stage
FROM amazonlinux:2 as builder

# Update system and install required packages
RUN yum update -y && \
    # Install development tools, curl, unzip, and OpenSSL development package
    yum groupinstall -y "Development Tools" && \
    yum install -y curl unzip openssl-devel pkgconfig && \
    yum clean all

# Install Rust using rustup (this will install Rust in /root/.cargo)
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y
ENV PATH=/root/.cargo/bin:$PATH

WORKDIR /src

COPY vaultwarden ./vaultwarden/


# Build Vaultwarden in release mode
RUN export VW_ROOT_PATH=$(ls -d ./vaultwarden/dani-garcia-vaultwarden*/ | head -n 1) && \
    echo "VW_ROOT_PATH = ${VW_ROOT_PATH}" && \
    cd ${VW_ROOT_PATH} && \
    echo "Currently in $(pwd)" && \
    mv * /src/vaultwarden

WORKDIR /src/vaultwarden

RUN cargo build --release --features sqlite

# Use Amazon Linux 2 base image (supports `yum`)
FROM amazonlinux:2

# Set the default value for the data directory to a writable location
# Setting this in github actions instead #ENV DATA_FOLDER="/tmp/vaultwarden/data"

# Sets the port for the Rocket web framework
ENV ROCKET_PORT=8080

# Install dependencies using yum
RUN yum install -y tar sqlite curl ca-certificates jq gzip openssl11-libs && yum clean all

# Use the GitHub API to get the download URL for the latest release asset
# that ends with "litestream-linux-amd64.zip".
RUN export LATEST_ASSET_URL=$(curl -s "https://api.github.com/repos/benbjohnson/litestream/releases/latest" | \
      jq -r '.assets[] | select(.name | endswith("linux-amd64.tar.gz")) | .browser_download_url') && \
    echo "Downloading Litestream asset from: ${LATEST_ASSET_URL}" && \
    curl -L "${LATEST_ASSET_URL}" -o /tmp/litestream.tar.gz && \
    # Extract the tar.gz archive; assuming it contains a file named litestream-linux-amd64
    tar -xzvf /tmp/litestream.tar.gz -C /usr/local/bin/ && \
    # Rename the binary to "litestream" if needed. Adjust the source name if the archive structure differs.
    # mv /usr/local/bin/litestream-linux-amd64 /usr/local/bin/litestream && \
    chmod +x /usr/local/bin/litestream && \
    rm /tmp/litestream.tar.gz

# Optionally, verify installation by printing the version
RUN litestream version

# Set working directory
WORKDIR /vaultwarden

# Copy Vaultwarden binary from latest release
#COPY vaultwarden /vaultwarden/vaultwarden
COPY --from=builder /src/vaultwarden/target/release/vaultwarden /vaultwarden/vaultwarden
RUN chmod +x /vaultwarden/vaultwarden

# Copy web-vault wesite from latest release
COPY web-vault /vaultwarden/


# Copy Litestream config
COPY litestream.yml /etc/litestream.yml

# Expose Vaultwarden API port
EXPOSE 8080

# AWS Lambda requires entrypoint to be `/lambda-entrypoint.sh`
COPY lambda-entrypoint.sh /lambda-entrypoint.sh
RUN chmod +x /lambda-entrypoint.sh

# CMD for AWS Lambda container execution
CMD ["/lambda-entrypoint.sh"]
