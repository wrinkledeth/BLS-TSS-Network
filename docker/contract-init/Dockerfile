FROM rust:latest

# Define working directory
WORKDIR /usr/src/app

# Install dependencies
RUN apt-get update && \
    apt-get install -y git neovim protobuf-compiler libprotobuf-dev pkg-config libssh-dev build-essential net-tools netcat

# Install Foundry and start Anvil
RUN curl -L https://foundry.paradigm.xyz | bash && \
    /root/.foundry/bin/foundryup

# Copy entrypoint script into the container
COPY entrypoint.sh /usr/src/app/entrypoint.sh
RUN chmod +x /usr/src/app/entrypoint.sh

# Create a directory for the external .env file
RUN mkdir -p /usr/src/app/external

# Run entrypoint script and keep container running
ENTRYPOINT ["/usr/src/app/entrypoint.sh"]