#!/usr/bin/env bash
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

function show_help(){
    echo ""
    echo "Compose Oneliner Installer"
    echo ""
    echo "OPTIONS:"
    echo "  [-b|--branch] git branch"
    echo "  [-k|--token] GCR token"
    echo "  [-p|--product] Product name to install"
    echo "  [-g|--git] alterntive git repo (the default is docker-compose.git)"
    echo "  [--download-dashboard] download dashboard"
    echo "  [--dashboard-version] download spcific dashboard version"
    echo "  [--download-only] preform download only without installing anything"
    echo "  [-d|--debug] enable debug mode"
    echo "  [-h|--help|help] this help menu"
    echo ""
}

## Unset all args 
unset BRANCH
unset TOKEN
unset PRODUCT
unset GIT
unset EXEC
unset DASHBOARD
unset DASHBOARD_VERSION
unset DOWNLOAD_ONLY

## Populating arguments
args=("$@")
for item in "${args[@]}"
do
    case $item in
        "-b"|"--branch")
            BRANCH="${args[((i+1))]}"
        ;;

        "-k"|"--token")
            TOKEN="${args[((i+1))]}"
        ;;

        "-p"|"--product")
            PRODUCT="${args[((i+1))]}"
        ;;

        "-g"|"--git")
            GIT="${args[((i+1))]}"
        ;;

        "-d"|"--debug")
            EXEC='bash -x'
        ;;

        "--download-dashboard")
            DASHBOARD="true"
        ;;

        "--dashboard-version")
            DASHBOARD_VERSION="${args[((i+1))]}"
            rx='^([0-9]+\.){2}(\*|[0-9]+)$'
            if [[ ! $DASHBOARD_VERSION =~ $rx ]]; then
                echo "ERROR: '$DASHBOARD_VERSION' is not a vaild version"
                echo "Vaild Format: x.y.z (exp: 1.24.0)"
                exit 99
            fi
        ;;

        "--download-only")
            DOWNLOAD_ONLY="true"
        ;;

        "-h"|"--help"|"help")
            show_help
            exit 0
        ;;


    esac
    ((i++))
done


if [[ -z ${BRANCH} ]] ; then
    echo "Branch must be specified!"
    exit 1
fi

if [[ -z ${TOKEN} ]]; then 
    echo "You must privide a docker registry token!"
    exit 1 
fi

if [[ -z $PRODUCT ]]; then
    echo "assuming product is BT..."
    PRODUCT="BT"
fi

if [[ -z $DASHBOARD  && ! -z $DASHBOARD_VERSION ]]; then
    echo "--download-dashboard was not spcify ignoring --dashboard-version"
fi

if [ -x "$(command -v apt-get)" ]; then

	# install git
	echo "Installing git"
	git --version > /dev/null 2>&1
	if [ $? != 0 ]; then
	    set -e
	    apt-get -qq update > /dev/null
	    apt-get -qq install -y --no-install-recommends git curl > /dev/null
	    set +e
	fi
elif [ -x "$(command -v yum)" ]; then
     echo "Installing git"
     yum install -y git
fi

[ -d /opt/compose-oneliner ] && rm -rf /opt/compose-oneliner

git clone --recurse-submodules  https://github.com/AnyVisionltd/compose-oneliner.git /opt/compose-oneliner

pushd /opt/compose-oneliner && chmod u+x /opt/compose-oneliner/compose-oneliner.sh
EXEC="${EXEC:-bash}"
$EXEC ./compose-oneliner.sh ${BRANCH} ${TOKEN} ${PRODUCT} ${GIT} ${DASHBOARD} ${DOWNLOAD_ONLY} ${DASHBOARD_VERSION}
if [ $? -ne 0 ] ; then 
	echo "Something went wrong contact support"
	exit 99
fi
