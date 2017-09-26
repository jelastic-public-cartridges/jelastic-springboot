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

# prestart_script="${STACK_PATH}.openshift/action_hooks/pre_start_SpringBoot"

function _clearCache(){
        if [[ -d "$DOWNLOADS" ]]
        then
                shopt -s dotglob;
                rm -Rf ${DOWNLOADS}/*;
                shopt -u dotglob;
        fi
}

function getPackageName() {
    if [ -f "$package_url" ]; then
        package_name="$package_url";
    elif [[ "${package_url}" =~ file://* ]]; then
        package_name="${package_url:7}"
        [ -f "$package_name" ] || { writeJSONResponseErr "result=>4078" "message=>Error loading file from URL"; die -q; }
    else
        ensureFileCanBeDownloaded $package_url;
        $WGET --no-check-certificate --content-disposition --directory-prefix="${DOWNLOADS}" $package_url >> $ACTIONS_LOG 2>&1 || { writeJSONResponseErr "result=>4078" "message=>Error loading file from URL"; die -q; }
        package_name="${DOWNLOADS}/$(ls ${DOWNLOADS})";
        [ ! -s "$package_name" ] && {
            set -f
            rm -f "${package_name}";
            set +f
            writeJSONResponseErr "result=>4078" "message=>Error loading file from URL";
            die -q;
        }
    fi
}

function deploy(){
    [ -f "$prestart_script" ] && $prestart_script
    local crt_control="${STACK_PATH}bin/control";
    if [[ -z "$package_url" || -z "$context" ]]
    then
        writeJSONResponseErr "result=>4058" "message=>Wrong arguments for deploy" ; return 1;
    fi
    [ -z "${WEBROOT}" ] && { writeJSONResponseErr "result=>4060" "message=>Deploy failed, see logs for details" ; return 1; }
    getPackageName;

    stopServiceSilent ${SERVICE} ;
    rm -rf "${WEBROOT}/*";

    unzip  -Z1 ${package_name} |  grep -q "META-INF/MANIFEST.MF" && {
    cp  ${package_name} ${WEBROOT}/$(basename ${package_name}); } ||  local jar_entry=$(unzip  -Z1 ${package_name}   | grep ".jar\|.war\.ear" | head -1 );
        [ ! -z $jar_entry ]  && {
        unzip -o "$package_name" -d "${WEBROOT}" 2>>$ACTIONS_LOG 1>/dev/null || writeJSONResponseErr "result=>4060" "message=>Application deployed with error";
    }
    _clearCache;
    chown -R 700:700 "${WEBROOT}"
    startService ${SERVICE} > /dev/null 2>&1;
    #writeJSONResponseOut "result=>0" "message=>Application deployed succesfully";
    echo
    return 0;
}

function _undeploy(){
#    if [[ -z "$context" ]]
#    then
#        echo "Wrong arguments for undeploy" 1>&2
#        exit 1
#    fi
    [ -f "$prestart_script" ] && $prestart_script
    stopServiceSilent ${SERVICE};

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
