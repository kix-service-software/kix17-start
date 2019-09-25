# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::Layout::KIXITSMConfigManagement;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::Output::HTML::Layout',
    'Kernel::System::DB',
    'Kernel::System::GeneralCatalog',
    'Kernel::System::Log',
    'Kernel::System::ITSMConfigItem',
    'Kernel::System::Ticket',
    'Kernel::System::User',
);

sub KIXSideBarAssignedConfigItemsTable {
    my ( $Self, %Param ) = @_;

    # create needed objects
    my $LayoutObject         = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $GeneralCatalogObject = $Kernel::OM->Get('Kernel::System::GeneralCatalog');
    my $ConfigItemObject     = $Kernel::OM->Get('Kernel::System::ITSMConfigItem');
    my $LinkObject           = $Kernel::OM->Get('Kernel::System::LinkObject');
    my $CustomerUserObject   = $Kernel::OM->Get('Kernel::System::CustomerUser');
    my $ConfigObject         = $Kernel::OM->Get('Kernel::Config');
    my $TicketObject         = $Kernel::OM->Get('Kernel::System::Ticket');
    my $UserObject           = $Kernel::OM->Get('Kernel::System::User');
    my $LogObject            = $Kernel::OM->Get('Kernel::System::Log');

    $Param{CallingAction} ||= '';
    if ( !$Param{Frontend} ) {
        $Param{Frontend} = ( $Param{CallingAction} =~ /^Customer/ ) ? 'Customer' : 'Agent';
    }

    # get customer data
    my %Customers;
    if ( $Param{CustomerUserID} ) {
        if ( !defined $Param{CustomerData} || (ref $Param{CustomerData} ne 'HASH') || !%{$Param{CustomerData}}) {
            my %CustomerData = $CustomerUserObject->CustomerUserDataGet(
                User => $Param{CustomerUserID},
            );
            $Customers{ $Param{CustomerUserID} } = \%CustomerData;
        }
        else {
            $Customers{ $Param{CustomerUserID} } = $Param{CustomerData};
        }
    }
    elsif ( $Param{CustomerUserIDs} ) {
        for my $Customer ( keys %{ $Param{CustomerUserIDs} } ) {
            my %CustomerData = $CustomerUserObject->CustomerUserDataGet(
                User => $Customer,
            );
            $Customers{$Customer} = \%CustomerData;
        }
    }
    elsif ( $Param{CustomerData} ) {
        if ( defined $Param{CustomerData}->{UserID} ) {
            $Customers{ $Param{CustomerData}->{UserID} } = $Param{CustomerData};
        }
        else {
            return;
        }
    }
    else {
        return;
    }

    my $CallingAction = $Param{CallingAction} || '';

    # check searchpattern
    my $KIXSidebarLinkedCIsParams =
        $ConfigObject->Get('KIXSidebarConfigItemLink::KIXSidebarLinkedCIsParams');
    my $ShowLinkCheckbox;
    if ( defined $Param{ShowCheckboxes} ) {
        $ShowLinkCheckbox = $Param{ShowCheckboxes};
    }
    else {
        $ShowLinkCheckbox = $KIXSidebarLinkedCIsParams->{ShowLinkCheckbox};
    }

    # check permissions to en/disable checkbox
    my $LinkCheckboxWriteable = 0;
    if ( !$Param{Config}->{ShowLinkCheckboxReadonly} ) {
        $LinkCheckboxWriteable = 1;
        if ( $Param{TicketID} ) {
            $LinkCheckboxWriteable = $TicketObject->TicketPermission(
                Type     => 'rw',
                TicketID => $Param{TicketID},
                UserID   => $Self->{UserID}
            );
        }
    }

    # check restrictions
    my %GetParam;
    for my $Field ( @{ $Param{SelectedSearchFields} } ) {
        $GetParam{$Field} = $Param{$Field};
    }

    my @AssignedCIIDs = ();
    CUSTOMER:
    for my $Customer ( keys %Customers ) {
        my $SearchInClassesRef = $ConfigObject->Get('KIXSidebarConfigItemLink::CISearchInClasses');

        # perform CMDB search and link results...
        CICLASS:
        for my $CIClass ( keys %{$SearchInClassesRef} ) {
            next CICLASS if !$SearchInClassesRef->{$CIClass};
            for my $SearchAttribute (
                split(
                    /\s*,\s*/,
                    (
                        $KIXSidebarLinkedCIsParams->{ 'SearchAttribute:::' . $CIClass }
                            || $KIXSidebarLinkedCIsParams->{SearchAttribute}
                        )
                )
            ) {
                $Param{SearchPattern}
                    = $Customers{$Customer}->{$SearchAttribute} || '';
                next CUSTOMER if !$Param{SearchPattern};

                my @SearchStrings = $Param{SearchPattern};

                my $SearchAttributeKeyList = $SearchInClassesRef->{$CIClass} || '';

                my $ClassItemRef = $GeneralCatalogObject->ItemGet(
                    Class => 'ITSM::ConfigItem::Class',
                    Name  => $CIClass,
                ) || 0;
                next CICLASS if ( ref($ClassItemRef) ne 'HASH' || !$ClassItemRef->{ItemID} );
                next CICLASS
                    if defined $Param{Class}
                        && $Param{Class} ne ''
                        && $Param{Class} ne $ClassItemRef->{ItemID};

                # get CI-class definition...
                my $XMLDefinition = $ConfigItemObject->DefinitionGet(
                    ClassID => $ClassItemRef->{ItemID},
                );
                if ( !$XMLDefinition->{DefinitionID} ) {
                    $LogObject->Log(
                        Priority => 'error',
                        Message  => "No Definition definied for class $CIClass!",
                    );
                    next CICLASS;
                }

                SEARCHATTR:
                for my $SearchAttributeKey ( split( ',', $SearchAttributeKeyList ) ) {
                    $SearchAttributeKey =~ s/^\s+//g;
                    $SearchAttributeKey =~ s/\s+$//g;
                    next SEARCHATTR if !$SearchAttributeKey;

                    for my $CurrSearchString (@SearchStrings) {
                        my %SearchParams = ();
                        my %SearchData   = ();

                        # prepare SearchData
                        foreach my $Key ( keys %GetParam ) {
                            $SearchData{$Key} = $GetParam{$Key}
                                if ( $Key ne 'Name' && $Key ne 'Number' );
                        }

                        # build search params...
                        $SearchData{$SearchAttributeKey} = $CurrSearchString;
                        my @SearchParamsWhat;
                        $Self->_ExportXMLSearchDataPrepare(
                            XMLDefinition => $XMLDefinition->{DefinitionRef},
                            What          => \@SearchParamsWhat,
                            SearchData    => \%SearchData,
                        );

                        # if this CI class doesn't contain all the search attributes then we have to ignore it
                        next CICLASS if scalar(@SearchParamsWhat) < scalar( keys %SearchData );

                        # build search hash...
                        if (@SearchParamsWhat) {
                            $SearchParams{What} = \@SearchParamsWhat;

                            my $ConfigItemList
                                = $ConfigItemObject->ConfigItemSearchExtended(
                                %GetParam,
                                %SearchParams,
                                ClassIDs => [ $ClassItemRef->{ItemID} ],
                                UserID   => $Param{UserID},
                                );
                            if ( $ConfigItemList && ref($ConfigItemList) eq 'ARRAY' ) {

                                # add only not existing items
                                for my $ListItem ( @{$ConfigItemList} ) {
                                    next if grep { $_ == $ListItem } @AssignedCIIDs;
                                    push @AssignedCIIDs, $ListItem;
                                }
                            }
                        }

                    }
                }
            }
        }
    }
    return '' if !scalar(@AssignedCIIDs);

    my $CIExcludeDeploymentStates = $ConfigObject->Get('KIXSidebarConfigItemLink::CIExcludeDeploymentStates');
    my $CIExcludeIncidentStates   = $ConfigObject->Get('KIXSidebarConfigItemLink::CIExcludeIncidentStates');

    my @AssignedCIIDsCheck = @AssignedCIIDs;
    @AssignedCIIDs = ();

    CONFIGITEM:
    for my $ConfigItemID (@AssignedCIIDsCheck) {
        my $ConfigItem = $ConfigItemObject->ConfigItemGet(
            ConfigItemID => $ConfigItemID,
        );

        for my $State ( @{$CIExcludeDeploymentStates} ) {
            next CONFIGITEM if $ConfigItem->{CurDeplState} eq $State;
        }

        for my $State ( @{$CIExcludeIncidentStates} ) {
            next CONFIGITEM if $ConfigItem->{CurInciState} eq $State;
        }

        # check access for config item
        my $HasAccess = $ConfigItemObject->Permission(
            Scope    => 'Item',
            ItemID   => $ConfigItemID,
            UserID   => $Self->{UserID},
            Type     => 'ro',
            Frontend => $Param{Frontend},
        ) || 0;

        next CONFIGITEM if !$HasAccess;
        push( @AssignedCIIDs, $ConfigItemID );
    }
    return '' if !scalar(@AssignedCIIDs);

    $Self->Block(
        Name => 'LinkConfigItem' . $Param{Frontend},
    );

    if ($ShowLinkCheckbox) {
        $Self->Block(
            Name => 'LinkConfigItemRowCheckboxHeader' . $Param{Frontend},
        );
    }

    my $ShownAttributes = $ConfigObject->Get('KIXSidebarConfigItemLink::ShownAttributes');

    for my $Key ( sort keys %{$ShownAttributes} ) {
        $Self->Block(
            Name => 'LinkConfigItemRowHeader' . $Param{Frontend},
            Data => {
                Head => $ShownAttributes->{$Key},
            },
        );
    }

    # Get all CI linked with this ticket
    my %ConfigItemList = ();
    if ( $Param{TicketID} ) {
        $Param{LinkMode} = 'Valid';
    }
    else {

        # set temporary formID as Ticketid
        $Param{TicketID} = $Param{FormID};
        $Param{LinkMode} = 'Temporary';
    }
    if ( $Param{TicketID} ) {

        # get linked objects
        my $LinkListWithData = $LinkObject->LinkListWithData(
            Object => 'Ticket',
            Key    => $Param{TicketID},
            State  => $Param{LinkMode},
            UserID => 1,
        );
        for my $LinkObject ( keys %{$LinkListWithData} ) {
            next if $LinkObject ne "ITSMConfigItem";
            for my $LinkType ( keys %{ $LinkListWithData->{$LinkObject} } ) {
                for my $LinkDirection ( keys %{ $LinkListWithData->{$LinkObject}->{$LinkType} } ) {
                    for my $LinkItem (
                        keys %{ $LinkListWithData->{$LinkObject}->{$LinkType}->{$LinkDirection} }
                    ) {
                        $ConfigItemList{$LinkItem} = 'checked="checked"';
                    }
                }
            }
        }
    }
    my $Count    = 0;
    my $DivCount = 1;

    # get user preferences
    my $ShownCILinks = 10;
    if ( $Param{Frontend} ne 'Customer' ) {
        my %UserPreferences = $UserObject->GetPreferences( UserID => $Self->{UserID} );
        $ShownCILinks = $UserPreferences{KIXSidebarCILinksShow} || 10;
    }

    my $LinkCounter = 1;
    my $AllCounter  = 0;

    for my $ConfigItemID (@AssignedCIIDs) {

        if ( $Count == 0 ) {
            $Self->Block(
                Name => 'LinkConfigItem' . $Param{Frontend} . 'Table',
                Data => {
                    DivCount => $DivCount,
                    Style    => 'display:none',
                },
            );
        }

        # get config item data
        my $ConfigItem = $ConfigItemObject->ConfigItemGet(
            ConfigItemID => $ConfigItemID,
        );

        # get last version hash
        my $VersionRef = $ConfigItemObject->VersionGet(
            ConfigItemID => $ConfigItemID,
        );

        # get xml-definition
        my $XMLDefinition = $ConfigItemObject->DefinitionGet(
            ClassID => $ConfigItem->{ClassID},
        );
        my $DefinitionRef = $XMLDefinition->{DefinitionRef};

        # output
        $Self->Block(
            Name => 'LinkConfigItemRow' . $Param{Frontend},
            Data => {
                Class  => $VersionRef->{Class},
                Name   => $VersionRef->{Name},
                Number => $ConfigItem->{Number},

                # IsChecked => $ConfigItemList{$ConfigItemID} || '',
                ID => $ConfigItemID,
            },
        );

        if ($ShowLinkCheckbox) {
            $Self->Block(
                Name => 'LinkConfigItemRowCheckbox' . $Param{Frontend},
                Data => {
                    Class          => $VersionRef->{Class},
                    Name           => $VersionRef->{Name},
                    Number         => $ConfigItem->{Number},
                    IsChecked      => $ConfigItemList{$ConfigItemID} || '',
                    LinkedTicketID => $Param{TicketID} || '',
                    LinkMode       => $Param{LinkMode} || '',
                    ID             => $ConfigItemID,
                },
            );
            if ($LinkCheckboxWriteable) {
                $Self->Block(
                    Name => 'LinkConfigItemRowCheckbox' . $Param{Frontend} . 'Edit',
                    Data => {
                        Class     => $VersionRef->{Class},
                        Name      => $VersionRef->{Name},
                        Number    => $ConfigItem->{Number},
                        IsChecked => $ConfigItemList{$ConfigItemID} || '',
                        ID        => $ConfigItemID,
                    },
                );
            }
            else {
                $Self->Block(
                    Name => 'LinkConfigItemRowCheckbox' . $Param{Frontend} . 'Show',
                    Data => {
                        Class     => $VersionRef->{Class},
                        Name      => $VersionRef->{Name},
                        Number    => $ConfigItem->{Number},
                        IsChecked => $ConfigItemList{$ConfigItemID} || '',
                        ID        => $ConfigItemID,
                    },
                );
            }
        }

        for my $Key ( sort keys %{$ShownAttributes} ) {

            my $ConfigItemKey = $Key;
            $ConfigItemKey =~ s/^(.*?)::(.*?)$/$2/;
            if ( $ConfigItemKey =~ /^(.*?)::(.*?)/ ) {
                $ConfigItemKey = $1;
            }

            my $Value;
            if ( defined $VersionRef->{$ConfigItemKey} ) {
                $Value = $VersionRef->{$ConfigItemKey};
            }
            else {
                my $Result = $ConfigItemObject->GetAttributeValuesByKey(
                    KeyName       => $ConfigItemKey,
                    XMLData       => $VersionRef->{XMLData}->[1]->{Version}->[1],
                    XMLDefinition => $VersionRef->{XMLDefinition},
                );

                # translate each value
                foreach my $Value ( @{$Result} ) {
                    $Value = $LayoutObject->{LanguageObject}->Translate($Value);
                }

                # join the result
                $Value = join( ", ", @{$Result} );
            }

            $Self->Block(
                Name => 'LinkConfigItemRowData' . $Param{Frontend},
                Data => {
                    Value => $Value,
                    ID    => $ConfigItemID
                },
            );
            if ( $Key =~ /Link/ ) {
                $Self->Block(
                    Name => 'LinkConfigItemRowDataLinkStart' . $Param{Frontend},
                    Data => {
                        Value => $Value,
                        Name  => $VersionRef->{Name},
                        ID    => $ConfigItemID
                    },
                );
                $Self->Block(
                    Name => 'LinkConfigItemRowDataLinkEnd' . $Param{Frontend},
                );
            }
            else {
                $Self->Block(
                    Name => 'LinkConfigItemRowDataLabelStart' . $Param{Frontend},
                    Data => {
                        Value => $Value,
                        Name  => $VersionRef->{Name},
                        ID    => $ConfigItemID
                    },
                );
                $Self->Block(
                    Name => 'LinkConfigItemRowDataLabelEnd' . $Param{Frontend},
                );
            }
        }

        if ( ++$Count >= $ShownCILinks ) {
            $DivCount++;
            $Count = 0;
        }
    }

    return $Self->Output(
        TemplateFile   => 'KIXSideBarAssignedConfigItemList',
        Data           => \%Param,
        KeepScriptTags => $Param{AJAX} || 0,
    );
}

