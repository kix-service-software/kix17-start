# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::CustomerDashboardRemoteDBAJAXHandler;

use strict;
use warnings;

our $ObjectManagerDisabled = 1;

# use base qw(Kernel::System::DB);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    # get needed objects
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $ParamObject  = $Kernel::OM->Get('Kernel::System::Web::Request');

    $Self->{Identifier} = $ParamObject->GetParam( Param => 'Identifier' )
        || 'CustomerDashboardRemoteDB';

    my $CustomerDashboardConfig
        = $ConfigObject->Get('AgentCustomerInformationCenter::Backend');
    for my $Config ( keys %{$CustomerDashboardConfig} ) {
        next if $Config !~ /$Self->{Identifier}/;
        $Self->{DashletConfig} = $CustomerDashboardConfig->{$Config};
        last;
    }

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $ConfigObject       = $Kernel::OM->Get('Kernel::Config');
    my $LayoutObject       = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ParamObject        = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $CustomerUserObject = $Kernel::OM->Get('Kernel::System::CustomerUser');
    my $TicketObject       = $Kernel::OM->Get('Kernel::System::Ticket');

    # get params
    my $SearchString   = $ParamObject->GetParam( Param => 'SearchString' )   || '';
    my $CallingAction  = $ParamObject->GetParam( Param => 'CallingAction' )  || '';
    my $CustomerUserID = $ParamObject->GetParam( Param => 'CustomerUserID' ) || '';
    my $CustomerLogin  = $ParamObject->GetParam( Param => 'CustomerLogin' )  || '';
    my $Identifier = $Self->{DashletConfig}->{Identifier} || '';
    my $Frontend = 'Agent';

    my @RestrictedDBAttributes = ();
    if ( defined( $Self->{DashletConfig}->{RestrictedDBAttributes} ) ) {
        @RestrictedDBAttributes = split( ",", $Self->{DashletConfig}->{RestrictedDBAttributes} );
    }
    my @RestrictedMandatory = ();
    if ( defined( $Self->{DashletConfig}->{RestrictedMandatory} ) ) {
        @RestrictedMandatory = split( ",", $Self->{DashletConfig}->{RestrictedMandatory} );
    }
    my @RestrictedOTRSObjects = ();
    if ( defined( $Self->{DashletConfig}->{RestrictedOTRSObjects} ) ) {
        @RestrictedOTRSObjects = split( ",", $Self->{DashletConfig}->{RestrictedOTRSObjects} );
    }
    my @RestrictedOTRSAttributes = ();
    if ( defined( $Self->{DashletConfig}->{RestrictedOTRSAttributes} ) ) {
        @RestrictedOTRSAttributes
            = split( ",", $Self->{DashletConfig}->{RestrictedOTRSAttributes} );
    }
    my @RestrictedValues = ();

    if (
        @RestrictedDBAttributes
        && @RestrictedOTRSObjects
        && @RestrictedOTRSAttributes
        && @RestrictedMandatory
        && scalar(@RestrictedOTRSAttributes) == scalar(@RestrictedOTRSObjects)
        && scalar(@RestrictedOTRSAttributes) == scalar(@RestrictedDBAttributes)
        && scalar(@RestrictedOTRSAttributes) == scalar(@RestrictedMandatory)
        )
    {
        for ( my $Index = 0; $Index < scalar(@RestrictedOTRSObjects); $Index++ ) {
            my $RestrictedValue = '';
            if (
                $RestrictedOTRSObjects[$Index] eq 'Configuration'
                && $RestrictedOTRSAttributes[$Index]
                )
            {
                $RestrictedValue = $RestrictedOTRSAttributes[$Index];
            }

            if ( !$RestrictedValue && $RestrictedMandatory[$Index] ) {
                $SearchString = "";
            }
            push( @RestrictedValues, $RestrictedValue );
        }
    }
    elsif (
        !@RestrictedDBAttributes
        && !@RestrictedOTRSObjects
        && !@RestrictedOTRSAttributes
        && !@RestrictedMandatory
        )
    {

        # do nothing
    }
    else {
        $SearchString = "";
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'Error',
            Message  => 'Invalid configuration of restrictions for '
                . $Self->{Identifier}
                . '.',
        );
    }

    # add customer user restrictions
    if ($CustomerLogin) {
        my %CustomerUserData = $CustomerUserObject->CustomerUserDataGet(
            User => $CustomerLogin,
        );
        push( @RestrictedValues, $CustomerUserData{UserLogin} );
        push(
            @RestrictedDBAttributes,
            $Self->{DashletConfig}->{RestrictedDBAttributeCustomerLogin}
        );
    }
    elsif ( defined $CustomerUserID && $CustomerUserID ) {
        push( @RestrictedValues, $CustomerUserID );
        push(
            @RestrictedDBAttributes,
            $Self->{DashletConfig}->{RestrictedDBAttributeCustomerUserID}
        );
    }

    # do search
    my $ResultArray;
    if ($SearchString) {
        $ResultArray = $Self->_CustomerDashboardRemoteDBSearch(
            DatabaseDSN           => $Self->{DashletConfig}->{DatabaseDSN},
            DatabaseUser          => $Self->{DashletConfig}->{DatabaseUser},
            DatabasePw            => $Self->{DashletConfig}->{DatabasePw},
            DatabaseCacheTTL      => $Self->{DashletConfig}->{DatabaseCacheTTL},
            DatabaseCaseSensitive => $Self->{DashletConfig}->{DatabaseCaseSensitive},
            DatabaseTable         => $Self->{DashletConfig}->{DatabaseTable},
            DatabaseType          => $Self->{DashletConfig}->{DatabaseType},
            IdentifierAttribute   => $Self->{DashletConfig}->{IdentifierAttribute},
            ShowAttributes        => $Self->{DashletConfig}->{ShowAttributes},
            RestrictedMandatory   => \@RestrictedMandatory,
            RestrictedAttributes  => \@RestrictedDBAttributes,
            RestrictedValues      => \@RestrictedValues,
            SearchAttribute       => $Self->{DashletConfig}->{SearchAttribute},
            SearchValue           => $SearchString,
            Limit                 => $Self->{DashletConfig}->{'MaxResultCount'},
        );
    }

    if ( $ResultArray && ref($ResultArray) eq 'ARRAY' && scalar( @{$ResultArray} > 0 ) ) {
        my $Style = '';
        my $MaxResultDisplay = $Self->{DashletConfig}->{'MaxResultDisplay'} || 10;

        my $SearchResultCount = scalar( @{$ResultArray} );

        my $ResultOffset = 0;
        if ( $Self->{DashletConfig}->{IdentifierAttribute} ) {
            $ResultOffset++;
        }

        my @HeadCols   = split( ",", $Self->{DashletConfig}->{ShowAttributesHead} || '' );
        my @ResultCols = split( ",", $Self->{DashletConfig}->{ShowAttributes}     || '' );
        my $HeadRow = ( scalar(@HeadCols) == scalar(@ResultCols) ) ? 1 : 0;

        if ( $SearchResultCount > $MaxResultDisplay ) {
            $Style = 'overflow-x:hidden;overflow-y:scroll;height:'
                . ( ( $MaxResultDisplay + $HeadRow ) * 20 ) . 'px;';
        }

        $LayoutObject->Block(
            Name => 'CustomerDashboardRemoteDBResult',
            Data => {
                %Param,
                Identifier => $Identifier,
                Style      => $Style,
            },
        );

        if ($HeadRow) {
            $LayoutObject->Block(
                Name => 'CustomerDashboardRemoteDBResultHead',
            );
            if ( defined $Self->{DashletConfig}->{SelectionDisabled}
                && !$Self->{DashletConfig}->{SelectionDisabled}
            ) {
                $LayoutObject->Block(
                    Name => 'CustomerDashboardRemoteDBResultHeadColumnCheck',
                );
            }
            for my $Head (@HeadCols) {
                $LayoutObject->Block(
                    Name => 'CustomerDashboardRemoteDBResultHeadColumnValue',
                    Data => {
                        Head => $Head,
                    },
                );
            }
        }

        my $MaxResultSize = $Self->{DashletConfig}->{'MaxResultSize'} || 0;

        for my $ResultRow ( @{$ResultArray} ) {

            $LayoutObject->Block(
                Name => 'CustomerDashboardRemoteDBResultRow',
                Data => {
                    Identifier => $Identifier,
                    Value      => $ResultRow->[0],
                },
            );

            for (
                my $ResultIndex = $ResultOffset;
                $ResultIndex < scalar( @{$ResultRow} );
                $ResultIndex++
                )
            {

                my $Result = $ResultRow->[$ResultIndex] || '';
                my $ResultShort = $Result;

                if ( $MaxResultSize > 0 ) {
                    $ResultShort = $LayoutObject->Ascii2Html(
                        Text => $Result,
                        Max  => $MaxResultSize,
                    );
                }

                my $LinkTicketID = '';
                if ( $Result && $Self->{DashletConfig}->{TicketLink} ) {
                    $LinkTicketID = $TicketObject->TicketCheckNumber( Tn => $Result );
                }

                $LayoutObject->Block(
                    Name => 'CustomerDashboardRemoteDBResultRowColumn',
                    Data => {
                        Result => $Result,
                        }
                );

                if ( $LinkTicketID && ( $Frontend eq 'Agent' || $Frontend eq 'Customer' ) ) {
                    $LayoutObject->Block(
                        Name => 'CustomerDashboardRemoteDBResultRowColumnLink',
                        Data => {
                            Result      => $Result,
                            ResultShort => $ResultShort,
                            Frontend    => $Frontend
                            }
                    );
                }
                else {
                    $LayoutObject->Block(
                        Name => 'CustomerDashboardRemoteDBResultRowColumnValue',
                        Data => {
                            Result      => $Result,
                            ResultShort => $ResultShort,
                            }
                    );
                }
            }
        }
    }
    else {
        $LayoutObject->Block(
            Name => 'NoSearchResult',
        );

    }

    my $Output = $LayoutObject->Output(
        TemplateFile => 'AgentCustomerDashboardRemoteDB',
        Data         => {
            %Param,
            Identifier => $Identifier,
        },
        KeepScriptTags => 1,
    );

    return $LayoutObject->Attachment(
        ContentType => 'application/json; charset='
            . $LayoutObject->{Charset},
        Content => $Output || '',
        Type    => 'inline',
        NoCache => 1,
    );

}

