#!/bin/bash

set -e

################################################################################
# init
################################################################################
BASEDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
WORKDIR=$BASEDIR/.work
ARCH=${ARCH:-arm}
WEAVE_VERSION="v1.7.2"

wka:init() {
  mkdir -p $WORKDIR
}

wka:host_arch() {
  local host_os
  local host_arch
  case "$(uname -s)" in
    Linux)
      host_os=linux;;
    *)
      wka:log "unsupported host OS, must be linux.";;
  esac

  case "$(uname -m)" in
    x86_64*)
      host_arch=amd64;;
    i?86_64*)
      host_arch=amd64;;
    amd64*)
      host_arch=amd64;;
    aarch64*)
      host_arch=arm64;;
    arm64*)
      host_arch=arm64;;
    arm*)
      host_arch=arm;;
    ppc64le*)
      host_arch=ppc64le;;
    *)
      wka:log "unsupported host arch, must be x86_64, arm, arm64 or ppc64le.";;
  esac
  echo "$host_arch"
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
  git -C $WORKDIR/$1 checkout $WEAVE_VERSION
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

wka:fix_goarch() {
  host_arch=$(wka:host_arch)
  for i in $( grep -r -l "GOARCH=amd64" $WORKDIR ); do
    wka:log "replacing GOARCH in $i"
    sed -i "s;GOARCH=amd64;GOARCH=$host_arch;" "${i}"
  done
}

wka:sanity_check() {
  set +e
  wka:log "sanity check"
  wka:log "host arch: $(wka:host_arch)"
  grep -r -E "weaveworks/(weave|weaveexec|weavedb|weavebuild|weave-kube|weave-npc):" $WORKDIR
  grep -r -E "(DOCKERHUB_USER|DH_ORG)(=|:-|^(=$))" $WORKDIR
  grep -r "FROM.*weaveworks/" $WORKDIR
  grep -r "GOARCH=amd64" $WORKDIR
  set -e
}

wka:delete_images() {
  set +e
  docker rmi `docker images -q kodbasen/weave-kube§:latest` > /dev/null 2>&1
  docker rmi `docker images -q kodbasen/weave-npc:latest` > /dev/null 2>&1
  docker rmi `docker images -q kodbasen/weave:latest` > /dev/null 2>&1
  docker rmi `docker images -q kodbasen/plugin:latest` > /dev/null 2>&1
  docker rmi `docker images -q kodbasen/weavedb:latest` > /dev/null 2>&1
  docker rmi `docker images -q kodbasen/weaveexec:latest` > /dev/null 2>&1
  docker rmi `docker images -q kodbasen/weavebuild:latest` > /dev/null 2>&1
  set -e
}

wka:build_weave-kube() {
  wka:log "starting building weave-kube..."
  cd ${WORKDIR}/weave-kube
  ${WORKDIR}/weave-kube/build.sh
  cd ${BASEDIR}
  wka:log "done building weave-kube..."
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
wka:fix_goarch

wka:sanity_check

wka:log "starting building weave..."
make -C ${WORKDIR}/weave
GOPATH=${WORKDIR}/weave-npc make -C ${WORKDIR}/weave-npc image
#wka:build_weave-kube
