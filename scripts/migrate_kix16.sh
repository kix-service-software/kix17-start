#!/bin/bash
# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
#
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

LOGFILE=/opt/kix/var/log/migrate_kix16.log

# determine apache user and service
APACHEUSER=wwwrun
APACHESERVICE=apache2
if [ -f /etc/centos-release ] || [ -f /etc/redhat-release ]; then
    APACHEUSER=apache
    APACHESERVICE=httpd
elif [ -f /etc/debian_version ]; then
    APACHEUSER=www-data
fi

# determine KIX16 parameters
cd /opt/kix16
KIX16_VERSION=`cat RELEASE | grep VERSION | cut -d' ' -f3 | sed -e "s/\s*//g"`
KIX16_DBMS=`perl -e 'use Kernel::Config;my %Data;Kernel::Config::Load(\%Data);foreach (keys %Data) {print "$_=$Data{$_}\n"}' | grep "DatabaseDSN=" | cut -d= -f2 | cut -d: -f2`
KIX16_DB=`perl -e 'use Kernel::Config;my %Data;Kernel::Config::Load(\%Data);foreach (keys %Data) {print "$_=$Data{$_}\n"}' | grep "Database=" | cut -d= -f2 | cut -d: -f2`
KIX16_DBUSER=`perl -e 'use Kernel::Config;my %Data;Kernel::Config::Load(\%Data);foreach (keys %Data) {print "$_=$Data{$_}\n"}' | grep "DatabaseUser=" | cut -d= -f2 | cut -d: -f2`
KIX16_DBHOST=`perl -e 'use Kernel::Config;my %Data;Kernel::Config::Load(\%Data);foreach (keys %Data) {print "$_=$Data{$_}\n"}' | grep "DatabaseHost=" | cut -d= -f2 | cut -d: -f2`
KIX16_DBPW=`perl -e 'use Kernel::Config;my %Data;Kernel::Config::Load(\%Data);foreach (keys %Data) {print "$_=$Data{$_}\n"}' | grep "DatabasePw=" | cut -d= -f2 | cut -d: -f2`
KIX16_DBPW=`perl -e 'use Kernel::System::DB; if ( "$ARGV[0]" =~ /^\{(.*)\}$/ ) { my $Result = Kernel::System::DB::_Decrypt({}, "$ARGV[0]");chop($Result);print $Result;} else { print "$ARGV[0]" }' $KIX16_DBPW`;

# determine KIX DBMS and DB
cd /opt/kix
KIX17_VERSION=`cat RELEASE | grep VERSION | cut -d' ' -f3 | sed -e "s/\s*//g"`
KIX17_DBMS=`perl -e 'use Kernel::Config;my %Data;Kernel::Config::Load(\%Data);foreach (keys %Data) {print "$_=$Data{$_}\n"}' | grep "DatabaseDSN=" | cut -d= -f2 | cut -d: -f2`
KIX17_DB=`perl -e 'use Kernel::Config;my %Data;Kernel::Config::Load(\%Data);foreach (keys %Data) {print "$_=$Data{$_}\n"}' | grep "Database=" | cut -d= -f2 | cut -d: -f2`
KIX17_DBUSER=`perl -e 'use Kernel::Config;my %Data;Kernel::Config::Load(\%Data);foreach (keys %Data) {print "$_=$Data{$_}\n"}' | grep "DatabaseUser=" | cut -d= -f2 | cut -d: -f2`
KIX17_DBHOST=`perl -e 'use Kernel::Config;my %Data;Kernel::Config::Load(\%Data);foreach (keys %Data) {print "$_=$Data{$_}\n"}' | grep "DatabaseHost=" | cut -d= -f2 | cut -d: -f2`
KIX17_DBPW=`perl -e 'use Kernel::Config;my %Data;Kernel::Config::Load(\%Data);foreach (keys %Data) {print "$_=$Data{$_}\n"}' | grep "DatabasePw=" | cut -d= -f2 | cut -d: -f2`
KIX17_DBPW=`perl -e 'use Kernel::System::DB; if ( "$ARGV[0]" =~ /^\{(.*)\}$/ ) { my $Result = Kernel::System::DB::_Decrypt({}, "$ARGV[0]");chop($Result);print $Result;} else { print "$ARGV[0]" }' $KIX17_DBPW`;

echo

# check DBMS
if [ "$KIX16_DBMS" != "$KIX17_DBMS" ]; then
    echo ERROR: DBMS mismatch! Migration not possible!
    exit 0
else
    echo "DBMS...OK ($KIX16_DBMS)"
fi

echo
read -r -p "Please enter the destination path for the temporary files, i.e. DB dump (default: /tmp): " TMP_PATH

if [ -z "$TMP_PATH" ]; then
    TMP_PATH=/tmp
fi

echo
echo upgrading from KIX version $KIX16_VERSION to KIX $KIX17_VERSION
echo
echo "PLEASE NOTE:"
echo "Depending on the size of your KIX 16 database this might take a long time."
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
mkdir -p $TMP_PATH/KIX17_migration
chmod 777 $TMP_PATH/KIX17_migration

# create upgrade log
touch $LOGFILE
chmod 777 $LOGFILE

# stop apache, cronjobs and daemon
echo stopping apache service
service $APACHESERVICE stop

echo stopping cronjobs
/opt/kix/bin/Cron.sh stop $APACHEUSER 2>&1 >> $LOGFILE

