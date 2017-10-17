#!/usr/bin/env bash

PROJECT_NAME=`grep "ELF_NAME =" Makefile | awk '{print $3}'`
NAME=${PROJECT_NAME}
CWD="${GOPATH}"'/src/github.com/stefancocora/'"${NAME}"
cd $CWD || exit 1

DEBUG=$3
ACTION=$4
GITCOMMIT=${GIT_COMMIT:-$(git rev-parse --short HEAD)}
GITBRANCH=$(git rev-parse --abbrev-ref HEAD)
GITCOMMIT_AND_DIRTY=""
ELF_VERSIONED=""
BUILDRUNTIME=$(go version | awk '{print $3}')
BUILDUSER="$USER"'@'$(hostname)
BUILDDATE=$(date +%Y%m%d-%H:%M:%S)
# APPENVIRONMENT shold be local for development of production for releasing to supported platform environments
# like acceptance/testing/preprod/prod
# based on APPENVIRONMENT=local/production some settings should change in code
# like log formattting(remove debugging for production releases)
# versioning ( removed -dev , proper semver versioning)
#
# a production build just needs
# util/build.sh production
APPENVIRONMENT=${1}
APPVERSION=${2}

if [[ ${APPVERSION} = "" ]] || [[ ! ${APPVERSION} ]]
then
  echo "I don't know what APPVERSION to build, please pass the APPVERSION ..."
  exit 1
fi

function usage {
  echo ""
  echo "$0 <appenvironment>"
  echo ""
  echo "Example:"
  printf "\n$0 dev                 # will build the dev appenvironment\n"
  printf "\n$0 production          # will build the production appenvironment\n"
  echo ""
}

# gotools checks for the existence of the required go tools, otherwise installs them with go get
function gotools {
    clear
    date
    printf "\n=== gotools: verifying required go tools\n"

    # check if the go tools are installed, install them otherwise
    go tool vet 2>/dev/null
    if [[ $? -eq 3 ]]
    then
        go get -v -u golang.org/x/tools/cmd/vet
    fi

    # migrated to dep
    dep -h 2>/dev/null
    if [[ $? -eq 3 ]]
    then
        go get -v -u github.com/golang/dep/cmd/dep
    fi
}

# unit runs unit tests
function unit {
    clear
    date
    printf "\n=== start unit\n"

    gotools

    declare -a TEST_SRC
    TEST_SRC=(pkg cmd)
    CMD_GOTEST="go test $(go list ./... ./vendor/... | grep -v vendor) -v -race"

    # printf "\n=== unitesting - ${CMD_GOTEST}\n"
    echo "=== unit: unitesting"
    printf "\n%s\n" "${CMD_GOTEST}"

    # go test -v --cover --coverprofile testcoverageprofile.out
    eval ${CMD_GOTEST}
}

