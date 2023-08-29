# ARPA Network L1/L2 Devnet Automation

## Usage

## Start Optimism Devnet

```bash
git clone https://github.com/wrinkledeth/optimism
cd optimism
git submodule update --init --recursive
make devnet-up-deploy
```

## Build node client 

```bash
cd crates/arpa-node
cargo build --bin node-client
``` 

## Deploy ARPA Network contracts to L1 and L2 and start randcast nodes

```bash
cd scripts
# activate venv
cp .env.example .env
python3 -m venv .venv
source .venv/bin/activate
# install dependencies
pip3 install -r requirements.txt
# run script 
python3 main.py -d localnet # localnet deployment
python3 main.py -d testnet # testnet deployment (requires editing .env files)
```

## Kill Existing Resources and Start Fresh

```bash
# Kill Arpa Node Containers
docker kill $(docker ps -q -f ancestxor=arpachainio/node:latest); docker rm -f $(docker ps -a -q -f ancestor=arpachainio/node:latest)

# Kill Node Procceses, remove logs and DB files
pkill -f 'node-client -c'
rm -rf /home/ubuntu/BLS-TSS-Network/crates/arpa-node/log
rm /home/ubuntu/BLS-TSS-Network/crates/arpa-node/*.sqlite

#Clean and redploy OP devnet
cd optimism
make devnet-clean
make devnet-up-deploy

# Helpful alias
alias nodekill='pkill -f "node-client -c"; rm -rf /home/ubuntu/BLS-TSS-Network/crates/arpa-node/log; rm /home/ubuntu/BLS-TSS-Network/crates/arpa-node/*.sqlite'

```
