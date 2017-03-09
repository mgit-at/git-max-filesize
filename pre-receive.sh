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

    # check for new branches
    local target="${oldref}..${newref}"
    if [[ "$oldref" == "$NULLSHA" ]]; then
      # try to find an existing ancestor
      local fp
      fp="$(find_ancestor "$newref")"
      if [[ "$?" == 0 ]]; then
        # use the existing ancestor as base
        target="${fp}..${newref}"
      else
        # otherwise check all objects in that branch
        target="${newref}"
      fi
    fi

    # find large objects
    local large_files
    large_files="$(git rev-list --objects "$target" | \
      git cat-file --batch-check='%(objectname) %(objecttype) %(objectsize) %(rest)' | \
      awk -v maxbytes="$maxsize" '$3 > maxbytes { print $4 }')"
    if [[ "$?" != 0 ]]; then
      echo "failed to check for large files in ref ${refname}"
      continue
    fi

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
  done

  exit "$status"
}

# find a suitable ancestor to decide which objects to check
function find_ancestor() {
  local newref="$1"

  # query all existing references
  local refs
  refs="$(git show-ref --heads -s)"
  if [[ "$?" != 0 ]]; then
    return "$EXIT_FAILURE"
  fi

  # check existing references for possible fork points
  local fps=""
  local ref
  for ref in $refs; do
    local fp
    fp="$(git merge-base "$ref" "$newref")"
    if [[ "$?" != 0 ]]; then
      continue
    fi

    # update / replace existing fork points
    local other
    for other in $fps; do
      local rval
      git merge-base --is-ancestor "$fp" "$other"
      rval="$?"
      if [[ "$rval" == 0 ]]; then
        # skip if current fork point is an ancestor
        continue 2
      elif [[ "$rval" == 1 ]]; then
        # replace if current fork point is a successor
        fps="$(echo ${fps/$other} ${fp})"
        continue 2
      else
        # ignore errors
        :
      fi
    done

    # add fork point
    fps="$(echo ${fps} ${fp})"
  done

  # select first fork point
  # in the very rare case that multiple fork points are found that are not
  # related to each other, simple choose the first one as a starting point.
  if [[ -z "$fps" ]]; then
    return "$EXIT_FAILURE"
  fi
  printf "%s\n" $fps | head -n 1
  return "$EXIT_SUCCESS"
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
