# auto-anchor-deploy.sh
A simple bash script for multiple iterative attempts to deploy solana smart contracts under the anchor framework

## How to use
### Download the script
```
curl -sSL https://raw.githubusercontent.com/hannesgao/auto-anchor-deploy.sh/refs/heads/main/auto-anchor-deploy.sh
```
### Make it executable
```
chmod +x auto-anchor-deploy.sh
```
### Change configuration parameters (optional)
```
# Configuration parameters, change them if needed
MAX_RETRIES=5   # times
WAIT_TIME=10    # seconds
```
### Run the script
```
./auto-anchor-deploy.sh
```
