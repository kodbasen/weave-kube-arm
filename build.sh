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
  echo "+++ wka $timestamp $1"
  shift
  for message; do
    echo "    $message"
  done
}

wka:clone() {
  if [ -d "$WORKDIR/$1" ]; then
    return
  fi
  wka:log "cloning $1"
  git clone https://github.com/weaveworks/$1 $WORKDIR/$1
}

wka:replace_image_in_files() {
  for i in $( grep -r -l --include=Dockerfile "FROM $1" $WORKDIR ); do
    wka:log "replacing image in Dockerfile $i"
    sed -i "s;^FROM ${1};FROM ${2};" "${i}"
  done
}

wka:replace_dockerhub_user_in_files() {
  for i in $( grep -r -l -E "(DOCKERHUB_USER|DH_ORG)(=|:-|^(=$))" $WORKDIR ); do
    wka:log "replacing DOCKERHUB_USER in $i"
    sed -i "s;DOCKERHUB_USER=weaveworks;DOCKERHUB_USER=kodbasen;" "${i}"
    sed -i "s;DH_ORG=weaveworks;DH_ORG=kodbasen;" "${i}"
    sed -i "s;DOCKERHUB_USER:-weaveworks;DOCKERHUB_USER:-kodbasen;" "${i}"
  done
}

wka:replace_image_in_shell_files() {
  for i in $( grep -r -l -E "weaveworks/(weave|weaveexec|weavedb|weavebuild|weave-kube|weave-npc):" $WORKDIR ); do
    wka:log "replacing images in shell file $i"
    sed -i "s;weaveworks/weave:;kodbasen/weave:;" "${i}"
    sed -i "s;weaveworks/weaveexec:;kodbasen/weaveexec:;" "${i}"
    sed -i "s;weaveworks/weavedb:;kodbasen/weavedb:;" "${i}"
    sed -i "s;weaveworks/weavebuild:;kodbasen/weavebuild:;" "${i}"
    sed -i "s;weaveworks/weave-kube:;kodbasen/weave-kube:;" "${i}"
    sed -i "s;weaveworks/weave-npc:;kodbasen/weave-npc:;" "${i}"
  done
}

wka:replace_docker_dist_url_in_files() {
  for i in $( grep -r -l --include=Makefile "builds/Linux/x86_64" $WORKDIR ); do
    wka:log "replacing docker dist url in $i"
    sed -i "s;https://get.docker.com/builds/Linux/x86_64/docker-\$(WEAVEEXEC_DOCKER_VERSION).tgz;https://github.com/kodbasen/weave-kube-arm/releases/download/v0.1/docker-1.8.2.tgz;" "${i}"
  done
}

wka:remove_race() {
  for i in $( grep -r -l "\-race" $WORKDIR ); do
    wka:log "removing golang:s -race parameter (not supported on ARM) in $i"
    sed -i "s;-race;;" "${i}"
  done
}

wka:sanity_check() {
  grep -r -E "weaveworks/(weave|weaveexec|weavedb|weavebuild|weave-kube|weave-npc):" $WORKDIR
  grep -r -E "(DOCKERHUB_USER|DH_ORG)(=|:-|^(=$))" $WORKDIR
  grep -r "FROM.*weaveworks/" $WORKDIR
}

wka:delete_images() {
  docker rmi `docker images -q kodbasen/weave:latest`
  docker rmi `docker images -q kodbasen/plugin:latest`
  docker rmi `docker images -q kodbasen/weaveexec:latest`
  docker rmi `docker images -q kodbasen/weavedb:latest`
  docker rmi `docker images -q kodbasen/weavebuild:latest`
}

wka:build_weave-kube() {
  cd ${WORKDIR}/weave-kube
  ${WORKDIR}/weave-kube/build.sh
  cd ${WORKDIR}
}

wka:init
#wka:delete_images
wka:clone "weave"
wka:clone "weave-kube"
wka:clone "weave-npc"
wka:replace_image_in_files "golang:1.5.2" "armhfbuild/golang:1.5.3"
wka:replace_image_in_files "weaveworks" "kodbasen"
wka:replace_image_in_files "alpine" "armhfbuild/alpine"
wka:replace_dockerhub_user_in_files
wka:replace_image_in_shell_files
wka:replace_docker_dist_url_in_files
wka:remove_race

wka:sanity_check


#make -C ${WORKDIR}/weave
#make -C ${WORKDIR}/weave-npc
#wka:build_weave-kube
