# --
# Copyright (C) 2006-2018 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::DynamicFieldITSMConfigItemAJAXHandler;

use strict;
use warnings;

use URI::Escape;
use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::Output::HTML::Layout',
    'Kernel::System::CustomerUser',
    'Kernel::System::DynamicField',
    'Kernel::System::Encode',
    'Kernel::System::GeneralCatalog',
    'Kernel::System::ITSMConfigItem',
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
    $Self->{LayoutObject}                  = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    $Self->{CustomerUserObject}            = $Kernel::OM->Get('Kernel::System::CustomerUser');
    $Self->{DynamicFieldObject}            = $Kernel::OM->Get('Kernel::System::DynamicField');
    $Self->{EncodeObject}                  = $Kernel::OM->Get('Kernel::System::Encode');
    $Self->{GeneralCatalogObject}          = $Kernel::OM->Get('Kernel::System::GeneralCatalog');
    $Self->{ITSMConfigItemObject}          = $Kernel::OM->Get('Kernel::System::ITSMConfigItem');
    $Self->{LogObject}                     = $Kernel::OM->Get('Kernel::System::Log');
    $Self->{TicketObject}                  = $Kernel::OM->Get('Kernel::System::Ticket');
    $Self->{ParamObject}                   = $Kernel::OM->Get('Kernel::System::Web::Request');

    my $JSON = '';

    # get mandatory param
    my $DynamicFieldID = $Self->{ParamObject}->GetParam( Param => 'DynamicFieldID' );

    if ($DynamicFieldID) {

        # get needed params
        my $Subaction   = $Self->{ParamObject}->GetParam( Param => 'Subaction' ) || '';
        my $FieldPrefix = $Self->{ParamObject}->GetParam( Param => 'FieldPrefix' ) || '';

        my $DynamicFieldConfig = $Self->{DynamicFieldObject}->DynamicFieldGet(
            ID => $DynamicFieldID,
        );

        if ( $DynamicFieldConfig->{FieldType} ne 'ITSMConfigItemReference' ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message => "DynamicFieldITSMConfigItemAJAXHandler: DynamicField doesn't refer to type ITSMConfigItem.",
            );
            return;
        }

        # get used entries
        my @Entries = $Self->{ParamObject}->GetArray( Param => $FieldPrefix . 'DynamicField_' . $DynamicFieldConfig->{Name} );

        # get attributes from web request
        my @ParamNames = $Self->{ParamObject}->GetParamNames();
        my %WebParams  = map { $_ => 1 } @ParamNames;

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

                    if (
                        $CustomerUserID
                        && $CustomerUserID =~ m/<(.*)>/
                    ) {
                        my %List = $Self->{CustomerUserObject}->CustomerSearch(
                            PostMasterSearch => $1,
                            Valid            => 1,
                        );
                        for my $Key ( keys %List ) {
                            if ( $List{$Key} eq $CustomerUserID ) {
                                $CustomerUserID = $Key;
                                last;
                            }
                        }
                    }
                }

                if ( $Self->{UserType} eq 'Customer' ) {
                    $CustomerUserID = $Self->{UserID};
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

                # get used Constrictions
                my $Constrictions = $DynamicFieldConfig->{Config}->{Constrictions};

                # build search params from constrictions...
                my @SearchParamsWhat;

                # prepare constrictions
                my %Constrictions = ();
                my $ConstrictionsCheck = 1;
                if ( $Constrictions ) {
                    my @Constrictions = split(/[\n\r]+/, $Constrictions);
                    CONSTRICTION:
                    for my $Constriction ( @Constrictions ) {
                        my @ConstrictionRule = split(/::/, $Constriction);
                        my $ConstrictionCheck = 1;
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
                            $Constrictions{$ConstrictionRule[0]} = $ConstrictionRule[2];
                            $ConstrictionCheck = 1;
                        } elsif (
                            $ConstrictionRule[1] eq 'Ticket'
                            && (
                                $WebParams{ $ConstrictionRule[2] }
                                || defined( $TicketData{ $ConstrictionRule[2] } )
                            )
                        ) {
                            # get value from ticket data
                            $Constrictions{$ConstrictionRule[0]} = $TicketData{ $ConstrictionRule[2] };
                            # use only first entry if array is given
                            if ( ref($Constrictions{$ConstrictionRule[0]}) eq 'ARRAY' ) {
                                $Constrictions{$ConstrictionRule[0]} = $Constrictions{$ConstrictionRule[0]}->[0];
                            }
                            # check if attribute is in web params
                            if ( $WebParams{ $ConstrictionRule[2] } ) {
                                $Constrictions{$ConstrictionRule[0]} = $Self->{ParamObject}->GetParam( Param => $ConstrictionRule[2] ) || '';
                            }
                            # mark check success if value is not empty
                            if ( $Constrictions{$ConstrictionRule[0]} ) {
                                $ConstrictionCheck = 1;
                            }
                            # set constriction value undef if empty
                            else {
                                delete( $Constrictions{$ConstrictionRule[0]} );
                            }
                        } elsif (
                            $ConstrictionRule[1] eq 'CustomerUser'
                            && $CustomerUserData{ $ConstrictionRule[2] }
                        ) {
                            $Constrictions{$ConstrictionRule[0]} = $CustomerUserData{ $ConstrictionRule[2] };
                            $ConstrictionCheck = 1;
                        }

                        # stop if mandatory constriction not valid
                        if ( !$ConstrictionCheck ) {
                            $ConstrictionsCheck = 0;
                            last CONSTRICTION;
                        }
                    }
                }

                if ($ConstrictionsCheck) {

                    my @ITSMConfigItemClasses = ();
                    if(
                        defined( $DynamicFieldConfig->{Config}->{ITSMConfigItemClasses} )
                        && IsArrayRefWithData( $DynamicFieldConfig->{Config}->{ITSMConfigItemClasses} )
                    ) {
                        @ITSMConfigItemClasses = @{$DynamicFieldConfig->{Config}->{ITSMConfigItemClasses}};
                    }
                    else {
                        my $ClassRef = $Self->{GeneralCatalogObject}->ItemList(
                            Class => 'ITSM::ConfigItem::Class',
                        );
                        for my $ClassID ( keys ( %{$ClassRef} ) ) {
                            push ( @ITSMConfigItemClasses, $ClassID );
                        }
                    }

                    for my $ClassID ( @ITSMConfigItemClasses ) {
                        # get current definition
                        my $XMLDefinition = $Self->{ITSMConfigItemObject}->DefinitionGet(
                            ClassID => $ClassID,
                        );

                        # prepare seach
                        $Self->_ExportXMLSearchDataPrepare(
                            XMLDefinition => $XMLDefinition->{DefinitionRef},
                            What          => \@SearchParamsWhat,
                            SearchData    => {
                                %Constrictions,
                            },
                        );
                    }

                    $Search = '*' . $Search . '*';

                    if ( !scalar( @SearchParamsWhat ) ) {
                        @SearchParamsWhat = undef;
                    }

                    my %ConfigItemIDs;
                    my $ConfigItemIDResult;
                    if ( $Search !~ m/^[*]+$/) {
                        $ConfigItemIDResult = $Self->{ITSMConfigItemObject}->ConfigItemSearchExtended(
                            Name         => $Search,
                            ClassIDs     => \@ITSMConfigItemClasses,
                            DeplStateIDs => $DynamicFieldConfig->{Config}->{DeploymentStates},
                            What         => \@SearchParamsWhat,
                        );

                        for my $ID ( @{$ConfigItemIDResult} ) {
                            $ConfigItemIDs{$ID} = 1;
                        }
                    }

                    $ConfigItemIDResult = $Self->{ITSMConfigItemObject}->ConfigItemSearchExtended(
                        Number       => $Search,
                        ClassIDs     => \@ITSMConfigItemClasses,
                        DeplStateIDs => $DynamicFieldConfig->{Config}->{DeploymentStates},
                        What         => \@SearchParamsWhat,
                    );

                    for my $ID ( @{$ConfigItemIDResult} ) {
                        $ConfigItemIDs{$ID} = 1;
                    }

                    my $MaxCount = 1;
                    CIID:
                    for my $Key ( sort ( keys ( %ConfigItemIDs ) ) ) {
                        next CIID if ( grep { /^$Key$/ } @Entries  );

                        my $ConfigItem = $Self->{ITSMConfigItemObject}->VersionGet(
                            ConfigItemID => $Key,
                            XMLDataGet   => 0,
                        );

                        my $Value = $DynamicFieldConfig->{Config}->{DisplayPattern} || '<CI_Name>';
                        while ($Value =~ m/<CI_([^>]+)>/) {
                            my $Replace = $ConfigItem->{$1} || '';
                            $Value =~ s/<CI_$1>/$Replace/g;
                        }

                        my $Title = $ConfigItem->{Name};

                        push @PossibleValues, {
                            Key   => $Key,
                            Value => $Value,
                            Title => $Title,
                        };
                        last CIID if ($MaxCount == ($DynamicFieldConfig->{Config}->{MaxQueryResult} || 10));
                        $MaxCount++;
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

            if (
                $CustomerUserID
                && $CustomerUserID =~ m/<(.*)>/
            ) {
                my %List = $Self->{CustomerUserObject}->CustomerSearch(
                    PostMasterSearch => $1,
                    Valid            => 1,
                );
                for my $Key ( keys %List ) {
                    if ( $List{$Key} eq $CustomerUserID ) {
                        $CustomerUserID = $Key;
                        last;
                    }
                }
            }

            if ( $Self->{UserType} eq 'Customer' ) {
                $CustomerUserID = $Self->{UserID};
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

            # get used Constrictions
            my $Constrictions = $DynamicFieldConfig->{Config}->{Constrictions};

            # build search params from constrictions...
            my @SearchParamsWhat;

            # prepare constrictions
            my %Constrictions = ();
            my $ConstrictionsCheck = 1;
            if ( $Constrictions ) {
                my @Constrictions = split(/[\n\r]+/, $Constrictions);
                CONSTRICTION:
                for my $Constriction ( @Constrictions ) {
                    my @ConstrictionRule = split(/::/, $Constriction);
                    my $ConstrictionCheck = 1;
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
                        $Constrictions{$ConstrictionRule[0]} = $ConstrictionRule[2];
                        $ConstrictionCheck = 1;
                    } elsif (
                        $ConstrictionRule[1] eq 'Ticket'
                        && (
                            $WebParams{ $ConstrictionRule[2] }
                            || defined( $TicketData{ $ConstrictionRule[2] } )
                        )
                    ) {
                        # get value from ticket data
                        $Constrictions{$ConstrictionRule[0]} = $TicketData{ $ConstrictionRule[2] };
                        # use only first entry if array is given
                        if ( ref($Constrictions{$ConstrictionRule[0]}) eq 'ARRAY' ) {
                            $Constrictions{$ConstrictionRule[0]} = $Constrictions{$ConstrictionRule[0]}->[0];
                        }
                        # check if attribute is in web params
                        if ( $WebParams{ $ConstrictionRule[2] } ) {
                            $Constrictions{$ConstrictionRule[0]} = $Self->{ParamObject}->GetParam( Param => $ConstrictionRule[2] ) || '';
                        }
                        # mark check success if value is not empty
                        if ( $Constrictions{$ConstrictionRule[0]} ) {
                            $ConstrictionCheck = 1;
                        }
                        # set constriction value undef if empty
                        else {
                            delete( $Constrictions{$ConstrictionRule[0]} );
                        }
                    } elsif (
                        $ConstrictionRule[1] eq 'CustomerUser'
                        && $CustomerUserData{ $ConstrictionRule[2] }
                    ) {
                        $Constrictions{$ConstrictionRule[0]} = $CustomerUserData{ $ConstrictionRule[2] };
                        $ConstrictionCheck = 1;
                    }

                    # stop if mandatory constriction not valid
                    if ( !$ConstrictionCheck ) {
                        $ConstrictionsCheck = 0;
                        last CONSTRICTION;
                    }
                }
            }

            if ($ConstrictionsCheck) {

                my @ITSMConfigItemClasses = ();
                if(
                    defined( $DynamicFieldConfig->{Config}->{ITSMConfigItemClasses} )
                    && IsArrayRefWithData( $DynamicFieldConfig->{Config}->{ITSMConfigItemClasses} )
                ) {
                    @ITSMConfigItemClasses = @{$DynamicFieldConfig->{Config}->{ITSMConfigItemClasses}};
                }
                else {
                    my $ClassRef = $Self->{GeneralCatalogObject}->ItemList(
                        Class => 'ITSM::ConfigItem::Class',
                    );
                    for my $ClassID ( keys ( %{$ClassRef} ) ) {
                        push ( @ITSMConfigItemClasses, $ClassID );
                    }
                }

                for my $ClassID ( @ITSMConfigItemClasses ) {
                    # get current definition
                    my $XMLDefinition = $Self->{ITSMConfigItemObject}->DefinitionGet(
                        ClassID => $ClassID,
                    );

                    # prepare seach
                    $Self->_ExportXMLSearchDataPrepare(
                        XMLDefinition => $XMLDefinition->{DefinitionRef},
                        What          => \@SearchParamsWhat,
                        SearchData    => {
                            %Constrictions,
                        },
                    );
                }

                if ( !scalar( @SearchParamsWhat ) ) {
                    @SearchParamsWhat = undef;
                }

                my $ConfigItemIDs = $Self->{ITSMConfigItemObject}->ConfigItemSearchExtended(
                    Number       => '*',
                    ClassIDs     => \@ITSMConfigItemClasses,
                    DeplStateIDs => $DynamicFieldConfig->{Config}->{DeploymentStates},
                    What         => \@SearchParamsWhat,
                );

                CIID:
                for my $Key ( @{$ConfigItemIDs} ) {
                    next CIID if ( !grep { /^$Key$/ } @Entries );

                    push ( @PossibleValues, $Key );
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
            if ( !grep { /^$Key$/ } @Entries ) {
                my $ConfigItem = $Self->{ITSMConfigItemObject}->VersionGet(
                    ConfigItemID => $Key,
                    XMLDataGet   => 0,
                );

                my $Value = $DynamicFieldConfig->{Config}->{DisplayPattern} || '<CI_Name>';
                while ($Value =~ m/<CI_([^>]+)>/) {
                    my $Replace = $ConfigItem->{$1} || '';
                    $Value =~ s/<CI_$1>/$Replace/g;
                }

                my $Title = $ConfigItem->{Name};

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

sub _ExportXMLSearchDataPrepare {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    return if !$Param{XMLDefinition} || ref $Param{XMLDefinition} ne 'ARRAY';
    return if !$Param{What}          || ref $Param{What}          ne 'ARRAY';
    return if !$Param{SearchData}    || ref $Param{SearchData}    ne 'HASH';

    # my config item object
    my $ConfigItemObject = $Kernel::OM->Get('Kernel::System::ITSMConfigItem');

    ITEM:
    for my $Item ( @{ $Param{XMLDefinition} } ) {

        # create key
        my $Key = $Param{Prefix} ? $Param{Prefix} . '::' . $Item->{Key} : $Item->{Key};
        my $DataKey = $Item->{Key};

        # prepare value
        my $Values = $Param{SearchData}->{$DataKey};
        if ($Values) {

            # create search key
            my $SearchKey = $Key;
            $SearchKey =~ s{ :: }{\'\}[%]\{\'}xmsg;

            # create search hash
            my $SearchHash = {
                '[1]{\'Version\'}[1]{\''
                    . $SearchKey
                    . '\'}[%]{\'Content\'}' => $Values,
            };
            push @{ $Param{What} }, $SearchHash;
        }
        next ITEM if !$Item->{Sub};

        # start recursion, if "Sub" was found
        $Self->_ExportXMLSearchDataPrepare(
            XMLDefinition => $Item->{Sub},
            What          => $Param{What},
            SearchData    => $Param{SearchData},
            Prefix        => $Key,
        );
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