sub _CustomerDashboardRemoteDBSearch {
    my ( $Self, %Param ) = @_;

    # get needed db object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # check needed params
    foreach (
        qw(
        DatabaseDSN DatabaseUser
        DatabaseTable ShowAttributes
        SearchAttribute SearchValue
        )
        )
    {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!",
            );
            return;
        }
    }

    $Self->{DSN}  = $Param{DatabaseDSN};
    $Self->{USER} = $Param{DatabaseUser};
    $Self->{PW}   = $Param{DatabasePw};

    # decrypt pw (if needed)
    if ( $Self->{PW} =~ /^\{(.*)\}$/ ) {
        $Self->{PW} = $Self->_Decrypt($1);
    }

    # get database type (auto detection)
    if ( $Self->{DSN} =~ /:mysql/i ) {
        $Self->{'DB::Type'} = 'mysql';
    }
    elsif ( $Self->{DSN} =~ /:pg/i ) {
        $Self->{'DB::Type'} = 'postgresql';
    }
    elsif ( $Self->{DSN} =~ /:oracle/i ) {
        $Self->{'DB::Type'} = 'oracle';
    }
    elsif ( $Self->{DSN} =~ /:db2/i ) {
        $Self->{'DB::Type'} = 'db2';
    }
    elsif ( $Self->{DSN} =~ /(mssql|sybase|sql server)/i ) {
        $Self->{'DB::Type'} = 'mssql';
    }

    # get database type (overwrite with params)
    if ( $Param{Type} ) {
        $Self->{'DB::Type'} = $Param{Type};
    }

    # load backend module
    if ( $Self->{'DB::Type'} ) {
        my $GenericModule = 'Kernel::System::DB::' . $Self->{'DB::Type'};
        return if !$Kernel::OM->Get('Kernel::System::Main')->Require($GenericModule);
        $DBObject->{Backend} = $GenericModule->new( %{$Self} );

        # set database functions
        $DBObject->{Backend}->LoadPreferences();
    }
    else {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'Error',
            Message  => 'Unknown database type! Set option Database::Type in '
                . 'Kernel/Config.pm to (mysql|postgresql|oracle|db2|mssql).',
        );
        return;
    }

    # check database settings
    for my $Setting (
        qw(
        Type Limit DirectBlob Attribute QuoteSingle QuoteBack
        Connect Encode CaseSensitive LcaseLikeInLargeText
        )
        )
    {
        if ( defined $Param{$Setting} ) {
            $DBObject->{Backend}->{"DB::$Setting"} = $Param{$Setting};
        }
    }

    # do database connect
    if ( !$Param{AutoConnectNo} ) {
        return if !$Self->_Connect();
    }

    my @List;
    my @RestrictedMandatory = ();
    if (
        $Param{RestrictedMandatory}
        && ref( $Param{RestrictedMandatory} ) eq 'ARRAY'
        )
    {
        push( @RestrictedMandatory, @{ $Param{RestrictedMandatory} } );
    }
    my @RestrictedAttributes = ();
    if (
        $Param{RestrictedAttributes}
        && ref( $Param{RestrictedAttributes} ) eq 'ARRAY'
        )
    {
        push( @RestrictedAttributes, @{ $Param{RestrictedAttributes} } );
    }
    my @QuotedRestrictedValues = ();
    if (
        $Param{RestrictedValues}
        && ref( $Param{RestrictedValues} ) eq 'ARRAY'
        )
    {
        for my $RestrictedValue ( @{ $Param{RestrictedValues} } ) {
            push( @QuotedRestrictedValues, $DBObject->Quote($RestrictedValue) );
        }
    }

    # check restricted configurtion
    if (
        @RestrictedMandatory
        && @RestrictedAttributes
        && @QuotedRestrictedValues
        && scalar(@RestrictedMandatory) == scalar(@QuotedRestrictedValues)
        && scalar(@RestrictedAttributes) == scalar(@QuotedRestrictedValues)
        )
    {
        for ( my $Index = 0; $Index < scalar(@RestrictedAttributes); $Index++ ) {
            if (
                $RestrictedMandatory[$Index]
                && !$QuotedRestrictedValues[$Index]
                )
            {
                return \@List;
            }
        }
    }

    my $QuotedValue = $DBObject->Quote( $Param{SearchValue} );

    # check cache
    if ( $Param{DatabaseCacheTTL} ) {
        my $CacheObject = $Kernel::OM->Get('Kernel::System::Cache');

        # set CacheType and CacheKey
        $Self->{CacheType} = "CustomerDashboardRemoteDB";
        $Self->{CacheKey}
            = "Results::"
            . $Param{DatabaseDSN} . "::"
            . $Param{DatabaseTable} . "::"
            . $Param{SearchAttribute} . "::"
            . $QuotedValue;

        # attach restricted config
        if (
            @RestrictedAttributes
            && @QuotedRestrictedValues
            && scalar(@RestrictedAttributes) == scalar(@QuotedRestrictedValues)
            )
        {
            for ( my $Index = 0; $Index < scalar(@RestrictedAttributes); $Index++ ) {
                $Self->{CacheKey}
                    .= "::"
                    . $RestrictedAttributes[$Index] . "::"
                    . $QuotedRestrictedValues[$Index];
            }
        }

        my $List = $CacheObject->Get(
            Type => $Self->{CacheType},
            Key  => $Self->{CacheKey},
        );
        return \@{$List} if $List;
    }
    my $QueryCondition = $DBObject->QueryCondition(
        Key          => $Param{SearchAttribute},
        Value        => $QuotedValue,
        SearchPrefix => '*',
        SearchSuffix => '*',
    );

    # attach restricted config
    if (
        @RestrictedAttributes
        && @QuotedRestrictedValues
        && scalar(@RestrictedAttributes) == scalar(@QuotedRestrictedValues)
        )
    {
        for ( my $Index = 0; $Index < scalar(@RestrictedAttributes); $Index++ ) {
            if ( $QuotedRestrictedValues[$Index] ) {
                $QueryCondition .= ' AND '
                    . $RestrictedAttributes[$Index]
                    . '=\''
                    . $QuotedRestrictedValues[$Index]
                    . '\'';
            }
        }
    }

    my $SelectString = '';
    if ( $Param{IdentifierAttribute} ) {
        $SelectString = $Param{IdentifierAttribute};
    }
    if ($SelectString) {
        $SelectString .= ',';
    }
    $SelectString .= $Param{ShowAttributes};

    # build SQL
    my $SQL = 'SELECT '
        . $SelectString
        . ' FROM '
        . $Param{DatabaseTable};
    if ( $QueryCondition ne '()' ) {
        $SQL .= ' WHERE '
            . $QueryCondition;
    }

    my $Success = $Self->_Prepare(
        SQL => $SQL,
    );
    if ( !$Success ) {
        return;
    }

    # fetch result
    while ( my @Row = $DBObject->FetchrowArray() ) {
        push( @List, \@Row );

        # Check if limit is reached
        last if ( $Param{Limit} && ( scalar @List ) == $Param{Limit} );
    }

    # cache request
    if ( $Param{DatabaseCacheTTL} ) {
        $Kernel::OM->Get('Kernel::System::Cache')->Set(
            Type  => $Self->{CacheType},
            Key   => $Self->{CacheKey},
            Value => \@List,
            TTL   => $Param{DatabaseCacheTTL},
        );
    }

    return \@List;
}

