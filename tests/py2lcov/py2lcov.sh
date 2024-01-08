#!/bin/bash
set +x

CLEAN_ONLY=0
COVER=

PARALLEL='--parallel 0'
PROFILE="--profile"
if [ 'x' == "x${COVER_DB}" ] ; then
    COVER_DB='cover_db'
fi
LOCAL_COVERAGE=1
KEEP_GOING=0
while [ $# -gt 0 ] ; do

    OPT=$1
    shift
    case $OPT in

        --clean | clean )
            CLEAN_ONLY=1
            ;;

        -v | --verbose | verbose )
            set -x
            ;;

        --keep-going )
            KEEP_GOING=1
            ;;

        --coverage )
            #COVER="perl -MDevel::Cover "
            if [[ "$1"x != 'x' && $1 != "-"* ]] ; then
               COVER_DB=$1
               LOCAL_COVERAGE=0
               shift
            fi
            COVER="perl -MDevel::Cover=-db,${COVER_DB},-coverage,statement,branch,condition,subroutine "
            ;;

        --home | -home )
            LCOV_HOME=$1
            shift
            if [ ! -f $LCOV_HOME/bin/lcov ] ; then
                echo "LCOV_HOME '$LCOV_HOME' does not exist"
                exit 1
            fi
            ;;

        --no-parallel )
            PARALLEL=''
            ;;

        --no-profile )
            PROFILE=''
            ;;

        * )
            echo "Error: unexpected option '$OPT'"
            exit 1
            ;;
    esac
done

if [ "x" == "x$LCOV_HOME" ] ; then
       if [ -f ../../bin/lcov ] ; then
           LCOV_HOME=../..
       else
           LCOV_HOME=../../../releng/coverage/lcov
       fi
fi

LCOV_HOME=`(cd ${LCOV_HOME} ; pwd)`

PY2LCOV_SCRIPT=${LCOV_HOME}/bin/py2lcov

if [ ! -x $PY2LCOV_SCRIPT ] ; then
    echo "missing py2lcov script - dying"
    exit 1
fi

if [[ ! ( -d $LCOV_HOME/bin && -d $LCOV_HOME/lib && -x $LCOV_HOME/bin/genhtml && -f $LCOV_HOME/lib/lcovutil.pm ) ]] ; then
    echo "LCOV_HOME '$LCOV_HOME' seems not to be invalid"
    exit 1
fi

export PATH=${LCOV_HOME}/bin:${LCOV_HOME}/share:${PATH}
export MANPATH=${MANPATH}:${LCOV_HOME}/man

if [ 'x' == "x$GENHTML_TOOL" ] ; then
    GENHTML_TOOL=${LCOV_HOME}/bin/genhtml
    LCOV_TOOL=${LCOV_HOME}/bin/lcov
    GENINFO_TOOL=${LCOV_HOME}/bin/geninfo
fi

ROOT=`pwd`
PARENT=`(cd .. ; pwd)`

LCOV_OPTS="--branch-coverage $PARALLEL $PROFILE"

rm -rf *.xml *.dat *.info *.json

if [ "x$COVER" != 'x' ] && [ 0 != $LOCAL_COVERAGE ] ; then
    cover -delete
fi

if [[ 1 == $CLEAN_ONLY ]] ; then
    exit 0
fi


which coverage
if [ 0 != $? ] ; then
    echo "unable to run py2lcov - please install python Coverage.py package"
    exit 1
fi

COVERAGE_FILE=./cov.dat coverage run --append --branch ${PY2LCOV_SCRIPT} --help
if [ 0 != $? ] ; then
    echo "coverage extract failed"
    exit 1
fi
COVERAGE_FILE=./cov.dat coverage xml -o help.xml
if [ 0 != $? ] ; then
    echo "coverage xml failed"
    exit 1
fi

COVERAGE_FILE=./cov2.dat coverage  run --branch ${PY2LCOV_SCRIPT} -i help.xml -o help.info
if [ 0 != $? ] ; then
    echo "coverage extract2 failed"
    if [ 0 == $KEEP_GOING ]  ; then
        exit 1
    fi
fi

COVERAGE_FILE=./cov2.dat coverage xml -o run.xml
if [ 0 != $? ] ; then
    echo "coverage xml2 failed"
    exit 1
fi

$COVER ${PY2LCOV_SCRIPT} -i run.xml -o run.info
if [ 0 != $? ] ; then
    echo "py2lcov failed"
    if [ 0 == $KEEP_GOING ]  ; then
        exit 1
    fi
fi

$COVER $LCOV_TOOL $LCOV_OPTS -o aggregate.info -a help.info -a run.info
if [ 0 != $? ] ; then
    echo "lcov aggregate failed"
    if [ 0 == $KEEP_GOING ] ; then
        exit 1
    fi
fi

$COVER $LCOV_TOOL $LCOV_OPTS --summary aggregate.info
if [ 0 != $? ] ; then
    echo "lcov summary failed"
    if [ 0 == $KEEP_GOING ] ; then
        exit 1
    fi
fi

echo "Tests passed"

if [ "x$COVER" != "x" ] && [ $LOCAL_COVERAGE == 1 ]; then
    cover
fi

#put that py2lcov coverage data into the cover_db - if it exists
if [ 'x' != "x$COVER" ] || [ 'x' != "x$HTML_RPT" ] ; then
    mkdir -p ${COVER_DB}
    cp run.info ${COVER_DB}/py2lcov.info
fi
