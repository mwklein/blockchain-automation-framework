#!/bin/bash 

usage="Installs the necessary software on a Mac to run the Blockchain Automation Framework (https://github.com/hyperledger-labs/blockchain-automation-framework)
Usage: $(basename "$0") [-h] [-b]

where:
    -h  show this help text
    -b  (Optional) will install necessary brew packages and casks
"

#DEFAULTS
brewPkgs=( 
    "docker"
    "docker-compose"
    "docker-machine"
    "minikube"
)

brewCasks=(
    "virtualbox"
    "visual-studio-code"
)

# Setup script colors
red=`tput setaf 1`
green=`tput setaf 2`
reset=`tput sgr0`

#CHECK FOR BREW AND INSTALL
installBrew () {
    # Check for Homebrew, install if we don't have it
    if test ! $(which brew); then
        echo "Installing homebrew..."
        ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
        (set -x; brew tap caskroom/versions;)
    fi
}

# INSTALL BREW PACKAGES
installBrewPkgs() {
    echo "${green}--------INSTALLING BREW PACKAGES--------${reset}"
    for pkg in "${brewPkgs[@]}"
    do
        installed=false
        version=$(brew info $pkg | sed -n "s/$pkg:\ stable \(.*\)\ (\(.*\)/\1/p")

        if [ -d "/usr/local/Cellar/$pkg" ]; then
            installed=true
        fi

        if [ $installed = true ]; then
            currentInstalledPath=$(find "/usr/local/Cellar/$pkg" -type d -maxdepth 1 -maxdepth 1 -name "*$version*")
            if [[ $currentInstalledPath == *"/usr/local/"* ]]; then
                echo "${red}${pkg}${reset} is at version $version and is ${green}up-to-date${reset}."
            else
                echo "${red}${pkg}${reset} is at version $version and requires ${red}update${reset}."
                (set -x; brew upgrade ${pkg};)
            fi
        else
            echo "${red}${pkg}${reset} is not installed. ${red}Let's install it...${reset}."
            brew install $pkg
        fi
        
    done
}

# INSTALL ALL BREW CASKS
installBrewCasks() {
    echo "${green}--------INSTALLING BREW CASKS--------${reset}"  

    for cask in ${brewCasks[@]}
    do
        version=$(brew cask info $cask | sed -n "s/$cask:\ \(.*\)/\1/p")
        installed=$(find "/usr/local/Caskroom/$cask" -type d -maxdepth 1 -maxdepth 1 -name "$version")

        if [[ -z $installed ]]; then
            echo "${red}${cask}${reset} is at version $version and requires ${red}update${reset}."
            (set -x; brew cask uninstall $cask --force;)
            (set -x; brew cask install $cask --force;)
        else
            echo "${red}${cask}${reset} is at version $version and is ${green}up-to-date${reset}."
        fi
    done
    if [ $paramBrewCleanup = false ]; then 
    	(set -x; brew cask cleanup;)
    fi
}

# ================== MAIN ==================

# Read command line arguments
paramBrew=false

while getopts ':hb' option; do
  case "$option" in
    h) echo "$usage"
       exit
       ;;
    b) paramBrew=true
       ;;
    :) printf "missing argument for -%s\n" "$OPTARG" >&2
       echo "$usage" >&2
       exit 1
       ;;
   \?) printf "illegal option: -%s\n" "$OPTARG" >&2
       echo "$usage" >&2
       exit 1
       ;;
  esac
done
shift $((OPTIND -1))

# If the -b flag is set
if [ $paramBrew = true ]; then
    (set -x; brew update;)
    installBrew
    installBrewPkgs
    installBrewCasks
fi

mkdir -p build
ssh-keygen -q -N "" -f build/gitops.pem

if test ! $(docker ps); then
    echo "Docker not currently working..."
    (set -x; docker-machine create baf;)
    (set -x; docker-machine start baf;)
    `$(docker-machine env baf)`
fi

minikube config set memory 4096
minikube config set kubernetes-version v1.15.4
minikube start --vm-driver=virtualbox

cp ~/.minikube/ca.crt build/.
cp ~/.minikube/client.crt build/.
cp ~/.minikube/client.key build/.
cp ~/.kube/config build/.

sed -i "s/\:\ .*client.crt/\:\ client.crt/g" ./build/config
sed -i 's/\:\ .*client.crt/\:\ client.key/g' ./build/config
sed -i 's/\:\ .*client.crt/\:\ ca.crt/g' ./build/config

cp 