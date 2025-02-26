#!/bin/bash

#=============================================================================
# Filename: auto-anchor-deploy.sh
# Version: 1.0
# Author: Hannes Gao
# Contact: https://github.com/hannesgao
# Creation Date: 2025.02.21
# Last Modified: 2025.02.26
# Description: A simple bash script for multiple iterative attempts to deploy 
#              solana smart contracts under the anchor framework
# Usage: ./solana-redeploy.sh
# License: MIT
#=============================================================================

# 设置颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# 配置参数
MAX_RETRIES=5
WAIT_TIME=10 # 单位：秒

# 检查anchor是否已安装
check_anchor() {
  if ! command -v anchor &> /dev/null; then
    echo -e "${RED}错误: Anchor CLI未安装。请先安装Anchor。${NC}"
    exit 1
  fi
}

# 检查Solana CLI是否已安装
check_solana() {
  if ! command -v solana &> /dev/null; then
    echo -e "${RED}错误: Solana CLI未安装。请先安装Solana CLI。${NC}"
    exit 1
  fi
}

# 获取最新的程序ID
get_program_id() {
  local program_id=$(solana address -k target/deploy/program-keypair.json 2>/dev/null)
  if [[ -z "$program_id" ]]; then
    echo -e "${RED}错误: 无法获取程序ID。请确保keypair文件存在。${NC}"
    exit 1
  fi
  echo "$program_id"
}

# 回收部署费用
reclaim_deployment_fees() {
  local program_id=$1
  echo -e "${YELLOW}正在尝试回收部署费用...${NC}"
  
  # 使用anchor clean命令回收部署费用
  anchor clean 2>/dev/null
  
  # 显式地关闭程序账户并回收SOL
  solana program close $program_id --bypass-warning
  
  # 检查回收结果
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}成功回收了部署费用！${NC}"
    return 0
  else
    echo -e "${RED}回收部署费用失败。${NC}"
    return 1
  fi
}

# 部署合约
deploy_contract() {
  echo -e "${YELLOW}正在部署智能合约...${NC}"
  
  # 执行anchor部署命令，捕获输出和退出码
  deploy_output=$(anchor deploy 2>&1)
  deploy_status=$?
  
  if [ $deploy_status -eq 0 ]; then
    echo -e "${GREEN}智能合约部署成功！${NC}"
    return 0
  else
    echo -e "${RED}部署失败！错误信息:${NC}"
    echo "$deploy_output"
    
    # 分析错误信息，根据不同情况返回不同的错误代码
    # 交易模拟失败 - 可能是合约逻辑问题
    if echo "$deploy_output" | grep -q "Transaction simulation failed"; then
      echo -e "${YELLOW}检测到交易模拟失败，可能是合约逻辑问题。${NC}"
      return 1
    
    # 账户不存在 - 可能是初始化问题
    elif echo "$deploy_output" | grep -q "Error: Account does not exist"; then
      echo -e "${YELLOW}检测到账户不存在错误，可能需要初始化。${NC}"
      return 2
      
    # 余额不足
    elif echo "$deploy_output" | grep -q "insufficient funds"; then
      echo -e "${RED}检测到余额不足错误。请确保您的钱包有足够的SOL。${NC}"
      return 3
      
    # 预算不足
    elif echo "$deploy_output" | grep -q "compute budget exceeded"; then
      echo -e "${YELLOW}检测到计算预算不足。${NC}"
      return 4
      
    # 交易超时
    elif echo "$deploy_output" | grep -q "timeout"; then
      echo -e "${YELLOW}检测到交易超时。可能是网络拥堵或连接问题。${NC}"
      return 5
      
    # RPC错误
    elif echo "$deploy_output" | grep -q "Error: failed to send transaction"; then
      echo -e "${YELLOW}检测到RPC错误，发送交易失败。${NC}"
      return 6
      
    # 签名错误
    elif echo "$deploy_output" | grep -q "signature verification failed"; then
      echo -e "${RED}检测到签名验证失败。请检查钱包和权限。${NC}"
      return 7
      
    # 存储账户空间不足
    elif echo "$deploy_output" | grep -q "account data too small"; then
      echo -e "${YELLOW}检测到存储空间不足。${NC}"
      return 8
      
    # 账户已经存在
    elif echo "$deploy_output" | grep -q "already in use"; then
      echo -e "${YELLOW}检测到程序ID已被使用。${NC}"
      return 9
      
    # 区块哈希过期
    elif echo "$deploy_output" | grep -q "blockhash not found"; then
      echo -e "${YELLOW}检测到区块哈希已过期。${NC}"
      return 10
      
    # 权限不足
    elif echo "$deploy_output" | grep -q "missing required signature"; then
      echo -e "${RED}检测到权限不足。请检查部署密钥。${NC}"
      return 11
      
    # 网络连接问题
    elif echo "$deploy_output" | grep -q "failed to connect" || echo "$deploy_output" | grep -q "Connection refused"; then
      echo -e "${YELLOW}检测到网络连接问题。${NC}"
      return 12
      
    # 无效的参数
    elif echo "$deploy_output" | grep -q "invalid argument"; then
      echo -e "${RED}检测到无效参数。请检查配置文件。${NC}"
      return 13
      
    # IDL更新失败
    elif echo "$deploy_output" | grep -q "Error writing IDL"; then
      echo -e "${YELLOW}IDL更新失败，但程序可能已部署。${NC}"
      return 14
      
    # 交易被拒绝
    elif echo "$deploy_output" | grep -q "transaction rejected"; then
      echo -e "${YELLOW}交易被节点拒绝。${NC}"
      return 15
      
    # 其他未知错误
    else
      echo -e "${RED}遇到未分类的错误，请查看上面的错误信息进行手动排查。${NC}"
      return 99
    fi
  fi
}

