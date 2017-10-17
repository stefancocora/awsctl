#!/usr/bin/env bash

NAME='awsgocli'
CWD="${GOPATH}"'/src/github.com/stefancocora/'"${NAME}"
cd $CWD

# echo $PATH
echo "--- start build"
date

GITCOMMIT=${GIT_COMMIT:-$(git rev-parse --short HEAD)}
# GIT_COMMIT=${GIT_COMMIT:0:7}
if [[ -n "`git status --porcelain`" ]]
then
  GIT_DIRTY="+UNCOMMITEDCHANGES"
else
  GIT_DIRTY=""
fi

# check if the go tools are installed, install them otherwise
go tool vet 2>/dev/null
if [ $$? -eq 3 ];
then
  go get golang.org/x/tools/cmd/vet
fi
godep -h 2>/dev/null
if [ $$? -eq 3 ];
then
  go get github.com/tools/godep
fi

CMD_LINT="golint ./..."
CMD_GOTEST="godep go test -v --cover --coverprofile testcoverageprofile.out"
CMD_CLEAN="go clean -i -r"
# VETARGS taken from https://github.com/UKHomeOffice/s3secrets/blob/master/Makefile
VETARGS="-asmdecl -atomic -bool -buildtags -copylocks -methods -nilfunc -printf -rangeloops -shift -structtags -unsafeptr"
CMD_VET="go tool vet -v $(VETARGS) *.go"
CMD_GODEP="godep save"
# quotes in bash are a mess
# http://stackoverflow.com/questions/13799789/expansion-of-variable-inside-single-quotes-in-a-command-in-bash-shell-script
if [[ GIT_DIRTY != "" ]]
then
  LDFLAGS="-X main.GitCommit=${GITCOMMIT}${GIT_DIRTY}"
else
  LDFLAGS="-X main.GitCommit=${GITCOMMIT}"
fi
CMD_INSTALL='go install -ldflags "'"${LDFLAGS}"'" ./...'
clear
echo "build: vendoring dependencies - ${CMD_GODEP}"
eval ${CMD_GODEP}
printf "\nbuild: unitesting - ${CMD_GOTEST}\n"
# go test -v --cover --coverprofile testcoverageprofile.out
eval ${CMD_GOTEST}
if [[ $? -eq 0 ]];
then
  # goling doesn't have a flag to ignore the vendor/ dir
  printf "\nbuild: linting code - ${CMD_LINT}\n"
  if [[ -d vendor ]];
  then
    mv vendor _vendor
    eval ${CMD_LINT}
    mv _vendor vendor
  fi
  printf "\nbuild: vet-ing code - ${CMD_VET}\n\n"
  eval ${CMD_VET}
  printf "\nbuild: cleaning previous binary and object files - ${CMD_CLEAN}"
  go clean -i -r
  printf "\nbuild: installing current binary and object files - ${CMD_INSTALL}\n"
  go install -ldflags "${LDFLAGS}" ./...
  # for a proper semver release for public consumption build it without a GITCOMMIT at all, so that it comes out like this (code automatically takes out the -dev part)
  # go clean -i -r
  # go install ./...
  # $0 --version
  # $0 v0.0.1
  date
  echo "--- done build"
else
  date
  echo "--- exception in build - something failed during testing or during compilation"
  exit 1
fi
