#!/bin/bash
# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Rene(dot)Boehm(at)cape(dash)it(dot)de
# --
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU AFFERO General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301 USA
# or see http://www.gnu.org/licenses/agpl.txt.
# --

LOGFILE=/opt/kix/var/log/migrate_otrs2kix.log

echo
read -r -p "Please enter the path to the OTRS installation (default: /opt/otrs): " OTRS_PATH

if [ -z "$OTRS_PATH" ]; then
    OTRS_PATH=/opt/otrs
fi

# determine apache user
APACHEUSER=wwwrun
if [ -f /etc/centos-release ] || [ -f /etc/redhat-release ]; then
    APACHEUSER=apache
elif [ -f /etc/debian_version ]; then
    APACHEUSER=www-data
fi

# determine OTRS parameters
cd $OTRS_PATH
OTRS_VERSION=`cat RELEASE | grep VERSION | cut -d' ' -f3 | sed -e "s/\s*//g"`
OTRS_DBMS=`perl -e 'use Kernel::Config;my %Data;Kernel::Config::Load(\%Data);foreach (keys %Data) {print "$_=$Data{$_}\n"}' | grep "DatabaseDSN=" | cut -d= -f2 | cut -d: -f2`
OTRS_DB=`perl -e 'use Kernel::Config;my %Data;Kernel::Config::Load(\%Data);foreach (keys %Data) {print "$_=$Data{$_}\n"}' | grep "Database=" | cut -d= -f2 | cut -d: -f2`
OTRS_DBUSER=`perl -e 'use Kernel::Config;my %Data;Kernel::Config::Load(\%Data);foreach (keys %Data) {print "$_=$Data{$_}\n"}' | grep "DatabaseUser=" | cut -d= -f2 | cut -d: -f2`
OTRS_DBHOST=`perl -e 'use Kernel::Config;my %Data;Kernel::Config::Load(\%Data);foreach (keys %Data) {print "$_=$Data{$_}\n"}' | grep "DatabaseHost=" | cut -d= -f2 | cut -d: -f2`
OTRS_DBPW=`perl -e 'use Kernel::Config;my %Data;Kernel::Config::Load(\%Data);foreach (keys %Data) {print "$_=$Data{$_}\n"}' | grep "DatabasePw=" | cut -d= -f2 | cut -d: -f2`
OTRS_DBPW=`perl -e 'use Kernel::System::DB; if ( "$ARGV[0]" =~ /^\{(.*)\}$/ ) { my $Result = Kernel::System::DB::_Decrypt({}, "$ARGV[0]");chop($Result);print $Result;} else { print "$ARGV[0]" }' $OTRS_DBPW`;

# determine KIX DBMS and DB
cd /opt/kix
KIX_FRAMEWORK=`cat RELEASE | grep FRAMEWORK | cut -d' ' -f3 | sed -e "s/\s*//g"`
KIX_DBMS=`perl -e 'use Kernel::Config;my %Data;Kernel::Config::Load(\%Data);foreach (keys %Data) {print "$_=$Data{$_}\n"}' | grep "DatabaseDSN=" | cut -d= -f2 | cut -d: -f2`
KIX_DB=`perl -e 'use Kernel::Config;my %Data;Kernel::Config::Load(\%Data);foreach (keys %Data) {print "$_=$Data{$_}\n"}' | grep "Database=" | cut -d= -f2 | cut -d: -f2`
KIX_DBUSER=`perl -e 'use Kernel::Config;my %Data;Kernel::Config::Load(\%Data);foreach (keys %Data) {print "$_=$Data{$_}\n"}' | grep "DatabaseUser=" | cut -d= -f2 | cut -d: -f2`
KIX_DBHOST=`perl -e 'use Kernel::Config;my %Data;Kernel::Config::Load(\%Data);foreach (keys %Data) {print "$_=$Data{$_}\n"}' | grep "DatabaseHost=" | cut -d= -f2 | cut -d: -f2`
KIX_DBPW=`perl -e 'use Kernel::Config;my %Data;Kernel::Config::Load(\%Data);foreach (keys %Data) {print "$_=$Data{$_}\n"}' | grep "DatabasePw=" | cut -d= -f2 | cut -d: -f2`
KIX_DBPW=`perl -e 'use Kernel::System::DB; if ( "$ARGV[0]" =~ /^\{(.*)\}$/ ) { my $Result = Kernel::System::DB::_Decrypt({}, "$ARGV[0]");chop($Result);print $Result;} else { print "$ARGV[0]" }' $KIX_DBPW`;

echo

# check frameworks
if [ "$OTRS_VERSION" != "$KIX_FRAMEWORK" ]; then
    echo "ERROR: version mismatch ($OTRS_VERSION vs. $KIX_FRAMEWORK)! Migration not possible!"
    exit 0
else
    echo "framework version...OK ($OTRS_VERSION)"
fi

# check DBMS
if [ "$OTRS_DBMS" != "$KIX_DBMS" ]; then
    echo ERROR: DBMS mismatch! Migration not possible!
    exit 0
else
    echo "DBMS...OK ($OTRS_DBMS)"
fi

echo
read -r -p "Please enter the destination path for the temporary files, i.e. DB dump (default: /tmp): " TMP_PATH

if [ -z "$TMP_PATH" ]; then
    TMP_PATH=/tmp
fi

echo
echo upgrading from OTRS version $OTRS_VERSION to KIX
echo
echo "PLEASE NOTE:"
echo "Depending on the size of your OTRS database this might take a long time."
echo
read -r -p "Continue? [y/N] " response
case $response in
    [yY])
        ;;
    *)
        exit
        ;;
esac

