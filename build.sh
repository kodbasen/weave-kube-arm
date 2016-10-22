#!/bin/bash

set -e

################################################################################
# init
################################################################################
BASEDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
WORKDIR=$BASEDIR/.work

wka:init() {
  mkdir -p $WORKDIR
}

wka:log() {
  timestamp=$(date +"[%m%d %H:%M:%S]")
  echo "+++ $timestamp $1"
  shift
  for message; do
    echo "    $message"
  done
}

wka:clone() {
  if [ -d "$WORKDIR/$1" ]; then
    return
  fi
  echo "cloning $1"
  git clone https://github.com/weaveworks/weave $WORKDIR/$1
}

wka:grep() {
  wka:log "grep images in $1"
  grep -r --include=Dockerfile "FROM" $1
}

wka:patch_files() {
  wka:log "patching files in $1"
  for i in $( grep -r -l --include=Dockerfile "FROM $2" $1 ); do
    wka:replace $i $2 $3
  done
}

wka:grep_files() {
  wka:log "grep images in $WORKDIR"
  grep -r --include=Dockerfile "FROM" $WORKDIR
}

wka:replace() {
  wka:log "s;^FROM ${2};FROM ${3};" "${1}"
  sed -i "s;^FROM ${2};FROM ${3};" "${1}"
}

wka:patch_weave() {
  sed -i "s;^FROM golang;FROM armhfbuild/golang;" "${WORKDIR}/weave/build/Dockerfile"
  sed -i "s;^FROM weaveworks/weaveexec;FROM kodbasen/weaveexec;" "${WORKDIR}/weave/prog/plugin/Dockerfile"
  sed -i "s;^FROM alpine;FROM armhfbuild/alpine;" "${WORKDIR}/weave/prog/weaveexec/Dockerfile"
}

wka:init
wka:clone "weave"
wka:clone "weave-kube"
wka:clone "weave-npc"
wka:patch_files ${WORKDIR} "golang:1.5.2" "armhfbuild/golang:1.5.3"
wka:patch_files ${WORKDIR} "weaveworks" "kodbasen"
wka:patch_files ${WORKDIR} "alpine" "armhfbuild/alpine"
wka:grep_files
#wka:grep ${WORKDIR}/weave-kube
#wka:grep ${WORKDIR}/weave-npc
#wka:patch_weave
