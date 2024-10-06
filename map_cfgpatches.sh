#!/bin/bash

# Default directory containing mods
MODS_DIR="/home/steam/.steam/steamcmd/arma3_windows/clientmods"

# Check if the SQF file is provided
if [ $# -lt 1 ]; then
  echo "Usage: $0 <path_to_sqf_file> [mods_directory]"
  exit 1
fi

SQF_FILE="$1"

# If a second argument is provided, use it as MODS_DIR
if [ $# -ge 2 ]; then
  MODS_DIR="$2"
fi

echo "Using mods directory: $MODS_DIR"

# Normalize MODS_DIR to ensure it ends with a single slash
MODS_DIR="${MODS_DIR%/}/"

# Check if the SQF file exists
if [ ! -f "$SQF_FILE" ]; then
  echo "Error: File '$SQF_FILE' not found."
  exit 1
fi

# Step 1: Parse the SQF file to extract the array of CfgPatches entries
echo "Parsing SQF file: $SQF_FILE"

# Read the file content and extract the array
FILE_CONTENT=$(cat "$SQF_FILE")

# Extract the array content between the square brackets []
ARRAY_CONTENT=$(echo "$FILE_CONTENT" | grep -oP '\[\K[^\]]+')

# Split the entries into an array
IFS=',' read -ra CfgPatchesEntries <<< "$ARRAY_CONTENT"

# Trim quotes and whitespace from each entry
declare -a CfgPatchesList
for entry in "${CfgPatchesEntries[@]}"; do
  # Remove leading and trailing whitespace and quotes
  trimmed_entry=$(echo "$entry" | sed -e 's/^[ \t]*"//' -e 's/"[ \t]*$//' -e 's/^[ \t]*//' -e 's/[ \t]*$//')
  CfgPatchesList+=("$trimmed_entry")
done

echo "Extracted ${#CfgPatchesList[@]} unique CfgPatches entries from SQF file."

# Write CfgPatchesList to a temporary file
CfgPatchesFile=$(mktemp)
printf "%s\n" "${CfgPatchesList[@]}" > "$CfgPatchesFile"

# Step 2: Scan all .pbo files once to build a mapping of CfgPatches entries to mod IDs

# Initialize an associative array to hold the mapping: CfgPatchesEntry -> ModID
declare -A CfgPatchesToModID

echo "Scanning .pbo files in mods directory..."

# Check if MODS_DIR exists
if [ ! -d "$MODS_DIR" ]; then
  echo "Error: Mods directory '$MODS_DIR' does not exist."
  exit 1
fi

# Use 'find' and read the output into an array
mapfile -t PBO_FILES < <(find "$MODS_DIR" -type f -name "*.pbo")

# Total number of .pbo files
TOTAL_PBO_FILES="${#PBO_FILES[@]}"
echo "Found $TOTAL_PBO_FILES .pbo files."

if [ "$TOTAL_PBO_FILES" -eq 0 ]; then
  echo "No .pbo files found in $MODS_DIR. Please check the directory path and ensure mods are installed."
  exit 1
fi

# Function to process a single .pbo file
process_pbo_file() {
  local pbo_file="$1"
  local CfgPatchesFile="$2"
  local MODS_DIR="$3"

  # Ensure the file exists
  if [ ! -f "$pbo_file" ]; then
    echo "Warning: File '$pbo_file' not found. Skipping." >&2
    return
  fi

  # Extract the mod_id from the path
  REL_PATH="${pbo_file#$MODS_DIR}"
  MOD_ID="${REL_PATH%%/*}"

  # Validate that MOD_ID is numeric
  if [[ ! "$MOD_ID" =~ ^[0-9]+$ ]]; then
    # Skip if MOD_ID is not numeric
    return
  fi

  # Use strings and grep to find exact matches
  matches=$(strings "$pbo_file" | grep -Fx -f "$CfgPatchesFile" | sort | uniq)

  # Output the results
  while IFS= read -r CfgEntry; do
    # Validate that CfgEntry is not empty
    if [ -n "$CfgEntry" ]; then
      echo "$CfgEntry|$MOD_ID"
    fi
  done <<< "$matches"
}
export -f process_pbo_file

# Run processing in parallel
echo "Processing .pbo files in parallel..."

# Create a temporary file to collect results
TMP_RESULTS=$(mktemp)

# Export MODS_DIR and CfgPatchesFile for subprocesses
export MODS_DIR
export CfgPatchesFile

# Use GNU parallel to process files in parallel
printf '%s\n' "${PBO_FILES[@]}" | parallel --bar --halt now,fail=1 process_pbo_file {} "$CfgPatchesFile" "$MODS_DIR" >> "$TMP_RESULTS"

# Read the results into the CfgPatchesToModID mapping
while IFS='|' read -r CfgEntry ModID; do
  # Validate CfgEntry and ModID
  if [ -z "$CfgEntry" ] || [ -z "$ModID" ] || [[ ! "$ModID" =~ ^[0-9]+$ ]]; then
    # Skip invalid entries
    continue
  fi

  if [[ -z "${CfgPatchesToModID[$CfgEntry]}" ]]; then
    CfgPatchesToModID["$CfgEntry"]="$ModID"
  else
    # Avoid duplicates
    if [[ ! "${CfgPatchesToModID[$CfgEntry]}" =~ $ModID ]]; then
      CfgPatchesToModID["$CfgEntry"]+=", $ModID"
    fi
  fi
done < "$TMP_RESULTS"

# Clean up temporary files
rm "$TMP_RESULTS" "$CfgPatchesFile"

echo "Completed scanning .pbo files."

# Step 3: For each mod ID, retrieve the mod name from the Steam Workshop page

# Initialize an associative array to hold mod IDs to mod names
declare -A ModIDToModName

# Extract unique mod IDs from the mappings
declare -A UniqueModIDs
for mod_ids in "${CfgPatchesToModID[@]}"; do
  # Split mod IDs by comma and add to UniqueModIDs array
  IFS=',' read -ra ids <<< "$mod_ids"
  for id in "${ids[@]}"; do
    id_trimmed=$(echo "$id" | xargs)  # Trim whitespace
    UniqueModIDs["$id_trimmed"]=1
  done
done

TOTAL_UNIQUE_MOD_IDS="${#UniqueModIDs[@]}"
echo "Retrieving mod names for $TOTAL_UNIQUE_MOD_IDS unique mod IDs..."

if [ "$TOTAL_UNIQUE_MOD_IDS" -eq 0 ]; then
  echo "No mod IDs found. Exiting."
  exit 1
fi

# Counter for progress display
MOD_COUNTER=0

# Retrieve mod names
for MOD_ID in "${!UniqueModIDs[@]}"; do
  MOD_COUNTER=$((MOD_COUNTER + 1))
  echo -ne "Fetching mod name for mod ID $MOD_ID ($MOD_COUNTER of $TOTAL_UNIQUE_MOD_IDS)...\r"

  # Validate that MOD_ID is numeric
  if [[ ! "$MOD_ID" =~ ^[0-9]+$ ]]; then
    echo -e "\nInvalid mod ID: $MOD_ID. Skipping."
    continue
  fi

  # Build the URL
  URL="https://steamcommunity.com/sharedfiles/filedetails/?id=$MOD_ID"

  # Use curl to get the page
  PAGE_CONTENT=$(curl -s "$URL")

  # Extract the mod name from the page content
  MOD_NAME=$(echo "$PAGE_CONTENT" | grep -oP '<div class="workshopItemTitle">\K[^<]+')

  if [ -z "$MOD_NAME" ]; then
    echo -e "\nCould not extract mod name for mod ID $MOD_ID"
    echo "URL: $URL"
    MOD_NAME="Unknown"
  fi

  # Store in the mapping
  ModIDToModName["$MOD_ID"]="$MOD_NAME"
done

echo -e "\nCompleted retrieving mod names."

# Step 4: Output the mappings as an SQF array file

OUTPUT_FILE="cfgpatches_mappings.sqf"
echo "Writing mappings to $OUTPUT_FILE..."

# Start the SQF array
echo "[" > "$OUTPUT_FILE"

FIRST_ENTRY=true

for CfgEntry in "${CfgPatchesList[@]}"; do
  mod_ids="${CfgPatchesToModID[$CfgEntry]}"
  if [ -n "$mod_ids" ]; then
    IFS=',' read -ra ids <<< "$mod_ids"
    for id in "${ids[@]}"; do
      id_trimmed=$(echo "$id" | xargs)  # Trim whitespace
      mod_name="${ModIDToModName[$id_trimmed]}"

      # Add a comma before each new array entry except the first
      if [ "$FIRST_ENTRY" = true ]; then
        FIRST_ENTRY=false
      else
        echo "," >> "$OUTPUT_FILE"
      fi

      # Write the entry to the SQF file
      echo "  [\"$CfgEntry\", \"$mod_name\", \"$id_trimmed\"]" >> "$OUTPUT_FILE"
    done
  else
    # If not found in any mod, write with empty mod name and ID
    if [ "$FIRST_ENTRY" = true ]; then
      FIRST_ENTRY=false
    else
      echo "," >> "$OUTPUT_FILE"
    fi
    echo "  [\"$CfgEntry\", \"\", \"\"]" >> "$OUTPUT_FILE"
  fi
done

# End the SQF array
echo -e "\n]" >> "$OUTPUT_FILE"

echo "Mappings have been written to $OUTPUT_FILE."

