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
  wka:log "replacing images in $1"
  for i in $( grep -r -l --include=Dockerfile "FROM $2" $1 ); do
    #wka:replace_image $i $2 $3
    sed -i "s;^FROM ${2};FROM ${3};" "${i}"
  done
}

wka:replace_dockerhub_user_in_files() {
  wka:log "replacing DOCKERHUB_USER in $1"
  for i in $( grep -r -l --include=Makefile --include=weave --include=release "DOCKERHUB_USER" $1 ); do
    #wka:replace_image $i $2 $3
    sed -i "s;DOCKERHUB_USER=${2};DOCKERHUB_USER=${3};" "${i}"
    sed -i "s;DOCKERHUB_USER:-${2};DOCKERHUB_USER:-${3};" "${i}"
  done
}

# Remove
wka:replace_image() {
  #wka:log "sed" "s;^FROM ${2};FROM ${3};" "${1}"
  sed -i "s;^FROM ${2};FROM ${3};" "${1}"
}

wka:remove_race() {
  wka:log "remove race parameter"
  for i in $( grep -r -l "\-race" $WORKDIR ); do
    echo $i
    sed -i "s;-race;;" "${i}"
  done
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
wka:replace_dockerhub_user_in_files ${WORKDIR} "weaveworks" "kodbasen"
wka:list_images
wka:remove_race
#wka:grep ${WORKDIR}/weave-kube
#wka:grep ${WORKDIR}/weave-npc
#wka:patch_weave
