# --
# Kernel/Modules/DynamicFieldRemoteDBAJAXHandler.pm - a module used to handle ajax requests
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Mario(dot)Illinger(at)cape(dash)it(dot)de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::DynamicFieldRemoteDBAJAXHandler;

use strict;
use warnings;

use URI::Escape;

use Kernel::System::DFRemoteDB;

our @ObjectDependencies = (
    'Kernel::Output::HTML::Layout',
    'Kernel::System::CustomerUser',
    'Kernel::System::DynamicField',
    'Kernel::System::DynamicField::Driver::RemoteDB',
    'Kernel::System::Encode',
    'Kernel::System::Log',
    'Kernel::System::Ticket',
    'Kernel::System::Web::Request',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # create needed objects
    $Self->{LayoutObject}         = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    $Self->{CustomerUserObject}   = $Kernel::OM->Get('Kernel::System::CustomerUser');
    $Self->{DynamicFieldObject}   = $Kernel::OM->Get('Kernel::System::DynamicField');
    $Self->{RemoteDBObject}       = $Kernel::OM->Get('Kernel::System::DynamicField::Driver::RemoteDB');
    $Self->{EncodeObject}         = $Kernel::OM->Get('Kernel::System::Encode');
    $Self->{LogObject}            = $Kernel::OM->Get('Kernel::System::Log');
    $Self->{TicketObject}         = $Kernel::OM->Get('Kernel::System::Ticket');
    $Self->{ParamObject}          = $Kernel::OM->Get('Kernel::System::Web::Request');

    my $JSON = '';

    # get mandatory param
    my $DynamicFieldID = $Self->{ParamObject}->GetParam( Param => 'DynamicFieldID' );

    if ($DynamicFieldID) {

        my $DynamicFieldConfig = $Self->{DynamicFieldObject}->DynamicFieldGet(
            ID => $DynamicFieldID,
        );

        if ( $DynamicFieldConfig->{FieldType} ne 'RemoteDB' ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message => "DynamicFieldRemoteDBAJAXHandler: DynamicField doesn't refer to type RemoteDB.",
            );
            return;
        }

        # get needed params
        my $Subaction   = $Self->{ParamObject}->GetParam( Param => 'Subaction' )   || '';
        my $FieldPrefix = $Self->{ParamObject}->GetParam( Param => 'FieldPrefix' ) || '';

        # get used entries
        my @Entries = $Self->{ParamObject}->GetArray( Param => $FieldPrefix . 'DynamicField_' . $DynamicFieldConfig->{Name} );

        # get attributes from web request
        my @ParamNames = $Self->{ParamObject}->GetParamNames();
        my %WebParams  = map { $_ => 1 } @ParamNames;

        my $DFRemoteDBObject = Kernel::System::DFRemoteDB->new(
            DatabaseDSN  => $DynamicFieldConfig->{Config}->{DatabaseDSN},
            DatabaseUser => $DynamicFieldConfig->{Config}->{DatabaseUser},
            DatabasePw   => $DynamicFieldConfig->{Config}->{DatabasePw},
            %{ $Self },
        );

        #handle subaction Search
        if ($Subaction eq 'Search') {
            my $Search = $Self->{ParamObject}->GetParam( Param => 'Search' ) || '';

            # encode the input
            $Self->{EncodeObject}->EncodeInput( \$Search );

            my @PossibleValues;

            if (
                defined $Search
                && $Search ne ''
            ) {
                my $ConfigOnly     = $Self->{ParamObject}->GetParam( Param => 'ConfigOnly' ) || '';
                my $TicketID       = '';
                my $CustomerUserID = '';
                if (!$ConfigOnly) {
                    $TicketID       = $Self->{ParamObject}->GetParam( Param => 'TicketID' )   || '';
                    $CustomerUserID = $Self->{ParamObject}->GetParam( Param => 'CustomerUserID' )
                                    || uri_unescape($Self->{ParamObject}->GetParam( Param => 'SelectedCustomerUser' ))
                                    || '';
                }

                my %TicketData;
                if ($TicketID =~ /^\d+$/) {
                    %TicketData = $Self->{TicketObject}->TicketGet(
                        TicketID      => $TicketID,
                        DynamicFields => 1,
                        Extended      => 1,
                        UserID        => 1,
                        Silent        => 1,
                    );
                    $CustomerUserID = $TicketData{CustomerUserID} if ( $TicketData{CustomerUserID} );
                }

                my %CustomerUserData;
                if ( $CustomerUserID ) {
                    %CustomerUserData = $Self->{CustomerUserObject}->CustomerUserDataGet(
                        User => $CustomerUserID,
                    );
                }

                $Search         =~ s/\*/%/gi;
                my $QuotedValue = $DFRemoteDBObject->Quote($Search);

                my @SearchFields = split( ',', $DynamicFieldConfig->{Config}->{DatabaseFieldSearch} );
                my $QueryCondition = $DFRemoteDBObject->QueryCondition(
                    Key           => \@SearchFields,
                    Value         => $QuotedValue,
                    SearchPrefix  => $DynamicFieldConfig->{Config}->{SearchPrefix},
                    SearchSuffix  => $DynamicFieldConfig->{Config}->{SearchSuffix},
                    CaseSensitive => $DynamicFieldConfig->{Config}->{CaseSensitive},
                );

                # get used Constrictions
                my $Constrictions = $DynamicFieldConfig->{Config}->{Constrictions};

                # prepare constrictions
                my $ConstrictionsCheck = 1;
                if ( $Constrictions ) {
                    my @Constrictions = split(/[\n\r]+/, $Constrictions);
                    CONSTRICTION:
                    for my $Constriction ( @Constrictions ) {
                        my @ConstrictionRule = split(/::/, $Constriction);
                        my $ConstrictionCheck = 1;
                        my $ConstrictionValue;
                        # check for valid constriction
                        next CONSTRICTION if (
                            scalar(@ConstrictionRule) != 4
                            || $ConstrictionRule[0] eq ""
                            || $ConstrictionRule[1] eq ""
                            || $ConstrictionRule[2] eq ""
                        );

                        # mandatory constriction
                        if (
                            !$ConfigOnly
                            && $ConstrictionRule[3]
                        ) {
                            $ConstrictionCheck = 0;
                        }

                        # only handle static constrictions in admininterface
                        if (
                            $ConstrictionRule[1] eq 'Configuration'
                        ) {
                            $ConstrictionValue = $ConstrictionRule[2];
                            $ConstrictionCheck = 1;
                        } elsif (
                            $ConstrictionRule[1] eq 'Ticket'
                            && (
                                $WebParams{ $ConstrictionRule[2] }
                                || defined( $TicketData{ $ConstrictionRule[2] } )
                            )
                        ) {
                            # get value from ticket data
                            $ConstrictionValue = $TicketData{ $ConstrictionRule[2] };
                            # use only first entry if array is given
                            if ( ref($ConstrictionValue) eq 'ARRAY' ) {
                                $ConstrictionValue = $ConstrictionValue->[0];
                            }
                            # check if attribute is in web params
                            if ( $WebParams{ $ConstrictionRule[2] } ) {
                                $ConstrictionValue = $Self->{ParamObject}->GetParam( Param => $ConstrictionRule[2] ) || '';
                            }
                            # mark check success if value is not empty
                            if ( $ConstrictionValue ) {
                                $ConstrictionCheck = 1;
                            }
                            # set constriction value undef if empty
                            else {
                                $ConstrictionValue = undef;
                            }
                        } elsif (
                            $ConstrictionRule[1] eq 'CustomerUser'
                            && $CustomerUserData{ $ConstrictionRule[2] }
                        ) {
                            $ConstrictionValue = $CustomerUserData{ $ConstrictionRule[2] };
                            $ConstrictionCheck = 1;
                        }

                        # stop if mandatory constriction not valid
                        if ( !$ConstrictionCheck ) {
                            $ConstrictionsCheck = 0;
                            last CONSTRICTION;
                        }

                        # quote constriction value
                        my $QuotedConstrictionValue = $DFRemoteDBObject->Quote($ConstrictionValue);

                        # skip if quoted constriction is empty/zero
                        if ( !$QuotedConstrictionValue ) {
                            next CONSTRICTION;
                        }

                        my $QueryConstrictionCondition = $DFRemoteDBObject->QueryCondition(
                            Key           => $ConstrictionRule[0],
                            Value         => $QuotedConstrictionValue,
                            SearchPrefix  => '',
                            SearchSuffix  => '',
                            CaseSensitive => $DynamicFieldConfig->{Config}->{CaseSensitive},
                        );
                        if ( $QueryConstrictionCondition ) {
                            if ( $QueryCondition ) {
                                $QueryCondition .= ' AND '
                            }
                            $QueryCondition .= $QueryConstrictionCondition;
                        }
                    }
                }

                if ($ConstrictionsCheck) {

                    my $SQL = 'SELECT '
                        . $DynamicFieldConfig->{Config}->{DatabaseFieldKey}
                        . ', '
                        . $DynamicFieldConfig->{Config}->{DatabaseFieldValue}
                        . ' FROM '
                        . $DynamicFieldConfig->{Config}->{DatabaseTable}
                        . ' WHERE '
                        . $QueryCondition;

                    # create cache object
                    if ( $DynamicFieldConfig->{Config}->{CacheTTL} ) {
                        $Self->{CacheObject} = Kernel::System::Cache->new( %{$Self} );

                        # set cache type
                        $Self->{CacheType} = 'DynamicField_RemoteDB_' . $DynamicFieldConfig->{Name};

                        my $PossibleValues = $Kernel::OM->Get('Kernel::System::Cache')->Get(
                            Type => $Self->{CacheType},
                            Key  => "Search::" . $SQL . "::" . join('::', @Entries),
                        );
                        @PossibleValues = @{$PossibleValues} if $PossibleValues;
                    }

                    if (!scalar(@PossibleValues)) {

                        my $Success = $DFRemoteDBObject->Prepare(
                            SQL   => $SQL,
                        );
                        if ( !$Success ) {
                            return;
                        }

                        my $MaxCount = 1;
                        RESULT:
                        while (my @Row = $DFRemoteDBObject->FetchrowArray()) {
                            my $Key    = $Row[0];
                            next RESULT if ( grep( /^$Key$/, @Entries ) );

                            my $Value  = $Row[1];

                            my $Title = $Value;
                            if ( $DynamicFieldConfig->{Config}->{ShowKeyInTitle} ) {
                                $Title .= ' (' . $Key . ')';
                            }

                            push @PossibleValues, {
                                Key    => $Key,
                                Value  => $Value,
                                Title  => $Title,
                            };
                            last RESULT if ($MaxCount == ($DynamicFieldConfig->{Config}->{MaxQueryResult} || 10));
                            $MaxCount++;
                        }

                        # cache request
                        if ( $DynamicFieldConfig->{Config}->{CacheTTL} ) {
                            $Kernel::OM->Get('Kernel::System::Cache')->Set(
                                Type  => $Self->{CacheType},
                                Key   => "Search::" . $SQL . "::" . join('::', @Entries),
                                Value => \@PossibleValues,
                                TTL   => $DynamicFieldConfig->{Config}->{CacheTTL},
                            );
                        }
                    }
                }
            }

            # build JSON output
            $JSON = $Self->{LayoutObject}->JSONEncode(
                Data => \@PossibleValues,
            );
        }

        # handle subaction PossibleValueCheck
        elsif($Subaction eq 'PossibleValueCheck') {
            my @PossibleValues;

            my $TicketID       = $Self->{ParamObject}->GetParam( Param => 'TicketID' ) || '';
            my $CustomerUserID = $Self->{ParamObject}->GetParam( Param => 'CustomerUserID' )
                                || uri_unescape($Self->{ParamObject}->GetParam( Param => 'SelectedCustomerUser' ))
                                || '';

            my %TicketData;
            if ($TicketID =~ /^\d+$/) {
                %TicketData = $Self->{TicketObject}->TicketGet(
                    TicketID      => $TicketID,
                    DynamicFields => 1,
                    Extended      => 1,
                    UserID        => 1,
                    Silent        => 1,
                );
                $CustomerUserID = $TicketData{CustomerUserID} if ( $TicketData{CustomerUserID} );
            }

            my %CustomerUserData;
            if ( $CustomerUserID ) {
                %CustomerUserData = $Self->{CustomerUserObject}->CustomerUserDataGet(
                    User => $CustomerUserID,
                );
            }

            my @SearchFields = split( ',', $DynamicFieldConfig->{Config}->{DatabaseFieldSearch} );
            my $QueryCondition = $DFRemoteDBObject->QueryCondition(
                Key           => \@SearchFields,
                Value         => '*',
                SearchPrefix  => '',
                SearchSuffix  => '',
                CaseSensitive => $DynamicFieldConfig->{Config}->{CaseSensitive},
            );

            # get used Constrictions
            my $Constrictions = $DynamicFieldConfig->{Config}->{Constrictions};

            # prepare constrictions
            my $ConstrictionsCheck = 1;
            if ( $Constrictions ) {
                my @Constrictions = split(/[\n\r]+/, $Constrictions);
                CONSTRICTION:
                for my $Constriction ( @Constrictions ) {
                    my @ConstrictionRule = split(/::/, $Constriction);
                    my $ConstrictionCheck = 1;
                    my $ConstrictionValue;
                    # check for valid constriction
                    next CONSTRICTION if (
                        scalar(@ConstrictionRule) != 4
                        || $ConstrictionRule[0] eq ""
                        || $ConstrictionRule[1] eq ""
                        || $ConstrictionRule[2] eq ""
                    );

                    # mandatory constriction
                    if ($ConstrictionRule[3]) {
                        $ConstrictionCheck = 0;
                    }

                    # only handle static constrictions in admininterface
                    if (
                        $ConstrictionRule[1] eq 'Configuration'
                    ) {
                        $ConstrictionValue = $ConstrictionRule[2];
                        $ConstrictionCheck = 1;
                    } elsif (
                        $ConstrictionRule[1] eq 'Ticket'
                        && (
                            $Self->{ParamObject}->GetParam( Param => $ConstrictionRule[2] )
                            || $TicketData{ $ConstrictionRule[2] }
                        )
                    ) {
                        $ConstrictionValue = $Self->{ParamObject}->GetParam( Param => $ConstrictionRule[2] )
                                          || $TicketData{ $ConstrictionRule[2] };
                        $ConstrictionCheck = 1;
                    } elsif (
                        $ConstrictionRule[1] eq 'CustomerUser'
                        && $CustomerUserData{ $ConstrictionRule[2] }
                    ) {
                        $ConstrictionValue = $CustomerUserData{ $ConstrictionRule[2] };
                        $ConstrictionCheck = 1;
                    }

                    # stop if mandatory constriction not valid
                    if ( !$ConstrictionCheck ) {
                        $ConstrictionsCheck = 0;
                        last CONSTRICTION;
                    }

                    # quote constriction value
                    my $QuotedConstrictionValue = $DFRemoteDBObject->Quote($ConstrictionValue);

                    # skip if quoted constriction is empty/zero
                    if ( !$QuotedConstrictionValue ) {
                        next CONSTRICTION;
                    }

                    my $QueryConstrictionCondition = $DFRemoteDBObject->QueryCondition(
                        Key           => $ConstrictionRule[0],
                        Value         => $QuotedConstrictionValue,
                        SearchPrefix  => '',
                        SearchSuffix  => '',
                        CaseSensitive => $DynamicFieldConfig->{Config}->{CaseSensitive},
                    );
                    if ( $QueryConstrictionCondition ) {
                        if ( $QueryCondition ) {
                            $QueryCondition .= ' AND '
                        }
                        $QueryCondition .= $QueryConstrictionCondition;
                    }
                }
            }

            if ($ConstrictionsCheck) {

                my $SQL = 'SELECT '
                    . $DynamicFieldConfig->{Config}->{DatabaseFieldKey}
                    . ' FROM '
                    . $DynamicFieldConfig->{Config}->{DatabaseTable}
                    . ' WHERE '
                    . $QueryCondition;

                # create cache object
                if ( $DynamicFieldConfig->{Config}->{CacheTTL} ) {
                    $Self->{CacheObject} = Kernel::System::Cache->new( %{$Self} );

                    # set cache type
                    $Self->{CacheType} = 'DynamicField_RemoteDB_' . $DynamicFieldConfig->{Name};

                    my $PossibleValues = $Kernel::OM->Get('Kernel::System::Cache')->Get(
                        Type => $Self->{CacheType},
                        Key  => "PossibleValueCheck::" . $SQL . "::" . join('::', @Entries),
                    );
                    @PossibleValues = @{$PossibleValues} if $PossibleValues;
                }

                if (!scalar(@PossibleValues)) {

                    my $Success = $DFRemoteDBObject->Prepare(
                        SQL   => $SQL,
                    );
                    if ( !$Success ) {
                        return;
                    }

                    RESULT:
                    while (my @Row = $DFRemoteDBObject->FetchrowArray()) {
                        my $Key = $Row[0];
                        next RESULT if ( !grep( /^$Key$/, @Entries ) );

                        push ( @PossibleValues, $Key );
                    }

                    # cache request
                    if ( $DynamicFieldConfig->{Config}->{CacheTTL} ) {
                        $Kernel::OM->Get('Kernel::System::Cache')->Set(
                            Type  => $Self->{CacheType},
                            Key   => "PossibleValueCheck::" . $SQL . "::" . join('::', @Entries),
                            Value => \@PossibleValues,
                            TTL   => $DynamicFieldConfig->{Config}->{CacheTTL},
                        );
                    }
                }

            }

            # build JSON output
            $JSON = $Self->{LayoutObject}->JSONEncode(
                Data => \@PossibleValues,
            );
        }

        # handle subaction AddValue
        elsif($Subaction eq 'AddValue') {
            my %Data;
            my $Key = $Self->{ParamObject}->GetParam( Param => 'Key' )  || '';
            if ( !grep( /^$Key$/, @Entries ) ) {
                my $Value = $Self->{RemoteDBObject}->ValueLookup(
                    Key                => $Key,
                    DynamicFieldConfig => $DynamicFieldConfig,
                );

                my $Title = $Value;
                if ( $DynamicFieldConfig->{Config}->{ShowKeyInTitle} ) {
                    $Title .= ' (' . $Key . ')';
                }

                $Data{Key}   = $Key;
                $Data{Value} = $Value;
                $Data{Title} = $Title;

                # build JSON output
                $JSON = $Self->{LayoutObject}->JSONEncode(
                    Data => \%Data,
                );
            }
        }

    }

    # send JSON response
    return $Self->{LayoutObject}->Attachment(
        ContentType => 'application/json; charset=' . $Self->{LayoutObject}->{Charset},
        Content     => $JSON || '',
        Type        => 'inline',
        NoCache     => 1,
    );
}

1;
