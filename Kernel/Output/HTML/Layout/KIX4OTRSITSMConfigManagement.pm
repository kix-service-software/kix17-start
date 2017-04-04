# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::Layout::KIX4OTRSITSMConfigManagement;

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
        my $SearchInClassesRef
            = $ConfigObject->Get('KIXSidebarConfigItemLink::CISearchInClasses');

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
                )
            {
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

    my $CIExcludeDeploymentStates
        = $ConfigObject->Get('KIXSidebarConfigItemLink::CIExcludeDeploymentStates');
    my $CIExcludeIncidentStates
        = $ConfigObject->Get('KIXSidebarConfigItemLink::CIExcludeIncidentStates');

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
                        )
                    {
                        $ConfigItemList{$LinkItem} = 'checked="checked"';
                    }
                }
            }
        }
    }
    my @CIArray;
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
                )
            {
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

    my $CIExcludeDeploymentStates
        = $ConfigObject->Get('CustomerDashboardConfigItemLink::CIExcludeDeploymentStates');
    my $CIExcludeIncidentStates
        = $ConfigObject->Get('CustomerDashboardConfigItemLink::CIExcludeIncidentStates');

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
        Data => {
        },
    );

    my $ShownAttributes
        = $ConfigObject->Get('CustomerDashboardConfigItemLink::ShownAttributes');

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

                    # IsChecked => $ConfigItemList{$ConfigItemID} || '',
                    ID => $ConfigItemID,
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

                # get sub definition hast for this attribute
                my %DefinitionHash = ();
                for my $Definition ( @{$DefinitionRef} ) {
                    next if !( $Definition->{Key} eq $ConfigItemKey );
                    %DefinitionHash = %{$Definition};
                }

                # get value to display
                if ( %DefinitionHash && keys %DefinitionHash ) {
                    $Value = $ConfigItemObject->XMLValueLookup(
                        Item  => \%DefinitionHash,
                        Value => $Value,
                    );
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
    my $Home = $ConfigObject->Get('Home');
    my $Config
        = $ConfigObject->Get("ITSMConfigItem::Frontend::AgentITSMConfigItemZoomTabImages");
    my $Path      = $Config->{ImageSavePath};
    my $Directory = $Home . $Path . $Param{ConfigItemID};

    # get all source files
    my @Files;
    if ( -e $Directory ) {
        opendir( DIR, $Directory );
        @Files = grep { !/^(.|..|(.*?)\.txt(.*))$/g } readdir(DIR);
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

sub _ConfigLine {
    my ( $Self, %Param ) = @_;

    # create needed objects
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    if ( !$Param{MainItemTranslated} ) {
        $Param{MainItemTranslated} = $LayoutObject->{LanguageObject}->Translate( $Param{MainItem} );
    }

    my $Line = '';
    for my $Item ( @{ $Param{DefinitionRef} } ) {

        next if ( grep { $_ eq $Item->{Name} } @{ $Param{UsedColumns} } );

        # get name for translating
        $Param{TranslationRef}->{ $Item->{Key} } = $Item->{Name};

        if (
            (
                !$Param{ReturnSelected}
                && !$Param{SelectedAttributes}->{ $Param{MainItem} . '::' . $Item->{Key} }
            )
            ||
            (
                $Param{ReturnSelected}
                && $Param{SelectedAttributes}->{ $Param{MainItem} . '::' . $Item->{Key} }
            )
            )
        {
            $Line = $Line . '<li class="ui-state-default'
                . $Param{CSSClass}
                . '" name="'
                . $Param{MainItem} . '::' . $Item->{Key} . '">'
                . $Param{MainItemTranslated} . '::'
                . $LayoutObject->{LanguageObject}->Translate( $Item->{Name} )
                . '<span class="ui-icon ui-icon-arrowthick-2-n-s"></span>'
                . '</li>';
            push @{ $Param{UsedColumns} }, $Item->{Name};
        }

        if ( $Item->{Sub} ) {
            $Line .= $Self->_ConfigLine(
                DefinitionRef      => $Item->{Sub},
                CSSClass           => $Param{CSSClass},
                MainItem           => $Param{MainItem} . '::' . $Item->{Key},
                MainItemTranslated => $Param{MainItemTranslated} . '::'
                    . $LayoutObject->{LanguageObject}->Translate( $Item->{Name} ),
                SelectedAttributes => $Param{SelectedAttributes},
                TranslationRef     => $Param{TranslationRef},
                UsedColumns        => $Param{UsedColumns},
            );
        }
    }

    return $Line;
}

sub _ShowColumnSettings {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    return if !$Param{ClassID};
    return if !$Param{View};
    return if !$Param{TitleValue};
    return if !$Param{Action};
    return if !$Param{LayoutObject};

    # create needed objects
    my $LayoutObject         = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $UserObject           = $Kernel::OM->Get('Kernel::System::User');
    my $GeneralCatalogObject = $Kernel::OM->Get('Kernel::System::GeneralCatalog');
    my $ConfigItemObject     = $Kernel::OM->Get('Kernel::System::ITSMConfigItem');
    my $CustomerUserObject   = $Kernel::OM->Get('Kernel::System::CustomerUser');
    my $ConfigObject         = $Kernel::OM->Get('Kernel::Config');
    my $LogObject            = $Kernel::OM->Get('Kernel::System::Log');

    my $ClassID = $Param{ClassID};
    my $View    = $Param{View};
    my $Action  = $Param{Action};

    # get data selection
    my %CurrentUserData = $UserObject->GetUserData(
        UserID => $Self->{UserID},
    );

    # get subattributes for column settings
    my $Definition;
    my %DefinitionHash = ();
    my $ClassList      = ();
    if ($ClassID) {

        # get definition
        if ( $ClassID ne 'All' ) {

            # get definition
            $Definition = $ConfigItemObject->DefinitionGet(
                ClassID => $ClassID,
            );
        }
        elsif ( $ClassID eq 'All' && $Action eq 'AgentITSMConfigItemSearch' )
        {

            $ClassList = $GeneralCatalogObject->ItemList(
                Class => 'ITSM::ConfigItem::Class',
            );

            # check access
            $Self->{Config}
                = $ConfigObject->Get("ITSMConfigItem::Frontend::$Self->{Action}");
            for my $ClassID ( sort keys %{$ClassList} ) {
                my $HasAccess = $ConfigItemObject->Permission(
                    Type    => $Self->{Config}->{Permission},
                    Scope   => 'Class',
                    ClassID => $ClassID,
                    UserID  => $Self->{UserID},
                );

                delete $ClassList->{$ClassID} if !$HasAccess;
            }

            # get definition hash
            for my $Class ( keys %{$ClassList} ) {
                $DefinitionHash{$Class} = $ConfigItemObject->DefinitionGet(
                    ClassID => $Class,
                );
            }
        }
    }

    my $CSSClass           = '';
    my @SelectedValueArray = ();

    # get user settings
    if (
        defined $CurrentUserData{
            'UserCustomCILV-'
                . $Action . '-'
                . $Param{TitleValue}
        }
        && $CurrentUserData{
            'UserCustomCILV-'
                . $Action . '-'
                . $Param{TitleValue}
        }
        )
    {
        my $SelectedColumnString
            = $CurrentUserData{
            'UserCustomCILV-'
                . $Action . '-'
                . $Param{TitleValue}
            };
        my @SelectedColumnArray = split( /,/, $SelectedColumnString );

        # get selected values
        for my $Item (@SelectedColumnArray) {
            push @SelectedValueArray, $Param{TitleValue} . '::' . $Item;
        }
    }

    # if no columns selected
    if ( !( scalar @SelectedValueArray ) ) {
        for my $ShownColumn ( keys %{ $Param{ShowColumns} } ) {
            next if !$Param{ShowColumns}->{$ShownColumn};
            push @SelectedValueArray, $Param{TitleValue} . '::' . $ShownColumn;
        }
    }
    else {
        my @TempArray = ();
        for my $ShownColumn (@SelectedValueArray) {
            $ShownColumn =~ m/^(.*?)::(.*)$/;
            push @TempArray, $2;
        }
        if ( $View eq 'Custom' ) {
            $Param{ShowColumns} = \@TempArray;
        }
    }

    # create translation hash
    my %TranslationHash = (
        'CurDeplState'     => 'Deployment State',
        'CurInciState'     => 'Current Incident State',
        'CurDeplStateType' => 'Deployment State Type',
        'CurInciStateType' => 'Current Incident State Type',
        'LastChanged'      => 'Last changed',
        'CurInciSignal'    => 'Current Incident Signal',
        'CurDeplSignal'    => 'Current Deployment Signal'
    );

    # get selected value string
    my $SelectedValueStrg
        = '<div class="SortableColumns"><span class="SortableColumnsDescription">'
        . $LayoutObject->{LanguageObject}->Translate('Selected Columns')
        . ':</span><ul class="ColumnOrder" id="SortableSelected">';

    my %SelectedAttributes = map { $_ => 1 } @SelectedValueArray;

    # get selected class specific attributes for translation
    $Self->_ConfigLine(
        DefinitionRef      => $Definition->{DefinitionRef},
        CSSClass           => $CSSClass,
        MainItem           => $Param{TitleValue},
        SelectedAttributes => \%SelectedAttributes,
        TranslationRef     => \%TranslationHash,
        ReturnSelected     => 1,
    );

    for my $Item (@SelectedValueArray) {

        # translate selected item
        my @SplitItem = split( /::/, $Item );

        # CI class name will not be translated
        my @TranslationArray;

        foreach my $SplitPart (@SplitItem) {
            if ( defined $TranslationHash{$SplitPart} ) {
                push @TranslationArray,
                    $LayoutObject->{LanguageObject}->Translate( $TranslationHash{$SplitPart} );
            }
            else {
                push @TranslationArray,
                    $LayoutObject->{LanguageObject}->Translate($SplitPart);
            }
        }

        $SelectedValueStrg .= '<li class="ui-state-default'
            . $CSSClass
            . '" name="'
            . $Item . '">'
            . join( '::', @TranslationArray )
            . '<span class="ui-icon ui-icon-arrowthick-2-n-s"></span>'
            . '</li>';
    }
    $SelectedValueStrg .= '</ul></div>';

    # get possible value string
    my $PossibleValueStrg
        = '<div class="SortableColumns"><span class="SortableColumnsDescription">'
        . $LayoutObject->{LanguageObject}->Translate('Possible Columns')
        . ':</span><ul class="ColumnOrder" id="SortablePossible">';

    # if no possible columns selected
    if ( !defined $Param{PossibleColumns} || !$Param{PossibleColumns} ) {
        $Self->{DefaultConfig}
            = $ConfigObject->Get("ITSMConfigItem::Frontend::AgentITSMConfigItem");
        $Param{PossibleColumns} = $Self->{DefaultConfig}->{ShowColumns};
    }

    my @UsedColumns = keys %{ $Param{PossibleColumns} };

    # add main attributes
    for my $MainItem ( keys %{ $Param{PossibleColumns} } ) {

        next if !$Param{PossibleColumns}->{$MainItem};
        next if $SelectedAttributes{ $Param{TitleValue} . '::' . $MainItem };

        my $TranslatedMainItem = $TranslationHash{$MainItem} || $MainItem;
        $PossibleValueStrg .= '<li class="ui-state-default'
            . $CSSClass
            . '" name="'
            . $Param{TitleValue} . '::' . $MainItem . '">'
            . $LayoutObject->{LanguageObject}->Translate( $Param{TitleValue} ) . '::'
            . $LayoutObject->{LanguageObject}->Translate($TranslatedMainItem)
            . '<span class="ui-icon ui-icon-arrowthick-2-n-s"></span>'
            . '</li>';
    }

    if ( $ClassID && $ClassID ne 'All' ) {

        # add class specific attributes
        $PossibleValueStrg .= $Self->_ConfigLine(
            DefinitionRef      => $Definition->{DefinitionRef},
            CSSClass           => $CSSClass,
            MainItem           => $Param{TitleValue},
            SelectedAttributes => \%SelectedAttributes,
            TranslationRef     => \%TranslationHash,
            UsedColumns        => \@UsedColumns,
        );
    }
    elsif ( $ClassID eq 'All' && $Action eq 'AgentITSMConfigItemSearch' ) {

        for my $Class ( keys %{$ClassList} ) {

            # add class specific attributes
            $PossibleValueStrg .= $Self->_ConfigLine(
                DefinitionRef      => $DefinitionHash{$Class}->{DefinitionRef},
                CSSClass           => $CSSClass,
                MainItem           => $Param{TitleValue},
                SelectedAttributes => \%SelectedAttributes,
                TranslationRef     => \%TranslationHash,
                UsedColumns        => \@UsedColumns,
            );
        }
    }
    $PossibleValueStrg .= '</ul></div>';

    # Output
    $LayoutObject->Block(
        Name => 'OverviewNavSettingCustomCILV',
        Data => {
            Columns => $PossibleValueStrg . $SelectedValueStrg,
        },
    );
    return \%TranslationHash;
}

# disable redefine warnings in this scope
{
    no warnings 'redefine';

    # overwrite sub ITSMConfigItemListShow to provide CustomConfigItemOverview-Settings
    sub Kernel::Output::HTML::Layout::ITSMConfigItemListShow {
        my ( $Self, %Param ) = @_;

        # take object ref to local, remove it from %Param (prevent memory leak)
        my $Env = delete $Param{Env};

        # lookup latest used view mode
        if ( !$Param{View} && $Self->{ 'UserITSMConfigItemOverview' . $Env->{Action} } ) {
            $Param{View} = $Self->{ 'UserITSMConfigItemOverview' . $Env->{Action} };
        }

        # KIX4OTRS-capeIT
        # fallback due to problem with session object (T#2015102290000583)
        my %UserPreferences
            = $Kernel::OM->Get('Kernel::System::User')->GetPreferences( UserID => $Self->{UserID} );
        if ( !$Param{View} && $UserPreferences{ 'UserITSMConfigItemOverview' . $Env->{Action} } ) {
            $Param{View} = $UserPreferences{ 'UserITSMConfigItemOverview' . $Env->{Action} };
        }

        # EO KIX4OTRS-capeIT

        # set frontend
        my $Frontend = $Param{Frontend} || 'Agent';

        # set defaut view mode to 'small'
        my $View = $Param{View} || 'Small';

        # KIX4OTRS-capeIT
        my $ClassID = $Param{Filter} || $Param{ClassID} || 'All';

        if (
            $Self->{Action} eq 'AgentITSMConfigItem'
            && ( !defined $Param{TitleValue} || $Param{TitleValue} eq '' )
            )
        {
            $Param{TitleValue} = 'All';
        }
        elsif (
            $Self->{Action} eq 'AgentITSMConfigItemSearch'
            && ( !defined $Param{TitleValue} || $Param{TitleValue} eq '' )
            && $ClassID ne 'All'
            && $ClassID ne '-'
            )
        {
            my $ClassList = $Kernel::OM->Get('Kernel::System::GeneralCatalog')->ItemList(
                Class => 'ITSM::ConfigItem::Class',
            );
            $Param{TitleValue} = $ClassList->{$ClassID};
        }
        elsif (
            $Self->{Action} eq 'AgentITSMConfigItemSearch'
            && ( !defined $Param{TitleValue} || $Param{TitleValue} eq '' )
            && $ClassID eq '-'
            )
        {
            $Param{TitleValue} = 'SearchResult';
        }
        elsif ( !defined $Param{TitleValue} || $Param{TitleValue} eq '' ) {
            $Param{TitleValue} = $ClassID;
        }

        # EO KIX4OTRS-capeIT

        # store latest view mode
        $Kernel::OM->Get('Kernel::System::AuthSession')->UpdateSessionID(
            SessionID => $Self->{SessionID},
            Key       => 'UserITSMConfigItemOverview' . $Env->{Action},
            Value     => $View,
        );

        # get needed objects
        my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
        my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

        # KIX4OTRS-capeIT
        # update preferences if needed
        my $Key = 'UserITSMConfigItemOverview' . $Env->{Action};
        my $LastView = $Self->{$Key} || '';

        # if ( !$ConfigObject->Get('DemoSystem') && $Self->{$Key} ne $View ) {
        if ( !$ConfigObject->Get('DemoSystem') && $LastView ne $View ) {

            $Kernel::OM->Get('Kernel::System::User')->SetPreferences(
                UserID => $Self->{UserID},
                Key    => $Key,
                Value  => $View,
            );
        }

        # EO KIX4OTRS-capeIT

        # get backend from config
        my $Backends = $ConfigObject->Get('ITSMConfigItem::Frontend::Overview');
        if ( !$Backends ) {
            return $LayoutObject->FatalError(
                Message => 'Need config option ITSMConfigItem::Frontend::Overview',
            );
        }

        # check for hash-ref
        if ( ref $Backends ne 'HASH' ) {
            return $LayoutObject->FatalError(
                Message =>
                    'Config option ITSMConfigItem::Frontend::Overview needs to be a HASH ref!',
            );
        }

        # check for config key
        if ( !$Backends->{$View} ) {
            return $LayoutObject->FatalError(
                Message => "No config option found for the view '$View'!",
            );
        }

        # nav bar
        my $StartHit = $Kernel::OM->Get('Kernel::System::Web::Request')->GetParam(
            Param => 'StartHit',
        ) || 1;

        # get personal page shown count
        my $PageShownPreferencesKey = 'UserConfigItemOverview' . $View . 'PageShown';
        my $PageShown               = $Self->{$PageShownPreferencesKey} || 10;
        my $Group                   = 'ConfigItemOverview' . $View . 'PageShown';

        # check start option, if higher then elements available, set
        # it to the last overview page (Thanks to Stefan Schmidt!)
        if ( $StartHit > $Param{Total} ) {
            my $Pages = int( ( $Param{Total} / $PageShown ) + 0.99999 );
            $StartHit = ( ( $Pages - 1 ) * $PageShown ) + 1;
        }

        # get data selection
        my %Data;
        my $Config = $ConfigObject->Get('PreferencesGroups');
        if ( $Config && $Config->{$Group} && $Config->{$Group}->{Data} ) {
            %Data = %{ $Config->{$Group}->{Data} };
        }

        # set page limit and build page nav
        my $Limit = $Param{Limit} || 20_000;
        my %PageNav = $LayoutObject->PageNavBar(
            Limit     => $Limit,
            StartHit  => $StartHit,
            PageShown => $PageShown,
            AllHits   => $Param{Total} || 0,
            Action    => 'Action=' . $Env->{Action},
            Link      => $Param{LinkPage},
        );

        # build shown ticket a page
        $Param{RequestedURL}    = "Action=$Self->{Action}";
        $Param{Group}           = $Group;
        $Param{PreferencesKey}  = $PageShownPreferencesKey;
        $Param{PageShownString} = $Self->BuildSelection(
            Name        => $PageShownPreferencesKey,
            SelectedID  => $PageShown,
            Data        => \%Data,
            Translation => 0,
        );

        # build navbar content
        $LayoutObject->Block(
            Name => 'OverviewNavBar',
            Data => \%Param,
        );

        # back link
        if ( $Param{LinkBack} ) {
            $LayoutObject->Block(
                Name => 'OverviewNavBarPageBack',
                Data => \%Param,
            );
        }

        # get filters
        if ( $Param{Filters} ) {

            # get given filters
            my @NavBarFilters;
            for my $Prio ( sort keys %{ $Param{Filters} } ) {
                push @NavBarFilters, $Param{Filters}->{$Prio};
            }

            # build filter content
            $LayoutObject->Block(
                Name => 'OverviewNavBarFilter',
                Data => {
                    %Param,
                },
            );

            # loop over filters
            my $Count = 0;
            for my $Filter (@NavBarFilters) {

                # increment filter count and build filter item
                $Count++;
                $LayoutObject->Block(
                    Name => 'OverviewNavBarFilterItem',
                    Data => {
                        %Param,
                        %{$Filter},
                    },
                );

                # filter is selected
                if ( $Filter->{Filter} eq $Param{Filter} ) {
                    $LayoutObject->Block(
                        Name => 'OverviewNavBarFilterItemSelected',
                        Data => {
                            %Param,
                            %{$Filter},
                        },
                    );

                }
                else {
                    $LayoutObject->Block(
                        Name => 'OverviewNavBarFilterItemSelectedNot',
                        Data => {
                            %Param,
                            %{$Filter},
                        },
                    );
                }
            }
        }

        # KIX4OTRS-capeIT
        # set priority if not defined
        for my $Backend (
            keys %{$Backends}
            )
        {
            if ( !defined $Backends->{$Backend}->{ModulePriority} ) {
                $Backends->{$Backend}->{ModulePriority} = 0;
            }
        }

        # EO KIX4OTRS-capeIT

        # loop over configured backends
        # for my $Backend ( sort keys %{$Backends} ) {

        for my $Backend (

            # KIX4OTRS-capeIT
            sort { $Backends->{$a}->{ModulePriority} cmp $Backends->{$b}->{ModulePriority} }

            # EO KIX4OTRS-capeIT
            keys %{$Backends}
            )
        {

            # build navbar view mode
            $LayoutObject->Block(
                Name => 'OverviewNavBarViewMode',
                Data => {
                    %Param,
                    %{ $Backends->{$Backend} },
                    Filter => $Param{Filter},
                    View   => $Backend,
                },
            );

            # current view is configured in backend
            if ( $View eq $Backend ) {
                $LayoutObject->Block(
                    Name => 'OverviewNavBarViewModeSelected',
                    Data => {
                        %Param,
                        %{ $Backends->{$Backend} },
                        Filter => $Param{Filter},
                        View   => $Backend,
                    },
                );
            }
            else {
                $LayoutObject->Block(
                    Name => 'OverviewNavBarViewModeNotSelected',
                    Data => {
                        %Param,
                        %{ $Backends->{$Backend} },
                        Filter => $Param{Filter},
                        View   => $Backend,
                    },
                );
            }
        }

        # check if page nav is available
        # KIX4OTRS-capeIT
        my $Columns = '';

        # EO KIX4OTRS-capeIT
        if (%PageNav) {
            $LayoutObject->Block(
                Name => 'OverviewNavBarPageNavBar',
                Data => \%PageNav,
            );

            # don't show context settings in AJAX case (e. g. in customer ticket history),
            #   because the submit with page reload will not work there
            if ( !$Param{AJAX} ) {
                $LayoutObject->Block(
                    Name => 'ContextSettings',
                    Data => {
                        %PageNav,
                        %Param,

                        # KIX4OTRS-capeIT
                        ClassID => $ClassID,

                        # EO KIX4OTRS-capeIT
                    },
                );

                # KIX4OTRS-capeIT
                $Param{TranslationRef} = $Self->_ShowColumnSettings(
                    ClassID      => $ClassID,
                    TitleValue   => $Param{TitleValue},
                    View         => $View,
                    ShowColumns  => $Param{PossibleColumns},
                    Action       => $LayoutObject->{Action},
                    LayoutObject => $LayoutObject,
                );

                # EO KIX4OTRS-capeIT
            }
        }

        # check if bulk feature is enabled
        my $BulkFeature = 0;
        if ( $ConfigObject->Get('ITSMConfigItem::Frontend::BulkFeature') ) {
            my @Groups;
            if ( $ConfigObject->Get('ITSMConfigItem::Frontend::BulkFeatureGroup') ) {
                @Groups = @{ $ConfigObject->Get('ITSMConfigItem::Frontend::BulkFeatureGroup') };
            }
            if ( !@Groups ) {
                $BulkFeature = 1;
            }
            else {
                GROUP:
                for my $Group (@Groups) {
                    next GROUP if !$LayoutObject->{"UserIsGroup[$Group]"};
                    if ( $LayoutObject->{"UserIsGroup[$Group]"} eq 'Yes' ) {
                        $BulkFeature = 1;
                        last GROUP;
                    }
                }
            }
        }

        # show the bulk action button if feature is enabled
        if ($BulkFeature) {
            $LayoutObject->Block(
                Name => 'BulkAction',
                Data => {
                    %PageNav,
                    %Param,
                },
            );
        }

        # build html content
        my $OutputNavBar = $LayoutObject->Output(
            TemplateFile => 'AgentITSMConfigItemOverviewNavBar',
            Data         => {%Param},
        );

        # create output
        my $OutputRaw = '';
        if ( !$Param{Output} ) {
            $LayoutObject->Print(
                Output => \$OutputNavBar,
            );
        }
        else {
            $OutputRaw .= $OutputNavBar;
        }

        # load module
        if ( !$Kernel::OM->Get('Kernel::System::Main')->Require( $Backends->{$View}->{Module} ) ) {
            return $LayoutObject->FatalError();
        }

        # check for backend object
        my $Object = $Backends->{$View}->{Module}->new( %{$Env} );
        return if !$Object;

        # run module
        my $Output = $Object->Run(
            %Param,
            Limit     => $Limit,
            StartHit  => $StartHit,
            PageShown => $PageShown,
            AllHits   => $Param{Total} || 0,
            Frontend  => $Frontend,
        );

        # create output
        if ( !$Param{Output} ) {
            $LayoutObject->Print(
                Output => \$Output,
            );
        }
        else {
            $OutputRaw .= $Output;
        }

        # create overview nav bar
        $LayoutObject->Block(
            Name => 'OverviewNavBar',
            Data => {%Param},
        );

        # return content if available
        return $OutputRaw;

    }

}

1;


=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
