---
type: tech
keywords: 
tags: 
---
# ARPA Randcast Docker Image

Wednesday, June 07, 2023

---

## Links

[Official Rust Image](https://www.docker.com/blog/simplify-your-deployments-using-the-rust-official-image/)

[Codebase](https://github.com/ARPA-Network/BLS-TSS-Network)

## Backlog

- [ ] Kick off container creation with github actions.
- [ ] setup anvil chain ec2 instance
  - [ ] setup proper networking
- [ ] Create interactive cli tool for generaeting yml files / docker run commands.

## To do

- [x] Run node with systemd / supervisor.
- [ ] fix supervisor docker commands. 
- [ ] load yml file as a volume mount
- [ ] Set up anvil local network
- [ ] Allow node containers to connect to host network
- [ ] open the rpc endpoint ports on the docker container (port range?)
- [ ] Test end to end with contracts deployed to local anvil
- [ ] Docker compose? Anvil docker????

## Dockerfiles

randcast-node container

```dockerfile
FROM rust:latest
WORKDIR /usr/src/app
COPY . .
RUN apt-get update
RUN apt-get install -y protobuf-compiler libprotobuf-dev pkg-config libssh-dev build-essential
RUN cargo build --release
ENTRYPOINT ["/usr/src/app/target/release/node-client", "-m", "new-run", "-c", "/config/node_config.yml"]
CMD ["bash", "-c", "tail -f /dev/null"]
```

anvil-chain container

```dockerfile
FROM rust:latest
WORKDIR /usr/src/app
COPY . .
RUN apt-get update
RUN apt-get install -y protobuf-compiler libprotobuf-dev pkg-config libssh-dev build-essential

# install foundry and start anvil
RUN curl -L https://foundry.paradigm.xyz | bash
RUN source /root/.bashrc
RUN foundryup

# Run anvil as a backgrounded proccess
CMD anvil --block-time 1

# deploy controller and adapter contracts
RUN cd /usr/src/app/contracts
RUN forge script script/ControllerLocalTest.s.sol:ControllerLocalTestScript --fork-url http://localhost:8545 --broadcast

# add operators, start the staking pool, stake for a user and some nodes
RUN forge script script/StakeNodeLocalTest.s.sol:StakeNodeLocalTestScript --fork-url http://localhost:8545 --broadcast -g 150

```

## Building the images

```bash
cd docker
docker build -t randcast-node ./docker/randcast-node
docker build -t anvil-chain ./docker/anvil-chain
```

## Docker Compose for 3 nodes and one anvil chain instance

```yml
version: "3.8"
services:
  node1:
    build: ./randcast-node
    volumes:
      - ./node1-config.yml:/config/node-config.yml
    ports:
      - "50062:50062"
      - "50092:50092"
    networks:
      - anvil
  node2:
    build: ./randcast-node
    volumes:
      - ./node2-config.yml:/config/node-config.yml
    ports:
      - "50062:50062"
      - "50092:50092"
    networks:
      - anvil
  node3:
    build: ./randcast-node
    volumes:
      - ./node3-config.yml:/config/node-config.yml
    ports:
      - "50062:50062"
      - "50092:50092"
    networks:
      - anvil
  anvil:
    build: ./anvil-chain
    ports:
      - "8545:8545"
      - "8546:8546"
      - "8547:8547"
```

## Docker Commands

```bash
# build containers
docker build -t randcast-node .
docker build -t anvil ./docker/anvil-chain

# run container
docker run -v ./node-config.yml:/config/node-config.yml randcast-node
```

## Node open ports

node_committer_rpc_endpoint: "[::1]:50062"

- for commiter nodes to talk to each other during BLS.
- each member submits their rpc endpoint to coordinator, and then coordinator broadcasts to all members.
- That means this public ip and port needs to be public on the internet.

node_management_rpc_endpoint: "[::1]:50092"

- Authenticated port / management rpc token in config file
- for management use (node operator can query running nodes)

## logging

currently delivered here: /usr/src/app/log/1/node.log

## Supervisor

``` dockerfile
FROM rust:latest
WORKDIR /usr/src/app
COPY . .
RUN apt-get update
RUN apt-get install -y protobuf-compiler libprotobuf-dev pkg-config libssh-dev build-essential
RUN cargo build --release

# Install a process manager to run the entrypoint command as a service
RUN apt-get install -y supervisor

# Create a Supervisor configuration file
RUN echo "[supervisord]\nnodaemon=true\n\n\
[program:node-client]\n\
command=/usr/src/app/target/release/node-client -m new-run -c /usr/src/app/crates/arpa-node/test/conf/config_test_1.yml\n\  ###### on subsequent runs use re-run
autostart=true\n\
autorestart=true\n\
stderr_logfile=/var/log/node-client.err.log\n\
stdout_logfile=/var/log/node-client.out.log" > /etc/supervisor/conf.d/node-client.conf

# Start Supervisor as the main process
CMD ["supervisord", "-c", "/etc/supervisor/supervisord.conf"]
```

## Custom state checks for supervisor

- [ ] Node client can have diff kinds of errors.
- [ ] Make sure subsequent runs after the first one use "re-run". Don't re-run for now. If the proccess stops just stop and try to alert the operator. 
  - [ ] You need to make sure you regisered and joined a group before re-running. 

## Allow docker to connect to host machine anvil

root@d7ec8e8f98f3:/usr/src/app# ip route show
default via 172.17.0.1 dev eth0 
172.17.0.0/16 dev eth0 proto kernel scope link src 172.17.0.3 

## Anvil space issue

[anvil docs](https://book.getfoundry.sh/reference/anvil/)

```bash
# find the offending logs
du -aBM --max-depth 1 | sort -nr | head -10

# log location
/root/.foundry/anvil/tmp/anvil-state-11-06-2023-03-35qDAeUy


--prune-history # don't keep full chain history
--silent # don't print logs to stdout
--block-time 1 # block time interval in seconds
--no-mining # disable interval mining, mine on demand.

anvil --block-time 10 --prune-history --silent &
```

anvil commands i need to run

```bash
anvil --no-mining --prune-history

forge script script/ControllerLocalTest.s.sol:ControllerLocalTestScript --fork-url http://localhost:8545 --broadcast

forge script script/StakeNodeLocalTest.s.sol:StakeNodeLocalTestScript --fork-url http://localhost:8545 --broadcast -g 150
```

## Interesting Anvil Containers

[eulith](https://github.com/Eulith/eulith-in-a-box/blob/master/start.sh)
[keulith docker](https://hub.docker.com/layers/keulith/devrpc/latest/images/sha256-763b225dff8c52cacb05e8fbfd3357bacb830c086d1802cc80790806a7d7dfab?context=explore)

[docker-anvil](https://github.com/hananbeer/docker-anvil/blob/main/Dockerfile)
[fork-chain](https://github.com/zekiblue/fork-chain/tree/master)
[cannon](https://github.com/usecannon/cannon)

railway??? gcp???

## Interacting with anvil-chain container

```bash

# figure out ip address


forge script script/ControllerLocalTest.s.sol:ControllerLocalTestScript --fork-url http://172.17.0.4:8545 --broadcast

forge script script/StakeNodeLocalTest.s.sol:StakeNodeLocalTestScript --fork-url http://172.17.0.4:8545 --broadcast -g 150
```

## Docker network and -p flag

If you want to expose a port on a container to other containers, it is better to use the `--network` flag. This will connect the containers to the same Docker network, allowing them to communicate with each other directly using the container names or IP addresses. You should use the `-p` flag if you want to map the port onto your host machine and make it accessible from outside the Docker environment.

To expose the port to other containers, you can use Docker's `--network` flag when starting the container, or you can create a custom Docker network and attach the containers to it.

Here are the steps to create a custom Docker network and attach containers to it:

1. Create a custom network:

```shell
docker network create my_custom_network
```

2. Start your `anvil-chain` and `anvil-chain` containers with the `--network` flag:

```shell
docker run -d --network my_custom_network --name my_anvil_base anvil-chain:latest
```

```shell
docker run -d --network my_custom_network --name my_anvil_chain anvil-chain:latest
```

Now, containers attached to the same network can communicate with each other using their container names as hostnames. For instance, if you're running a service that needs to connect to `anvil-chain` on port 8545, you would use the following address: `http://my_anvil_base:8545`.

If you want to expose the service to your host machine, you can add the `-p` flag when starting the container:

```shell
docker run -d --network my_custom_network -p 8545:8545 --name my_anvil_base anvil-chain:latest
```

This will allow you to access the `anvil-chain` container at `http://localhost:8545` on your host machine.

## Actual Randcast Network Commands

[docker networking](https://docs.docker.com/network/)

```bash

# create network
docker network create randcast_network 

# build iamges
cd BLS-TSS-Network
docker build -t anvil-chain ./docker/anvil-chain
docker build -t contract-init ./docker/contract-init
docker build -t arpa-node ./docker/arpa-node


# Start anvil chain
docker run -d --network randcast_network --name anvil-chain anvil-chain:latest

# Run contract init (ensure .env configured correctly)
docker run -d --network randcast_network --name contract-init -v ./contracts/.env:/usr/src/app/external/.env contract-init:latest 

# Run 3 arpa nodes (ensure config files are correct)
docker run -d --network randcast_network --name node1 -v ./docker/arpa-node/config_1.yml:/usr/src/app/external/config.yml arpa-node:latest 
docker run -d --network randcast_network --name node2 -v ./docker/arpa-node/config_2.yml:/usr/src/app/external/config.yml arpa-node:latest 
docker run -d --network randcast_network --name node3 -v ./docker/arpa-node/config_3.yml:/usr/src/app/external/config.yml arpa-node:latest 

# check if nodes grouped succesfully (from contract-init)
cat /usr/src/app/log/1/node.log | grep "available"
  # "Group index:0 epoch:1 is available, committers saved."

# deploy user contract
# (exec into contract-init container)
cd BLS-TSS-Network/contracts
forge script /usr/src/app/BLS-TSS-Network/contracts/script/GetRandomNumberLocalTest.s.sol:GetRandomNumberLocalTestScript --fork-url http://anvil-chain:8545 --broadcast

# check the randomness result recorded by the adapter and the user contract respectively
export ETH_RPC_URL=http://anvil-chain:8545

cast call 0xa513e6e4b8f2a923d98304ec87f64353c4d5c853 "getLastRandomness()(uint256)"

cast call 0x712516e61C8B383dF4A63CFe83d7701Bce54B03e "lastRandomnessResult()(uint256)"

# the above two outputs of uint256 type should be identical
```

---

## Docker commands

```bash
docker ls # list containers
docker inspect <container_id> # inspect container

docker network ls # list networks
docker inspect <network_id> # inspect network
docker network connect <network_id> <container_id> # attach container to network

docker image ls # list images
