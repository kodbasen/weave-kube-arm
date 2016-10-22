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

wka:replace_image_in_files() {
  wka:log "patching files in $1"
  for i in $( grep -r -l --include=Dockerfile "FROM $2" $1 ); do
    wka:replace_image $i $2 $3
  done
}

wka:replace_image() {
  #wka:log "sed" "s;^FROM ${2};FROM ${3};" "${1}"
  sed -i "s;^FROM ${2};FROM ${3};" "${1}"
}

wka:list_images() {
  for i in $( grep -r --include=Dockerfile "FROM" $WORKDIR ); do
    wka:log "$i"
  done
}

wka:init
wka:clone "weave"
wka:clone "weave-kube"
wka:clone "weave-npc"
wka:replace_image_in_files ${WORKDIR} "golang:1.5.2" "armhfbuild/golang:1.5.3"
wka:replace_image_in_files ${WORKDIR} "weaveworks" "kodbasen"
wka:replace_image_in_files ${WORKDIR} "alpine" "armhfbuild/alpine"
wka:list_images
#wka:grep ${WORKDIR}/weave-kube
#wka:grep ${WORKDIR}/weave-npc
#wka:patch_weave
