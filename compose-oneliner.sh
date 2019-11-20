#!/usr/bin/env bash
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

## Unset all args 
unset BRANCH
unset TOKEN
unset PRODUCT
unset GIT
unset DASHBOARD
unset DASHBOARD_VERSION
unset DOWNLOAD_ONLY

# Absolute path to this script
SCRIPT=$(readlink -f "$0")
# Absolute path to the script directory
BASEDIR=$(dirname "$SCRIPT")
HOME_DIR=`eval echo ~$(logname)`
COMPOSE_BASH_URL="https://github.com/AnyVisionltd"


function show_help(){
    echo ""
    echo "Compose oneliner help"
    echo ""
    echo "OPTIONS:"
    echo "  [-b|--branch] git branch"
    echo "  [-k|--token] GCR token"
    echo "  [-p|--product] Product name to install, for example: insights"
    echo "  [-g|--git] alterntive git repo (the default is docker-compose.git)"
    echo "  [--download-dashboard] download dashboard"
    echo "  [--dashboard-version] download spcific dashboard version"
    echo "  [--download-only] preform download only without installing anything"
    echo "  [-h|--help|help] this help menu"
    echo ""
}


function download-dashboard {
    local COMPOSE_PATH=$1
    if [[ -z $DASHBOARD_VERSION ]]; then
        IFS='.' read -ra a <<< """$(grep -F /api: ${COMPOSE_PATH} | grep -Po 'api:\K[^"]+')"""
        ver="${a[0]}.${a[1]}.${a[2]}"
    else
        ver="${DASHBOARD_VERSION}"
    fi 

    echo "=============================================================" 
    echo "==  Downloading AnyVision-${ver}-linux-x86_64.AppImage...  ==" 
    echo "=============================================================" 
    echo
    curl -o "${HOME_DIR}/AnyVision-${ver}-linux-x86_64.AppImage" "https://s3.eu-central-1.amazonaws.com/anyvision-dashboard/${ver}/AnyVision-${ver}-linux-x86_64.AppImage"
    chmod +x "${HOME_DIR}/AnyVision-${ver}-linux-x86_64.AppImage"
    echo "Saved to: ${HOME_DIR}/AnyVision-${ver}-linux-x86_64.AppImage"
    chown -R $(logname):$(logname) ${HOME_DIR}/AnyVision-${ver}-linux-x86_64.AppImage
}

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

if [ "${DOWNLOAD_ONLY}" == "true" ]; then
    if [[ -z $DASHBOARD_VERSION ]]; then
        echo "You must spcify --dashboard-version when invocing --download-only"
        exit 99
    fi
    download-dashboard 
    exit 0
fi

if [[ -z ${BRANCH} ]] ; then
    echo
    echo "Branch must be specified!"
    show_help
    exit 1
fi

if [[ -z ${TOKEN} ]]; then 
    echo
    echo "You must privide a docker registry token!"
    show_help
    exit 1 
fi

if [[ -z $PRODUCT ]]; then
    echo "assuming product is BT..."
    PRODUCT="BT"
fi

if [[ -z ${GIT} ]]; then
    GIT="docker-compose"
fi

if [[ -z ${DASHBOARD} ]]; then
    DASHBOARD="false"
fi

if [[ "$DASHBOARD" == "false"  && -n $DASHBOARD_VERSION ]]; then
    echo "--download-dashboard was not spcify ignoring --dashboard-version"
    unset DASHBOARD_VERSION
fi

DOCKER_COMPOSE_DIR=${HOME_DIR}/${GIT}

if [ -x "$(command -v apt-get)" ]; then

	# install git
	echo "Installing git"
	if ! git --version > /dev/null 2>&1; then
	    set -e
	    apt-get -qq update > /dev/null
	    apt-get -qq install -y --no-install-recommends git curl > /dev/null
	    set +e
	fi
elif [ -x "$(command -v yum)" ]; then
     echo "Installing git"
     yum install -y git
fi

if [[ $TOKEN != "" ]] && [[ $TOKEN == *".json" ]] && [[ -f $TOKEN ]] ;then
    gcr_user="_json_key" 
    gcr_key="$(< ${TOKEN} tr '\n' ' ')"