=item _Connect()

to connect to a database

    $Self->_Connect();

=cut

sub _Connect {
    my $Self = shift;

    # get needed db object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # debug
    if ( $Self->{Debug} > 2 ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Caller   => 1,
            Priority => 'debug',
            Message =>
                "CustomerDashboardRemoteDB.pm->Connect: DSN: $Self->{DSN}, User: $Self->{USER}, Pw: $Self->{PW}, DB Type: $Self->{'DB::Type'};",
        );
    }

    # db connect
    $Self->{dbh} = DBI->connect(
        $Self->{DSN},
        $Self->{USER},
        $Self->{PW},
        $DBObject->{Backend}->{'DB::Attribute'},
    );

    if ( !$Self->{dbh} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Caller   => 1,
            Priority => 'Error',
            Message  => $DBI::errstr,
        );
        return;
    }

    if ( $DBObject->{Backend}->{'DB::Connect'} ) {
        $Self->_Do( SQL => $DBObject->{Backend}->{'DB::Connect'} );
    }

    # set utf-8 on for PostgreSQL
    if ( $DBObject->{Backend}->{'DB::Type'} eq 'postgresql' ) {
        $Self->{dbh}->{pg_enable_utf8} = 1;
    }

    return $Self->{dbh};
}

=item _Disconnect()

