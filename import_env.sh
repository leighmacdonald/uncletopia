#!/usr/bin/env bash
# Auto switch between envs stored in different git branches from a secondary repo
#
# Repo should mirror this repo like so:
#
#     /group_vars/*.yml
#     /host_vars/*.yml
#     /hosts.yml
#
# Usage: ./import_env.sh /path/to/env/repo branch_name

ENV_PATH=$1
BRANCH=$2

function clean_existing() {
  rm -v group_vars/*.yml
  rm -v host_vars/*.yml
  rm -v hosts.yml
}

function check_sanity() {
    if [ ! -d "$1" ]; then
      echo "ENV_PATH does not exist: $1"
      exit 1
    fi

    if [[ -z ${2} ]]; then
        echo "Must set branch name"
        exit 2
    fi

    pushd "$1" || exit 2
    local branch_exists
    branch_exists=$(git branch --list "${2}")
    popd || exit 2

    if [[ -z ${branch_exists} ]]; then
      echo "Branch name $2 does not exists."
      exit 2
    fi
    return 0
}

function switch_branch() {
  pushd "$1" || exit 2
  git checkout "${2}" && git pull || exit 2
  popd || exit 2
}

function load_branch() {
    cp -v "${1}"/hosts.yml .
    cp -v "${1}"/host_vars/*.yml host_vars/
    cp -v "${1}"/group_vars/*.yml group_vars/
}

check_sanity "$ENV_PATH" "$BRANCH" || exit $?
switch_branch "$ENV_PATH" "$BRANCH" || exit $?
clean_existing
load_branch "$ENV_PATH"