sub CustomerDashboardAssignedConfigItemsTable {
    my ( $Self, %Param ) = @_;

    # create needed objects
    my $LayoutObject         = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $GeneralCatalogObject = $Kernel::OM->Get('Kernel::System::GeneralCatalog');
    my $ConfigItemObject     = $Kernel::OM->Get('Kernel::System::ITSMConfigItem');
    my $CustomerUserObject   = $Kernel::OM->Get('Kernel::System::CustomerUser');
    my $ConfigObject         = $Kernel::OM->Get('Kernel::Config');
    my $LogObject            = $Kernel::OM->Get('Kernel::System::Log');

    # get customer data
    my %Customers;
    if ( $Param{CustomerUserIDs} ) {
        for my $Customer ( keys %{ $Param{CustomerUserIDs} } ) {
            my %CustomerData = $CustomerUserObject->CustomerUserDataGet(
                User => $Customer,
            );
            $Customers{$Customer} = \%CustomerData;
        }
    }
    else {
        return;
    }

    # check searchpattern
    my $KIXSidebarLinkedCIsParams =
        $ConfigObject->Get('KIXSidebarConfigItemLink::KIXSidebarLinkedCIsParams');

    my @AssignedCIIDs = ();
    my %Assigned;
    CUSTOMER:
    for my $Customer ( keys %Customers ) {

        my $SearchInClassesRef
            = $ConfigObject->Get('CustomerDashboardConfigItemLink::CISearchInClasses');

        # perform CMDB search and link results...
        CICLASS:
        for my $CIClass ( keys %{$SearchInClassesRef} ) {

            next CICLASS if !$SearchInClassesRef->{$CIClass};

            for my $SearchAttribute (
                split(
                    /\s*,\s*/,
                    (
                        $KIXSidebarLinkedCIsParams->{ 'SearchAttribute:::' . $CIClass }
                            || $KIXSidebarLinkedCIsParams->{SearchAttribute}
                        )
                )
            ) {
                $Param{SearchPattern}
                    = $Customers{$Customer}->{$SearchAttribute} || '';
                next CUSTOMER if !$Param{SearchPattern};

                my @SearchStrings = $Param{SearchPattern};

                my $SearchAttributeKeyList = $SearchInClassesRef->{$CIClass} || '';

                my $ClassItemRef = $GeneralCatalogObject->ItemGet(
                    Class => 'ITSM::ConfigItem::Class',
                    Name  => $CIClass,
                ) || 0;
                next CICLASS if ( ref($ClassItemRef) ne 'HASH' || !$ClassItemRef->{ItemID} );
                next CICLASS
                    if defined $Param{Class}
                        && $Param{Class} ne ''
                        && $Param{Class} ne $ClassItemRef->{ItemID};

                # get CI-class definition...
                my $XMLDefinition = $ConfigItemObject->DefinitionGet(
                    ClassID => $ClassItemRef->{ItemID},
                );
                if ( !$XMLDefinition->{DefinitionID} ) {
                    $LogObject->Log(
                        Priority => 'error',
                        Message  => "No Definition definied for class $CIClass!",
                    );
                    next CICLASS;
                }

                SEARCHATTR:
                for my $SearchAttributeKey ( split( ',', $SearchAttributeKeyList ) ) {
                    $SearchAttributeKey =~ s/^\s+//g;
                    $SearchAttributeKey =~ s/\s+$//g;
                    next SEARCHATTR if !$SearchAttributeKey;

                    for my $CurrSearchString (@SearchStrings) {
                        my %SearchParams = ();
                        my %SearchData   = ();

                        # build search params...
                        $SearchData{$SearchAttributeKey} = $CurrSearchString;
                        my @SearchParamsWhat;
                        $Self->_ExportXMLSearchDataPrepare(
                            XMLDefinition => $XMLDefinition->{DefinitionRef},
                            What          => \@SearchParamsWhat,
                            SearchData    => \%SearchData,
                        );

                        # build search hash...
                        next CICLASS if scalar(@SearchParamsWhat) < scalar( keys %SearchData );

                        # build search hash...
                        if (@SearchParamsWhat) {
                            $SearchParams{What} = \@SearchParamsWhat;

                            my $ConfigItemList
                                = $ConfigItemObject->ConfigItemSearchExtended(
                                %SearchParams,
                                ClassIDs => [ $ClassItemRef->{ItemID} ],
                                UserID   => $Param{UserID},
                                );
                            if ( $ConfigItemList && ref($ConfigItemList) eq 'ARRAY' ) {

                                # add only not existing items
                                for my $ListItem ( @{$ConfigItemList} ) {
                                    next if grep { $_ == $ListItem } @AssignedCIIDs;
                                    push @AssignedCIIDs, $ListItem;
                                    push @{ $Assigned{$CIClass} }, $ListItem;
                                }
                            }
                        }
                    }

                }
            }
        }
    }
    return '' if !scalar(@AssignedCIIDs);

    my $CIExcludeDeploymentStates = $ConfigObject->Get('CustomerDashboardConfigItemLink::CIExcludeDeploymentStates');
    my $CIExcludeIncidentStates   = $ConfigObject->Get('CustomerDashboardConfigItemLink::CIExcludeIncidentStates');

    my %AssignedCheck = %Assigned;
    %Assigned = ();

    for my $CIClass ( keys %AssignedCheck ) {
        CONFIGITEM:
        for my $ConfigItemID ( @{ $AssignedCheck{$CIClass} } ) {
            my $ConfigItem = $ConfigItemObject->ConfigItemGet(
                ConfigItemID => $ConfigItemID,
            );

            for my $State ( @{$CIExcludeDeploymentStates} ) {
                next CONFIGITEM if $ConfigItem->{CurDeplState} eq $State;
            }

            for my $State ( @{$CIExcludeIncidentStates} ) {
                next CONFIGITEM if $ConfigItem->{CurInciState} eq $State;
            }

            if ( !defined $Assigned{$CIClass} ) {
                my @TempArray = ();
                $Assigned{$CIClass} = \@TempArray;
            }

            push( @{ $Assigned{$CIClass} }, $ConfigItemID );
        }
    }
    return '' if !scalar(@AssignedCIIDs);

    $Self->Block(
        Name => 'LinkConfigItemTable',
        Data => {},
    );

    my $ShownAttributes = $ConfigObject->Get('CustomerDashboardConfigItemLink::ShownAttributes');

    # fixed number of shown CIs (for now)
    my $ShownCILinks = 10;

    for my $Class ( sort keys %Assigned ) {
        my $TabID = $Class;
        $TabID =~ s/\s*//g;

        $Self->Block(
            Name => 'LinkConfigItemTabLink',
            Data => {
                ClassName => $Class,
                TabID     => $TabID,
                Count     => scalar @{ $Assigned{$Class} }
            },
        );
        $Self->Block(
            Name => 'LinkConfigItemTabContent',
            Data => {
                ClassName => $Class,
                TabID     => $TabID,
            },
        );

        my $Count    = 0;
        my $DivCount = 1;

        for my $ConfigItemID ( @{ $Assigned{$Class} } ) {

            # check access for config item
            my $HasAccess = $ConfigItemObject->Permission(
                Scope  => 'Item',
                ItemID => $ConfigItemID,
                UserID => $Self->{UserID},
                Type   => 'ro',
            ) || 0;

            next if !$HasAccess;

            # get config item data
            my $ConfigItem = $ConfigItemObject->ConfigItemGet(
                ConfigItemID => $ConfigItemID,
            );

            # get last version hash
            my $VersionRef = $ConfigItemObject->VersionGet(
                ConfigItemID => $ConfigItemID,
            );

            # get xml-definition
            my $XMLDefinition = $ConfigItemObject->DefinitionGet(
                ClassID => $ConfigItem->{ClassID},
            );
            my $DefinitionRef = $XMLDefinition->{DefinitionRef};

            if ( $Count == 0 ) {
                $Self->Block(
                    Name => 'LinkConfigItemPage',
                    Data => {
                        DivCount => $DivCount,
                        Style    => 'display:none',
                        TabID    => $TabID,
                    },
                );

                for my $Key ( sort keys %{$ShownAttributes} ) {
                    $Self->Block(
                        Name => 'LinkConfigItemRowHeader',
                        Data => {
                            Head => $ShownAttributes->{$Key},
                        },
                    );
                }
            }

            $Self->Block(
                Name => 'LinkConfigItemRow',
                Data => {
                    Class  => $VersionRef->{Class},
                    Name   => $VersionRef->{Name},
                    Number => $ConfigItem->{Number},
                    ID     => $ConfigItemID,
                },
            );

            for my $Key ( sort keys %{$ShownAttributes} ) {

                my $ConfigItemKey = $Key;
                $ConfigItemKey =~ s/^(.*?)::(.*?)$/$2/;
                if ( $ConfigItemKey =~ /^(.*?)::(.*?)/ ) {
                    $ConfigItemKey = $1;
                }

                my $Value;
                if ( defined $VersionRef->{$ConfigItemKey} ) {
                    $Value = $VersionRef->{$ConfigItemKey};
                }
                else {
                    # GetAttributeValuesByKey gets lookup value of xml attribute
                    my $Result = $ConfigItemObject->GetAttributeValuesByKey(
                        KeyName       => $ConfigItemKey,
                        XMLData       => $VersionRef->{XMLData}->[1]->{Version}->[1],
                        XMLDefinition => $VersionRef->{XMLDefinition},
                    );

                    # translate each value
                    foreach my $Value ( @{$Result} ) {
                        $Value = $LayoutObject->{LanguageObject}->Translate($Value);
                    }

                    # join the result
                    $Value = join( ", ", @{$Result} );
                }

                # output
                $Self->Block(
                    Name => 'LinkConfigItemRowData',
                    Data => {
                        Value => $Value,
                        ID    => $ConfigItemID
                    },
                );
                if ( $Key =~ /Link/ ) {
                    $Self->Block(
                        Name => 'LinkConfigItemRowDataLinkStart',
                        Data => {
                            Value => $Value,
                            Name  => $VersionRef->{Name},
                            ID    => $ConfigItemID
                        },
                    );
                    $Self->Block(
                        Name => 'LinkConfigItemRowDataLinkEnd',
                    );
                }
                else {
                    $Self->Block(
                        Name => 'LinkConfigItemRowDataLabelStart',
                        Data => {
                            Value => $Value,
                            Name  => $VersionRef->{Name},
                            ID    => $ConfigItemID
                        },
                    );
                    $Self->Block(
                        Name => 'LinkConfigItemRowDataLabelEnd',
                    );
                }
            }

            if ( ++$Count >= $ShownCILinks ) {
                $DivCount++;
                $Count = 0;
            }
        }
    }

    return $Self->Output(
        TemplateFile   => 'CustomerDashboardLinkedCIs',
        Data           => \%Param,
        KeepScriptTags => 0,
    );
}

