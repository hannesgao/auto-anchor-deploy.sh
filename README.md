# auto-anchor-deploy.sh
A simple bash script for multiple iterative attempts to deploy solana smart contracts under the anchor framework

## How to use
### Download the script
```bash
curl -sSL https://raw.githubusercontent.com/hannesgao/auto-anchor-deploy.sh/refs/heads/main/auto-anchor-deploy.sh
```
### Make it executable
```bash
chmod +x auto-anchor-deploy.sh
```
### Change configuration parameters in script (optional)
```bash
# Configuration parameters, change them if needed
MAX_RETRIES=5   # times
WAIT_TIME=10    # seconds
```
### Run the script
```bash
./auto-anchor-deploy.sh
```
