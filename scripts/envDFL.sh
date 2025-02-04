#!/bin/bash
#
# Copyright (c) 2021, RTE (http://www.rte-france.com)
# See AUTHORS.txt
# All rights reserved.
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, you can obtain one at http://mozilla.org/MPL/2.0/.
# SPDX-License-Identifier: MPL-2.0
#

# This file aimes to encapsulate processing for users to compiler and use DFL

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

error_exit() {
    echo "${1:-"Unknown Error"}" 1>&2
    exit 1
}

export_var_env() {
    local var="$@"
    local name=${var%%=*}
    local value="${var#*=}"

    if ! `expr $name : "DYNAFLOW_LAUNCHER_.*" > /dev/null`; then
      error_exit "You must export variables with DYNAFLOW_LAUNCHER_ prefix for $name."
    fi

    if eval "[ \"\$$name\" ]"; then
      eval "value=\${$name}"
      ##echo "Environment variable for $name already set : $value"
      return
    fi

    if [ "$value" = UNDEFINED ]; then
      error_exit "You must define the value of $name"
    fi
    export $name="$value"
}

export_var_env_force() {
  local var="$@"
  local name=${var%%=*}
  local value="${var#*=}"

  if ! `expr $name : "DYNAFLOW_LAUNCHER_.*" > /dev/null`; then
    error_exit "You must export variables with DYNAFLOW_LAUNCHER prefix for $name."
  fi

  if eval "[ \"\$$name\" ]"; then
    unset $name
    export $name="$value"
    return
  fi

  if [ "$value" = UNDEFINED ]; then
    error_exit "You must define the value of $name"
  fi
  export $name="$value"
}

export_var_env_force_dynawo() {
  local var="$@"
  local name=${var%%=*}
  local value="${var#*=}"

  if ! `expr $name : "DYNAWO_.*" > /dev/null`; then
    error_exit "You must export variables with DYNAWO prefix for $name."
  fi

  if eval "[ \"\$$name\" ]"; then
    unset $name
    export $name="$value"
    return
  fi

  if [ "$value" = UNDEFINED ]; then
    error_exit "You must define the value of $name"
  fi
  export $name="$value"
}

export_var_env_dynawo_with_default() {
  # export_var_env_dynawo_with_default <VAR> <EXTERNAL_VAL> <DEFAULT_VAL>
  # case <EXTERNAL_VAL> non empty : <EXTERNAL_VAL>
  # case <EXTERNAL_VAL> empty : <DEFAULT_VAL>
  export_var_env_force_dynawo $1=$2
}

ld_library_path_remove() {
  export LD_LIBRARY_PATH=`echo -n $LD_LIBRARY_PATH | awk -v RS=: -v ORS=: '$0 != "'$1'"' | sed 's/:$//'`;
}

ld_library_path_prepend() {
  if [ ! -z "$LD_LIBRARY_PATH" ]; then
    ld_library_path_remove $1
    export LD_LIBRARY_PATH="$1:$LD_LIBRARY_PATH"
  else
    export LD_LIBRARY_PATH="$1"
  fi
}

pythonpath_remove() {
  export PYTHONPATH=`echo -n $PYTHONPATH | awk -v RS=: -v ORS=: '$0 != "'$1'"' | sed 's/:$//'`;
}

pythonpath_prepend() {
  if [ ! -z "$PYTHONPATH" ]; then
    pythonpath_remove $1
    export PYTHONPATH="$1:$PYTHONPATH"
  else
    export PYTHONPATH="$1"
  fi
}

