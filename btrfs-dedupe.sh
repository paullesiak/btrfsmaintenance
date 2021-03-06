#!/bin/sh
#
# Copyright (c) 2014 SuSE Linux AG, Nuernberg, Germany.
#
# please send bugfixes or comments to http://www.suse.de/feedback.

#
# paranoia settings
#
umask 022
PATH=/sbin:/bin:/usr/sbin:/usr/bin
export PATH

if [ -f /etc/sysconfig/btrfsmaintenance ] ; then
    . /etc/sysconfig/btrfsmaintenance
fi

if [ -f /etc/default/btrfsmaintenance ] ; then
    . /etc/default/btrfsmaintenance
fi

LOGIDENTIFIER='btrfs-dedupe'
. $(dirname $(realpath $0))/btrfsmaintenance-functions

{
evaluate_auto_mountpoint BTRFS_BALANCE_MOUNTPOINTS
OIFS="$IFS"
IFS=:
exec 2>&1 # redirect stderr to stdout to catch all output to log destination
for MM in $BTRFS_BALANCE_MOUNTPOINTS; do
        hr
	IFS="$OIFS"
	if [ $(stat -f --format=%T "$MM") != "btrfs" ]; then
		echo "Path $MM is not btrfs, skipping"
		continue
	fi
	echo "Before dedupe of $MM"
	btrfs filesystem usage "$MM" | indent
	df -H "$MM" | indent
        echo "Running dedupe $MM"

	duperemove -rdxh --hashfile=$(mktemp) $MM | grep -v -E '(csum|Skipping|Try to dedupe)' | indent

	echo "After dedupe of $MM"
	btrfs filesystem usage "$MM" | indent
	df -H "$MM" | indent
done

} | \
case "$BTRFS_LOG_OUTPUT" in
	stdout) cat;;
	journal) systemd-cat -t "$LOGIDENTIFIER";;
	syslog) logger -t "$LOGIDENTIFIER";;
	none) cat >/dev/null;;
	*) cat;;
esac

exit 0
