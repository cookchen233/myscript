#!/bin/bash

# Format the timestamp into a human-readable date and time
pbpaste| xargs -I {} date -r "{}" "+%Y-%m-%d %H:%M:%S"

read -r -t 300
