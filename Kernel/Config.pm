# --
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www-cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Config;

use strict;
use warnings;
use utf8;

sub Load {
    my $Self = shift;

    # ---------------------------------------------------- #
    # database settings                                    #
    # ---------------------------------------------------- #

    # The database host
    $Self->{DatabaseHost} = '__DBHOST__';

    # The database name
    $Self->{Database} = '__DBNAME__';

    # The database user
    $Self->{DatabaseUser} = '__DBUSER__';

    # The password of database user. You also can use bin/otrs.
    # for crypted passwords
    $Self->{DatabasePw} = '__DBPASSWORD__';

    # The database DSN
    $Self->{DatabaseDSN} = "DBI:__DBD__:__DBATTR__=$Self->{Database};host=$Self->{DatabaseHost};";

    # ---------------------------------------------------- #
    # fs root directory
    # ---------------------------------------------------- #
    $Self->{Home} = '/opt/kix';
    $Self->{'Frontend::WebPath'} = '/kix-web/';
    $Self->{ScriptAlias} = 'kix/';
    
    # --------------------------------------------------- #
    # LogModule                                           #
    # --------------------------------------------------- #
    $Self->{'LogModule'} = 'Kernel::System::Log::File';
    $Self->{'LogModule::LogFile'} = $Self->{Home}.'/var/log/kix.log';
    $Self->{'LogModule::LogFile::Date'} = 1;    

    # ---------------------------------------------------- #
    # insert your own config settings "here"               #
    # config settings taken from Kernel/Config/Defaults.pm #
    # ---------------------------------------------------- #
    $Self->{CheckMXRecord} = 0;
    $Self->{SecureMode} = 1;
    $Self->{SystemID} = 17;
    $Self->{FQDN} = '__FQDN__';
        
    # ---------------------------------------------------- #

    # ---------------------------------------------------- #
    # data inserted by installer                           #
    # ---------------------------------------------------- #
    # $DIBI$

    # ---------------------------------------------------- #
    # ---------------------------------------------------- #
    #                                                      #
    # end of your own config options!!!                    #
    #                                                      #
    # ---------------------------------------------------- #
    # ---------------------------------------------------- #
}

# ---------------------------------------------------- #
# needed system stuff (don't edit this)                #
# ---------------------------------------------------- #
use strict;
use warnings;

use vars qw(@ISA);

use Kernel::Config::Defaults;
push (@ISA, 'Kernel::Config::Defaults');

# -----------------------------------------------------#

1;