define_options() {
    export_var_env DYNAFLOW_LAUNCHER_USAGE="Usage: `basename $0` [option] -- program to deal with DynaFlow Launcher

where [option] can be:
        =========== Build
        build-user                                build DynaFlow Launcher
        clean                                     clean DynaFlow Launcher
        clean-build-all                           Clean and rebuild DynaFlow Launcher
        build-tests-coverage                      build DynaFlow Launcher and run coverage

        =========== Tests
        tests                                     launch DynaFlow Launcher unit tests
        update-references                         update MAIN tests references

        =========== Launch
        launch [network] [config]                 launch DynaFlow Launcher:
                                                  - network: filepath (only IIDM is supported)
                                                  - config: filepath (JSON configuration file)
        launch-sa [network] [config] [contingencies] launch DynaFlow Launcher to run a Security Analysis:
                                                  - network: filepath (only IIDM is supported)
                                                  - config: filepath (JSON configuration file)
                                                  - contingencies: filepath (JSON file)

        =========== Others
        help                                      show all available options
        format                                    format modified git files using clang-format
        version                                   show DynaFlow Launcher version
        reset-environment                         reset all environment variables set by DynaFlow Launcher
"
}

help() {
    define_options
    echo "$DYNAFLOW_LAUNCHER_USAGE"
}

set_commit_hook() {
    $HERE/set_commit_hook.sh
}

set_environment() {
    # dynawo vars
    export DYNAWO_INSTALL_DIR=$DYNAWO_HOME
    export IIDM_XML_XSD_PATH=$DYNAWO_INSTALL_DIR/share/iidm/xsd

    # dynawo vars that can be replaced by external
    export_var_env_dynawo_with_default DYNAWO_DDB_DIR $DYNAFLOW_LAUNCHER_EXTERNAL_DDB $DYNAWO_INSTALL_DIR/ddb

    # DYNAWO_IIDM_EXTENSION is used only in case of external IIDM extensions.
    # Empty string is equivalent to not set for Dynawo
    export_var_env_force_dynawo DYNAWO_IIDM_EXTENSION=$DYNAFLOW_LAUNCHER_EXTERNAL_IIDM_EXTENSION

    # dynawo vars that can be extended by external
    export DYNAWO_LIBIIDM_EXTENSIONS=$DYNAWO_INSTALL_DIR/lib:$DYNAFLOW_LAUNCHER_EXTERNAL_LIBRARIES
    export DYNAWO_RESOURCES_DIR=$DYNAWO_INSTALL_DIR/share:$DYNAWO_INSTALL_DIR/share/xsd:$DYNAFLOW_LAUNCHER_EXTERNAL_RESOURCES_DIR

    # dynawo algorithms
    # Use same locale of dynaflow launcher
    export DYNAWO_ALGORITHMS_LOCALE=$DYNAFLOW_LAUNCHER_LOCALE

    # global vars
    ld_library_path_prepend $DYNAWO_INSTALL_DIR/lib         # For Dynawo library
    ld_library_path_prepend $DYNAWO_ALGORITHMS_HOME/lib     # For Dynawo-algorithms library
    ld_library_path_prepend $DYNAFLOW_LAUNCHER_HOME/lib64   # For local DFL libraries, used only at runtime in case we compile in shared
    ld_library_path_prepend $DYNAFLOW_LAUNCHER_EXTERNAL_LIBRARIES # To add external model libraries loaded during simulation

    # build
    export_var_env_force DYNAFLOW_LAUNCHER_BUILD_DIR=$DYNAFLOW_LAUNCHER_HOME/buildLinux
    export_var_env_force DYNAFLOW_LAUNCHER_INSTALL_DIR=$DYNAFLOW_LAUNCHER_HOME/installLinux

    export_var_env DYNAFLOW_LAUNCHER_SHARED_LIB=OFF # same default value as cmakelist
    export_var_env DYNAFLOW_LAUNCHER_USE_DOXYGEN=ON # same default value as cmakelist
    export_var_env DYNAFLOW_LAUNCHER_BUILD_TESTS=ON # same default value as cmakelist
    export_var_env DYNAFLOW_LAUNCHER_CMAKE_GENERATOR="Unix Makefiles"
    export_var_env DYNAFLOW_LAUNCHER_PROCESSORS_USED=1

    # Run
    if [ $1 -ne 1 ]
    then
        # export runtime variables only if unit tests are not run
        export_var_env_force DYNAFLOW_LAUNCHER_INSTALL=$DYNAFLOW_LAUNCHER_INSTALL_DIR
        export_var_env_force DYNAFLOW_LAUNCHER_LIBRARIES=$DYNAWO_DDB_DIR # same as dynawo
        export_var_env_force DYNAFLOW_LAUNCHER_XSD=$DYNAFLOW_LAUNCHER_INSTALL_DIR/etc/xsd
        export_var_env DYNAFLOW_LAUNCHER_LOG_LEVEL=INFO # INFO by default
    fi

    # python
    pythonpath_prepend $DYNAWO_HOME/sbin/nrt/nrt_diff

    # hooks
    set_commit_hook
}