# create temporary directory
mkdir -p $TMP_PATH/kix_migration
chmod 777 $TMP_PATH/kix_migration

# create upgrade log
touch $LOGFILE
chmod 777 $LOGFILE

# stop apache, cronjobs and daemon
echo stopping apache service
service apache2 stop

echo stopping cronjobs
/opt/kix/bin/Cron.sh stop $APACHEUSER 2>&1 >> $LOGFILE

echo stopping daemon
sudo -u $APACHEUSER /opt/kix/bin/kix.Daemon.pl stop --force 1>> $LOGFILE 2>&1

case $KIX_DBMS in
    mysql)
        echo "You are using MySQL or MariaDB. Please enter the credentials of the MySQL/MariaDB admin user to continue."
        read -r -p "MySQL/MariaDB admin user: " MYSQL_USER
        read -r -p "MySQL/MariaDB admin user password: " MYSQL_PW

        if [ -n "$OTRS_DBHOST" ]; then
            USE_OTRS_DBHOST=-h$OTRS_DBHOST
        fi

        echo migrating database
        # create dump of old database
        echo "  creating database dump"
        mysqldump $USE_OTRS_DBHOST -u$OTRS_DBUSER -p$OTRS_DBPW $OTRS_DB > $TMP_PATH/kix_migration/kix_db.dmp 2>> $LOGFILE

        # special handling for views
        sed -i '/^\/\*\!50013 DEFINER=`.*`@`.*` SQL SECURITY DEFINER \*\/$/d' $TMP_PATH/kix_migration/kix_db.dmp 2>> $LOGFILE

        # drop database
        echo "  dropping database"
        mysql -u$MYSQL_USER -p$MYSQL_PW -e "DROP DATABASE $KIX_DB" 2>&1 >> $LOGFILE

        # re-create database
        echo "  creating new database"
        mysql -u$MYSQL_USER -p$MYSQL_PW -e "CREATE DATABASE $KIX_DB CHARACTER SET utf8" 2>&1 >> $LOGFILE

        # import old dump
        echo "  importing database dump"
        mysql -u$KIX_DBUSER -p$KIX_DBPW $KIX_DB < $TMP_PATH/kix_migration/kix_db.dmp 2>> $LOGFILE
        ;;
    Pg)
        if [ -n "$OTRS_DBHOST" ] && [ "$OTRS_DBHOST" != "localhost" ] && [ "$OTRS_DBHOST" != "127.0.0.1" ]; then
            USE_OTRS_DBHOST="-h $OTRS_DBHOST"
        fi

        echo migrating database
        # create dump of old database
        echo "  creating database dump"
        sudo -u postgres bash -c "pg_dump $USE_OTRS_DBHOST $OTRS_DB -f $TMP_PATH/kix_migration/kix_db.dmp 2>&1 >> $LOGFILE"

        # drop database
        echo "  dropping database"
        sudo -u postgres bash -c "dropdb $KIX_DB 2>&1 >> $LOGFILE"

        # re-create database
        echo "  creating new database"
        sudo -u postgres bash -c "createdb -T template0 -E UTF8 -O kix $KIX_DB 2>&1 >> $LOGFILE"

        # import old dump
        echo "  importing database dump"
        export PGPASSWORD=$KIX_DBPW;export PGOPTIONS='--client-min-messages=warning';psql -q -h localhost -U kix $KIX_DB -f $TMP_PATH/kix_migration/kix_db.dmp 2>> $LOGFILE >> $LOGFILE
        ;;

esac

# disable hard error handling
set +e

# upgrade database and cleanup obsolete packages
sudo -u $APACHEUSER bash -c "/opt/kix/scripts/database/update/kix-upgrade-to-17.pl -f otrs >> $LOGFILE 2>&1"

# migrate config
echo migrating OTRS config
for FILE in ZZZAuto.pm ZZZACL.pm ZZZProcessManagement.pm; do
    if [ -f $OTRS_PATH/Kernel/Config/Files/$FILE ]; then
        cp -vpf $OTRS_PATH/Kernel/Config/Files/$FILE /opt/kix/Kernel/Config/Files 2>&1 >> $LOGFILE
    fi
done

# clear user skins
sudo -u $APACHEUSER bash -c "/opt/kix/bin/kix.Console.pl Admin::User::ClearPreferences --key UserSkin >> $LOGFILE 2>&1"

# remove double entries in package_repository due to force install
sudo -u $APACHEUSER bash -c "/opt/kix/bin/kix.Console.pl Admin::KIX::CleanupPackageRepository >> $LOGFILE 2>&1"

# remove temporary directory
rm -rf $TMP_PATH/kix_migration

echo rebuilding config
sudo -u $APACHEUSER bash -c "/opt/kix/bin/kix.Console.pl Maint::Config::Rebuild 2>&1 >> $LOGFILE"

echo deleting caches
sudo -u $APACHEUSER bash -c "/opt/kix/bin/kix.Console.pl Maint::Cache::Delete 2>&1 >> $LOGFILE"
sudo -u $APACHEUSER bash -c "/opt/kix/bin/kix.Console.pl Maint::Loader::CacheCleanup 2>&1 >> $LOGFILE"

echo
echo "*****************************************************************************************"
echo "The migration has been finished. Cronjobs, the daemon and the webserver are still stopped."
echo
echo "Now copy your changes in $OTRS_PATH/Kernel/Config.pm to /opt/kix/Kernel/Config.pm."
echo "Also please copy your old OTRS SystemID setting to the KIX Config.pm."
echo "(Do not change the other settings that are already contained in the KIX Config.pm!!!)"
echo
echo "Afterwards please re-install the remaining installed packages using the package manager"
echo "*****************************************************************************************"