# function used to build the binary
# knows how to build dev and production releases
function build {
  local APPENVIRONMENT=$1
  echo "application environment: ${APPENVIRONMENT}"
  if [[ "${APPENVIRONMENT}" = "production" ]]
  then
      local APPVERSIONPRERELEASE=""
  else
      local APPVERSIONPRERELEASE="dev"
  fi

  clear
  date
  printf "\n=== start build\n"

  # GIT_COMMIT=${GIT_COMMIT:0:7}
  if [[ -n "`git status --porcelain`" ]]
  then
    GIT_DIRTY="+UNCOMMITEDCHANGES"
  else
    GIT_DIRTY=""
  fi

  CMD_LINT="golint $(go list ./... | grep -v vendor)"
  # coverprofile tool cant handle multiple packages at the same time
  # https://github.com/golang/go/issues/6909
  # fix:
  # https://mlafeldt.github.io/blog/test-coverage-in-go/
  # https://github.com/mlafeldt/chef-runner/blob/master/script/coverage
  CMD_COVERPROFILE_HTML="go tool cover -html=testcoverageprofile.out -o testcoverageprofile.html"

  # recursive clean deletes too much
  # http://stackoverflow.com/a/33372718
  # CMD_CLEAN="go clean -i -r"
  CMD_CLEAN="go clean -i"
  # VETARGS taken from https://github.com/UKHomeOffice/s3secrets/blob/master/Makefile
  # VETARGS="-asmdecl -atomic -bool -buildtags -copylocks -methods -nilfunc -printf -rangeloops -shift -structtags -unsafeptr"
  # go tool vet can't find vendored packages
  # https://github.com/golang/go/issues/17571#issuecomment-257977762
  # CMD_VET="go tool vet -v ${VETARGS} *.go"
  CMD_VET="go vet -x ${VETARGS} $(go list ./... | grep -v vendor)"

  # quotes in bash are a mess
  # http://stackoverflow.com/questions/13799789/expansion-of-variable-inside-single-quotes-in-a-command-in-bash-shell-script
  if [[ $GIT_DIRTY != "" ]]
  then
    GITCOMMIT_AND_DIRTY=${GITCOMMIT}${GIT_DIRTY}
    LDFLAGS="
            -s -w
            -X github.com/stefancocora/${PROJECT_NAME}/pkg/version.GitCommit=${GITCOMMIT_AND_DIRTY} \
            -X github.com/stefancocora/${PROJECT_NAME}/pkg/version.Gitbranch=${GITBRANCH} \
            -X github.com/stefancocora/${PROJECT_NAME}/pkg/version.Buildruntime=${BUILDRUNTIME} \
            -X github.com/stefancocora/${PROJECT_NAME}/pkg/version.Gitbuilduser=${BUILDUSER} \
            -X github.com/stefancocora/${PROJECT_NAME}/pkg/version.Gitbuilddate=${BUILDDATE} \
            -X github.com/stefancocora/${PROJECT_NAME}/pkg/version.AppEnvironment=${APPENVIRONMENT} \
            -X github.com/stefancocora/${PROJECT_NAME}/pkg/version.VersionPrerelease=${APPVERSIONPRERELEASE} \
            -X github.com/stefancocora/${PROJECT_NAME}/pkg/version.Version=${APPVERSION}
    "
  else
    GITCOMMIT_AND_DIRTY=${GITCOMMIT}
    LDFLAGS="
            -s -w
            -X github.com/stefancocora/${PROJECT_NAME}/pkg/version.GitCommit=${GITCOMMIT_AND_DIRTY} \
            -X github.com/stefancocora/${PROJECT_NAME}/pkg/version.Gitbranch=${GITBRANCH} \
            -X github.com/stefancocora/${PROJECT_NAME}/pkg/version.Buildruntime=${BUILDRUNTIME} \
            -X github.com/stefancocora/${PROJECT_NAME}/pkg/version.Gitbuilduser=${BUILDUSER} \
            -X github.com/stefancocora/${PROJECT_NAME}/pkg/version.Gitbuilddate=${BUILDDATE} \
            -X github.com/stefancocora/${PROJECT_NAME}/pkg/version.AppEnvironment=${APPENVIRONMENT} \
            -X github.com/stefancocora/${PROJECT_NAME}/pkg/version.VersionPrerelease=${APPVERSIONPRERELEASE} \
            -X github.com/stefancocora/${PROJECT_NAME}/pkg/version.Version=${APPVERSION}
    "
  fi

  if [[ $? -eq 0 ]];
  then
    # goling doesn't have a flag to ignore the vendor/ dir
    printf "\n=== build: linting code - ${CMD_LINT}\n"
    eval ${CMD_LINT}
    # printf "\n=== build: generating test coverage html output - ${CMD_COVERPROFILE_HTML}\n"
    # eval ${CMD_COVERPROFILE_HTML}
    printf "\n=== build: vet-ing code - ${CMD_VET}\n\n"
    eval ${CMD_VET}
    if [[ $? -ne 0 ]];
    then
      date
      echo "=== exception in vet-ing code - something failed during vet-ing"
      exit 1
    fi
    printf "\n=== build: cleaning previous binary and object files - ${CMD_CLEAN}\n"
    # recursive go clean breaks go vet
    # https://github.com/golang/go/issues/19129
    # https://github.com/golang/go/issues/11415
    go clean -i
    # force to statically link when using the net std lib
    # https://golang.org/pkg/net/#hdr-Name_Resolution
    # https://www.osso.nl/blog/golang-statically-linked/

    # changed build to go build instead of go install due to upstream bug
    # https://github.com/golang/go/issues/18981
    printf "\n=== build: building current binary\n"
    export GODEBUG=netdns=go+1
    export CGO_ENABLED=0
    export GOOS="linux"
    export GOARCH="amd64"
    echo "GODEBUG=$GODEBUG"
    echo "CGO_ENABLED=$CGO_ENABLED"
    echo "GOOS=$GOOS"
    echo "GOARCH=$GOARCH"
    # golang linker flags https://golang.org/cmd/link/
    # https://github.com/golang/dep/blob/master/hack/build-all.bash
    go build -a -ldflags "${LDFLAGS}" -o bin/awsctl .
    # for a proper semver release for public consumption build it without a GITCOMMIT at all, so that it comes out like this (code automatically takes out the -dev part)
    # go clean -i -r
    # go install ./...
    # $0 --version
    # $0 v0.0.1
    if [[ $? -ne 0 ]];
    then
      date
      echo "=== error when building code - something failed ..."
      exit 1
    fi

    # copy built binary
    if [[ "${APPENVIRONMENT}" = "production" ]]
    then
        ELF_VERSIONED="${NAME}-${APPVERSION}-${GITCOMMIT_AND_DIRTY}"
    else
        ELF_VERSIONED="${NAME}-${APPVERSION}-${APPVERSIONPRERELEASE}-${GITCOMMIT_AND_DIRTY}"
    fi

    if [[ ! -d "./bin" ]]
    then
        mkdir "./bin"
        cp "bin/${NAME}" "./bin/${ELF_VERSIONED}"
    else
        cp "bin/${NAME}" "./bin/${ELF_VERSIONED}"
    fi

    printf "\n=== build: info about the built binary\n"
    echo ""
    ls -lha "./bin/${ELF_VERSIONED}"
    file "./bin/${ELF_VERSIONED}"
    ldd "./bin/${ELF_VERSIONED}"
    md5sum "./bin/${ELF_VERSIONED}"
    sha256sum "./bin/${ELF_VERSIONED}"
    sha512sum "./bin/${ELF_VERSIONED}"
    echo ""
    date
    echo "=== build done"
  else
    date
    echo "=== exception in build - something failed during testing or during compilation"
    exit 1
  fi
}