to disconnect from a database

    $Self->Disconnect();

=cut

sub _Disconnect {
    my $Self = shift;

    # debug
    if ( $Self->{Debug} > 2 ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Caller   => 1,
            Priority => 'debug',
            Message  => 'KIXSBRemoteDB.pm->Disconnect',
        );
    }

    # do disconnect
    if ( $Self->{dbh} ) {
        $Self->{dbh}->disconnect();
    }

    return 1;
}

=item _Do()

to insert, update or delete values

    $Self->Do( SQL => "INSERT INTO table (name) VALUES ('dog')" );

    $Self->Do( SQL => "DELETE FROM table" );

    you also can use DBI bind values (used for large strings):

    my $Var1 = 'dog1';
    my $Var2 = 'dog2';

    $Self->_Do(
        SQL  => "INSERT INTO table (name1, name2) VALUES (?, ?)",
        Bind => [ \$Var1, \$Var2 ],
    );

=cut

sub _Do {
    my ( $Self, %Param ) = @_;

    # get needed db object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # check needed stuff
    if ( !$Param{SQL} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need SQL!'
        );
        return;
    }

    if ( $DBObject->{Backend}->{'DB::PreProcessSQL'} ) {
        $DBObject->{Backend}->PreProcessSQL( \$Param{SQL} );
    }

    # check bind params
    my @Array;
    if ( $Param{Bind} ) {
        for my $Data ( @{ $Param{Bind} } ) {
            if ( ref $Data eq 'SCALAR' ) {
                push @Array, $$Data;
            }
            else {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Caller   => 1,
                    Priority => 'Error',
                    Message  => 'No SCALAR param in Bind!',
                );
                return;
            }
        }
        if ( @Array && $DBObject->{Backend}->{'DB::PreProcessBindData'} ) {
            $DBObject->{Backend}->PreProcessBindData( \@Array );
        }
    }

    # Replace current_timestamp with real time stamp.
    # - This avoids time inconsistencies of app and db server
    # - This avoids timestamp problems in Postgresql servers where
    #   the timestamp is sometimes 1 second off the perl timestamp.
    my $Timestamp = $Kernel::OM->Get('Kernel::System::Time')->CurrentTimestamp();
    $Param{SQL} =~ s{
        (?<= \s | \( | , )  # lookahead
        current_timestamp   # replace current_timestamp by 'yyyy-mm-dd hh:mm:ss'
        (?=  \s | \) | , )  # lookbehind
    }
    {
        '$Timestamp'
    }xmsg;

    # debug
    if ( $Self->{Debug} > 0 ) {
        $Self->{DoCounter}++;
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Caller   => 1,
            Priority => 'debug',

            # capeIT
            #            Message  => "DB.pm->Do ($Self->{DoCounter}) SQL: '$Param{SQL}'",
            Message => "KIXSBRemoteDB.pm->Do ($Self->{DoCounter}) SQL: '$Param{SQL}'",

            # EO capeIT
        );
    }

    # send sql to database
    if ( !$Self->{dbh}->do( $Param{SQL}, undef, @Array ) ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Caller   => 1,
            Priority => 'error',
            Message  => "$DBI::errstr, SQL: '$Param{SQL}'",
        );
        return;
    }

    return 1;
}

