#!/bin/sh

echo "User Name: $1"
echo "User Email: $2"
echo "User ID: $3"
echo "PAT: $4"

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

if [ $# -ne 4 ]; then
  echo "Expected 4 arguments 'User Name', 'User Email', 'User Id', 'token'"
  exit 1   
fi

USER_NAME=$1
USER_EMAIL=$2
CLEAN_DIR="clean"
USER_ID=$3
PAT=$4

repo_path=$(pwd)
echo "Repo Path: $repo_path"
pwd
cd ..
pwd
sudo yum -y install rsync
if [ -d "$CLEAN_DIR" ]; then
  echo "Clean existing directory"
  cd clean
  rm -rf $GITHUB_PARENT_REPO_NAME 
else
  echo "Create new directory"
  mkdir clean
  cd clean
fi
echo "git clone https://github.com/$GITHUB_PARENT_USER/$GITHUB_PARENT_REPO_NAME.git"
git clone https://github.com/$GITHUB_PARENT_USER/$GITHUB_PARENT_REPO_NAME.git
echo "Folder of clean parent repo: $(pwd)"
echo "cd $repo_path"
cd $repo_path
echo "Folder of cloned repo: $(pwd)"
#echo "rsync -aq --exclude '.codecatalyst/*.yaml' --exclude '.git' ./../clean/$GITHUB_PARENT_REPO_NAME/* ."
#echo "rsync -av --exclude='.git/' --exclude='.codecatalyst/**/*.yaml' --exclude='.codecatalyst/*.yaml' ./../clean/$GITHUB_PARENT_REPO_NAME/ ."
echo "rsync -av --exclude='.git/' --exclude='.codecatalyst/' ./../clean/$GITHUB_PARENT_REPO_NAME/ ."
#rsync -aq --exclude '.codecatalyst/*.yaml' --exclude '.git' ./../clean/$GITHUB_PARENT_REPO_NAME/* .
#rsync -av --exclude='.git/' --exclude='.codecatalyst/**/*.yaml' --exclude='.codecatalyst/*.yaml' ./../clean/$GITHUB_PARENT_REPO_NAME/ .
rsync -av --exclude='.git/' --exclude='.codecatalyst/' ./../clean/$GITHUB_PARENT_REPO_NAME/ .
first_commit_time=$(date --date "$(git show -s --format=%cI $(git rev-list --max-parents=0 HEAD))" +"%s")
echo "First Commit Time: $first_commit_time"
current_time=$(date --date "$(date)" +"%s")
echo "Current Time: $current_time"
time_diff=$((current_time - $first_commit_time))
echo "Time Difference: $time_diff"
if [ $time_diff > 300 ]; then
  git diff-index --quiet HEAD --
  if [ $? -eq 1 ]; then
    echo "Code changes detected"
    git diff-index HEAD --
    echo "Git remotes"
    git remote -v
    git config --global user.email "$USER_EMAIL"
    git config --global user.name "$USER_NAME"
    git add .
    git commit -m "Updated from parent https://github.com/$GITHUB_PARENT_USER/$GITHUB_PARENT_REPO_NAME.git"
    git branch temp-branch
    git checkout main
    git merge -X theirs temp-branch
    echo "Before Push"
    remote_url=$(git config --get remote.origin.url)
    echo "Remote URL: $remote_url"
    repo_without_protocol="${remote_url#https://}"
    echo "Remote URL without protocol: $repo_without_protocol"
    echo "git push --repo https://$USER_ID:$PAT@$repo_without_protocol"
    git push --repo https://$USER_ID:$PAT@$repo_without_protocol
    echo "After push"
  else
    echo "No code changes"
  fi
else
  echo "Ignore merge in new repo - Assuming the first commit time of the new repo will be less than 5 minutes."
fi