elif  [[ $TOKEN != "" ]] && [[ ! -f $TOKEN ]] && [[ $TOKEN != *".json" ]]; then
    gcr_user="oauth2accesstoken"
    gcr_key=$TOKEN
fi

COMPOSE_REPO="${COMPOSE_BASH_URL}/${GIT}.git"
[ -d $DOCKER_COMPOSE_DIR ] || mkdir $DOCKER_COMPOSE_DIR
[ -d ${DOCKER_COMPOSE_DIR}/${BRANCH} ] && rm -rf ${DOCKER_COMPOSE_DIR:?}/${BRANCH:?}

if ! git clone ${COMPOSE_REPO} -b ${BRANCH} ${DOCKER_COMPOSE_DIR}/${BRANCH}; then
    echo "No such branch try again"
    exit 1
fi

pushd ${DOCKER_COMPOSE_DIR}/${BRANCH}
DOCKER_COMPOSE_FILE=`find . -type f -regextype posix-extended -regex './docker\-compose\-(local\-)?gpu\.yml'`
if [[ PRODUCT=="insights" ]]; then
    DOCKER_COMPOSE_PRODUCT_FILE=`find . -type f -regextype posix-extended -regex './docker\-compose\-insights\.yml'`
    if [ $? -ne 0 ]; then
        echo "No such product $PRODUCT try again"
        exit 1
    fi
fi
popd

# Set Environment
export ANSIBLE_LOCALHOST_WARNING=false
export ANSIBLE_DEPRECATION_WARNINGS=false
export DEBIAN_FRONTEND=noninteractive

echo "=====================================================================" 
echo "== Making sure that all dependencies are installed, please wait... ==" 
echo "=====================================================================" 
## APT update
set -e
apt -qq update 
apt -qq install -y software-properties-common 
apt-add-repository --yes --update ppa:ansible/ansible 
apt -qq install -y ansible 
set +e

[ -d /opt/compose-oneliner ] && rm -rf /opt/compose-oneliner
git clone --recurse-submodules  https://github.com/AnyVisionltd/compose-oneliner.git /opt/compose-oneliner
pushd /opt/compose-oneliner


if ! ansible-playbook --become --become-user=root ansible/main.yml -vv; then
    echo "" 
    echo "Installation failed, please contact support." 
    exit 1
fi


function run_xhost {
    if [ -z ${SUDO_USER} ]; then 
        echo "SUDO_USER is blank, cannot retrive this parameter, mayabe running sudo with other profile (-)."
    else 
        echo "SUDO_USER is set to '$SUDO_USER', running xhost + with '$SUDO_USER'"
        su - ${SUDO_USER} -c "xhost +SI:localuser:root"
    fi
}


## Fix nvidia-driver bug on Ubuntu 18.04 black screen on login: https://devtalk.nvidia.com/default/topic/1048019/linux/black-screen-after-install-cuda-10-1-on-ubuntu-18-04/post/5321320/#5321320
sed -i -r -e 's/^GRUB_CMDLINE_LINUX_DEFAULT="(.*)?quiet ?(.*)?"/GRUB_CMDLINE_LINUX_DEFAULT="\1\2"/' -e 's/^GRUB_CMDLINE_LINUX_DEFAULT="(.*)?splash ?(.*)?"/GRUB_CMDLINE_LINUX_DEFAULT="\1\2"/' /etc/default/grub
update-grub
usermod -aG docker $(logname)
[[ "${DASHBOARD}" == "true" ]] && download-dashboard "${DOCKER_COMPOSE_DIR}/${BRANCH}/docker-compose.yml"
chown -R $(logname):$(logname) ${HOME_DIR}
docker login -u "${gcr_user}" -p "${gcr_key}" "https://gcr.io"

pushd ${DOCKER_COMPOSE_DIR}/${BRANCH}
case "${PRODUCT}" in 
    "BT")
        docker-compose -f ${DOCKER_COMPOSE_FILE} up -d
        exit
    ;;
    "insights")
        timedatectl set-timezone Etc/UTC && echo "changed the local machine time to UTC"
        run_xhost
        docker-compose -f ${DOCKER_COMPOSE_FILE} -f ${DOCKER_COMPOSE_PRODUCT_FILE} up -d
        exit
    ;;
    esac
else
    echo "No product selected"
    exit 99
fi
echo "Done, Please reboot before continuing."