=item _Prepare()

to prepare a SELECT statement

    $Self->_Prepare(
        SQL   => "SELECT id, name FROM table",
        Limit => 10,
    );

or in case you want just to get row 10 until 30

    $Self->_Prepare(
        SQL   => "SELECT id, name FROM table",
        Start => 10,
        Limit => 20,
    );

in case you don't want utf-8 encoding for some columns, use this:

    $Self->_Prepare(
        SQL    => "SELECT id, name, content FROM table",
        Encode => [ 1, 1, 0 ],
    );

you also can use DBI bind values, required for large strings:

    my $Var1 = 'dog1';
    my $Var2 = 'dog2';

    $Self->_Prepare(
        SQL    => "SELECT id, name, content FROM table WHERE name_a = ? AND name_b = ?",
        Encode => [ 1, 1, 0 ],
        Bind   => [ \$Var1, \$Var2 ],
    );

=cut

sub _Prepare {
    my ( $Self, %Param ) = @_;

    # get needed db object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    my $SQL   = $Param{SQL};
    my $Limit = $Param{Limit} || '';
    my $Start = $Param{Start} || '';

    # check needed stuff
    if ( !$Param{SQL} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need SQL!'
        );
        return;
    }
    if ( defined $Param{Encode} ) {
        $Self->{Encode} = $Param{Encode};
    }
    else {
        $Self->{Encode} = undef;
    }
    $Self->{Limit}        = 0;
    $Self->{LimitStart}   = 0;
    $Self->{LimitCounter} = 0;

    # build final select query
    if ($Limit) {
        if ($Start) {
            $Limit = $Limit + $Start;
            $Self->{LimitStart} = $Start;
        }
        if ( $DBObject->{Backend}->{'DB::Limit'} eq 'limit' ) {
            $SQL .= " LIMIT $Limit";
        }
        elsif ( $DBObject->{Backend}->{'DB::Limit'} eq 'top' ) {
            $SQL =~ s{ \A (SELECT ([ ]DISTINCT|)) }{$1 TOP $Limit}xmsi;
        }
        else {
            $Self->{Limit} = $Limit;
        }
    }

    # debug
    if ( $Self->{Debug} > 1 ) {
        $Self->{PrepareCounter}++;
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Caller   => 1,
            Priority => 'debug',

     # capeIT
     #            Message  => "DB.pm->Prepare ($Self->{PrepareCounter}/" . time() . ") SQL: '$SQL'",
            Message => "KIXSBRemoteDB.pm->Prepare ($Self->{PrepareCounter}/"
                . time()
                . ") SQL: '$SQL'",

            # EO capeIT
        );
    }

    # slow log feature
    my $LogTime;
    if ( $Self->{SlowLog} ) {
        $LogTime = time();
    }

    if ( $DBObject->{Backend}->{'DB::PreProcessSQL'} ) {
        $DBObject->{Backend}->PreProcessSQL( \$SQL );
    }

    # check bind params
    my @Array;
    if ( $Param{Bind} ) {
        for my $Data ( @{ $Param{Bind} } ) {
            if ( ref $Data eq 'SCALAR' ) {
                push @Array, $$Data;
            }
            else {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Caller   => 1,
                    Priority => 'Error',
                    Message  => 'No SCALAR param in Bind!',
                );
                return;
            }
        }
        if ( @Array && $DBObject->{Backend}->{'DB::PreProcessBindData'} ) {
            $DBObject->{Backend}->PreProcessBindData( \@Array );
        }
    }

    # do
    if ( !( $DBObject->{Cursor} = $Self->{dbh}->prepare($SQL) ) ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Caller   => 1,
            Priority => 'Error',
            Message  => "$DBI::errstr, SQL: '$SQL'",
        );
        return;
    }

    if ( !$DBObject->{Cursor}->execute(@Array) ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Caller   => 1,
            Priority => 'Error',
            Message  => "$DBI::errstr, SQL: '$SQL'",
        );
        return;
    }

    # slow log feature
    if ( $Self->{SlowLog} ) {
        my $LogTimeTaken = time() - $LogTime;
        if ( $LogTimeTaken > 4 ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Caller   => 1,
                Priority => 'error',
                Message  => "Slow ($LogTimeTaken s) SQL: '$SQL'",
            );
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
