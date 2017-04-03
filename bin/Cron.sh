#!/bin/sh
# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

CURRENTUSER=`whoami`
CRON_USER="$2"

# check if a common user try to use -u
if test -n "$CRON_USER"; then
    if test $CURRENTUSER != root; then
#rbo - T2016121190001552 - replaced OTRS wording
        echo "Run this script just as webserver user! Or use 'Cron.sh {start|stop|restart} <webserver user>' as root!"
        exit 5
    fi
fi

# check if the cron user is specified
if test -z "$CRON_USER"; then
    if test $CURRENTUSER = root; then
#rbo - T2016121190001552 - replaced OTRS wording
        echo "Run this script just as webserver user! Or use 'Cron.sh {start|stop|restart} <webserver user>' as root!"
        exit 5
    fi
fi

# find otrs root
cd "`dirname $0`/../"
#rbo - T2016121190001552 - replaced OTRS wording
KIX_HOME="`pwd`"
cd -

#rbo - T2016121190001552 - replaced OTRS wording
if test -e $KIX_HOME/var/cron; then
    KIX_ROOT=$KIX_HOME
else
    echo "No cronjobs in $KIX_HOME/var/cron found!";
    echo " * Check the \$HOME (/etc/passwd) of the OTRS user. It must be the root dir of your OTRS system (e. g. /opt/otrs). ";
    exit 5;
fi

#rbo - T2016121190001552 - replaced OTRS wording
CRON_DIR=$KIX_ROOT/var/cron
CRON_TMP_FILE=$KIX_ROOT/var/tmp/otrs-cron-tmp.$$

#rbo - T2016121190001552 - replaced OTRS wording
echo "Cron.sh - start/stop KIX cronjobs"

#
# main part
#
case "$1" in
    # ------------------------------------------------------
    # start
    # ------------------------------------------------------
    start)
        # add -u to cron user if user exists
        if test -n "$CRON_USER"; then
            CRON_USER=" -u $CRON_USER"
        fi

        if mkdir -p $CRON_DIR; cd $CRON_DIR && ls -d * | grep -Ev "(\.(dist|rpm|bak|backup|custom_backup|save|swp)|\~)$" | xargs cat > $CRON_TMP_FILE && crontab $CRON_USER $CRON_TMP_FILE; then

            rm -rf $CRON_TMP_FILE
            echo "(using $KIX_ROOT) done";
            exit 0;
        else
            echo "failed";
            exit 1;
        fi
    ;;
    # ------------------------------------------------------
    # stop
    # ------------------------------------------------------
    stop)
        # add -u to cron user if user exists
        if test -n "$CRON_USER"; then
            CRON_USER=" -u $CRON_USER"
        fi

        if crontab $CRON_USER -r ; then
            echo "done";
            exit 0;
        else
            echo "failed";
            exit 1;
        fi
    ;;
    # ------------------------------------------------------
    # restart
    # ------------------------------------------------------
    restart)
        $0 stop "$CRON_USER"
        $0 start "$CRON_USER"
    ;;
    # ------------------------------------------------------
    # Usage
    # ------------------------------------------------------
    *)
    echo "Usage: $0 {start|stop|restart}"
    exit 1
esac