# 主函数
main() {
  # 检查必要的工具
  check_anchor
  check_solana
  
  # 编译程序
  echo -e "${YELLOW}正在编译程序...${NC}"
  anchor build
  
  if [ $? -ne 0 ]; then
    echo -e "${RED}编译失败，请修复代码错误后再试。${NC}"
    exit 1
  fi
  
  # 获取程序ID
  PROGRAM_ID=$(get_program_id)
  echo -e "${GREEN}程序ID: ${PROGRAM_ID}${NC}"
  
  # 尝试部署，最多重试MAX_RETRIES次
  for ((i=1; i<=MAX_RETRIES; i++)); do
    echo -e "${YELLOW}部署尝试 $i/$MAX_RETRIES${NC}"
    
    deploy_contract
    deploy_result=$?
    
    if [ $deploy_result -eq 0 ]; then
      # 部署成功
      echo -e "${GREEN}成功完成部署！${NC}"
      exit 0
    elif [[ $deploy_result -eq 1 || $deploy_result -eq 2 || $deploy_result -eq 4 || 
            $deploy_result -eq 5 || $deploy_result -eq 6 || $deploy_result -eq 8 || 
            $deploy_result -eq 10 || $deploy_result -eq 12 || $deploy_result -eq 14 || 
            $deploy_result -eq 15 ]]; then
      # 可重试的错误类型，尝试回收费用
      echo -e "${YELLOW}遇到可恢复的错误，将尝试回收费用并重新部署...${NC}"
      reclaim_deployment_fees $PROGRAM_ID
      
      # 针对计算预算不足的情况，增加计算预算
      if [ $deploy_result -eq 4 ]; then
        echo -e "${YELLOW}下一次尝试将增加计算预算...${NC}"
        # 设置环境变量，之后的部署会使用更大的计算预算
        export ANCHOR_COMPUTE_BUDGET=400000
      fi
      
      # 针对网络问题，增加等待时间
      if [[ $deploy_result -eq 5 || $deploy_result -eq 6 || $deploy_result -eq 12 ]]; then
        local extended_wait=$((WAIT_TIME * 2))
        echo -e "${YELLOW}检测到网络问题，等待 ${extended_wait} 秒后重试...${NC}"
        sleep $extended_wait
      else
        # 正常等待
        echo -e "${YELLOW}等待 ${WAIT_TIME} 秒后重试...${NC}"
        sleep $WAIT_TIME
      fi
      
    elif [ $deploy_result -eq 3 ]; then
      # 余额不足，无法自动恢复
      echo -e "${RED}检测到钱包余额不足，请充值后再尝试部署。${NC}"
      exit 1
      
    elif [ $deploy_result -eq 7 ] || [ $deploy_result -eq 11 ]; then
      # 签名或权限问题，无法自动恢复
      echo -e "${RED}检测到签名/权限问题，请检查您的部署密钥是否正确配置。${NC}"
      exit 1
      
    elif [ $deploy_result -eq 9 ]; then
      # 程序ID已被使用，建议更换
      echo -e "${RED}程序ID已被使用，请尝试生成新的程序ID。${NC}"
      echo -e "${YELLOW}可以使用以下命令生成新的密钥对:${NC}"
      echo "solana-keygen new -o target/deploy/new-program-keypair.json"
      exit 1
      
    elif [ $deploy_result -eq 13 ]; then
      # 配置问题
      echo -e "${RED}检测到配置或参数问题，请检查Anchor.toml和程序ID配置是否正确。${NC}"
      exit 1
      
    else
      # 其他未知错误，给出详细建议
      echo -e "${RED}遇到无法自动恢复的错误(代码:$deploy_result)，请手动检查。${NC}"
      exit 1
    fi
  done
  
  echo -e "${RED}达到最大重试次数 ($MAX_RETRIES)，自动部署失败。${NC}"
  echo -e "${YELLOW}建议手动检查以下几点:${NC}"
  echo "1. 确认您的钱包余额充足"
  echo "   运行: solana balance"
  echo "2. 检查网络连接和Solana集群状态"
  echo "   运行: solana cluster-version"
  echo "3. 检查合约逻辑是否有问题"
  echo "4. 尝试使用更大的计算预算手动部署:"
  echo "   运行: anchor deploy --program-name your_program_name -- --compute-budget 600000"
  echo "5. 检查是否有足够的空间存储程序代码:"
  echo "   运行: solana program show <PROGRAM_ID>"
  echo "6. 尝试更换RPC节点:"
  echo "   运行: solana config set --url https://alternative-rpc-url.com"
  echo "7. 检查部署密钥是否具有足够权限:"
  echo "   运行: solana program show --keypair <YOUR_KEYPAIR> --output json <PROGRAM_ID>"
  echo "8. 如果是IDL更新失败，但程序已部署，可以尝试手动更新IDL:"
  echo "   运行: anchor idl init --filepath target/idl/<YOUR_PROGRAM>.json <PROGRAM_ID>"
  echo "9. 如果是网络拥堵问题，尝试在非高峰期部署"
  echo "10. 确认Anchor.toml中的配置与实际环境一致"
  exit 1
}

# 执行主函数
main