case ${APPENVIRONMENT} in
    dev)

    if [[ ${DEBUG} = 'true' ]]
    then
      echo "=== debug mode === "
      echo "appenvironment: ${APPENVIRONMENT}"
      echo "appversion: ${APPVERSION}"
      echo "debug: ${DEBUG}"
      echo "action: ${ACTION}"
    fi
    case ${ACTION} in
        unit)
            unit
            shift
            ;;
        build)
            build "${APPENVIRONMENT}"
            shift
            ;;
        *)
            echo "unknown action"
            usage
            exit 1
            shift
            ;;
    esac
    shift
    ;;
    production)
    if [[ ${DEBUG} = 'true' ]]
    then
      echo "=== debug mode === "
      echo "appenvironment: ${APPENVIRONMENT}"
      echo "appversion: ${APPVERSION}"
      echo "debug: ${DEBUG}"
      echo "action: ${ACTION}"
    fi
    case ${ACTION} in
        unit)
            unit
            shift
            ;;
        build)
            build "${APPENVIRONMENT}"
            shift
            ;;
        *)
            echo "unknown action"
            usage
            exit 1
            shift
            ;;
    esac
    shift
    ;;
    -h)
    usage
    exit 1
    shift
    ;;
    --help)
    usage
    exit 1
    shift
    ;;
    *)
    usage
    exit 1
    shift
    ;;
esac