sub CountConfigItemImages {
    my ( $Self, %Param ) = @_;

    # create needed objects
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # get file and path info
    my $Home      = $ConfigObject->Get('Home');
    my $Config    = $ConfigObject->Get("ITSMConfigItem::Frontend::AgentITSMConfigItemZoomTabImages");
    my $Path      = $Config->{ImageSavePath};
    my $Directory = $Home . $Path . $Param{ConfigItemID};

    # get all source files
    my @Files;
    if ( -e $Directory ) {
        opendir( DIR, $Directory );
        @Files = grep( { !/^(?:.|..|(?:.*?)\.txt(?:.*))$/g } readdir(DIR) );
        closedir(DIR);
    }

    my $Result = scalar(@Files);

    return $Result;

}

#-------------------------------------------------------------------------------
# internal methods...

=item _ExportXMLSearchDataPrepare()

recusion function to prepare the export XML search params

    $ObjectBackend->_ExportXMLSearchDataPrepare(
        XMLDefinition => $ArrayRef,
        What          => $ArrayRef,
        SearchData    => $HashRef,
    );

=cut

sub _ExportXMLSearchDataPrepare {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    return if !$Param{XMLDefinition} || ref $Param{XMLDefinition} ne 'ARRAY';
    return if !$Param{What}          || ref $Param{What}          ne 'ARRAY';
    return if !$Param{SearchData}    || ref $Param{SearchData}    ne 'HASH';

    # create needed objects
    my $ConfigItemObject = $Kernel::OM->Get('Kernel::System::ITSMConfigItem');

    ITEM:
    for my $Item ( @{ $Param{XMLDefinition} } ) {

        # create key
        my $Key = $Param{Prefix} ? $Param{Prefix} . '::' . $Item->{Key} : $Item->{Key};

        # prepare value
        my $Values = $ConfigItemObject->XMLExportSearchValuePrepare(
            Item  => $Item,
            Value => $Param{SearchData}->{$Key},
        );
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
