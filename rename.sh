#!/bin/bash

# Base directory containing all seasons
BASE_DIR="/Users/Chen/Downloads/18-绝望主妇-全注解版"

# Loop through all season directories (S01, S02, etc.)
for season_dir in "$BASE_DIR"/S*; do
  # Extract season number (e.g., S01)
  season=$(basename "$season_dir")
  
  # Loop through all episode files in the season directory
  for episode_file in "$season_dir"/E*.pdf; do
    # Extract episode number (e.g., E01.pdf)
    episode=$(basename "$episode_file")
    
    # Create new filename (e.g., S01E01.pdf)
    new_filename="$season$episode"
    
    # Rename the file
    mv "$episode_file" "$season_dir/$new_filename"
    
    echo "Renamed: $episode_file -> $season_dir/$new_filename"
  done
done

echo "Renaming complete!"
