#!/bin/bash -u
#
# git-max-filesize
#
# git pre-receive hook to reject large files that should be commited
# via git-lfs (large file support) instead.
#
# Author: Christoph Hack <chack@mgit.at>
# Copyright (c) 2017 mgIT GmbH. All rights reserved.
# Distributed under the Apache License. See LICENSE for details.
#
set -o pipefail

readonly DEFAULT_MAXSIZE="5242880" # 5MB
readonly CONFIG_NAME="hooks.maxfilesize"
readonly NULLSHA="0000000000000000000000000000000000000000"
readonly EXIT_SUCCESS="0"
readonly EXIT_FAILURE="1"

# main entry point
function main() {
  local status="$EXIT_SUCCESS"

  # get maximum filesize (from repository-specific config)
  local maxsize
  maxsize="$(get_maxsize)"
  if [[ "$?" != 0 ]]; then
    echo "failed to get ${CONFIG_NAME} from config"
    exit "$EXIT_FAILURE"
  fi

  # skip this hook entirely if maxsize is 0.
  if [[ "$maxsize" == 0 ]]; then
    cat > /dev/null
    exit "$EXIT_SUCCESS"
  fi

  # read lines from stdin (format: "<oldref> <newref> <refname>\n")
  local oldref
  local newref
  local refname
  while read oldref newref refname; do
    # skip branch deletions
    if [[ "$newref" == "$NULLSHA" ]]; then
      continue
    fi

    # find large objects
    # check all objects from $oldref (possible $NULLSHA) to $newref, but
    # skip all objects that have already been accepted (i.e. are referenced by
    # another branch or tag).
    local target
    if [[ "$oldref" == "$NULLSHA" ]]; then
      target="$newref"
    else
      target="${oldref}..${newref}"
    fi
    local large_files
    large_files="$(git rev-list --objects "$target" --not --branches=\* --tags=\* | \
      git cat-file $'--batch-check=%(objectname)\t%(objecttype)\t%(objectsize)\t%(rest)' | \
      awk -F '\t' -v maxbytes="$maxsize" '$3 > maxbytes' | cut -f 4-)"
    if [[ "$?" != 0 ]]; then
      echo "failed to check for large files in ref ${refname}"
      continue
    fi

    IFS=$'\n'
    for file in $large_files; do
      if [[ "$status" == 0 ]]; then
        echo ""
        echo "-------------------------------------------------------------------------"
        echo "Your push was rejected because it contains files larger than $(numfmt --to=iec "$maxsize")."
        echo "Please use https://git-lfs.github.com/ to store larger files."
        echo "-------------------------------------------------------------------------"
        echo ""
        echo "Offending files:"
        status="$EXIT_FAILURE"
      fi
      echo " - ${file} (ref: ${refname})"
    done
    unset IFS
  done

  exit "$status"
}

# get the maximum filesize configured for this repository or the default
# value if no specific option has been set. Suffixes like 5k, 5m, 5g, etc.
# can be used (see git config --int).
function get_maxsize() {
  local value;
  value="$(git config --int "$CONFIG_NAME")"
  if [[ "$?" != 0 ]] || [[ -z "$value" ]]; then
    echo "$DEFAULT_MAXSIZE"
    return "$EXIT_SUCCESS"
  fi
  echo "$value"
  return "$EXIT_SUCCESS"
}

main