echo stopping daemon
sudo -u $APACHEUSER /opt/kix/bin/kix.Daemon.pl stop --force 1>> $LOGFILE 2>&1

case $KIX17_DBMS in
    mysql)
        echo "You are using MySQL or MariaDB. Please enter the credentials of the MySQL/MariaDB admin user to continue."
        read -r -p "MySQL/MariaDB admin user: " MYSQL_USER
        read -r -p "MySQL/MariaDB admin user password: " MYSQL_PW

        if [ -n "$KIX16_DBHOST" ]; then
            USE_KIX16_DBHOST=-h$KIX16_DBHOST
        fi

        echo migrating database
        # create dump of old database
        echo "  creating database dump"
        mysqldump $USE_KIX16_DBHOST -u$KIX16_DBUSER -p$KIX16_DBPW $KIX16_DB > $TMP_PATH/KIX17_migration/KIX16_DB.dmp 2>> $LOGFILE

        # special handling for views
        sed -i '/^\/\*\!50013 DEFINER=`.*`@`.*` SQL SECURITY DEFINER \*\/$/d' $TMP_PATH/KIX17_migration/KIX16_DB.dmp 2>> $LOGFILE

        # drop database
        echo "  dropping database"
        mysql -u$MYSQL_USER -p$MYSQL_PW -e "DROP DATABASE $KIX17_DB" 2>&1 >> $LOGFILE

        # re-create database
        echo "  creating new database"
        mysql -u$MYSQL_USER -p$MYSQL_PW -e "CREATE DATABASE $KIX17_DB CHARACTER SET utf8" 2>&1 >> $LOGFILE

        # import old dump
        echo "  importing database dump"
        mysql -u$KIX17_DBUSER -p$KIX17_DBPW $KIX17_DB < $TMP_PATH/KIX17_migration/KIX16_DB.dmp 2>> $LOGFILE
        ;;
    Pg)
        if [ -n "$KIX16_DBHOST" ] && [ "$KIX16_DBHOST" != "localhost" ] && [ "$KIX16_DBHOST" != "127.0.0.1" ]; then
            USE_KIX16_DBHOST="-h $KIX16_DBHOST"
        fi

        echo migrating database
        # create dump of old database
        echo "  creating database dump"
        sudo -u postgres bash -c "pg_dump $USE_KIX16_DBHOST $KIX16_DB -f $TMP_PATH/KIX17_migration/KIX16_DB.dmp 2>&1 >> $LOGFILE"

        # drop database
        echo "  dropping database"
        sudo -u postgres bash -c "dropdb $KIX17_DB 2>&1 >> $LOGFILE"

        # re-create database
        echo "  creating new database"
        sudo -u postgres bash -c "createdb -T template0 -E UTF8 -O kix $KIX17_DB 2>&1 >> $LOGFILE"

        # import old dump
        echo "  importing database dump"
        export PGPASSWORD=$KIX17_DBPW;export PGOPTIONS='--client-min-messages=warning';psql -q -h localhost -U kix $KIX17_DB -f $TMP_PATH/KIX17_migration/KIX16_DB.dmp 2>> $LOGFILE >> $LOGFILE
        ;;

esac

# disable hard error handling
set +e

# upgrade database and cleanup obsolete packages
echo upgrading database
sudo -u $APACHEUSER bash -c "/opt/kix/scripts/database/update/kix-upgrade-to-17.pl -f 16 >> $LOGFILE 2>&1"

# migrate config
echo migrating config
for FILE in ZZZAuto.pm ZZZACL.pm ZZZProcessManagement.pm; do
    if [ -f /opt/kix16/Kernel/Config/Files/$FILE ]; then
        cp -vpf /opt/kix16/Kernel/Config/Files/$FILE /opt/kix/Kernel/Config/Files 2>&1 >> $LOGFILE
    fi
done

# clear user skins
echo removing skin setting from user preferences
sudo -u $APACHEUSER bash -c "/opt/kix/bin/kix.Console.pl Admin::User::ClearPreferences --key UserSkin >> $LOGFILE 2>&1"

# remove temporary directory
rm -rf $TMP_PATH/KIX17_migration

echo rebuilding config
sudo -u $APACHEUSER bash -c "/opt/kix/bin/kix.Console.pl Maint::Config::Rebuild 2>&1 >> $LOGFILE"

echo deleting caches
sudo -u $APACHEUSER bash -c "/opt/kix/bin/kix.Console.pl Maint::Cache::Delete 2>&1 >> $LOGFILE"
sudo -u $APACHEUSER bash -c "/opt/kix/bin/kix.Console.pl Maint::Loader::CacheCleanup 2>&1 >> $LOGFILE"

echo
echo "*****************************************************************************************"
echo "The migration has been finished. Cronjobs, the daemon and the webserver are still stopped."
echo "Please check the migration log and Support Data Collector for errors."
echo "You can find the migration log file here: $LOGFILE"
echo
echo "Now copy your changes in $KIX16_PATH/Kernel/Config.pm to /opt/kix/Kernel/Config.pm."
echo "Also please copy your old SystemID setting to the KIX Config.pm."
echo "(Do not change the other settings that are already contained in the KIX Config.pm!!!)"
echo
echo "Afterwards please re-install the remaining installed packages using the package manager"
echo "*****************************************************************************************"