reset_environment_variables() {
    for var in $(printenv | grep DYNAFLOW_LAUNCHER_ | cut -d '=' -f 1); do
        unset $var
    done

    ld_library_path_remove $DYNAFLOW_LAUNCHER_HOME/lib64
    ld_library_path_remove $DYNAFLOW_LAUNCHER_HOME/lib

    pythonpath_remove $DYNAWO_HOME/sbin/nrt/nrt_diff

    unset DYNAWO_HOME
    unset DYNAWO_INSTALL_DIR
    unset DYNAWO_RESOURCES_DIR
    unset DYNAWO_DDB_DIR
    unset DYNAWO_IIDM_EXTENSION
    unset DYNAWO_LIBIIDM_EXTENSIONS
    unset IIDM_XML_XSD_PATH

    unset DYNAWO_ALGORITHMS_HOME
}

clean() {
    rm -rf $DYNAFLOW_LAUNCHER_BUILD_DIR
    rm -rf $DYNAFLOW_LAUNCHER_INSTALL_DIR
    rm -rf $DYNAFLOW_LAUNCHER_HOME/tests/outputs/results
    rm -rf $DYNAFLOW_LAUNCHER_HOME/tests/main/results
    rm -rf $DYNAFLOW_LAUNCHER_HOME/tests/main_sa/results
}

cmake_configure() {
    mkdir -p $DYNAFLOW_LAUNCHER_BUILD_DIR
    pushd $DYNAFLOW_LAUNCHER_BUILD_DIR > /dev/null
    cmake $DYNAFLOW_LAUNCHER_HOME \
        -G "$DYNAFLOW_LAUNCHER_CMAKE_GENERATOR" \
        -DCMAKE_BUILD_TYPE:STRING=$DYNAFLOW_LAUNCHER_BUILD_TYPE \
        -DCMAKE_INSTALL_PREFIX:STRING=$DYNAFLOW_LAUNCHER_INSTALL_DIR \
        -DDYNAWO_HOME:STRING=$DYNAWO_HOME \
        -DDYNAWO_ALGORITHMS_HOME:STRING=$DYNAWO_ALGORITHMS_HOME \
        -DBOOST_ROOT:STRING=$DYNAWO_HOME \
        -DDYNAFLOW_LAUNCHER_LOCALE:STRING=$DYNAFLOW_LAUNCHER_LOCALE \
        -DDYNAFLOW_LAUNCHER_SHARED_LIB:BOOL=$DYNAFLOW_LAUNCHER_SHARED_LIB \
        -DDYNAFLOW_LAUNCHER_USE_DOXYGEN:BOOL=$DYNAFLOW_LAUNCHER_USE_DOXYGEN \
        -DDYNAFLOW_LAUNCHER_BUILD_TESTS:BOOL=$DYNAFLOW_LAUNCHER_BUILD_TESTS
    popd > /dev/null
}

cmake_build() {
    apply_clang_format
    cmake --build $DYNAFLOW_LAUNCHER_BUILD_DIR --target install -j $DYNAFLOW_LAUNCHER_PROCESSORS_USED
}

cmake_tests() {
    pushd $DYNAFLOW_LAUNCHER_BUILD_DIR > /dev/null
    ctest -j $DYNAFLOW_LAUNCHER_PROCESSORS_USED --output-on-failure
    RETURN_CODE=$?
    popd > /dev/null
    return ${RETURN_CODE}
}

