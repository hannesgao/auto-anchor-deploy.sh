# auto-anchor-deploy.sh
A simple bash script for multiple iterative attempts to deploy solana smart contracts under the anchor framework

## How to use
### Download the script
```shell
curl -sSL https://raw.githubusercontent.com/hannesgao/auto-anchor-deploy.sh/refs/heads/main/auto-anchor-deploy.sh
```
### Make it executable
```shell
chmod +x auto-anchor-deploy.sh
```
### Change configuration parameters in script (optional)
```shell
# Configuration parameters, change them if needed
MAX_RETRIES=5   # times
WAIT_TIME=10    # seconds
```
### Run the script
```shell
./auto-anchor-deploy.sh
```
