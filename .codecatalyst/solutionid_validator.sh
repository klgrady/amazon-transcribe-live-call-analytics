#!/bin/sh

#set -e
#export SOLUTIONID="SO9052"

# Name of the environment variable file
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Name of the environment variable file
ENV_FILE="$SCRIPT_DIR/.env"
echo "ENV_FILE: $ENV_FILE"

# Check if the environment file exists
if [ ! -f "$ENV_FILE" ]; then
    echo "Error: $ENV_FILE file not found."
    exit 1
fi

# Load environment variables from the file
set -a
source "$ENV_FILE"
set +a

echo "grep -nr --exclude-dir='.codecatalyst' "${SOLUTIONID}" ./.."
result=$(grep -nr --exclude-dir='.codecatalyst' "${SOLUTIONID}" ./..)
if [ $? -eq 0 ] 
then
  echo "Solution ID ${SOLUTIONID} found\n"
  echo "$result"
  exit 0
else
  echo "Solution ID ${SOLUTIONID} not found"
  exit 1
fi

export result