cmake_coverage() {
    ctest \
        -S cmake/CTestScript.cmake \
        -DDYNAWO_HOME=$DYNAWO_HOME \
        -DDYNAWO_ALGORITHMS_HOME=$DYNAWO_ALGORITHMS_HOME \
        -DBOOST_ROOT=$DYNAWO_HOME \
        -VV
}

clean_build_all() {
    clean
    build_user
}

build_user() {
    cmake_configure
    cmake_build
}

build_tests_coverage() {
    rm -rf $DYNAFLOW_LAUNCHER_HOME/buildCoverage
    cmake_coverage
}

launch() {
    if [ ! -f $1 ]; then
        error_exit "IIDM network file $network doesn't exist"
    fi
    if [ ! -f $2 ]; then
        error_exit "DFL configuration file $config doesn't exist"
    fi
    $DYNAFLOW_LAUNCHER_INSTALL_DIR/bin/DynaFlowLauncher \
    --log-level $DYNAFLOW_LAUNCHER_LOG_LEVEL \
    --network $1 \
    --config $2
}

launch_sa() {
    if [ ! -f $1 ]; then
        error_exit "IIDM network file $1 doesn't exist"
    fi
    if [ ! -f $2 ]; then
        error_exit "DFL configuration file $2 doesn't exist"
    fi
    if [ ! -f $3 ]; then
        error_exit "Security Analysis contingencies file $3 doesn't exist"
    fi
    $DYNAFLOW_LAUNCHER_INSTALL_DIR/bin/DynaFlowLauncher \
    --log-level $DYNAFLOW_LAUNCHER_LOG_LEVEL \
    --network $1 \
    --config $2 \
    --contingencies $3
}

version() {
    $DYNAFLOW_LAUNCHER_INSTALL_DIR/bin/DynaFlowLauncher --version
}

update_references() {
    $HERE/updateMainReference.py
}

apply_clang_format() {
    CLANGF=$(which clang-format)
    if [ -z $CLANGF ]; then
        echo "WARNING: Clang format not found"
    else
        pushd $DYNAFLOW_LAUNCHER_HOME > /dev/null
        for file in $(git diff-index --name-only HEAD | grep -iE '\.(cpp|cc|h|hpp)$'); do
            $CLANGF -i $file
        done
        popd > /dev/null
    fi
}

#################################
########### Main script #########
#################################

MODE=0 # normal
case $1 in
    tests)
        # environment used for unit tests is defined only in cmakelist
        MODE=1
        ;;
    build-tests-coverage)
        # environment used for unit tests in coverage case is defined only in cmakelist
        MODE=1
        ;;
    *)
        ;;
esac
set_environment $MODE

case $1 in
    build-user)
        build_user || error_exit "Failed to build DFL"
        ;;
    build-tests-coverage)
        build_tests_coverage || error_exit "Failed to perform coverage"
        ;;
    clean)
        clean || error_exit "Failed to clean DFL"
        ;;
    clean-build-all)
        clean_build_all || error_exit "Failed to clean build DFL"
        ;;
    help)
        help
        ;;
    launch)
        launch $2 $3 || error_exit "Failed to perform launch with network=$2, config=$3"
        ;;
    launch-sa)
        launch_sa $2 $3 $4 || error_exit "Failed to perform launch-sa with network=$2, config=$3, contingencies=$4"
        ;;
    reset-environment)
        reset_environment_variables || error_exit "Failed to reset environment variables"
        ;;
    tests)
        cmake_tests || error_exit "Failed to perform tests"
        ;;
    update-references)
        update_references || error_exit "Failed to update MAIN references"
        ;;
    format)
        apply_clang_format || error_exit "Failed to format files"
        ;;
    version)
        version
        ;;
    *)
        echo "$1 is an invalid option"
        help
        exit 1
        ;;
esac
