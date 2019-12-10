#!/bin/sh

#ISO_DOWNLOAD_URL=https://download.freebsd.org/ftp/releases/ISO-IMAGES/12.0

MEMSTICK_IMG_RELEASE_12=FreeBSD-12.0-RELEASE-amd64-mini-memstick.img.xz
MEMSTICK_IMG_DOWNLOAD_URL_RELEASE_12=https://download.freebsd.org/ftp/releases/ISO-IMAGES/12.0

MEMSTICK_IMG=${MEMSTICK_IMG:-${MEMSTICK_IMG_RELEASE_12}}
MEMSTICK_IMG_DOWNLOAD_URL=${MEMSTICK_IMG_DOWNLOAD_URL:-${MEMSTICK_IMG_DOWNLOAD_URL_RELEASE_12}}

[ -f ${MEMSTICK_IMG} ] || fetch ${MEMSTICK_IMG_DOWNLOAD_URL}/${MEMSTICK_IMG}

if [ "X`file ${MEMSTICK_IMG} | awk -F: '{ print $2 }'`" = "X XZ compressed data" ]; then
	IMG="bcwipe-`basename ${MEMSTICK_IMG} .xz`"
	[ -f ${IMG} ] || xzcat ${MEMSTICK_IMG} > ${IMG}
else
	IMG="bcwipe-${MEMSTICK_IMG}"
	[ -f ${IMG} ] || cp ${MEMSTICK_IMG} > ${IMG}
fi

echo ${IMG_MNT:="./mnt"}

md=`sudo mdconfig -a -t vnode -f ${IMG}`
echo ${md}

sudo gpart list ${md}

[ -d mnt ] || mkdir ${IMG_MNT}
sudo mount /dev/${md}s2a ${IMG_MNT}

ls -l ${IMG_MNT}

sudo umount ${IMG_MNT}

sudo mdconfig -d -u ${md}

