# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2024 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::CustomerCompany::Preferences::DB;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Cache',
    'Kernel::System::DB',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{CacheType} = 'CustomerCompanyPreferencesDB';
    $Self->{CacheTTL}  = 60 * 60 * 24 * 20;

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # preferences table data
    $Self->{PreferencesTable} = $ConfigObject->Get('CustomerCompany::PreferencesModule')->{Params}->{Table}
        || 'kix_customer_company_prefs';
    $Self->{PreferencesTableKey} = $ConfigObject->Get('CustomerCompany::PreferencesModule')->{Params}->{TableKey}
        || 'preferences_key';
    $Self->{PreferencesTableValue} = $ConfigObject->Get('CustomerCompany::PreferencesModule')->{Params}->{TableValue}
        || 'preferences_value';
    $Self->{PreferencesTableUserID} = $ConfigObject->Get('CustomerCompany::PreferencesModule')->{Params}->{TableUserID}
        || 'user_id';

    # set lower if database is case sensitive
    $Self->{Lower} = '';
    if ( $Kernel::OM->Get('Kernel::System::DB')->GetDatabaseFunction('CaseSensitive') ) {
        $Self->{Lower} = 'LOWER';
    }

    # create cache prefix
    $Self->{CachePrefix} = 'CustomerCompanyPreferencesDB'
        . $Self->{PreferencesTable}
        . $Self->{PreferencesTableKey}
        . $Self->{PreferencesTableValue}
        . $Self->{PreferencesTableUserID};

    return $Self;
}

sub SetPreferences {
    my ( $Self, %Param ) = @_;

    return if !$Param{CustomerID};
    return if !$Param{Key};

    my $Value = defined $Param{Value} ? $Param{Value} : '';

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # delete old data
    return if !$DBObject->Do(
        SQL => "DELETE FROM $Self->{PreferencesTable}"
             . " WHERE $Self->{PreferencesTableUserID} = ?"
             . "  AND $Self->{PreferencesTableKey} = ?",
        Bind => [ \$Param{CustomerID}, \$Param{Key} ],
    );

    # insert new data
    return if !$DBObject->Do(
        SQL => "INSERT INTO $Self->{PreferencesTable}"
             . " ($Self->{PreferencesTableUserID}, $Self->{PreferencesTableKey}, $Self->{PreferencesTableValue})"
             . " VALUES (?, ?, ?)",
        Bind => [ \$Param{CustomerID}, \$Param{Key}, \$Value ],
    );

    # delete cache
    $Kernel::OM->Get('Kernel::System::Cache')->Delete(
        Type => $Self->{CacheType},
        Key  => $Self->{CachePrefix} . $Param{CustomerID},
    );

    return 1;
}

=item RenamePreferences()

rename the old Customerid with the new Customerid in the preferences

returns 1 if success or undef otherwise

    my $Success = $PreferencesObject->RenamePreferences(
        NewCustomerID => 2,
        OldCustomerID => 1,
    );

=cut

sub RenamePreferences {
    my ( $Self, %Param ) = @_;

    return if !$Param{NewCustomerID};
    return if !$Param{OldCustomerID};

    # update the preferences
    return if !$Kernel::OM->Get('Kernel::System::DB')->Prepare(
        SQL => "UPDATE $Self->{PreferencesTable}"
             . " SET $Self->{PreferencesTableUserID} = ?"
             . " WHERE $Self->{PreferencesTableUserID} = ?",
        Bind => [ \$Param{NewCustomerID}, \$Param{OldCustomerID}, ],
    );

    # delete cache
    $Kernel::OM->Get('Kernel::System::Cache')->Delete(
        Type => $Self->{CacheType},
        Key  => $Self->{CachePrefix} . $Param{OldCustomerID},
    );

    return 1;
}

sub GetPreferences {
    my ( $Self, %Param ) = @_;

    return if !$Param{CustomerID};

    # read cache
    my $Cache = $Kernel::OM->Get('Kernel::System::Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $Self->{CachePrefix} . $Param{CustomerID},
    );
    return %{$Cache} if $Cache;

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # get preferences
    return if !$DBObject->Prepare(
        SQL => "SELECT $Self->{PreferencesTableKey}, $Self->{PreferencesTableValue}"
             . " FROM $Self->{PreferencesTable}"
             . " WHERE $Self->{PreferencesTableUserID} = ?",
        Bind => [ \$Param{CustomerID} ],
    );

    # fetch the result
    my %Data;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Data{ $Row[0] } = $Row[1];
    }

    # set cache
    $Kernel::OM->Get('Kernel::System::Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $Self->{CachePrefix} . $Param{CustomerID},
        Value => \%Data,
    );

    return %Data;
}

sub SearchPreferences {
    my ( $Self, %Param ) = @_;

    my $Key   = $Param{Key}   || '';
    my $Value = $Param{Value} || '';

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    my $Lower = '';
    if ( $DBObject->GetDatabaseFunction('CaseSensitive') ) {
        $Lower = 'LOWER';
    }

    my $SQL = "SELECT $Self->{PreferencesTableUserID}, $Self->{PreferencesTableValue}"
            . " FROM $Self->{PreferencesTable}"
            . " WHERE $Self->{PreferencesTableKey} = ?";
    my @Bind = ( \$Key );

    if ($Value) {
        $SQL .= " AND $Lower($Self->{PreferencesTableValue}) LIKE $Lower(?)";
        push @Bind, \$Value;
    }

    # get preferences
    return if !$DBObject->Prepare(
        SQL  => $SQL,
        Bind => \@Bind,
    );

    # fetch the result
    my %CustomerID;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $CustomerID{ $Row[0] } = $Row[1];
    }

    return %CustomerID;
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
