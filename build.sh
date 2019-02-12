#!/bin/bash

# set -x

# Path of this script
BASE_PATH="$(dirname "$(realpath "$0")")";

PROGNAME=$(basename $0)

usage() {
    echo "USAGE: ${PROGNAME} [-d Dockerfile] [-r REPOSITORY] [-t TAG]"
    echo ""
    echo " -d | --dockerfile : The Dockerfile to build the base image"
    echo "                     Default: Dockerfile"
    echo " -r | --repository : The repository name to tag the built image with"
    echo "                     Default: dankempster/jenkins-ansible"
    echo " -t | --tag        : The tag for the built image. e.g. 'latest'"
    echo "                     Default: build"
    echo ""
}

errorExit() {
#	----------------------------------------------------------------
#	Function for exit due to fatal program error
#		Accepts 1 argument:
#			string : descriptive error message
#	----------------------------------------------------------------
#
#   Example call of the error_exit function.  Note the inclusion
#   of the LINENO environment variable.  It contains the current
#   line number.
#
#	   error_exit "$LINENO: An error has occurred."
#
    echo "${PROGNAME}: ${1:-"Unknown Error"}" 1>&2
    exit 2
}

usageErrorExit() {
    echo "${PROGNAME}: ${1}" 1>&2
    echo ""
    usage
    exit 1
}

dockerfile=Dockerfile
repoName="dankempster/jenkins-ansible"
tag="build"

while [ "$1" != "" ]; do
    case $1 in
        -d | --docker )
            shift
            dockerfile=$1
            ;;
        -r | --repository )
            shift
            repoName=$1
            ;;
        -h | --help )
            usage
            exit 0
            ;;
        -t | --tag )
			shift
            tag=$1
            ;;
        * )
            usageErrorExit "Unknown argument '${1}'"
    esac
    shift
done

if [ "$repoName" == "" ]; then
    usageErrorExit "Repository name (-r) cannot be empty!"
elif [ "$tag" == "" ]; then
    usageErrorExit "Image tag (-t) cannot be empty!"
fi

baseImage="geerlingguy/docker-debian9-ansible:latest"

docker pull $baseImage
echo ""
bash ${BASE_PATH}/bin/docker-playbook.sh \
    -d $dockerfile \
    -c /lib/systemd/systemd \
    -p 8080 \
    -p 50000 \
    -v /sys/fs/cgroup:/sys/fs/cgroup:ro \
    -t "${repoName}:${tag}"
