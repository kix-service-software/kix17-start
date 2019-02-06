# --
# Modified version of the work: Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2019 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::CustomerCompany::DB;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::Cache',
    'Kernel::System::DB',
    'Kernel::System::Log',
    'Kernel::System::Valid',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # check needed data
    for my $Needed (qw( PreferencesObject CustomerCompanyMap )) {
        $Self->{$Needed} = $Param{$Needed} || die "Got no $Needed!";
    }

    # config options
    $Self->{CustomerCompanyTable} = $Self->{CustomerCompanyMap}->{Params}->{Table}
        || die "Need CustomerCompany->Params->Table in Kernel/Config.pm!";
    $Self->{CustomerCompanyKey} = $Self->{CustomerCompanyMap}->{CustomerCompanyKey}
        || die "Need CustomerCompany->CustomerCompanyKey in Kernel/Config.pm!";
    $Self->{CustomerCompanyValid} = $Self->{CustomerCompanyMap}->{'CustomerCompanyValid'};
    $Self->{SearchListLimit}      = $Self->{CustomerCompanyMap}->{'CustomerCompanySearchListLimit'} || 50000;
    $Self->{SearchPrefix}         = $Self->{CustomerCompanyMap}->{'CustomerCompanySearchPrefix'};
    if ( !defined( $Self->{SearchPrefix} ) ) {
        $Self->{SearchPrefix} = '';
    }
    $Self->{SearchSuffix} = $Self->{CustomerCompanyMap}->{'CustomerCompanySearchSuffix'};
    if ( !defined( $Self->{SearchSuffix} ) ) {
        $Self->{SearchSuffix} = '*';
    }

    # create cache object, but only if CacheTTL is set in customer config
    if ( $Self->{CustomerCompanyMap}->{CacheTTL} ) {
        $Self->{CacheObject} = $Kernel::OM->Get('Kernel::System::Cache');
        $Self->{CacheType}   = 'CustomerCompany' . $Param{Count};
        $Self->{CacheTTL}    = $Self->{CustomerCompanyMap}->{CacheTTL} || 0;
    }

    # get database object
    $Self->{DBObject} = $Kernel::OM->Get('Kernel::System::DB');

    # create new db connect if DSN is given
    if ( $Self->{CustomerCompanyMap}->{Params}->{DSN} ) {
        $Self->{DBObject} = Kernel::System::DB->new(
            DatabaseDSN  => $Self->{CustomerCompanyMap}->{Params}->{DSN},
            DatabaseUser => $Self->{CustomerCompanyMap}->{Params}->{User},
            DatabasePw   => $Self->{CustomerCompanyMap}->{Params}->{Password},
            Type         => $Self->{CustomerCompanyMap}->{Params}->{Type} || '',
        ) || die('Can\'t connect to database!');

        # remember that we have the DBObject not from parent call
        $Self->{NotParentDBObject} = 1;
    }

    # this setting specifies if the table has the create_time,
    # create_by, change_time and change_by fields of OTRS
    $Self->{ForeignDB} = $Self->{CustomerCompanyMap}->{Params}->{ForeignDB} ? 1 : 0;

    # defines if the database search will be performend case sensitive (1) or not (0)
    $Self->{CaseSensitive} = $Self->{CustomerCompanyMap}->{Params}->{SearchCaseSensitive}
        // $Self->{CustomerCompanyMap}->{Params}->{CaseSensitive} || 0;

    return $Self;
}

