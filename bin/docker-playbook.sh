#!/bin/bash

set -x

PROGNAME=$(basename $0)

usage() {
    echo "USAGE: ${PROGNAME} [OPTIONS] -t REPOSITORY[:TAG]"
    echo ""
    echo "Options:"
    echo ""
    echo "  -a | --playbook PLAYBOOK           : The Ansible playbook.yml file to run.  "
    echo "                                       Default: playbook.yml                  "
    echo "  -b | --base-image REPOSITORY[:TAG] : The docker image to use as the base for"
    echo "                                       for the build.                         "
    echo "  -c | --target-cmd COMMAND          : The CMD for the target image.          "
    echo "  -d | --dockerfile DOCKERFILE       : The Dockerfile to use to build the base"
    echo "                                       image to build the target image.       "
    echo "                                       Default: Dockerfile                    "
    echo "  -e | --target-entrypoint ENTRYPOINT: The CMD for the built image.           "
    echo "  -p | --port PORT                   : A port to expose on the target image.  "
    echo "                                       Use multiple times to exopse multiple. "
    echo "                                       ports.                                 "
    echo "  -t | --target REPOSITORY[:TAG]     : Tag for the target image being created."
    echo "  -v | --volume PATH                 : The path to mount a volume at in the   "
    echo "                                       target image. Use multiple for multiple"
    echo "                                       volumes."
    echo "  -z | --build-cmd CMD               : The command to use to keep the base    " 
    echo "                                       active while Ansible runs."
    echo "                                       Default: 'bash -i'"
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

baseImage=""
buildCmd="bash -i"
dockerfile=Dockerfile
playbook="playbook.yml"
targetImage=""
targetCmd=""
targetEntrypoint=""

intermediateImage="dockerplaybook:intermediate"

builtBaseImage=0
builtIntermediateImage=0

intermediateId=""
finalId=""

dockerRunArgs=""
dockerCommitArgs=""


cleanUp() {

    if [ "${intermediateId}" != "" ]; then 
        docker rm -v $(docker stop ${intermediateId})
    fi

    if [ "${finalId}" != "" ]; then 
        docker rm -v $(docker stop ${finalId})
    fi
    
    if [ $builtIntermediateImage -eq 1 ]; then
        docker rmi ${intermediateImage}
    fi
    
    if [ $builtBaseImage -eq 1 ]; then
        docker rmi ${baseImage}
    fi
}

cleanUpTrap() {
	echo ""
	echo ""
	echo ""
	echo "Recieved signal. Cleaning up ..."
	echo ""
	cleanUp
	exit 1
}

buildBaseImage() {
    baseImage="dockerplaybook:base_image"

    docker build -f ${dockerfile} . -t ${baseImage}
    builtBaseImage=1
}

buildIntermediateImage() {  
    
    intermediateId=$(docker run -dt -v $(pwd):/project${dockerRunArgs} ${baseImage} ${buildCmd})

    echo "Running ansible-playbook in intermediate container ${intermediateId}"

    # Run the playbook
    docker exec -t -w /project ${intermediateId} ansible-playbook ${playbook}

    # Create the image from the container
    echo "Creating intermediate image from container ${intermediateId}"
    docker stop ${intermediateId}
    docker commit -p ${intermediateId} $intermediateImage
    builtIntermediateImage=1

    # Clean up
    docker rm ${intermediateId}
    intermediateId=""
}

buildFinalImage() {
    
    if [ "${targetEntrypoint}" != "" ]; then
        dockerRunArgs="--entrypoint ${targetEntrypoint} ${dockerRunArgs}"
    fi

    echo "Creating ${targetImage} from intermediate image"
    finalId=$(docker run${dockerRunArgs} -d ${intermediateImage} ${targetCmd})

    # Create the image from the container
    echo docker commit -p ${finalId} $dockerCommitArgs ${targetImage}
    docker commit -p ${finalId} $dockerCommitArgs ${targetImage}
}

if [ $# -eq 0 ]; then
    echo "ERROR: Missing arguments" 1>&2
    usage
    exit 1
fi

while [ "$1" != "" ]; do
    case $1 in
        -a | --playbook )
            shift
            playbook=$1
            ;;
        -b | --base | --base-image )
            shift
            baseImage=$1
            ;;
        -c | --target-cmd )
            shift
            targetCmd=$1
            ;;
        -d | --dockerfile )
            shift
            dockerfile=$1
            ;;
        -e | --target-entrypoint )
            shift
            targetEntrypoint=$1
            ;;
        -g | --change )
            shift
            dockerCommitArgs="${dockerCommitArgs} --change='${1}'"
            ;;
        -h | --help )
            usage
            exit 0
            ;;
        -p | --port )
            shift
            dockerRunArgs="${dockerRunArgs} -p ${1}"
            ;;
        -t | --target )
            shift
            targetImage=$1
            ;;
        -v | --volume )
            shift
            dockerRunArgs="${dockerRunArgs} -v ${1}"
            ;;
        -z | --build-cmd )
            shift
            buildCmd=$1
            ;;
        * )
            usageErrorExit "Unknown option '${1}'"
    esac
    shift
done

if [ "${targetImage}" == "" ]; then
    usageErrorExit "Missing --target-image option"
fi

# if we received one of these signals, Clean up before terminating the script
trap "cleanUpTrap" SIGHUP SIGINT SIGTERM


# Build
if [ "${baseImage}" == "" ]; then
    buildBaseImage
    echo ""
fi
buildIntermediateImage
echo ""
buildFinalImage
echo ""


# Clean up
echo "Cleaning up"
echo ""
cleanUp


echo ""
echo "Ready! To run your new image:"
echo ""
echo "    $ docker run${dockerRunArgs} ${targetImage}"
echo ""
