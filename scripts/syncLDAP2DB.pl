#!/usr/bin/perl
# --
# Modified version of the work: Copyright (C) 2006-2023 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2023 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;

use File::Basename;
use FindBin qw($RealBin);
use lib dirname($RealBin);
use lib dirname($RealBin) . "/Kernel/cpan-lib";
use lib dirname($RealBin) . "/Custom";

use Net::LDAP;
use Kernel::System::ObjectManager;

# create object manager
local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Kernel::System::Log' => {
        LogPrefix => 'syncLDAP2DB',
    },
);

my $UidLDAP = 'uid';
my $UidDB   = 'login';

my %Map = (
    email       => 'mail',
    customer_id => 'mail',
    first_name  => 'sn',
    last_name   => 'givenname',
    pw          => 'test',
    comments    => 'postaladdress',
);

my $LDAPHost    = 'bay.csuhayward.edu';
my %LDAPParams  = ();
my $LDAPBaseDN  = 'ou=seas,o=csuh';
my $LDAPBindDN  = '';
my $LDAPBindPW  = '';
my $LDAPScope   = 'sub';
my $LDAPCharset = 'utf-8';
my $LDAPFilter  = '(ObjectClass=*)';
my $DBCharset   = 'utf-8';
my $DBTable     = 'customer_user';

# ldap connect and bind (maybe with SearchUserDN and SearchUserPw)
my $LDAP = Net::LDAP->new( $LDAPHost, %LDAPParams ) || die "$@";
if (
    !$LDAP->bind(
        dn       => $LDAPBindDN,
        password => $LDAPBindPW
    )
) {
    $Kernel::OM->Get('Kernel::System::Log')->Log(
        Priority => 'error',
        Message  => "Bind failed!",
    );
    exit 1;
}

# split request of all accounts
my $DBObject = $Kernel::OM->Get('Kernel::System::DB');
for my $Prefix ( "0" .. "9", "a" .. "z" ) {
    my $Filter = "($UidLDAP=$Prefix*)";
    if ($LDAPFilter) {
        $Filter = "(&$LDAPFilter$Filter)";
    }

    # perform user search
    my $Result = $LDAP->search(
        base   => $LDAPBaseDN,
        scope  => $LDAPScope,
        filter => $Filter,
    );

    #print "F: ($UidLDAP=$Prefix*)\n";
    for my $Entry ( $Result->all_entries() ) {
        my $UID = $Entry->get_value($UidLDAP);
        if ($UID) {

            # check if uid exists in db
            my $Insert = 1;
            $DBObject->Prepare(
                SQL   => "SELECT $UidDB FROM $DBTable WHERE $UidDB = ?",
                Bind  => [ \$UID ],
                Limit => 1,
            );

            while ( my @Row = $DBObject->FetchrowArray() ) {
                $Insert = 0;
            }

            my $SQLPre  = '';
            my $SQLPost = '';
            my $Type    = '';
            if ($Insert) {
                $Type = 'INSERT';
            }
            else {
                $Type = 'UPDATE';
            }

            for my $Key ( sort keys %Map ) {
                my $Value = $DBObject->Quote(
                    _ConvertTo( $Entry->get_value( $Map{$Key} ) )
                );
                if ( $Type eq 'UPDATE' ) {
                    if ($SQLPre) {
                        $SQLPre .= ", ";
                    }
                    $SQLPre .= " $Key = '$Value'";
                }
                else {
                    if ($SQLPre) {
                        $SQLPre .= ", ";
                    }
                    $SQLPre .= "$Key";
                    if ($SQLPost) {
                        $SQLPost .= ", ";
                    }
                    $SQLPost .= "'$Value'";
                }
            }

            my $SQL = '';

            if ( $Type eq 'UPDATE' ) {
                print "UPDATE: $UID\n";
                $SQL =
                    "UPDATE $DBTable"
                    . " SET $SQLPre, valid_id = 1, change_time = current_timestamp, change_by = 1"
                    . " WHERE $UidDB = ?";
            }
            else {
                print "INSERT: $UID\n";
                $SQL =
                    "INSERT INTO $DBTable ($SQLPre, $UidDB, valid_id, create_time, create_by, change_time, change_by)"
                    . " VALUES ($SQLPost, ?, 1, current_timestamp, 1, current_timestamp, 1)";
            }

            $DBObject->Do(
                SQL  => $SQL,
                Bind => [ \$UID ],
            );
        }
    }
}

sub _ConvertTo {
    my $Text = shift;

    return '' if !$Text;

    return $Text if $DBCharset eq $LDAPCharset;

    return $Kernel::OM->Get('Kernel::System::Encode')->Convert(
        Text => $Text,
        To   => $DBCharset,
        From => $LDAPCharset,
    );
}

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