sub CustomerCompanyList {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    my $Valid = 1;
    if ( !$Param{Valid} && defined( $Param{Valid} ) ) {
        $Valid = 0;
    }

    my $Limit = $Param{Limit} // $Self->{SearchListLimit};

    my $CacheType;
    my $CacheKey;

    # check cache
    if ( $Self->{CacheObject} ) {

        $CacheType = $Self->{CacheType} . '_CustomerCompanyList';
        $CacheKey = "CustomerCompanyList::${Valid}::${Limit}::" . ( $Param{Search} || '' );

        my $Data = $Self->{CacheObject}->Get(
            Type => $CacheType,
            Key  => $CacheKey,
        );
        return %{$Data} if ref $Data eq 'HASH';
    }

    # what is the result
    my $What = join(
        ', ',
        @{ $Self->{CustomerCompanyMap}->{CustomerCompanyListFields} }
    );

    # add valid option if required
    my $SQL;
    my @Bind;

    if ($Valid) {

        # get valid object
        my $ValidObject = $Kernel::OM->Get('Kernel::System::Valid');

        $SQL
            .= "$Self->{CustomerCompanyValid} IN ( ${\(join ', ', $ValidObject->ValidIDsGet())} )";
    }

    # where
    if ( $Param{Search} ) {

        my @Parts = split /\+/, $Param{Search}, 6;
        for my $Part (@Parts) {
            $Part = $Self->{SearchPrefix} . $Part . $Self->{SearchSuffix};
            $Part =~ s/\*/%/g;
            $Part =~ s/%%/%/g;

            if ( defined $SQL ) {
                $SQL .= " AND ";
            }

            my $CustomerCompanySearchFields = $Self->{CustomerCompanyMap}->{CustomerCompanySearchFields};

            if ( $CustomerCompanySearchFields && ref $CustomerCompanySearchFields eq 'ARRAY' ) {

                my @SQLParts;
                for my $Field ( @{$CustomerCompanySearchFields} ) {
                    if ( $Self->{CaseSensitive} ) {
                        push @SQLParts, "$Field LIKE ?";
                        push @Bind,     \$Part;
                    }
                    else {
                        push @SQLParts, "LOWER($Field) LIKE LOWER(?)";
                        push @Bind,     \$Part;
                    }
                }
                if (@SQLParts) {
                    $SQL .= join( ' OR ', @SQLParts );
                }
            }
        }
    }

    # sql
    my $CompleteSQL = "SELECT $Self->{CustomerCompanyKey}, $What FROM $Self->{CustomerCompanyTable}";
    $CompleteSQL .= $SQL ? " WHERE $SQL" : '';

    # ask database
    $Self->{DBObject}->Prepare(
        SQL   => $CompleteSQL,
        Bind  => \@Bind,
        Limit => $Limit,
    );

    # fetch the result
    my %List;
    while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {

        my $CustomerCompanyID = shift @Row;
        $List{$CustomerCompanyID} = join( ' ', map { defined($_) ? $_ : '' } @Row );
    }

    # cache request
    if ( $Self->{CacheObject} ) {
        $Self->{CacheObject}->Set(
            Type  => $CacheType,
            Key   => $CacheKey,
            Value => \%List,
            TTL   => $Self->{CacheTTL},
        );
    }

    return %List;
}

sub CustomerCompanyGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{CustomerID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need CustomerID!'
        );
        return;
    }

    # check cache
    if ( $Self->{CacheObject} ) {
        my $Data = $Self->{CacheObject}->Get(
            Type => $Self->{CacheType},
            Key  => "CustomerCompanyGet::$Param{CustomerID}",
        );
        return %{$Data} if ref $Data eq 'HASH';
    }

    # build select
    my @Fields;
    my %FieldsMap;
    for my $Entry ( @{ $Self->{CustomerCompanyMap}->{Map} } ) {
        push @Fields, $Entry->[2];
        $FieldsMap{ $Entry->[2] } = $Entry->[0];
    }
    my $SQL = 'SELECT ' . join( ', ', @Fields );

    if ( !$Self->{ForeignDB} ) {
        $SQL .= ", create_time, create_by, change_time, change_by";
    }

    # this seems to be legacy, if Name is passed it should take precedence over CustomerID
    my $CustomerID = $Param{Name} || $Param{CustomerID};

    $SQL .= " FROM $Self->{CustomerCompanyTable} WHERE ";

    if ( $Self->{CaseSensitive} ) {
        $SQL .= "$Self->{CustomerCompanyKey} = ?";
    }
    else {
        $SQL .= "LOWER($Self->{CustomerCompanyKey}) = LOWER( ? )";
    }

    # get initial data
    return if !$Self->{DBObject}->Prepare(
        SQL  => $SQL,
        Bind => [ \$CustomerID ]
    );

    # fetch the result
    my %Data;
    ROW:
    while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {

        my $MapCounter = 0;

        for my $Field (@Fields) {
            $Data{ $FieldsMap{$Field} } = $Row[$MapCounter];
            $MapCounter++;
        }

        next ROW if $Self->{ForeignDB};

        for my $Key (qw(CreateTime CreateBy ChangeTime ChangeBy)) {
            $Data{$Key} = $Row[$MapCounter];
            $MapCounter++;
        }
    }

    # get preferences
    my %Preferences = $Self->GetPreferences( CustomerID => $Param{CustomerID} );

    # cache request
    if ( $Self->{CacheObject} ) {
        $Self->{CacheObject}->Set(
            Type  => $Self->{CacheType},
            Key   => "CustomerCompanyGet::$Param{CustomerID}",
            Value => { %Data, %Preferences },
            TTL   => $Self->{CacheTTL},
        );
    }

    return ( %Data, %Preferences );
}

sub CustomerCompanyAdd {
    my ( $Self, %Param ) = @_;

    # check ro/rw
    if ( $Self->{ReadOnly} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'CustomerCompany backend is read only!'
        );
        return;
    }

    my @Fields;
    my @Placeholders;
    my @Values;

    for my $Entry ( @{ $Self->{CustomerCompanyMap}->{Map} } ) {
        push @Fields,       $Entry->[2];
        push @Placeholders, '?';
        push @Values,       \$Param{ $Entry->[0] };
    }
    if ( !$Self->{ForeignDB} ) {
        push @Fields,       qw(create_time create_by change_time change_by);
        push @Placeholders, qw(current_timestamp ? current_timestamp ?);
        push @Values, ( \$Param{UserID}, \$Param{UserID} );
    }

    # build insert
    my $SQL = "INSERT INTO $Self->{CustomerCompanyTable} (";
    $SQL .= join( ', ', @Fields ) . " ) VALUES ( " . join( ', ', @Placeholders ) . " )";

    return if !$Self->{DBObject}->Do(
        SQL  => $SQL,
        Bind => \@Values,
    );

    # log notice
    $Kernel::OM->Get('Kernel::System::Log')->Log(
        Priority => 'info',
        Message =>
            "CustomerCompany: '$Param{CustomerCompanyName}/$Param{CustomerID}' created successfully ($Param{UserID})!",
    );

    $Self->_CustomerCompanyCacheClear( CustomerID => $Param{CustomerID} );

    return $Param{CustomerID};
}

