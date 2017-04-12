#!/bin/bash

# Copyright 2017 Jelastic, Inc.

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

# http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

include os, output;

function _clearCache(){
        if [[ -d "$DOWNLOADS" ]]
        then
                shopt -s dotglob;
                rm -Rf ${DOWNLOADS}/*;
                shopt -u dotglob;
        fi
}

function _deploy(){
    local crt_control="/opt/repo/bin/control";
    if [[ -z "$package_url" || -z "$context" ]]
    then
        echo "Wrong arguments for deploy" 1>&2;
        exit 1;
    fi
    _clearCache;
    ensureFileCanBeDownloaded $package_url;
    $WGET --no-check-certificate --content-disposition --directory-prefix=${DOWNLOADS} $package_url >> $ACTIONS_LOG 2>&1 || { writeJSONResponseErr "result=>4078" "message=>Error loading file from URL"; die -q; }
    package_name=`ls ${DOWNLOADS}`;

    [ ! -s "$DOWNLOADS/$package_name" ] && {
        rm -f ${DOWNLOADS}/${package_name};
        writeJSONResponseErr "result=>4078" "message=>Error loading file from URL";
        die -q;
    }

    stopService ${SERVICE} > /dev/null 2>&1;
    rm -rf ${WEBROOT}/*

    unzip  -Z1 ${DOWNLOADS}/${package_name} |  grep -q "META-INF/MANIFEST.MF" && {
    cp  ${DOWNLOADS}/${package_name} ${WEBROOT}/${package_name}; } ||  local jar_entry=$(unzip  -Z1 ${DOWNLOADS}/${package_name}   | grep ".jar\|.war\.ear" | head -1 );
        [ ! -z $jar_entry ]  && {
        unzip -o "$DOWNLOADS/$package_name" -d "${WEBROOT}" 2>>$ACTIONS_LOG 1>/dev/null || writeJSONResponseErr "result=>4060" "message=>Application deployed with error";
    }
    _clearCache;
    chown -R 700:700 "${WEBROOT}"
    chown -R 700:700 "/opt/repo/logs"
    startService ${SERVICE} > /dev/null 2>&1;
    writeJSONResponseOut "result=>0" "message=>Application deployed succesfully";
    echo
}

function _undeploy(){
#    if [[ -z "$context" ]]
#    then
#        echo "Wrong arguments for undeploy" 1>&2
#        exit 1
#    fi

    stopService ${SERVICE} > /dev/null 2>&1;

    [ ! -z "${WEBROOT}" ] && rm -rf ${WEBROOT}/* && { writeJSONResponseOut  "result=>0" "message=>Application undeployed succesfully";  exit 0 ;}  || { writeJSONResponseErr "result=>4060" "message=>Undeploy failed"; exit 1; }

}

function describeDeploy(){
    echo "deploy java application \n\t\t -p \t <package URL> \n\t\t -c
\t <context> \n\t\t ";
}

function describeUndeploy(){
    echo "undeploy java application \n\t\t -c \t <context>";
}

function describeRename(){
    echo "rename java context \n\t\t -n \t <new context> \n\t\t -o \t
<old context>\n\t\t";
}
