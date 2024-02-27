#!/usr/bin/env bash
# Bash3 Boilerplate. Copyright (c) 2014, kvz.io

set -o errexit
set -o pipefail
set -o nounset
# set -o xtrace

trap 'echo -e "Aborted, error $? in command: $BASH_COMMAND"; trap ERR; exit 1' ERR

# Set magic variables for current file & dir
__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__base="$(basename ${__file} .sh)"
__root="$(cd "$(dirname "${__dir}")" && pwd)" # <-- change this as it depends on your app

rpmtopdir="${1:-}"

# trap 'echo Signal caught, cleaning up >&2; cd /tmp; /bin/rm -rfv "$TMP"; exit 15' 1 2 3 15
# allow command fail:
# fail_command || true
#

CHECKEXISTS() {
  if [[ ! -f $__dir/downloads/$1 ]];then
    echo "$1 not found, run 'pullsrc.sh', or manually put it in the downloads dir."
    exit 1
  fi
}


GUESS_DIST() {
        local dist=$(rpm --eval '%{?dist}' | tr -d '.')
        [[ -n $dist ]] && echo $dist && return 0

	local glibcver=$(ldd --version | head -n1 | grep -Eo '[0-9]+' | tr -d '\n')

	# centos 5 uses glibc 2.5
	[[ $glibcver -eq 25 ]] && echo 'el5' && return 0

	# centos 6 uses glibc 2.12
	[[ $glibcver -eq 212 ]] && echo 'el6' && return 0

	# centos 7 uses glibc 2.17
	[[ $glibcver -eq 217 ]] && echo 'el7' && return 0

	# centos 8 uses glibc 2.28, not yet to be in a seprate dir
	#[[ $glibcver -eq 228 ]] && echo 'el8' && return 0

	# some centos-like dists ships higher version of glibc, fallback to el7
	[[ $glibcver -gt 217 ]] && echo 'el7' && return 0
}

if [[ -z $rpmtopdir ]]; then
    DISTVER=$(GUESS_DIST)
    case $DISTVER in
        amzn1)
            rpmtopdir=amzn1
            ;;
        amzn2)
            rpmtopdir=amzn2
            ;;
        amzn2023)
            rpmtopdir=amzn2023
            ;;
        el7)
            rpmtopdir=el7
            ;;
        el6)
            rpmtopdir=el6
            ;;
        el5)
            rpmtopdir=el5
            # on centos5, it's prefered to use gcc44
	    rpm -q gcc44 && export CC=gcc44
            ;;
        *)
            echo "dist undefined, please specify manualy: el5 el6 el7 amzn1 amzn2 amzn2023"
	    VENDOR=$(rpm --eval '%{?_vendor}')
	    echo -e "Current OS vendor: $VENDOR \n"
	    [[ -f /etc/os-release ]] && cat /etc/os-release
	    [[ -f /etc/redhat-release ]] && cat /etc/redhat-release 
	    [[ -f /etc/system-release ]] && cat /etc/system-release
            exit 1
            ;;
    esac
fi

[[ $rpmtopdir == "GETEL" ]] && GUESS_DIST && exit 0

if [[ ! -d $rpmtopdir ]]; then 
  echo "only work in el5/el6/el7/amzn1/amzn2/amzn2023"
  echo "eg: ${0} el7"
  exit 1
fi

source version.env
SOURCES=( $OPENSSHSRC \
          $OPENSSLSRC \
          $ASKPASSSRC \
)
# only on EL5, perl source is needed.
[[ $rpmtopdir == "el5" ]] && SOURCES+=($PERLSRC)

pushd $rpmtopdir
for fn in ${SOURCES[@]}; do
  CHECKEXISTS $fn && \
    install -v -m666 $__dir/downloads/$fn ./SOURCES/
done

rpmbuild -ba SPECS/openssh.spec --target $(uname -m) --define "_topdir $PWD" \
	--define "opensslver ${OPENSSLVER}" \
	--define "opensshver ${OPENSSHVER}" \
	--define "opensshpkgrel ${PKGREL}" \
	--define "perlver ${PERLVER}" \
	--define 'no_gtk2 1' \
	--define 'skip_gnome_askpass 1' \
	--define 'skip_x11_askpass 1' \
	;
popd

