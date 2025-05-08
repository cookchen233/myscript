#!/bin/bash

cd ~/Coding/admin-vue/

# Define commands in an array
commands=(
  # "yarn dev --port 5555"
  "yarn dev --port 5556"
  # "yarn dev --port 5557"
  # "yarn dev --port 5558"
  
  # "cd ~/Coding/bbv2-uniapp/ && pnpm run dev:h5 --port 4444"
  # "cd ~/Coding/cargo-uniapp/ && pnpm run dev:h5 --port 4445"
  "cd ~/Coding/driving-uniapp/ && pnpm run dev:h5 --port 4446"
  "cd ~/Coding/safe-uniapp/ && pnpm run dev:h5 --port 4447"
  
  # "cd ~/Coding/cargo-uniapp/ && pnpm run dev:mp-weixin"
  # "cd ~/Coding/driving-uniapp/ && pnpm run dev:mp-weixin"
)

# Filter out commented and empty lines, then pass to concurrently
filtered_commands=()
for cmd in "${commands[@]}"; do
  if [[ ! "$cmd" =~ ^[[:space:]]*# ]] && [[ -n "$cmd" ]]; then
    filtered_commands+=("$cmd")
  fi
done

concurrently "${filtered_commands[@]}"