sub CustomerCompanyUpdate {
    my ( $Self, %Param ) = @_;

    # check ro/rw
    if ( $Self->{ReadOnly} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Customer backend is read only!'
        );
        return;
    }

    # check needed stuff
    for my $Entry ( @{ $Self->{CustomerCompanyMap}->{Map} } ) {
        if ( !$Param{ $Entry->[0] } && $Entry->[4] && $Entry->[0] ne 'UserPassword' ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Entry->[0]!"
            );
            return;
        }
    }

    my @Fields;
    my @Values;

    FIELD:
    for my $Entry ( @{ $Self->{CustomerCompanyMap}->{Map} } ) {
        next FIELD if $Entry->[0] =~ /^UserPassword$/i;
        push @Fields, $Entry->[2] . ' = ?';
        push @Values, \$Param{ $Entry->[0] };
    }
    if ( !$Self->{ForeignDB} ) {
        push @Fields, ( 'change_time = current_timestamp', 'change_by = ?' );
        push @Values, \$Param{UserID};
    }

    # create SQL statement
    my $SQL = "UPDATE $Self->{CustomerCompanyTable} SET ";
    $SQL .= join( ', ', @Fields );

    if ( $Self->{CaseSensitive} ) {
        $SQL .= " WHERE $Self->{CustomerCompanyKey} = ?";
    }
    else {
        $SQL .= " WHERE LOWER($Self->{CustomerCompanyKey}) = LOWER( ? )";
    }
    push @Values, \$Param{CustomerCompanyID};

    return if !$Self->{DBObject}->Do(
        SQL  => $SQL,
        Bind => \@Values,
    );

    # check if we need to update Customer Preferences
    if ( $Param{CustomerCompanyID} ne $Param{CustomerID} ) {

        # update the preferences
        $Self->{PreferencesObject}->RenamePreferences(
            NewCustomerID => $Param{CustomerID},
            OldCustomerID => $Param{CustomerCompanyID},
        );
    }

    # log notice
    $Kernel::OM->Get('Kernel::System::Log')->Log(
        Priority => 'info',
        Message =>
            "CustomerCompany: '$Param{CustomerCompanyName}/$Param{CustomerID}' updated successfully ($Param{UserID})!",
    );

    $Self->_CustomerCompanyCacheClear( CustomerID => $Param{CustomerID} );
    if ( $Param{CustomerCompanyID} ne $Param{CustomerID} ) {
        $Self->_CustomerCompanyCacheClear( CustomerID => $Param{CustomerCompanyID} );
    }

    return 1;
}

sub SetPreferences {
    my ( $Self, %Param ) = @_;

    # check needed params
    if ( !$Param{CustomerID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need CustomerID!',
        );
        return;
    }

    $Self->_CustomerCompanyCacheClear( CustomerID => $Param{CustomerID} );

    return $Self->{PreferencesObject}->SetPreferences(%Param);
}

sub GetPreferences {
    my ( $Self, %Param ) = @_;

    # check needed params
    if ( !$Param{CustomerID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need CustomerID!',
        );
        return;
    }

    return $Self->{PreferencesObject}->GetPreferences(%Param);
}

sub SearchPreferences {
    my ( $Self, %Param ) = @_;

    return $Self->{PreferencesObject}->SearchPreferences(%Param);
}

sub _CustomerCompanyCacheClear {
    my ( $Self, %Param ) = @_;

    return if !$Self->{CacheObject};

    if ( !$Param{CustomerID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need CustomerID!'
        );
        return;
    }

    $Self->{CacheObject}->Delete(
        Type => $Self->{CacheType},
        Key  => "CustomerCompanyGet::$Param{CustomerID}",
    );

    # delete all search cache entries
    $Self->{CacheObject}->CleanUp(
        Type => $Self->{CacheType} . '_CustomerCompanyList',
    );

    for my $Function (qw(CustomerCompanyList)) {
        for my $Valid ( 0 .. 1 ) {
            $Self->{CacheObject}->Delete(
                Type => $Self->{CacheType},
                Key  => "${Function}::${Valid}",
            );
        }
    }

    return 1;
}

sub DESTROY {
    my $Self = shift;

    # disconnect if it's not a parent DBObject
    if ( $Self->{NotParentDBObject} ) {
        if ( $Self->{DBObject} ) {
            $Self->{DBObject}->Disconnect();
        }
    }

    return 1;
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
