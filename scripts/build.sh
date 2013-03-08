#!/bin/bash

# Copyright (c) 2013 Hewlett-Packard Development Company, L.P.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Uncomment line below for debugging
#set -x

# We assume that script is inside scripts subfolder of build project
# and forge pathes based on that
CALLDIR=${PWD}
SCRIPTDIR=`dirname $0`
# Now let's ensure that:
pushd ${SCRIPTDIR} > /dev/null
if [ `ls ../ | grep -c scripts` -lt 1 ]
    then echo "Make sure that `basename $0` is in scripts folder of project"
    popd
    exit 1
fi
popd > /dev/null

cd ${SCRIPTDIR}
cd ..
# Has mcf been ran and generated a makefile?
test -f Makefile || echo "Make sure that mcf has been run and Makefile is generated" && exit 2

function showusage {
  echo "Usage: `basename $0`
               -p, --buildhistory-path  Path to buildhistory directory with information for our image
               -h, --help               Print this help message
               -N, --build-number       Build number. This will be calculated from git if not given.
               -u, --scp-url            scp will use this path to download and update \${URL}/latest_project_baselines.txt
                                        and also \${URL}/history will be populated"
  exit 3
}

# We need at least buildhistory path with an argument
if [ $# -lt 2 ] ; then showusage ; fi

TEMP=`getopt -o p:hN:u: --long buildhistory-path:,help,build-number:,scp-url: \
    -n $(basename $0) -- "$@"`

if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi


# Note the quotes around `$TEMP': they are essential!
eval set -- "$TEMP"

while true ; do
    case $1 in
        -p|--buildhistory-path) BUILDHISTORY_PATH="$2" ; shift 2 ;;
        -h|--help) showusage ; shift ;;
        -N|--build-number) BN="$2" ; shift 2 ;;
        -u|--scp-url) URL="$2" ; shift 2 ;;
        --) shift ; break ;;
        *) echo $2 ; showusage ;;
    esac
done

# Remaining arguments - probably can be used?
#for arg do echo '--> '"\`$arg'" ; done

if test -z $BN ; then
    BUILD_COMMIT=`git show -1 | head -n 1 | cut -f 2 -d " "`
    BUILD_NUMBER=`git rev-list ${BUILD_COMMIT} | wc -l`
else
    BUILD_NUMBER=$BN
fi
BUILDHISTORY_INSTALLED_PACKAGES="${BUILDHISTORY_PATH}/installed-packages.txt"
BUILDHISTORY_BUILD_ID="${BUILDHISTORY_PATH}/build-id"


# Now real action is done:
make

if [ ! -d "${BUILDHISTORY_PATH}" ] ; then
  echo "buildhistory_path '${BUILDHISTORY_PATH}' is not directory"
  exit 2
fi
if [ ! -e "${BUILDHISTORY_INSTALLED_PACKAGES}" ] ; then
  echo "installed-packages.txt does not exist in buildhistory_path '${BUILDHISTORY_INSTALLED_PACKAGES}'"
  exit 2
fi
if [ ! -e "${BUILDHISTORY_BUILD_ID}" ] ; then
  echo "build-id does not exist in buildhistory_path '${BUILDHISTORY_BUILD_ID}'"
  exit 2
fi

# Copy build-id to .txt for browser to show it as text/plain instead of downloading it
cp -v ${BUILDHISTORY_BUILD_ID} ${BUILDHISTORY_BUILD_ID}.txt

command \
  meta-webos/scripts/build-changes/update_build_changes.sh \
    "${BN}" \
    "${URL}" 2>&1 || printf "\nChangelog generation failed or script not found.\nPlease check lines above for errors\n"

cd ${CALLDIR}

# vim: ts=4 sts=4 sw=4 et
