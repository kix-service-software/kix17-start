# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::Layout::KIX4OTRS;

use strict;
use warnings;
use Digest::MD5 qw(md5_hex);
use Encode;

use Kernel::System::VariableCheck qw(:all);

our $ObjectManagerDisabled = 1;

sub KIXSideBarReuseArticleAttachmentsTable {
    my ( $Self, %Param ) = @_;

    # Get all article attachments of this ticket
    my @ArticleList = $Kernel::OM->Get('Kernel::System::Ticket')->ArticleContentIndex(
        TicketID                   => $Param{TicketID},
        StripPlainBodyAsAttachment => 1,
        UserID                     => $Self->{UserID},
    );

    my %AttachmentList;
    foreach my $Article (@ArticleList) {
        my %AtmIndex = %{ $Article->{Atms} };

        foreach my $FileID ( sort keys %AtmIndex ) {
            next
                if (
                $Param{SearchString}
                && $AtmIndex{$FileID}->{Filename} !~ /$Param{SearchString}/
                );
            $AttachmentList{ $Article->{ArticleID} . '::' . $FileID } = $AtmIndex{$FileID};
        }
    }

    my $Count        = 0;
    my $DivCount     = 1;
    my $ItemsPerPage = 10;

    for my $AttachmentID (
        sort { $AttachmentList{$a}->{Filename} cmp $AttachmentList{$b}->{Filename} }
        keys %AttachmentList
        )
    {

        if ( $Count == 0 ) {
            $Self->Block(
                Name => 'ArticleAttachmentTable',
                Data => {
                    DivCount => $DivCount,
                    Style    => 'display:none',
                },
            );
        }

        $Self->Block(
            Name => 'ArticleAttachmentRow',
            Data => {
                %{ $AttachmentList{$AttachmentID} },
                ArticleAttachmentID => $AttachmentID,
            },
        );

        if ( ++$Count >= $ItemsPerPage ) {
            $DivCount++;
            $Count = 0;
        }
    }

    if (%AttachmentList) {
        return $Self->Output(
            TemplateFile   => 'ArticleAttachmentList',
            Data           => \%Param,
            KeepScriptTags => $Param{AJAX} || 0,
        );
    }
    return;
}

sub BuildQuickLinkHTML {
    my ( $Self, %Param ) = @_;
    my $Output;

    if ( $Kernel::OM->Get('Kernel::System::Main')->Require('Kernel::System::QuickLink') ) {
        my $QuickLinkObject = $Kernel::OM->Get('Kernel::System::QuickLink');

        my $QuickLinkObjectStrg = $Self->LinkObjectSelectableObjectList(
            %Param,
            FilterModule => $QuickLinkObject,
            FilterMethod => 'FilterSelectableObjectsList',
        );

        # prepare and show label
        my $ObjectName = $Param{Object};
        $ObjectName =~ s/^ITSM//g;
        $Self->Block(
            Name => $ObjectName . 'Label',
        );

        # output the footer block
        $Output = $Self->Output(
            TemplateFile => 'QuickLink',
            Data         => {
                QuickLinkObjectStrg => $QuickLinkObjectStrg,
                %Param,
            },
        );
    }

    return $Output;
}

sub BuildNotifyKIX4OTRSHTML {
    my ( $Self, %Param ) = @_;

    my $Type        = $Param{Type}        || '';
    my $Translation = $Param{Translation} || 1;
    my $ReturnType  = $Param{ReturnType}  || '';
    my $Result      = $Param{Result}      || 1;
    my $Message     = '';
    my $Class       = $Param{Class}       || '';
    $Class .= $Result ? ' Success' : ' Error';

    # set output style
    if ( $ReturnType eq 'Text' ) {

        # generate message
        if ( $Type eq 'TicketFreeText' ) {
            $Message =
                'TicketFreeText-field '
                . ( $Result ? 'successfully' : 'could not be' )
                . ' updated!';
        }
        elsif ( $Type eq 'TicketFreeTime' ) {
            $Message =
                'TicketFreeTime-field '
                . ( $Result ? 'successfully' : 'could not be' )
                . ' updated!';
        }
        elsif ( $Type eq 'TicketData' ) {
            $Message = 'Ticket data ' . ( $Result ? 'successfully' : 'could not be' ) . ' updated!';
        }
        elsif ( $Type eq 'TicketRemarks' ) {
            $Message = 'Remarks ' . ( $Result ? 'successfully' : 'could not be' ) . ' saved!';
        }
        else {
            $Message = $Type . ( $Result ? ' successfully' : ' could not be' ) . ' saved!';
        }
        $Self->Block(
            Name => ($Translation) ? 'Text' : 'QData',
            Data => {
                Data => $Message,
            },
        );
    }
    elsif ( $ReturnType eq 'Direct' ) {
        $Self->Block(
            Name => 'Data',
            Data => \%Param,
        );
    }
    else {
        $Self->Block(
            Name => 'QData',
            Data => \%Param,
        );
    }

    # add div to HTML
    if ( $Param{Div} ) {
        $Self->Block(
            Name => 'DivStart',
            Data => {},
        );
        $Self->Block(
            Name => 'DivStop',
            Data => {},
        );
    }

    # add link to notify
    if ( $Param{Link} ) {
        $Self->Block(
            Name => 'LinkStart',
            Data => \%Param,
        );
        $Self->Block(
            Name => 'LinkStop',
            Data => \%Param,
        );
    }

    # build and return HTML
    return $Self->Output(
        TemplateFile => 'NotifyKIX4OTRS',
        Data         => {
            Class => $Class,
        },
    );
}

sub HasDatepickerDirectSet {
    my ( $Self, %Param ) = @_;
    $Self->{HasDatepicker} = 1;
    return;
}

sub IsBlockDefined {
    my ( $Self, %Param ) = @_;
    my $Found = 0;
    foreach my $BlockDef ( @{ $Self->{BlockData} } ) {
        if ( $BlockDef->{Name} eq $Param{Name} ) {
            $Found = 1;
            last;
        }
    }
    return $Found;
}

sub CustomerAssignedCustomerIDsTable {
    my ( $Self, %Param ) = @_;

    for my $CurrKey (qw(CustomerUserID)) {
        return '' if !$Param{$CurrKey};
    }

    # get customer IDs for current user...
    my %CustomerData = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerUserDataGet(
        User => $Param{CustomerUserID},
    );
    my @CustomerIDs = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerIDs(
        User => $Param{CustomerUserID},
    );
    if ( %CustomerData && ( grep { $_ eq $CustomerData{UserCustomerID}; } @CustomerIDs ) == 0 ) {
        push( @CustomerIDs, $CustomerData{UserCustomerID} );
    }
    return '' if !@CustomerIDs || scalar(@CustomerIDs) == 1;

    # build customer IDs table
    for my $CustomerID (@CustomerIDs) {

        # get customer data
        my %CustomerData = $Kernel::OM->Get('Kernel::System::CustomerCompany')->CustomerCompanyGet(
            CustomerID => $CustomerID,
        );

        $Self->Block(
            Name => 'CustomerIDRow',
            Data => {
                %CustomerData,
                ID => $CustomerID,
            },
        );
    }
    return $Self->Output(
        TemplateFile   => 'CustomerAssignedCustomerIDsList',
        Data           => \%Param,
        KeepScriptTags => $Param{AJAX} || 0,
    );
}

sub AgentCustomerDetailsViewTable {
    my ( $Self, %Param ) = @_;

    # add ticket params if given
    if ( $Param{Ticket} ) {
        %{ $Param{Data} } = ( %{ $Param{Data} }, %{ $Param{Ticket} } );
    }

    $Self->Block(
        Name => 'CustomerDetails',
    );

    my @MapNew;
    my $Map = $Param{Data}->{Config}->{Map};
    if ($Map) {
        @MapNew = ( @{$Map} );
    }

    # check if customer company support is enabled
    if ( $Param{Data}->{Config}->{CustomerCompanySupport} ) {
        my $Map2 = $Param{Data}->{CompanyConfig}->{Map};
        if ($Map2) {
            push( @MapNew, @{$Map2} );
        }
    }

    # build table
    for my $Field (@MapNew) {
        if ( $Field->[3] && $Field->[3] >= 1 && $Param{Data}->{ $Field->[0] } ) {
            my %Record = (
                %{ $Param{Data} },
                Key   => $Field->[1],
                Value => $Param{Data}->{ $Field->[0] },
            );
            if ( $Field->[6] ) {
                $Record{LinkStart} = "<a href=\"$Field->[6]\"";
                if ( $Field->[8] ) {
                    $Record{LinkStart} .= " target=\"$Field->[8]\"";
                }
                if ( $Field->[9] ) {
                    $Record{LinkStart} .= " class=\"$Field->[9]\"";
                }
                $Record{LinkStart} .= ">";
                $Record{LinkStop} = "</a>";
            }
            if ( $Field->[0] ) {
                $Record{ValueShort} = $Self->Ascii2Html(
                    Text => $Record{Value},
                    Max  => $Param{Max},
                );
            }
            $Self->Block(
                Name => 'CustomerDetailsRow',
                Data => \%Record,
            );
        }
    }
    return $Self->Output(
        TemplateFile   => 'AgentCustomerTableView',
        Data           => \%Param,
        KeepScriptTags => $Param{AJAX} || 0,
    );
}

sub AgentKIXSidebar {
    my ( $Self, %Param ) = @_;
    my $Output = '';

    # get common config
    my $CommonConfig = $Kernel::OM->Get('Kernel::Config')
        ->Get('Frontend::KIXSidebarBackend');

    # get module config
    my $ModuleConfig = $Kernel::OM->Get('Kernel::Config')
        ->Get( 'Frontend::' . ( $Param{Action} || $Self->{Action} ) . '::KIXSidebarBackend' );

    # use this for old XML
    if ( !$ModuleConfig ) {
        $ModuleConfig = $Kernel::OM->Get('Kernel::Config')->Get(
            'Ticket::Frontend::' . ( $Param{Action} || $Self->{Action} ) . '::KIXSidebarBackend'
        );
    }

    # KIXSidebarTools
    my $KIXSidebarToolsConfig = $Kernel::OM->Get('Kernel::Config')->Get('KIXSidebarTools');

    for my $Identifier ( @{ $KIXSidebarToolsConfig->{Identifier} } ) {
        my $ActionsMatch = $KIXSidebarToolsConfig->{ActionsMatch}->{$Identifier};
        if (
            defined $KIXSidebarToolsConfig->{ActionsMatch}->{$Identifier} &&
            substr( $KIXSidebarToolsConfig->{ActionsMatch}->{$Identifier}, 0, 8 ) eq
            '[regexp]'
            )
        {
            $ActionsMatch = substr $KIXSidebarToolsConfig->{ActionsMatch}->{$Identifier}, 8;
        }
        next if !defined $ActionsMatch || !$ActionsMatch || $Self->{Action} !~ /$ActionsMatch/;

        for my $Data ( keys %{ $KIXSidebarToolsConfig->{Data} } ) {
            my ( $DataIdentifier, $DataAttribute ) = split( ':::', $Data );
            next if $Identifier ne $DataIdentifier;
            $ModuleConfig->{$Identifier}->{$DataAttribute} =
                $KIXSidebarToolsConfig->{Data}->{ $Identifier . ':::' . $DataAttribute } || '';
        }

        # next if no module defined
        next if !$KIXSidebarToolsConfig->{Data}->{ $Identifier . ':::Module' };

        $ModuleConfig->{$Identifier}->{Identifier} = $Identifier;
    }
    return if !$CommonConfig && !$ModuleConfig;

    # build config hash
    my $Config;

    # common config
    for my $Backend ( sort keys %{$CommonConfig} ) {
        my $Action = ( $Param{Action} || $Self->{Action} );
        next if $Action !~ /^$CommonConfig->{$Backend}->{Actions}$/g;

        if ( $CommonConfig->{$Backend}->{Prio} ) {

            # prio defined as attribute
            $Config->{ $CommonConfig->{$Backend}->{Prio} . '-' . $Backend } =
                $CommonConfig->{$Backend};
        }
        else {
            $Config->{$Backend} = $CommonConfig->{$Backend};
        }
    }

    # module config
    for my $Backend ( sort keys %{$ModuleConfig} ) {
        if ( $CommonConfig->{$Backend}->{Prio} ) {

            # prio defined as attribute
            $Config->{ $CommonConfig->{$Backend}->{Prio} . '-' . $Backend } =
                $ModuleConfig->{$Backend};
        }
        else {
            $Config->{$Backend} = $ModuleConfig->{$Backend};
        }
    }

    # get user preferences
    my @SidebarBackend;
    my %Preferences
        = $Kernel::OM->Get('Kernel::System::User')->GetPreferences( UserID => $Self->{UserID} );
    if ( $Preferences{ ( $Param{Action} || $Self->{Action} ) . 'Position' } ) {
        @SidebarBackend = split /\;/,
            $Preferences{ ( $Param{Action} || $Self->{Action} ) . 'Position' };
    }

    my %SidebarBackends;
    if ( defined $Config && ref $Config eq 'HASH' ) {
        %SidebarBackends = %{$Config};
    }

    if (@SidebarBackend || %SidebarBackends) {
        # TicketID lookup
        if ( !$Param{TicketID} && $Kernel::OM->Get('Kernel::System::Web::Request')->GetParam( Param => 'TicketNumber' ) ) {
            $Param{TicketID} = $Kernel::OM->Get('Kernel::System::Ticket')->TicketIDLookup(
                TicketNumber => $Kernel::OM->Get('Kernel::System::Web::Request')->GetParam( Param => 'TicketNumber' ),
                UserID       => $Self->{UserID},
            );
        }
    }

    # if there are user preferences
    if ( scalar @SidebarBackend ) {

        my $Backend;

        # get shown backends
        BACKEND:
        for my $BackendModul (@SidebarBackend) {

            $Backend = '';
            for my $BackendItem ( keys %{$Config} ) {
                if ( $BackendItem =~ /$BackendModul/ ) {
                    $Backend = $BackendItem;
                }
            }
            next if !$Backend;

            delete $SidebarBackends{$Backend};

            # check permissions
            if ( $Config->{$Backend}->{Group} ) {
                my @Groups = split( ';', $Config->{$Backend}->{Group} );
                for my $Group (@Groups) {
                    my $Backend = 'UserIsGroup[' . $Group . ']';
                    next BACKEND if !$Self->{$Backend};
                    next BACKEND if $Self->{$Backend} ne 'Yes';
                }
            }

            # load backend module
            next BACKEND
                if !$Kernel::OM->Get('Kernel::System::Main')
                    ->Require( $Config->{$Backend}->{Module} );

            # execute event backend
            my $Generic = $Config->{$Backend}->{Module}->new(
                %{$Self},
                %Param,
                %{ $Config->{$Backend} },
                Frontend     => 'Agent',
                Config       => $Config->{$Backend},
                LayoutObject => $Self,
                Change       => $Param{Change} || '',
                WorkOrder    => $Param{WorkOrder} || '',
            );
            $Output .= $Generic->Run(
                %{$Self},
                %Param,
                %{ $Config->{$Backend} },
                Frontend  => 'Agent',
                Config    => $Config->{$Backend},
                Change    => $Param{Change} || '',
                WorkOrder => $Param{WorkOrder} || '',
            );
        }
    }

    # get shown backends
    BACKEND:
    for my $Backend ( sort keys %SidebarBackends ) {

        # check permissions
        if ( $Config->{$Backend}->{Group} ) {
            my @Groups = split( ';', $Config->{$Backend}->{Group} );
            for my $Group (@Groups) {
                my $Backend = 'UserIsGroup[' . $Group . ']';
                next BACKEND if !$Self->{$Backend};
                next BACKEND if $Self->{$Backend} ne 'Yes';
            }
        }

        # load backend module
        next BACKEND
            if !$Kernel::OM->Get('Kernel::System::Main')->Require( $Config->{$Backend}->{Module} );

        # execute event backend
        my $Generic = $Config->{$Backend}->{Module}->new(
            %{$Self},
            %Param,
            %{ $Config->{$Backend} },
            Frontend     => 'Agent',
            Config       => $Config->{$Backend},
            LayoutObject => $Self,
            Change       => $Param{Change} || '',
            WorkOrder    => $Param{WorkOrder} || '',
        );
        my $BackendResult = $Generic->Run(
            %{$Self},
            %Param,
            %{ $Config->{$Backend} },
            Frontend  => 'Agent',
            Config    => $Config->{$Backend},
            Change    => $Param{Change} || '',
            WorkOrder => $Param{WorkOrder} || '',
        );
        if ( defined($BackendResult) && $BackendResult ) {
            $Output .= $BackendResult;
        }
    }

    return $Output;
}

sub CustomerKIXSidebar {
    my ( $Self, %Param ) = @_;
    my $Output;

    # get common config
    my $CommonConfig = $Kernel::OM->Get('Kernel::Config')
        ->Get('CustomerFrontend::KIXSidebarBackend');

    # get module config
    my $ModuleConfig = $Kernel::OM->Get('Kernel::Config')
        ->Get( 'CustomerFrontend::' . $Self->{Action} . '::KIXSidebarBackend' );

    # use this for old XML
    if ( !$ModuleConfig ) {
        $ModuleConfig = $Kernel::OM->Get('Kernel::Config')->Get(
            'Ticket::CustomerFrontend::' . $Self->{Action} . '::KIXSidebarBackend'
        );
    }

    # KIXSidebarTools
    my $KIXSidebarToolsConfig = $Kernel::OM->Get('Kernel::Config')->Get('KIXSidebarTools');

    for my $Identifier ( @{ $KIXSidebarToolsConfig->{Identifier} } ) {
        my $ActionsMatch = $KIXSidebarToolsConfig->{ActionsMatch}->{$Identifier};
        if (
            substr( $KIXSidebarToolsConfig->{ActionsMatch}->{$Identifier}, 0, 8 ) eq
            '[regexp]'
            )
        {
            $ActionsMatch = substr $KIXSidebarToolsConfig->{ActionsMatch}->{$Identifier}, 8;
        }
        next if $Self->{Action} !~ /$ActionsMatch/;

        for my $Data ( keys %{ $KIXSidebarToolsConfig->{Data} } ) {
            my ( $DataIdentifier, $DataAttribute ) = split( ':::', $Data );
            next if $Identifier ne $DataIdentifier;
            $ModuleConfig->{$Identifier}->{$DataAttribute} =
                $KIXSidebarToolsConfig->{Data}->{ $Identifier . ':::' . $DataAttribute } || '';
        }
        $ModuleConfig->{$Identifier}->{Identifier} = $Identifier;
    }
    return if !$CommonConfig && !$ModuleConfig;

    # build config hash
    my $Config;
    for my $Backend ( sort keys %{$CommonConfig} ) {
        my $Action = ( $Param{Action} || $Self->{Action} );
        next if $Action !~ /^$CommonConfig->{$Backend}->{Actions}$/g;

        if ( $CommonConfig->{$Backend}->{Prio} ) {

            # prio defined as attribute
            $Config->{ $CommonConfig->{$Backend}->{Prio} . '-' . $Backend } =
                $CommonConfig->{$Backend};
        }
        else {
            $Config->{$Backend} = $CommonConfig->{$Backend};
        }
    }
    for my $Backend ( sort keys %{$ModuleConfig} ) {
        if ( $CommonConfig->{$Backend}->{Prio} ) {

            # prio defined as attribute
            $Config->{ $CommonConfig->{$Backend}->{Prio} . '-' . $Backend } =
                $ModuleConfig->{$Backend};
        }
        else {
            $Config->{$Backend} = $ModuleConfig->{$Backend};
        }
    }

    if ($Config) {
        # TicketID lookup
        if ( !$Param{TicketID} && $Kernel::OM->Get('Kernel::System::Web::Request')->GetParam( Param => 'TicketNumber' ) ) {
            $Param{TicketID} = $Kernel::OM->Get('Kernel::System::Ticket')->TicketIDLookup(
                TicketNumber => $Kernel::OM->Get('Kernel::System::Web::Request')->GetParam( Param => 'TicketNumber' ),
                UserID       => $Self->{UserID},
            );
        }
    }

    # get shown backends
    BACKEND:
    for my $Backend ( sort keys %{$Config} ) {

        # load backend module
        next BACKEND
            if !$Kernel::OM->Get('Kernel::System::Main')->Require( $Config->{$Backend}->{Module} );

        # execute event backend
        my $Generic = $Config->{$Backend}->{Module}->new(
            %{$Self},
            %Param,
            %{ $Config->{$Backend} },
            Frontend     => 'Customer',
            Config       => $Config->{$Backend},
            LayoutObject => $Self,
        );
        $Output .= $Generic->Run(
            %{$Self},
            %Param,
            %{ $Config->{$Backend} },
            Frontend => 'Customer',
            Config   => $Config->{$Backend},
        );
    }
    return $Output;
}

=item AgentListOptionJSON()

build a output with DisabledOption witch can be used for JSON data for pull downs

    my $DataHash = $LayoutObject->AgentListOptionJSON(
        [
            Data          => $ArrayRef,      # use $HashRef, $ArrayRef or $ArrayHashRef (see below)
            Name          => 'TheName',      # name of element
            MaxLevel      => $IntegerValue,  # recursion depth of QueueTree
        ],
        [
            # ...
        ]
    );

=cut

sub AgentListOptionJSON {
    my ( $Self, $Array, %Param ) = @_;

    my %DataHash;
    my $MaxLevel = defined( $Param{MaxLevel} ) ? $Param{MaxLevel} : 10;

    for my $Data ( @{$Array} ) {

        %Param = %{$Data};
        my %TempDataHash;

        # check needed stuff
        for (qw(Name Data)) {
            if ( !defined $Param{$_} ) {
                $Kernel::OM->Get('Kernel::System::Log')
                    ->Log( Priority => 'error', Message => "Need $_!" );
                return;
            }
        }

        my $Name = $Param{Name};
        my %Data;
        my %UsedData;
        if ( $Param{Data} && ref $Param{Data} eq 'HASH' ) {
            %Data = %{ $Param{Data} };
        }
        else {
            return 'Need Data Ref in AgentQueueListOptionJSON()!';
        }

        # add suffix for correct sorting
        for ( sort { $Data{$a} cmp $Data{$b} } keys %Data ) {
            $Data{$_} .= '::';
        }

        # to show disabled queues only one time in the selection tree
        my %DisabledQueueAlreadyUsed;

        # create hash
        my %NewHash;
        my %DisabledOptions;
        my @DataArray;
        for ( sort { $Data{$a} cmp $Data{$b} } keys %Data ) {
            my @Queue = split( /::/, $Param{Data}->{$_} );
            my $QueueSize = scalar(@Queue);
            $UsedData{ $Param{Data}->{$_} } = 1;
            my $UpQueue = $Param{Data}->{$_};
            $UpQueue =~ s/^(.*)::.+?$/$1/g;
            if ( !$Queue[$MaxLevel] && $Queue[-1] ne '' ) {
                if ( !$UsedData{$UpQueue} ) {
                    my $Value = '';
                    for my $Index ( 0 .. $QueueSize - 2 ) {
                        if ( !$DisabledQueueAlreadyUsed{$UpQueue} ) {
                            my $Key = '-';

                            # build value-string
                            if ($Index) {
                                $Value .= '::' . $Queue[$Index];
                            }
                            else {
                                $Value .= $Queue[$Index];
                            }

                            # do not disable used queues
                            if ( !$UsedData{$Value} ) {
                                my $HashKey = '';
                                if ( $Param{Name} eq 'Services' ) {
                                    $HashKey = $Kernel::OM->Get('Kernel::System::Service')
                                        ->ServiceLookup(
                                        Name => $Value
                                        );
                                }
                                elsif ( $Param{Name} eq 'Dest' ) {
                                    $HashKey = $Key . "||" . $Value;
                                }

                                $NewHash{$HashKey}                = $Value;
                                $DisabledOptions{$HashKey}        = $Value;
                                $DisabledQueueAlreadyUsed{$Value} = 1;
                            }
                        }
                    }
                }
                my $Key       = $_;
                my $Value     = '';
                my $Separator = '';
                for my $Index ( 0 .. $QueueSize - 1 ) {
                    $Value .= $Separator . $Queue[$Index];
                    $Separator = "::";
                }
                $NewHash{$Key} = $Value;
            }
        }
        $TempDataHash{DisabledOptions} = \%DisabledOptions;
        $TempDataHash{Data}            = \%NewHash;
        $DataHash{ $Param{Name} }      = \%TempDataHash;
    }
    return \%DataHash;
}

sub AgentQueueListOptionJSON {
    my ( $Self, $Array, %Param ) = @_;

    $Self->AgentListOptionJSON(
        $Array
    );
}

=item DependingDynamicFieldTree()

to create the depending dynamic field tree

    $ObjectBackend->DependingDynamicFieldTree(
        Nodes       => $HashRef,
        SelectedID  => $ID, # optional
    );

=cut

sub DependingDynamicFieldTree {

    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Nodes)) {
        if ( !defined $Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')
                ->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    # get needed objects
    my $DependingDynamicFieldObject = $Kernel::OM->Get('Kernel::System::DependingDynamicField');
    my $DynamicFieldObject          = $Kernel::OM->Get('Kernel::System::DynamicField');

    # get node data
    my %AllNodes        = %{ $Param{Nodes} };
    my %NodeReverseList = reverse %AllNodes;
    my %AllNodeData;

    # get selected node
    if ( !$Param{SelectedID} ) {
        $Param{SelectedID} = 0;
    }
    my @SelectedSplit = ();
    if ( $Param{SelectedID} && $AllNodes{ $Param{SelectedID} } ) {
        @SelectedSplit = split( /::/, $AllNodes{ $Param{SelectedID} } );
    }
    my $Level = $#SelectedSplit + 2;

    # create hash without :: for better sorting
    my %ToSortHash;
    for my $NodeID ( keys %AllNodes ) {
        my @NodeSplit = split( /::/, $AllNodes{$NodeID} );
        $ToSortHash{$NodeID} = join( "   ", @NodeSplit );
    }

    # sort hash and add IDs to array
    my @SortedArray;
    for my $NodeID ( sort { $ToSortHash{$a} cmp $ToSortHash{$b} } keys %ToSortHash ) {
        push @SortedArray, $NodeID;
    }

    # build tree information
    for my $NodeID (@SortedArray) {

        my @NodeSplit = split( /::/, $AllNodes{$NodeID} );
        $AllNodeData{$NodeID} = {
            Name  => $NodeSplit[-1],
            ID    => $NodeID,
            Split => \@NodeSplit,
        };

        # process current node information to all parents
        my $NodeName = '';
        for ( 0 .. $#NodeSplit - 1 ) {
            $NodeName .= '::' if $NodeName;
            $NodeName .= $NodeSplit[$_];
        }
    }

    # build tree string
    my $NodeBuildLastLevel = 0;
    my $NodeStrg;

    my $ElementStyle = '';
    for my $Current (@SortedArray) {

        my %Object     = %{ $AllNodeData{$Current} };
        my @Split      = @{ $Object{Split} };
        my $ObjectName = $Object{Name};
        my $ObjectID   = $Object{ID} || 0;

        # build entry
        my $ObjectStrg  = '';
        my $ListClass   = '';
        my $AnchorClass = '';

        # get invalid trees
        if ( $Current =~ m/^DynamicField_(.*)$/ ) {
            my $DynamicFieldData
                = $Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldGet( Name => $1 );
            my $DepedingDynamicFieldHash =
                $Kernel::OM->Get('Kernel::System::DependingDynamicField')
                ->DependingDynamicFieldTreeNameGet(
                ID => $DynamicFieldData->{ID}
                );
            if ( $DepedingDynamicFieldHash->{ValidID} != 1 ) {
                $ListClass .= ' InvalidTreeElement';
                $ElementStyle = 'color:#A0A0A0';
            }
            else {
                $ElementStyle = '';
            }
        }

        # should I focus and expand this node
        if (
            $Param{SelectedID}
            && $Current eq $Param{SelectedID}
            && $Level - 1 >= $#Split
            )
        {
            if ( $#SelectedSplit >= $#Split ) {
                $ListClass   .= ' Active';
                $AnchorClass .= ' selected';
            }
        }

        $ObjectName = $1 . '::' . $2 if ( $ObjectName =~ m/(.*?)\|(.*)/ );

        # create delete icon
        $ObjectStrg
            .= '<i class="fa fa-trash-o"></i>';

        $ObjectStrg
            .= '<a href="index.pl?Action='
            . $Self->{Action}
            . ';Subaction=Edit;DependingFieldID='
            . $ObjectID
            . ';" class="'
            . $ListClass
            . '" style="'
            . $ElementStyle
            . '"><span class="DependingDynamicField NoReload">'
            . $ObjectName . '</span></a>';

        # open menu
        if ( $NodeBuildLastLevel < $#Split ) {
            $NodeStrg .= '<ul>';
        }

        # close former sub menu
        elsif ( $NodeBuildLastLevel > $#Split ) {
            $NodeStrg .= '</li>';
            $NodeStrg .= '</ul>' x ( $NodeBuildLastLevel - $#Split );
            $NodeStrg .= '</li>';
        }

        # close former list element
        elsif ($NodeStrg) {
            $NodeStrg .= '</li>';
        }

        $NodeStrg .= '<li>' . $ObjectStrg;

        # keep current queue level for next category
        $NodeBuildLastLevel = $#Split;
    }

    # build category tree (and close all sub category menus)
    my $Result;
    $Result .= '<ul>';
    $Result .= $NodeStrg || '';
    $Result .= '</li></ul>' x $NodeBuildLastLevel;
    $Result .= '</li></ul>';

    return $Result;
}

# disable redefine warnings in this scope
{
    no warnings 'redefine';

    # overwrite sub Notify from Layout.pm to suppress messages the user doesn't want to see
    sub Kernel::Output::HTML::Layout::Notify {
        my ( $Self, %Param ) = @_;

        # create & return output
        if ( !$Param{Info} && !$Param{Data} ) {
            $Param{BackendMessage} = $Kernel::OM->Get('Kernel::System::Log')->GetLogEntry(
                Type => 'Notice',
                What => 'Message',
                )
                || $Kernel::OM->Get('Kernel::System::Log')->GetLogEntry(
                Type => 'Error',
                What => 'Message',
                ) || '';

            $Param{Info} = $Param{BackendMessage};

            # return if we have nothing to show
            return '' if !$Param{Info};
        }

        my $BoxClass = 'Notice';

        if ( $Param{Info} ) {
            $Param{Info} =~ s/\n//g;
        }
        if ( $Param{Priority} && $Param{Priority} eq 'Error' ) {
            $BoxClass = 'Error';
        }
        elsif ( $Param{Priority} && $Param{Priority} eq 'Success' ) {
            $BoxClass = 'Success';
        }
        elsif ( $Param{Priority} && $Param{Priority} eq 'Info' ) {
            $BoxClass = 'Info';
        }

        # KIX4OTRS-capeIT
        if ( $Self->{Baselink} =~ /\/index.pl/ ) {
            my ( $CallerPackage, $CallerFilename, $CallerLine ) = caller;
            my %UserPreferences
                = $Kernel::OM->Get('Kernel::System::User')->GetPreferences( UserID => $Self->{UserID} );
    
            my $CallerInfo= ( $CallerPackage || '' ) . '_' . ( $CallerLine || '' ) . '_' . ( $Param{Info} || '');
            $CallerInfo = Digest::MD5::md5_hex(utf8::is_utf8($CallerInfo) ? Encode::encode_utf8($CallerInfo) : $CallerInfo);
    
            $Param{NotifyID} = md5_hex($CallerInfo);
            return ""
                if (
                $UserPreferences{ 'UserAgentDoNotShowNotifiyMessage_' . $Param{NotifyID} }
                && $Self->{SessionID} eq
                $UserPreferences{ 'UserAgentDoNotShowNotifiyMessage_' . $Param{NotifyID} }
                );
        }
        # EO KIX4OTRS-capeIT

        if ( $Param{Link} ) {
            $Self->Block(
                Name => 'LinkStart',
                Data => {
                    LinkStart => $Param{Link},
                    LinkClass => $Param{LinkClass} || '',
                },
            );
        }
        if ( $Param{Data} ) {
            $Self->Block(
                Name => 'Data',
                Data => \%Param,
            );
        }
        else {
            $Self->Block(
                Name => 'Text',
                Data => \%Param,
            );
        }
        if ( $Param{Link} ) {
            $Self->Block(
                Name => 'LinkStop',
                Data => {
                    LinkStop => '</a>',
                },
            );
        }
        return $Self->Output(
            TemplateFile => 'Notify',
            Data         => {
                %Param,
                BoxClass => $BoxClass,
            },
        );
    }

    # overwrite sub AgentCustomerViewTable from LayoutTicket.pm to use CustomerUserInfoString
    sub Kernel::Output::HTML::Layout::AgentCustomerViewTable {
        my ( $Self, %Param ) = @_;

        # check customer params
        if ( ref $Param{Data} ne 'HASH' ) {
            $Self->FatalError( Message => 'Need Hash ref in Data param' );
        }
        elsif ( ref $Param{Data} eq 'HASH' && !%{ $Param{Data} } ) {
            return $Self->{LanguageObject}->Translate('none');
        }

        # add ticket params if given
        if ( $Param{Ticket} ) {
            %{ $Param{Data} } = ( %{ $Param{Data} }, %{ $Param{Ticket} } );
        }

        my @MapNew;
        my $Map = $Param{Data}->{Config}->{Map};
        if ($Map) {
            @MapNew = ( @{$Map} );
        }

        # check if customer company support is enabled
        if ( $Param{Data}->{Config}->{CustomerCompanySupport} ) {
            my $Map2 = $Param{Data}->{CompanyConfig}->{Map};
            if ($Map2) {
                push( @MapNew, @{$Map2} );
            }
        }

        my $ShownType = 1;
        if ( $Param{Type} && $Param{Type} eq 'Lite' ) {
            $ShownType = 2;

            # check if min one lite view item is configured, if not, use
            # the normal view also
            my $Used = 0;
            for my $Field (@MapNew) {
                if ( $Field->[3] == 2 ) {
                    $Used = 1;
                }
            }
            if ( !$Used ) {
                $ShownType = 1;
            }
        }

        # build html table
        $Self->Block(
            Name => 'Customer',
            Data => $Param{Data},
        );

        # get needed objects
        my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
        my $MainObject   = $Kernel::OM->Get('Kernel::System::Main');

        # check Frontend::CustomerUser::Image
        my $CustomerImage = $ConfigObject->Get('Frontend::CustomerUser::Image');
        if ($CustomerImage) {
            my %Modules = %{$CustomerImage};

            MODULE:
            for my $Module ( sort keys %Modules ) {
                if ( !$MainObject->Require( $Modules{$Module}->{Module} ) ) {
                    $Self->FatalDie();
                }

                my $Object = $Modules{$Module}->{Module}->new(
                    %{$Self},
                    LayoutObject => $Self,
                );

                # run module
                next MODULE if !$Object;

                $Object->Run(
                    Config => $Modules{$Module},
                    Data   => $Param{Data},
                );
            }
        }

        # KIX4OTRS-capeIT
        # use CustomerInfoString
        my $CustomerInfoString = $Param{Data}->{Config}->{CustomerInfoString}
            || $ConfigObject->Get('DefaultCustomerInfoString') || '';

        if ($CustomerInfoString) {
            $CustomerInfoString = $Self->Output(
                Template => $CustomerInfoString,
                Data     => {},
            );
            my $CustomerData = $Param{Data};
            while ( $CustomerInfoString =~ /\$CustomerData\-\>\{(.+?)}/ ) {
                my $Tag = $1;
                if ( $CustomerData->{$Tag} ) {
                    $CustomerInfoString =~ s/\$CustomerData\-\>\{$Tag\}/$CustomerData->{$Tag}/;
                }
                else {
                    $CustomerInfoString =~ s/\$CustomerData\-\>\{$Tag\}//;
                }
            }
            $Self->Block(
                Name => 'CustomerInfoString',
                Data => {
                    CustomerInfoString => $CustomerInfoString,
                    %{ $Param{Data} },
                    }
            );
        }
        else {

            # EO KIX4OTRS-capeIT
            # build table
            for my $Field (@MapNew) {
                if ( $Field->[3] && $Field->[3] >= $ShownType && $Param{Data}->{ $Field->[0] } ) {
                    my %Record = (
                        %{ $Param{Data} },
                        Key   => $Field->[1],
                        Value => $Param{Data}->{ $Field->[0] },
                    );
                    if ( $Field->[6] ) {
                        $Record{LinkStart} = "<a href=\"$Field->[6]\"";
                        if ( $Field->[8] ) {
                            $Record{LinkStart} .= " target=\"$Field->[8]\"";
                        }
                        if ( $Field->[9] ) {
                            $Record{LinkStart} .= " class=\"$Field->[9]\"";
                        }
                        $Record{LinkStart} .= ">";
                        $Record{LinkStop} = "</a>";
                    }
                    if ( $Field->[0] ) {
                        $Record{ValueShort} = $Self->Ascii2Html(
                            Text => $Record{Value},
                            Max  => $Param{Max}
                        );
                    }
                    $Self->Block(
                        Name => 'CustomerRow',
                        Data => \%Record,
                    );

                    if (
                        $Param{Data}->{Config}->{CustomerCompanySupport}
                        && $Field->[0] eq 'CustomerCompanyName'
                        )
                    {
                        my $CompanyValidID = $Param{Data}->{CustomerCompanyValidID};

                        if ($CompanyValidID) {
                            my @ValidIDs = $Kernel::OM->Get('Kernel::System::Valid')->ValidIDsGet();
                            my $CompanyIsValid = grep { $CompanyValidID == $_ } @ValidIDs;

                            if ( !$CompanyIsValid ) {
                                $Self->Block(
                                    Name => 'CustomerRowCustomerCompanyInvalid',
                                );
                            }
                        }
                    }
                }
            }

            # KIX4OTRS-capeIT
        }

        # EO KIX4OTRS-capeIT

        # check Frontend::CustomerUser::Item
        my $CustomerItem      = $ConfigObject->Get('Frontend::CustomerUser::Item');
        my $CustomerItemCount = 0;
        if ($CustomerItem) {
            $Self->Block(
                Name => 'CustomerItem',
            );
            my %Modules = %{$CustomerItem};

            MODULE:
            for my $Module ( sort keys %Modules ) {
                if ( !$MainObject->Require( $Modules{$Module}->{Module} ) ) {
                    $Self->FatalDie();
                }

                my $Object = $Modules{$Module}->{Module}->new(
                    %{$Self},
                    LayoutObject => $Self,
                );

                # run module
                next MODULE if !$Object;

                my $Run = $Object->Run(
                    Config => $Modules{$Module},
                    Data   => $Param{Data},

                    # KIX4OTRS-capeIT
                    CallingAction => $Param{CallingAction}

                    # EO KIX4OTRS-capeIT
                );

                next MODULE if !$Run;

                $CustomerItemCount++;
            }
        }

        # create & return output
        # KIX4OTRS-capeIT
        # return $Self->Output( TemplateFile => 'AgentCustomerTableView', Data => \%Param );
        return $Self->Output(
            TemplateFile   => 'AgentCustomerTableView',
            Data           => \%Param,
            KeepScriptTags => $Param{Data}->{AJAX} || 0,
        );

        # EO KIX4OTRS-capeIT
    }

    sub Kernel::Output::HTML::Layout::BuildDateSelection {
        my ( $Self, %Param ) = @_;

        my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

        # KIX4OTRS-capeIT
        my ( $SmartStyleDate, $SmartStyleTime, $MinuteInterval );
        my $TimeIntervalConfig
            = $ConfigObject->Get('DateSelection::Layout::TimeInputIntervall');

        # get default values
        if ( $Self->{Action} ne 'AgentTicketSearch' && $Self->{Action} ne 'AgentITSMConfigItemSearch' ) {
            $SmartStyleDate
                = ( defined $Param{SmartDateInput} )
                ? $Param{SmartDateInput}
                : $ConfigObject->Get('DateSelection::Layout::SmartDateInput');
            $SmartStyleTime
                = ( defined $Param{SmartTimeInput} )
                ? $Param{SmartTimeInput}
                : $ConfigObject->Get('DateSelection::Layout::SmartTimeInput');
            $MinuteInterval
                = ( defined $Param{TimeInputIntervall} )
                ? $Param{TimeInputIntervall}
                : 30;
        }

        # set time input interval from sysconfig if defined
        for my $Action ( keys %{$TimeIntervalConfig} ) {
            next if $Self->{Action} !~ /$Action/;
            $MinuteInterval = $TimeIntervalConfig->{$Action};
            last;
        }

        # EO KIX4OTRS-capeIT

        my $DateInputStyle = $ConfigObject->Get('TimeInputFormat');
        my $Prefix         = $Param{Prefix} || '';
        my $DiffTime       = $Param{DiffTime} || 0;
        my $Format         = defined( $Param{Format} ) ? $Param{Format} : 'DateInputFormatLong';
        my $Area           = $Param{Area} || 'Agent';
        my $Optional       = $Param{ $Prefix . 'Optional' } || 0;
        my $Required       = $Param{ $Prefix . 'Required' } || 0;
        my $Used           = $Param{ $Prefix . 'Used' } || 0;

        # KIX4OTRS-capeIT
        # my $Class          = $Param{ $Prefix . 'Class' } || '';
        my $Class          = '';
        my $ClassDate      = '';
        my $ClassTime      = '';
        if ( !$SmartStyleDate && !$SmartStyleTime ) {
            $Class          = $Param{ $Prefix . 'Class' } || '';
        }
        elsif ( $SmartStyleDate && !$SmartStyleTime ) {
            if ( $Param{ $Prefix . 'Class' } ) {
                $ClassDate = $Param{ $Prefix . 'Class' } . ' Modernize';
                $ClassTime = $Param{ $Prefix . 'Class' };
            }
            else {
                $ClassDate = 'Modernize';
                $ClassTime = '';
            }
        }
        else {
            if ( $Param{ $Prefix . 'Class' } ) {
                $ClassDate = $Param{ $Prefix . 'Class' } . ' Modernize';
                $ClassTime = $Param{ $Prefix . 'Class' } . ' Modernize';
            }
            else {
                $ClassDate = 'Modernize';
                $ClassTime = 'Modernize';
            }
        }
        # EO KIX4OTRS-capeIT

        # Defines, if the date selection should be validated on client side with JS
        my $Validate = $Param{Validate} || 0;

        # Validate that the date is in the future (e. g. pending times)
        my $ValidateDateInFuture    = $Param{ValidateDateInFuture}    || 0;
        my $ValidateDateNotInFuture = $Param{ValidateDateNotInFuture} || 0;

        my ( $s, $m, $h, $D, $M, $Y ) = $Self->{UserTimeObject}->SystemTime2Date(
            SystemTime => $Self->{UserTimeObject}->SystemTime() + $DiffTime,
        );

        my ( $Cs, $Cm, $Ch, $CD, $CM, $CY ) = $Self->{UserTimeObject}->SystemTime2Date(
            SystemTime => $Self->{UserTimeObject}->SystemTime(),
        );

        # time zone translation
        if (
            $ConfigObject->Get('TimeZoneUser')
            && $Self->{UserTimeZone}
            && $Param{ $Prefix . 'Year' }
            && $Param{ $Prefix . 'Month' }
            && $Param{ $Prefix . 'Day' }
            && !$Param{OverrideTimeZone}
            )
        {
            my $TimeStamp = $Self->{TimeObject}->TimeStamp2SystemTime(
                String => $Param{ $Prefix . 'Year' } . '-'
                    . $Param{ $Prefix . 'Month' } . '-'
                    . $Param{ $Prefix . 'Day' } . ' '
                    . ( $Param{ $Prefix . 'Hour' }   || 0 ) . ':'
                    . ( $Param{ $Prefix . 'Minute' } || 0 )
                    . ':00',
            );
            $TimeStamp = $TimeStamp + ( $Self->{UserTimeZone} * 3600 );
            (
                $Param{ $Prefix . 'Second' },
                $Param{ $Prefix . 'Minute' },
                $Param{ $Prefix . 'Hour' },
                $Param{ $Prefix . 'Day' },
                $Param{ $Prefix . 'Month' },
                $Param{ $Prefix . 'Year' }
            ) = $Self->{UserTimeObject}->SystemTime2Date( SystemTime => $TimeStamp );
        }

        # KIX4OTRS-capeIT
        my $DateValidateClasses = '';
        if ($Validate) {
            $DateValidateClasses
                .= "Validate_DateDay Validate_DateYear_${Prefix}Year Validate_DateMonth_${Prefix}Month";

            if ( $Format eq 'DateInputFormatLong' ) {
                $DateValidateClasses
                    .= " Validate_DateHour_${Prefix}Hour Validate_DateMinute_${Prefix}Minute";
            }

            if ($ValidateDateInFuture) {
                $DateValidateClasses .= " Validate_DateInFuture";
            }
            if ($ValidateDateNotInFuture) {
                $DateValidateClasses .= " Validate_DateNotInFuture";
            }
        }
        if ($SmartStyleDate) {
            $DateValidateClasses = "Validate_DateFull";
            if ($ValidateDateInFuture) {
                $DateValidateClasses .= " Validate_DateFullInFuture";
            }
        }
        my $DateFormat
            = $Kernel::OM->Get('Kernel::Output::HTML::Layout')->{LanguageObject}->{DateInputFormat};
        $DateFormat =~ s/\%D/dd/g;
        $DateFormat =~ s/\%M/mm/g;
        $DateFormat =~ s/\%Y/yy/g;

        # EO KIX4OTRS-capeIT

        # year
        # KIX4OTRS-capeIT
        if ($SmartStyleDate) {
            my $Date = $Kernel::OM->Get('Kernel::Output::HTML::Layout')->{LanguageObject}
                ->FormatTimeString(
                sprintf( "%04d", ( $Param{ $Prefix . 'Year' } || $Y ) ) .
                    '-' .
                    sprintf( "%02d", ( $Param{ $Prefix . 'Month' } || $M ) ) .
                    '-' .
                    sprintf( "%02d", ( $Param{ $Prefix . 'Day' } || $D ) ) .
                    ' 00:00:00',
                'DateFormatShort',
                );
            $Param{DateStr} = "<input type=\"text\" "
                . ( $Validate ? "class=\"$DateValidateClasses $ClassDate\" " : "class=\"$ClassDate\" " )
                . "name=\"${Prefix}Date\" id=\"${Prefix}Date\" size=\"10\" maxlength=\"10\" "
                . "title=\""
                . $Kernel::OM->Get('Kernel::Output::HTML::Layout')->{LanguageObject}->Get('Date')
                . "\" value=\""
                . ( $Param{ $Prefix . 'Date' } || $Date ) . "\"/>";
            $Param{DateStr} .= "<input type=\"hidden\" "
                . "class=\"$Class\" "
                . "name=\"${Prefix}Year\" id=\"${Prefix}Year\" size=\"4\" maxlength=\"4\" "
                . "value=\""
                . sprintf( "%04d", ( $Param{ $Prefix . 'Year' } || $Y ) ) . "\"/>";
        }

        # if ( $DateInputStyle eq 'Option' ) {
        elsif ( $DateInputStyle eq 'Option' ) {

            # EO KIX4OTRS-capeIT
            my %Year;
            if ( defined $Param{YearPeriodPast} && defined $Param{YearPeriodFuture} ) {
                for ( $Y - $Param{YearPeriodPast} .. $Y + $Param{YearPeriodFuture} ) {
                    $Year{$_} = $_;
                }
            }
            else {
                for ( 2001 .. $Y + 1 + ( $Param{YearDiff} || 0 ) ) {
                    $Year{$_} = $_;
                }
            }

       # Check if the DiffTime is in a future year. In this case, we add the missing years between
       # $CY (current year) and $Y (year) to allow the user to manually set back the year if needed.
            if ( $Y > $CY ) {
                for ( $CY .. $Y ) {
                    $Year{$_} = $_;
                }
            }

            $Param{Year} = $Self->BuildSelection(
                Name        => $Prefix . 'Year',
                Data        => \%Year,
                SelectedID  => int( $Param{ $Prefix . 'Year' } || $Y ),
                Translation => 0,
                Class       => $Validate ? 'Validate_DateYear' : '',
                Title       => $Self->{LanguageObject}->Translate('Year'),
                Disabled    => $Param{Disabled},
            );
        }
        else {
            $Param{Year} = "<input type=\"text\" "
                . ( $Validate ? "class=\"Validate_DateYear $Class\" " : "class=\"$Class\" " )
                . "name=\"${Prefix}Year\" id=\"${Prefix}Year\" size=\"4\" maxlength=\"4\" "
                . "title=\""
                . $Self->{LanguageObject}->Translate('Year')
                . "\" value=\""
                . sprintf( "%02d", ( $Param{ $Prefix . 'Year' } || $Y ) ) . "\" "
                . ( $Param{Disabled} ? 'readonly="readonly"' : '' ) . "/>";
        }

        # month
        # KIX4OTRS-capeIT
        if ($SmartStyleDate) {
            $Param{DateStr} .= "<input type=\"hidden\" "
                . "class=\"$ClassDate\" "
                . "name=\"${Prefix}Month\" id=\"${Prefix}Month\" size=\"2\" maxlength=\"2\" "
                . "value=\""
                . sprintf( "%02d", ( $Param{ $Prefix . 'Month' } || $M ) ) . "\"/>";
        }

        # if ( $DateInputStyle eq 'Option' ) {
        elsif ( $DateInputStyle eq 'Option' ) {

            # EO KIX4OTRS-capeIT
            my %Month = map { $_ => sprintf( "%02d", $_ ); } ( 1 .. 12 );
            $Param{Month} = $Self->BuildSelection(
                Name        => $Prefix . 'Month',
                Data        => \%Month,
                SelectedID  => int( $Param{ $Prefix . 'Month' } || $M ),
                Translation => 0,
                Class       => $Validate ? 'Validate_DateMonth' : '',
                Title       => $Self->{LanguageObject}->Translate('Month'),
                Disabled    => $Param{Disabled},
            );
        }
        else {
            $Param{Month} = "<input type=\"text\" "
                . ( $Validate ? "class=\"Validate_DateMonth $Class\" " : "class=\"$Class\" " )
                . "name=\"${Prefix}Month\" id=\"${Prefix}Month\" size=\"2\" maxlength=\"2\" "
                . "title=\""
                . $Self->{LanguageObject}->Translate('Month')
                . "\" value=\""
                . sprintf( "%02d", ( $Param{ $Prefix . 'Month' } || $M ) ) . "\" "
                . ( $Param{Disabled} ? 'readonly="readonly"' : '' ) . "/>";
        }

        # day
        # KIX4OTRS-capeIT
        if ($SmartStyleDate) {
            $Param{DateStr} .= "<input type=\"hidden\" "
                . "class=\"$ClassDate\" "
                . "name=\"${Prefix}Day\" id=\"${Prefix}Day\" size=\"2\" maxlength=\"2\" "
                . "value=\""
                . sprintf( "%02d", ( $Param{ $Prefix . 'Day' } || $D ) ) . "\"/>";
        }

        #if ( $DateInputStyle eq 'Option' ) {
        elsif ( $DateInputStyle eq 'Option' ) {

            # EO KIX4OTRS-capeIT
            my %Day = map { $_ => sprintf( "%02d", $_ ); } ( 1 .. 31 );
            $Param{Day} = $Self->BuildSelection(
                Name        => $Prefix . 'Day',
                Data        => \%Day,
                SelectedID  => int( $Param{ $Prefix . 'Day' } || $D ),
                Translation => 0,
                Class       => "$DateValidateClasses $Class",
                Title       => $Self->{LanguageObject}->Translate('Day'),
                Disabled    => $Param{Disabled},
            );
        }
        else {
            $Param{Day} = "<input type=\"text\" "
                . "class=\"$DateValidateClasses $Class\" "
                . "name=\"${Prefix}Day\" id=\"${Prefix}Day\" size=\"2\" maxlength=\"2\" "
                . "title=\""
                . $Self->{LanguageObject}->Translate('Day')
                . "\" value=\""
                . sprintf( "%02d", ( $Param{ $Prefix . 'Day' } || $D ) ) . "\" "
                . ( $Param{Disabled} ? 'readonly="readonly"' : '' ) . "/>";

        }
        if ( $Format eq 'DateInputFormatLong' ) {

            # hour
            # KIX4OTRS-capeIT
            if ($SmartStyleTime) {
                $h =
                    defined( $Param{ $Prefix . 'Hour' } )
                    ? int( $Param{ $Prefix . 'Hour' } )
                    : $h;
                $m
                    = defined( $Param{ $Prefix . 'Minute' } )
                    ? int( $Param{ $Prefix . 'Minute' } )
                    : $m;

                if ( $m != 0 && ( $m % $MinuteInterval ) != 0 ) {
                    my $Minute = $MinuteInterval;
                    while ( ( $Minute / $m ) < 1 && ( $Minute < 60 ) ) {
                        $Minute += $MinuteInterval;
                    }
                    if ( $Minute >= 60 && $h >= 23 ) {
                        $h = 23;
                        $m = 59;
                    }
                    elsif ( $Minute >= 60 ) {
                        $h = $h + 1;
                        $m = 0;
                    }
                    else {
                        $m = $Minute;
                    }
                }
                $h = sprintf( "%02d", $h );
                $m = sprintf( "%02d", $m );
                my %TimeDef = (
                    '23:59' => '23:59',
                );
                my $HourParts = 60 / $MinuteInterval - 1;
                for my $CurrHour ( 0 .. 23 ) {
                    for my $CurrPart ( 0 .. $HourParts ) {
                        my $Tmp
                            = sprintf(
                            "%02d:%02d", $CurrHour,
                            ( $MinuteInterval * $CurrPart )
                            );
                        $TimeDef{$Tmp} = $Tmp;
                    }
                }
                $Param{TimeStr} = $Self->BuildSelection(
                    Name                => $Prefix . 'Time',
                    Data                => \%TimeDef,
                    SelectedID          => $h . ':' . $m,
                    LanguageTranslation => 0,
                    Class               => $Validate ? ( 'Validate_DateTime ' . $ClassTime ) : $ClassTime,
                    Title => $Kernel::OM->Get('Kernel::Output::HTML::Layout')->{LanguageObject}
                        ->Get('Time'),
                );
                $Param{TimeStr} .= "<input type=\"hidden\" "
                    . (
                    $Validate ? "class=\"Validate_DateHour $Class\" " : "class=\"$Class\" "
                    )
                    . "name=\"${Prefix}Hour\" id=\"${Prefix}Hour\" size=\"2\" maxlength=\"2\" "
                    . "value=\""
                    . $h
                    . "\"/>";
            }

            #if ( $DateInputStyle eq 'Option' ) {
            elsif ( $DateInputStyle eq 'Option' ) {

                # EO KIX4OTRS-capeIT
                my %Hour = map { $_ => sprintf( "%02d", $_ ); } ( 0 .. 23 );
                $Param{Hour} = $Self->BuildSelection(
                    Name       => $Prefix . 'Hour',
                    Data       => \%Hour,
                    SelectedID => defined( $Param{ $Prefix . 'Hour' } )
                    ? int( $Param{ $Prefix . 'Hour' } )
                    : int($h),
                    Translation => 0,
                    Class       => $Validate ? ( 'Validate_DateHour ' . $Class ) : $Class,
                    Title       => $Self->{LanguageObject}->Translate('Hours'),
                    Disabled    => $Param{Disabled},
                );
            }
            else {
                $Param{Hour} = "<input type=\"text\" "
                    . ( $Validate ? "class=\"Validate_DateHour $Class\" " : "class=\"$Class\" " )
                    . "name=\"${Prefix}Hour\" id=\"${Prefix}Hour\" size=\"2\" maxlength=\"2\" "
                    . "title=\""
                    . $Self->{LanguageObject}->Translate('Hours')
                    . "\" value=\""
                    . sprintf(
                    "%02d",
                    (
                        defined( $Param{ $Prefix . 'Hour' } )
                        ? int( $Param{ $Prefix . 'Hour' } )
                        : $h
                        )
                    )
                    . "\" "
                    . ( $Param{Disabled} ? 'readonly="readonly"' : '' ) . "/>";

            }

            # minute
            # KIX4OTRS-capeIT
            if ($SmartStyleTime) {
                $Param{TimeStr} .= "<input type=\"hidden\" "
                    . (
                    $Validate ? "class=\"Validate_DateMinute $Class\" " : "class=\"$Class\" "
                    )
                    . "name=\"${Prefix}Minute\" id=\"${Prefix}Minute\" size=\"2\" maxlength=\"2\" "
                    . " value=\""
                    . $m
                    . "\"/>";
            }

            #if ( $DateInputStyle eq 'Option' ) {
            elsif ( $DateInputStyle eq 'Option' ) {

                # EO KIX4OTRS-capeIT

                my %Minute = map { $_ => sprintf( "%02d", $_ ); } ( 0 .. 59 );
                $Param{Minute} = $Self->BuildSelection(
                    Name       => $Prefix . 'Minute',
                    Data       => \%Minute,
                    SelectedID => defined( $Param{ $Prefix . 'Minute' } )
                    ? int( $Param{ $Prefix . 'Minute' } )
                    : int($m),
                    Translation => 0,
                    Class       => $Validate ? ( 'Validate_DateMinute ' . $Class ) : $Class,
                    Title       => $Self->{LanguageObject}->Translate('Minutes'),
                    Disabled    => $Param{Disabled},
                );
            }
            else {
                $Param{Minute} = "<input type=\"text\" "
                    . ( $Validate ? "class=\"Validate_DateMinute $Class\" " : "class=\"$Class\" " )
                    . "name=\"${Prefix}Minute\" id=\"${Prefix}Minute\" size=\"2\" maxlength=\"2\" "
                    . "title=\""
                    . $Self->{LanguageObject}->Translate('Minutes')
                    . "\" value=\""
                    . sprintf(
                    "%02d",
                    (
                        defined( $Param{ $Prefix . 'Minute' } )
                        ? int( $Param{ $Prefix . 'Minute' } )
                        : $m
                        )
                    ) . "\" "
                    . ( $Param{Disabled} ? 'readonly="readonly"' : '' ) . "/>";
            }
        }

        # Get first day of the week
        my $WeekDayStart = $ConfigObject->Get('CalendarWeekDayStart');
        if ( $Param{Calendar} ) {
            if ( $ConfigObject->Get( "TimeZone::Calendar" . $Param{Calendar} . "Name" ) ) {
                $WeekDayStart
                    = $ConfigObject->Get( "CalendarWeekDayStart::Calendar" . $Param{Calendar} );
            }
        }
        if ( !defined $WeekDayStart ) {
            $WeekDayStart = 1;
        }

        my $Output;

        # optional checkbox
        if ($Optional) {
            my $Checked = '';
            if ($Used) {
                $Checked = ' checked="checked"';
            }
            $Output .= "<input type=\"checkbox\" name=\""
                . $Prefix
                . "Used\" id=\"" . $Prefix . "Used\" value=\"1\""
                . $Checked
                . " class=\"$Class\""
                . " title=\""
                . $Self->{LanguageObject}->Translate('Check to activate this date')
                . "\" "
                . ( $Param{Disabled} ? 'disabled="disabled"' : '' )
                . "/>&nbsp;";
        }

        # date format
        # KIX4OTRS-capeIT
        if ($SmartStyleDate) {
            $Output .= $Param{DateStr};
            if ( $Param{TimeStr} || $Param{Hour} ) {
                $Output .= ' - ';
                $Output .= $Param{TimeStr} || ( $Param{Hour} . ':' . $Param{Minute} );
            }
        }
        elsif ( !$SmartStyleDate && $SmartStyleTime ) {
            $Output .= $Param{Day} . $Param{Month} . $Param{Year};
            if ( $Param{TimeStr} || $Param{Hour} ) {
                $Output .= ' - ';
                $Output .= $Param{TimeStr} || ( $Param{Hour} . ':' . $Param{Minute} );
            }
        }
        else {

            # EO KIX4OTRS-capeIT
            $Output .= $Self->{LanguageObject}->Time(
                Action => 'Return',
                Format => 'DateInputFormat',
                Mode   => 'NotNumeric',
                %Param,
            );
        }

        # prepare datepicker for specific calendar
        my $VacationDays = '';
        if ( $Param{Calendar} ) {
            $VacationDays = $Self->DatepickerGetVacationDays(
                Calendar => $Param{Calendar},
            );
        }
        my $VacationDaysJSON = $Self->JSONEncode(
            Data => $VacationDays,
        );

        # Add Datepicker JS to output.
        my $DatepickerJS = 'Core.UI.Datepicker.Init({
            // KIX4OTRS-capeIT
            Date: $("#" + Core.App.EscapeSelector("' . $Prefix . '") + "Date"),
            Time: $("#" + Core.App.EscapeSelector("' . $Prefix . '") + "Time"),
            Format: "' . $DateFormat . '",
            // EO KIX4OTRS-capeIT
            Day: $("#" + Core.App.EscapeSelector("' . $Prefix . '") + "Day"),
            Month: $("#" + Core.App.EscapeSelector("' . $Prefix . '") + "Month"),
            Year: $("#" + Core.App.EscapeSelector("' . $Prefix . '") + "Year"),
            Hour: $("#" + Core.App.EscapeSelector("' . $Prefix . '") + "Hour"),
            Minute: $("#" + Core.App.EscapeSelector("' . $Prefix . '") + "Minute"),
            VacationDays: ' . $VacationDaysJSON . ',
            DateInFuture: ' .    ( $ValidateDateInFuture    ? 'true' : 'false' ) . ',
            DateNotInFuture: ' . ( $ValidateDateNotInFuture ? 'true' : 'false' ) . ',
            WeekDayStart: ' . $WeekDayStart . '
        });';

        if ( $Self->{Action} eq 'AgentStatistics' ) {
            $DatepickerJS .= "\n" . 'Core.Config.Set("' . $Prefix . 'Format", "' . $DateFormat . '");
                Core.Config.Set("' . $Prefix . 'VacationDays", ' . $VacationDaysJSON . ');
                Core.Config.Set("' . $Prefix . 'DateInFuture", ' . ( $ValidateDateInFuture    ? 'true' : 'false' ) . ');
                Core.Config.Set("' . $Prefix . 'DateNotInFuture", ' . ( $ValidateDateNotInFuture ? 'true' : 'false' ) . ');
                Core.Config.Set("' . $Prefix . 'WeekDayStart", ' . $WeekDayStart . ');';
        }

        $Self->AddJSOnDocumentComplete( Code => $DatepickerJS );
        $Self->{HasDatepicker} = 1;    # Call some Datepicker init code.

        return $Output;
    }

    # overwrite AgentQueueListOption about user preferences for GenericAutoCompleteSearch
    sub Kernel::Output::HTML::Layout::AgentQueueListOption {
        my ( $Self, %Param ) = @_;

        my $Size           = $Param{Size}                      ? "size='$Param{Size}'"  : '';
        my $MaxLevel       = defined( $Param{MaxLevel} )       ? $Param{MaxLevel}       : 10;
        my $SelectedID     = defined( $Param{SelectedID} )     ? $Param{SelectedID}     : '';
        my $Selected       = defined( $Param{Selected} )       ? $Param{Selected}       : '';
        my $CurrentQueueID = defined( $Param{CurrentQueueID} ) ? $Param{CurrentQueueID} : '';
        my $Class          = defined( $Param{Class} )          ? $Param{Class}          : '';
        my $SelectedIDRefArray = $Param{SelectedIDRefArray} || '';
        my $Multiple       = $Param{Multiple}                  ? 'multiple = "multiple"' : '';
        my $TreeView       = $Param{TreeView}                  ? $Param{TreeView}        : 0;
        my $OptionTitle    = defined( $Param{OptionTitle} )    ? $Param{OptionTitle}     : 0;
        my $OnChangeSubmit = defined( $Param{OnChangeSubmit} ) ? $Param{OnChangeSubmit}  : '';
        if ($OnChangeSubmit) {
            $OnChangeSubmit = " onchange=\"submit();\"";
        }
        else {
            $OnChangeSubmit = '';
        }

        # set OnChange if AJAX is used
        if ( $Param{Ajax} ) {

            # get log object
            my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

            if ( !$Param{Ajax}->{Depend} ) {
                $LogObject->Log(
                    Priority => 'error',
                    Message  => 'Need Depend Param Ajax option!',
                );
                $Self->FatalError();
            }
            if ( !$Param{Ajax}->{Update} ) {
                $LogObject->Log(
                    Priority => 'error',
                    Message  => 'Need Update Param Ajax option()!',
                );
                $Self->FatalError();
            }
            $Param{OnChange} = "Core.AJAX.FormUpdate(\$('#"
                . $Param{Name} . "'), '"
                . $Param{Ajax}->{Subaction} . "',"
                . " '$Param{Name}',"
                . " ['"
                . join( "', '", @{ $Param{Ajax}->{Update} } ) . "']);";
        }

        if ( $Param{OnChange} ) {
            $OnChangeSubmit = " onchange=\"$Param{OnChange}\"";
        }

        #  KIX4OTRS-capeIT
        my %UserPreferences;
        my $AutoCompleteConfig
            = $Kernel::OM->Get('Kernel::Config')
            ->Get('Ticket::Frontend::GenericAutoCompleteSearch');
        my $SearchType
            = $AutoCompleteConfig->{SearchTypeMapping}->{ $Self->{Action} . ":::" . $Param{Name} }
            || '';

        if ($SearchType) {

            # get UserPreferences
            %UserPreferences = $Kernel::OM->Get('Kernel::System::User')
                ->GetPreferences( UserID => $Self->{UserID} );
        }

        #  EO KIX4OTRS-capeIT

        # just show a simple list
        #  KIX4OTRS-capeIT
        # if ( $Kernel::OM->Get('Kernel::Config')->Get('Ticket::Frontend::ListType'){
        if (
            $Kernel::OM->Get('Kernel::Config')->Get('Ticket::Frontend::ListType') eq 'list'
            || (
                $UserPreferences{ 'User' . $SearchType . 'SelectionStyle' }
                && $UserPreferences{ 'User' . $SearchType . 'SelectionStyle' } eq 'AutoComplete'
            )
            )
        {

            # EO KIX4OTRS-capeIT

            # transform data from Hash in Array because of ordering in frontend by Queue name
            # it was a problem wit name like '(some_queue)'
            # see bug#10621 http://bugs.otrs.org/show_bug.cgi?id=10621
            my %QueueDataHash = %{ $Param{Data} || {} };

            # get StandardResponsesStrg
            my %ReverseQueueDataHash = reverse %QueueDataHash;
            my @QueueDataArray       = map {
                {
                    Key   => $ReverseQueueDataHash{$_},
                    Value => $_
                }
            } sort values %QueueDataHash;

            # find index of first element in array @QueueDataArray for displaying in frontend
            # at the top should be element with ' $QueueDataArray[$_]->{Key} = 0' like "- Move -"
            # when such element is found, it is moved at the top
            my ($FirstElementIndex) = grep $QueueDataArray[$_]->{Key} == 0, 0 .. $#QueueDataArray;
            splice( @QueueDataArray, 0, 0, splice( @QueueDataArray, $FirstElementIndex, 1 ) );
            $Param{Data} = \@QueueDataArray;

            $Param{MoveQueuesStrg} = $Self->BuildSelection(
                %Param,
                HTMLQuote     => 0,
                SelectedID    => $Param{SelectedID} || $Param{SelectedIDRefArray} || '',
                SelectedValue => $Param{Selected},
                Translation   => 0,
            );
            return $Param{MoveQueuesStrg};
        }

        # build tree list
        $Param{MoveQueuesStrg} = '<select name="'
            . $Param{Name}
            . '" id="'
            . $Param{Name}
            . '" class="'
            . $Class
            . '" data-tree="true"'
            . " $Size $Multiple $OnChangeSubmit>\n";
        my %UsedData;
        my %Data;

        if ( $Param{Data} && ref $Param{Data} eq 'HASH' ) {
            %Data = %{ $Param{Data} };
        }
        else {
            return 'Need Data Ref in AgentQueueListOption()!';
        }

        # add suffix for correct sorting
        my $KeyNoQueue;
        my $ValueNoQueue;
        my $MoveStr = $Self->{LanguageObject}->Get('Move');
        my $ValueOfQueueNoKey .= "- " . $MoveStr . " -";
        DATA:
        for ( sort { $Data{$a} cmp $Data{$b} } keys %Data ) {

            # find value for default item in select box
            # it can be "-" or "Move"
            if (
                $Data{$_} eq "-"
                || $Data{$_} eq $ValueOfQueueNoKey
                )
            {
                $KeyNoQueue   = $_;
                $ValueNoQueue = $Data{$_};
                next DATA;
            }
            $Data{$_} .= '::';
        }

        # set default item of select box
        if ($ValueNoQueue) {
            $Param{MoveQueuesStrg} .= '<option value="'
                . $KeyNoQueue
                . '">'
                . $ValueNoQueue
                . "</option>\n";
        }

        # build selection string
        KEY:
        for ( sort { $Data{$a} cmp $Data{$b} } keys %Data ) {

            # default item of select box has set already
            next KEY if ( $Data{$_} eq "-" || $Data{$_} eq $ValueOfQueueNoKey );

            my @Queue = split( /::/, $Param{Data}->{$_} );
            $UsedData{ $Param{Data}->{$_} } = 1;
            my $UpQueue = $Param{Data}->{$_};
            $UpQueue =~ s/^(.*)::.+?$/$1/g;
            if ( !$Queue[$MaxLevel] && $Queue[-1] ne '' ) {
                $Queue[-1] = $Self->Ascii2Html(
                    Text => $Queue[-1],
                    Max  => 50 - $#Queue
                );
                my $Space = '';
                for ( my $i = 0; $i < $#Queue; $i++ ) {
                    $Space .= '&nbsp;&nbsp;';
                }

                # check if SelectedIDRefArray exists
                if ($SelectedIDRefArray) {
                    for my $ID ( @{$SelectedIDRefArray} ) {
                        if ( $ID eq $_ ) {
                            $Param{SelectedIDRefArrayOK}->{$_} = 1;
                        }
                    }
                }

                # get HTML utils object
                my $HTMLUtilsObject = $Kernel::OM->Get('Kernel::System::HTMLUtils');

                if ( !$UsedData{$UpQueue} ) {

                    # integrate the not selectable parent and root queues of this queue
                    # useful for ACLs and complex permission settings
                    for my $Index ( 0 .. ( scalar @Queue - 2 ) ) {

                        # get the Full Queue Name (with all its parents separated by '::') this will
                        # make a unique name and will be used to set the %DisabledQueueAlreadyUsed
                        # using unique names will prevent erroneous hide of Sub-Queues with the
                        # same name, refer to bug#8148
                        my $FullQueueName;
                        for my $Counter ( 0 .. $Index ) {
                            $FullQueueName .= $Queue[$Counter];
                            if ( int $Counter < int $Index ) {
                                $FullQueueName .= '::';
                            }
                        }

                        if ( !$UsedData{$FullQueueName} ) {
                            my $DSpace               = '&nbsp;&nbsp;' x $Index;
                            my $OptionTitleHTMLValue = '';
                            if ($OptionTitle) {
                                my $HTMLValue = $HTMLUtilsObject->ToHTML(
                                    String => $Queue[$Index],
                                );
                                $OptionTitleHTMLValue = ' title="' . $HTMLValue . '"';
                            }
                            $Param{MoveQueuesStrg}
                                .= '<option value="-" disabled="disabled"'
                                . $OptionTitleHTMLValue
                                . '>'
                                . $DSpace
                                . $Queue[$Index]
                                . "</option>\n";
                            $UsedData{$FullQueueName} = 1;
                        }
                    }
                }

                # create selectable elements
                my $String               = $Space . $Queue[-1];
                my $OptionTitleHTMLValue = '';
                if ($OptionTitle) {
                    my $HTMLValue = $HTMLUtilsObject->ToHTML(
                        String => $Queue[-1],
                    );
                    $OptionTitleHTMLValue = ' title="' . $HTMLValue . '"';
                }
                if (
                    $SelectedID  eq $_
                    || $Selected eq $Param{Data}->{$_}
                    || $Param{SelectedIDRefArrayOK}->{$_}
                    )
                {
                    $Param{MoveQueuesStrg}
                        .= '<option selected="selected" value="'
                        . $_ . '"'
                        . $OptionTitleHTMLValue . '>'
                        . $String
                        . "</option>\n";
                }
                elsif ( $CurrentQueueID eq $_ )
                {
                    $Param{MoveQueuesStrg}
                        .= '<option value="-" disabled="disabled"'
                        . $OptionTitleHTMLValue . '>'
                        . $String
                        . "</option>\n";
                }
                else {
                    $Param{MoveQueuesStrg}
                        .= '<option value="'
                        . $_ . '"'
                        . $OptionTitleHTMLValue . '>'
                        . $String
                        . "</option>\n";
                }
            }
        }
        $Param{MoveQueuesStrg} .= "</select>\n";

        if ( $Param{TreeView} ) {
            my $TreeSelectionMessage = $Self->{LanguageObject}->Translate("Show Tree Selection");
            $Param{MoveQueuesStrg}
                .= ' <a href="#" title="'
                . $TreeSelectionMessage
                . '" class="ShowTreeSelection"><span>'
                . $TreeSelectionMessage . '</span><i class="fa fa-sitemap"></i></a>';
        }

        return $Param{MoveQueuesStrg};
    }

    # overwrite buildselection for added GenericAutoCompleteSearch
    sub Kernel::Output::HTML::Layout::BuildSelection {
        my ( $Self, %Param ) = @_;

        # check needed stuff
        for (qw(Name Data)) {
            if ( !$Param{$_} ) {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message  => "Need $_!"
                );
                return;
            }
        }

        # The parameters 'Ajax' and 'OnChange' are exclusive
        if ( $Param{Ajax} && $Param{OnChange} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "The parameters 'OnChange' and 'Ajax' exclude each other!"
            );
            return;
        }

        # KIX4OTRS-capeIT
        if (
            $Kernel::OM->Get('Kernel::Config')->Get('Ticket::TypeTranslation')
            && ( $Param{Name} eq 'TypeID' || $Param{Name} eq 'TypeIDs' )
            )
        {
            $Param{Translation} = 1;
        }

        # EO KIX4OTRS-capeIT

        # set OnChange if AJAX is used
        if ( $Param{Ajax} ) {
            if ( !$Param{Ajax}->{Depend} ) {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message  => 'Need Depend Param Ajax option!',
                );
                $Self->FatalError();
            }
            if ( !$Param{Ajax}->{Update} ) {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message  => 'Need Update Param Ajax option()!',
                );
                $Self->FatalError();
            }
            my $Selector = $Param{ID} || $Param{Name};
            $Param{OnChange} = "Core.AJAX.FormUpdate(\$('#"
                . $Selector . "'), '" . $Param{Ajax}->{Subaction} . "',"
                . " '$Param{Name}',"
                . " ['"
                . join( "', '", @{ $Param{Ajax}->{Update} } ) . "']);";
        }

        # create OptionRef
        my $OptionRef = $Self->_BuildSelectionOptionRefCreate(%Param);

        # create AttributeRef
        my $AttributeRef = $Self->_BuildSelectionAttributeRefCreate(%Param);

        # create DataRef
        my $DataRef = $Self->_BuildSelectionDataRefCreate(
            Data         => $Param{Data},
            AttributeRef => $AttributeRef,
            OptionRef    => $OptionRef,
        );

        # create FiltersRef
        my @Filters;
        my $FilterActive;
        if ( $Param{Filters} ) {
            my $Index = 1;
            for my $Filter ( sort keys %{ $Param{Filters} } ) {
                if (
                    $Param{Filters}->{$Filter}->{Name}
                    && $Param{Filters}->{$Filter}->{Values}
                    )
                {
                    my $FilterData = $Self->_BuildSelectionDataRefCreate(
                        Data         => $Param{Filters}->{$Filter}->{Values},
                        AttributeRef => $AttributeRef,
                        OptionRef    => $OptionRef,
                    );
                    push @Filters, {
                        Name => $Param{Filters}->{$Filter}->{Name},
                        Data => $FilterData,
                    };
                    if ( $Param{Filters}->{$Filter}->{Active} ) {
                        $FilterActive = $Index;
                    }
                }
                else {
                    $Kernel::OM->Get('Kernel::System::Log')->Log(
                        Priority => 'error',
                        Message  => 'Each Filter must provide Name and Values!',
                    );
                    $Self->FatalError();
                }
                $Index++;
            }
            @Filters = sort { $a->{Name} cmp $b->{Name} } @Filters;
        }

        # KIX4OTRS-capeIT
        # get disabled selections
        if ( defined $Param{DisabledOptions} && ref $Param{DisabledOptions} eq 'HASH' ) {
            my $DisabledOptions = $Param{DisabledOptions};
            for my $Item ( keys %{ $Param{DisabledOptions} } ) {
                my $ItemValue = $Param{DisabledOptions}->{$Item};
                my @ItemArray = split( '::', $ItemValue );
                for ( my $Index = 0; $Index < scalar @{$DataRef}; $Index++ ) {
                    next
                        if (
                        $DataRef->[$Index]->{Value} !~ m/$ItemArray[-1]$/
                        || $DataRef->[$Index]->{Key} ne $Item
                        );
                    $DataRef->[$Index]->{Disabled} = 1;
                }
            }
        }

        # get UserPreferences
        if (
            ref $Kernel::OM->Get('Kernel::Config')
            ->Get('Ticket::Frontend::GenericAutoCompleteSearch') eq 'HASH'
            && defined $Self->{UserID}
            && $Self->{Action} !~ /^Customer/
            )
        {
            my $AutoCompleteConfig
                = $Kernel::OM->Get('Kernel::Config')
                ->Get('Ticket::Frontend::GenericAutoCompleteSearch');
            my %UserPreferences = $Kernel::OM->Get('Kernel::System::User')
                ->GetPreferences( UserID => $Self->{UserID} );

            my $SearchType;

            my $SearchTypeMappingKey;
            if ( $Self->{Action} && $Param{Name} ) {
                $SearchTypeMappingKey = $Self->{Action} . ":::" . $Param{Name};
            }

            if (
                $SearchTypeMappingKey
                && defined $AutoCompleteConfig->{SearchTypeMapping}->{$SearchTypeMappingKey}
                )
            {
                $SearchType = $AutoCompleteConfig->{SearchTypeMapping}->{$SearchTypeMappingKey};
            }

            # create string for autocomplete
            if (
                $SearchType
                && $UserPreferences{ 'User' . $SearchType . 'SelectionStyle' }
                && $UserPreferences{ 'User' . $SearchType . 'SelectionStyle' } eq 'AutoComplete'
                )
            {
                my $AutoCompleteString
                    = '<input id="'
                    . $Param{Name}
                    . '" type="hidden" name="'
                    . $Param{Name}
                    . '" value=""/>'
                    . '<input id="'
                    . $Param{Name}
                    . 'autocomplete" type="text" name="'
                    . $Param{Name}
                    . 'autocomplete" value="" class=" W75pc AutocompleteOff Validate_Required"/>';

                $Self->AddJSOnDocumentComplete( Code => <<"EOF");
    Core.Config.Set("GenericAutoCompleteSearch.MinQueryLength",$AutoCompleteConfig->{MinQueryLength});
    Core.Config.Set("GenericAutoCompleteSearch.QueryDelay",$AutoCompleteConfig->{QueryDelay});
    Core.Config.Set("GenericAutoCompleteSearch.MaxResultsDisplayed",$AutoCompleteConfig->{MaxResultsDisplayed});
    Core.KIX4OTRS.GenericAutoCompleteSearch.Init(\$("#$Param{Name}autocomplete"),\$("#$Param{Name}"));
EOF
                return $AutoCompleteString;
            }
        }

        # EO KIX4OTRS-capeIT
        # generate output
        my $String = $Self->_BuildSelectionOutput(
            AttributeRef  => $AttributeRef,
            DataRef       => $DataRef,
            OptionTitle   => $Param{OptionTitle},
            TreeView      => $Param{TreeView},
            FiltersRef    => \@Filters,
            FilterActive  => $FilterActive,
            ExpandFilters => $Param{ExpandFilters},
            # KIX4OTRS-capeIT
            DisabledOptions => $Param{DisabledOptions},
            # EO KIX4OTRS-capeIT
        );
        return $String;
    }

    sub Kernel::Output::HTML::Layout::BuildSelectionJSON {
        my ( $Self, $Array ) = @_;
        my %DataHash;

        for my $Data ( @{$Array} ) {
            my %Param = %{$Data};

            # log object
            my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

            # check needed stuff
            for (qw(Name)) {
                if ( !defined $Param{$_} ) {
                    $LogObject->Log(
                        Priority => 'error',
                        Message  => "Need $_!"
                    );
                    return;
                }
            }

            # KIX4OTRS-capeIT
            if (
                $Kernel::OM->Get('Kernel::Config')->Get('Ticket::TypeTranslation')
                &&  ( $Param{Name} eq 'TypeID' || $Param{Name} eq 'TypeIDs' )
                )
            {
                $Param{Translation} = 1;
            }

            my $Disabled = 0;
            my $DisabledOptions;
            if ( defined $Param{DisabledOptions} && ref $Param{DisabledOptions} eq 'HASH' ) {
                $Disabled        = 1;
                $DisabledOptions = $Param{DisabledOptions};
            }

            # EO KIX4OTRS-capeIT

             if ( !defined( $Param{Data} ) ) {
                if ( !$Param{PossibleNone} ) {
                    $LogObject->Log(
                        Priority => 'error',
                        Message  => "Need Data!"
                    );
                    return;
                }
                $DataHash{''} = '-';
            }
            elsif ( ref $Param{Data} eq '' ) {

                # KIX4OTRS-capeIT
                if ( defined $Param{FieldDisabled} && $Param{FieldDisabled} ) {
                    my @DataArray;
                    push @DataArray, $Param{Data};
                    push @DataArray, Kernel::System::JSON::False();
                    $DataHash{ $Param{Name} } = \@DataArray;
                }
                else {
                    $DataHash{ $Param{Name} } = $Param{Data};
                }

                # EO KIX4OTRS-capeIT
            }
            else {

                # create OptionRef
                my $OptionRef = $Self->_BuildSelectionOptionRefCreate(
                    %Param,
                    HTMLQuote => 0,
                );

                # create AttributeRef
                my $AttributeRef = $Self->_BuildSelectionAttributeRefCreate(%Param);

                # create DataRef
                my $DataRef = $Self->_BuildSelectionDataRefCreate(
                    Data         => $Param{Data},
                    AttributeRef => $AttributeRef,
                    OptionRef    => $OptionRef,
                );

                # create data structure
                if ( $AttributeRef && $DataRef ) {
                    my @DataArray;
                    for my $Row ( @{$DataRef} ) {
                        my $Key = '';
                        if ( defined $Row->{Key} ) {
                            $Key = $Row->{Key};
                        }
                        my $Value = '';
                        if ( defined $Row->{Value} ) {
                            $Value = $Row->{Value};
                        }

                        # DefaultSelected parameter for JavaScript New Option
                        my $DefaultSelected = Kernel::System::JSON::False();

                      # KIX4OTRS-capeIT
                      # to set a disabled option (Disabled is not included in JavaScript New Option)
                      # my $Disabled = Kernel::System::JSON::False();
                        my $DisabledOption = Kernel::System::JSON::False();

                        # EO KIX4OTRS-capeIT
                        if ( $Row->{Selected} ) {
                            $DefaultSelected = Kernel::System::JSON::True();
                        }
                        elsif ( $Row->{Disabled} ) {
                            $DefaultSelected = Kernel::System::JSON::False();

                            # KIX4OTRS-capeIT
                            # $Disabled        = Kernel::System::JSON::True();
                            $DisabledOption = Kernel::System::JSON::True();

                            # EO KIX4OTRS-capeIT
                        }

                        if ($Disabled) {
                            if ( $DisabledOptions->{$Key} ) {
                                $DisabledOption = Kernel::System::JSON::True();
                            }
                        }

                        # Selected parameter for JavaScript NewOption
                        my $Selected = $DefaultSelected;
                        push @DataArray,
                            [ $Key, $Value, $DefaultSelected, $Selected, $DisabledOption ];
                    }

                    # KIX4OTRS-capeIT
                    if ( defined $Param{FieldDisabled} && $Param{FieldDisabled} ) {
                        push @DataArray, Kernel::System::JSON::False();
                    }

                    # EO KIX4OTRS-capeIT
                    $DataHash{ $AttributeRef->{name} } = \@DataArray;
                }
            }
        }

        return $Self->JSONEncode(
            Data => \%DataHash,
        );
    }

    # overwrite sub TicketMetaItems to provide CustomTicketOverview
    sub Kernel::Output::HTML::Layout::TicketMetaItems {
        my ( $Self, %Param ) = @_;

        # KIX4OTRS-capeIT
        my %ActiveColums = (
            'Priority'    => 1,
            'New Article' => 1,
            'Locked'      => 0,
            'Watcher'     => 0,
        );

        if ( $Param{ViewableColumns} && ref( $Param{ViewableColumns} ) eq 'ARRAY' ) {
            my @ViewableColumns = @{ $Param{ViewableColumns} };
            $ActiveColums{'Priority'}    = 0;
            $ActiveColums{'New Article'} = 0;
            $ActiveColums{'Locked'}      = 0;
            $ActiveColums{'Watcher'}     = 0;
            for my $Columns (@ViewableColumns) {
                $ActiveColums{$Columns} = 1;
            }
        }

        # EO KIX4OTRS-capeIT

        if ( ref $Param{Ticket} ne 'HASH' ) {
            $Self->FatalError( Message => 'Need Hash ref in Ticket param!' );
        }

        # return attributes
        my @Result;

        # show priority
        # KIX4OTRS-capeIT
        # if (1) {
        if ( $ActiveColums{'Priority'} ) {

            # EO KIX4OTRS-capeIT
            push @Result, {

                #            Image => $Image,
                Title      => $Param{Ticket}->{Priority},
                Class      => 'Flag',
                ClassSpan  => 'PriorityID-' . $Param{Ticket}->{PriorityID},
                ClassTable => 'Flags',
            };
        }

        # get ticket object
        my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

        my %Ticket = $TicketObject->TicketGet( TicketID => $Param{Ticket}->{TicketID} );

        # Show if new message is in there, but show archived tickets as read.
        my %TicketFlag;
        if ( $Ticket{ArchiveFlag} ne 'y' ) {
            %TicketFlag = $TicketObject->TicketFlagGet(
                TicketID => $Param{Ticket}->{TicketID},
                UserID   => $Self->{UserID},
            );
        }

        # KIX4OTRS-capeIT
        # if ( $Ticket{ArchiveFlag} eq 'y' || $TicketFlag{Seen} ) {
        if ( $ActiveColums{'New Article'} && ( $Ticket{ArchiveFlag} eq 'y' || $TicketFlag{Seen} ) )
        {

            # EO KIX4OTRS-capeIT
            push @Result, undef;
        }

        # KIX4OTRS-capeIT
        # else
        elsif ( $Ticket{ArchiveFlag} ne 'y' && $ActiveColums{'New Article'} ) {

            # EO KIX4OTRS-capeIT

            # just show ticket flags if agent belongs to the ticket
            my $ShowMeta;
            if (
                $Self->{UserID} == $Param{Ticket}->{OwnerID}
                || $Self->{UserID} == $Param{Ticket}->{ResponsibleID}
                )
            {
                $ShowMeta = 1;
            }
            if ( !$ShowMeta && $Kernel::OM->Get('Kernel::Config')->Get('Ticket::Watcher') ) {
                my %Watch = $TicketObject->TicketWatchGet(
                    TicketID => $Param{Ticket}->{TicketID},
                );
                if ( $Watch{ $Self->{UserID} } ) {
                    $ShowMeta = 1;
                }
            }

            # show ticket flags
            my $Image = 'meta-new-inactive.png';
            if ($ShowMeta) {
                $Image = 'meta-new.png';
                push @Result, {
                    Image      => $Image,
                    Title      => 'Unread article(s) available',
                    Class      => 'UnreadArticles',
                    ClassSpan  => 'UnreadArticles Remarkable',
                    ClassTable => 'UnreadArticles',
                };
            }
            else {
                push @Result, {
                    Image      => $Image,
                    Title      => 'Unread article(s) available',
                    Class      => 'UnreadArticles',
                    ClassSpan  => 'UnreadArticles Ordinary',
                    ClassTable => 'UnreadArticles',
                };
            }
        }

        return @Result;
    }

    # overwrite sub TicketListShow to provide CustomTicketOverview-Settings
    sub Kernel::Output::HTML::Layout::TicketListShow {
        my ( $Self, %Param ) = @_;

        # KIX4OTRS-capeIT
        my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');

        # EO KIX4OTRS-capeIT

        # take object ref to local, remove it from %Param (prevent memory leak)
        my $Env = $Param{Env};
        delete $Param{Env};

        # lookup latest used view mode
        if ( !$Param{View} && $Self->{ 'UserTicketOverview' . $Env->{Action} } ) {
            $Param{View} = $Self->{ 'UserTicketOverview' . $Env->{Action} };
        }

        # set default view mode to 'small'
        my $View = $Param{View} || 'Small';

        # set default view mode for AgentTicketQueue or AgentTicketService
        if (
            !$Param{View}
            && (
                $Env->{Action} eq 'AgentTicketQueue'
                || $Env->{Action} eq 'AgentTicketService'
            )
            )
        {
            $View = 'Preview';
        }

        # store latest view mode
        $Kernel::OM->Get('Kernel::System::AuthSession')->UpdateSessionID(
            SessionID => $Self->{SessionID},
            Key       => 'UserTicketOverview' . $Env->{Action},
            Value     => $View,
        );

        # get config object
        my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

        # update preferences if needed
        my $Key = 'UserTicketOverview' . $Env->{Action};

        # KIX4OTRS-capeIT
        my $LastView = $Self->{$Key} || '';

        # if ( !$ConfigObject->Get('DemoSystem') && $Self->{$Key} ne $View ) {
        if ( !$ConfigObject->Get('DemoSystem') && $LastView ne $View ) {

            # EO KIX4OTRS-capeIT
            $Kernel::OM->Get('Kernel::System::User')->SetPreferences(
                UserID => $Self->{UserID},
                Key    => $Key,
                Value  => $View,
            );
        }

        # check backends
        my $Backends = $ConfigObject->Get('Ticket::Frontend::Overview');
        if ( !$Backends ) {
            return $Self->FatalError(
                Message => 'Need config option Ticket::Frontend::Overview',
            );
        }
        if ( ref $Backends ne 'HASH' ) {
            return $Self->FatalError(
                Message => 'Config option Ticket::Frontend::Overview need to be HASH ref!',
            );
        }

        # check if selected view is available
        if ( !$Backends->{$View} ) {

            # try to find fallback, take first configured view mode
            KEY:
            for my $Key ( sort keys %{$Backends} ) {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message  => "No Config option found for view mode $View, took $Key instead!",
                );
                $View = $Key;
                last KEY;
            }
        }

        # load overview backend module
        if ( !$Kernel::OM->Get('Kernel::System::Main')->Require( $Backends->{$View}->{Module} ) ) {
            return $Env->{LayoutObject}->FatalError();
        }
        my $Object = $Backends->{$View}->{Module}->new( %{$Env} );
        return if !$Object;

        # retireve filter values
        if ( $Param{FilterContentOnly} ) {
            return $Object->FilterContent(
                %Param,
            );
        }

        # run action row backend module
        $Param{ActionRow} = $Object->ActionRow(
            %Param,
            Config => $Backends->{$View},
        );

        # run overview backend module
        $Param{SortOrderBar} = $Object->SortOrderBar(
            %Param,
            Config => $Backends->{$View},
        );

        # check start option, if higher then tickets available, set
        # it to the last ticket page (Thanks to Stefan Schmidt!)
        my $StartHit = $Kernel::OM->Get('Kernel::System::Web::Request')->GetParam( Param => 'StartHit' ) || 1;

        # get personal page shown count
        my $PageShownPreferencesKey = 'UserTicketOverview' . $View . 'PageShown';
        my $PageShown               = $Self->{$PageShownPreferencesKey} || 10;
        my $Group                   = 'TicketOverview' . $View . 'PageShown';

        # get data selection
        my %Data;
        my $Config = $ConfigObject->Get('PreferencesGroups');
        if ( $Config && $Config->{$Group} && $Config->{$Group}->{Data} ) {
            %Data = %{ $Config->{$Group}->{Data} };
        }

        # calculate max. shown per page
        if ( $StartHit > $Param{Total} ) {
            my $Pages = int( ( $Param{Total} / $PageShown ) + 0.99999 );
            $StartHit = ( ( $Pages - 1 ) * $PageShown ) + 1;
        }

        # build nav bar
        my $Limit = $Param{Limit} || 20_000;
        my %PageNav = $Self->PageNavBar(
            Limit     => $Limit,
            StartHit  => $StartHit,
            PageShown => $PageShown,
            AllHits   => $Param{Total} || 0,
            Action    => 'Action=' . $Self->{Action},
            Link      => $Param{LinkPage},
            IDPrefix  => $Self->{Action},
        );

        # build shown ticket per page
        # KIX4OTRS-capeIT
        # this results in a re-open of the search dialog if someone uses the context settings after a ticket search
        # $Param{RequestedURL}    = "Action=$Self->{Action}";
        $Param{RequestedURL}
            = $Kernel::OM->Get('Kernel::System::Web::Request')->{Query}->url( -query_string => 1 )
            || "Action=$Self->{Action}";

        # EO KIX4OTRS-capeIT
        $Param{Group}           = $Group;
        $Param{PreferencesKey}  = $PageShownPreferencesKey;
        $Param{PageShownString} = $Self->BuildSelection(
            Name        => $PageShownPreferencesKey,
            SelectedID  => $PageShown,
            Translation => 0,
            Data        => \%Data,
            Sort        => 'NumericValue',
        );

        # nav bar at the beginning of a overview
        $Param{View} = $View;
        $Self->Block(
            Name => 'OverviewNavBar',
            Data => \%Param,
        );

        # back link
        if ( $Param{LinkBack} ) {
            $Self->Block(
                Name => 'OverviewNavBarPageBack',
                Data => \%Param,
            );
        }

        # filter selection
        if ( $Param{Filters} ) {
            my @NavBarFilters;
            for my $Prio ( sort keys %{ $Param{Filters} } ) {
                push @NavBarFilters, $Param{Filters}->{$Prio};
            }
            $Self->Block(
                Name => 'OverviewNavBarFilter',
                Data => {
                    %Param,
                },
            );
            my $Count = 0;
            for my $Filter (@NavBarFilters) {
                $Count++;
                if ( $Count == scalar @NavBarFilters ) {
                    $Filter->{CSS} = 'Last';
                }
                $Self->Block(
                    Name => 'OverviewNavBarFilterItem',
                    Data => {
                        %Param,
                        %{$Filter},
                    },
                );
                if ( $Filter->{Filter} eq $Param{Filter} ) {
                    $Self->Block(
                        Name => 'OverviewNavBarFilterItemSelected',
                        Data => {
                            %Param,
                            %{$Filter},
                        },
                    );
                }
                else {
                    $Self->Block(
                        Name => 'OverviewNavBarFilterItemSelectedNot',
                        Data => {
                            %Param,
                            %{$Filter},
                        },
                    );
                }
            }
        }

        # view mode
        for my $Backend (
            sort { $Backends->{$a}->{ModulePriority} <=> $Backends->{$b}->{ModulePriority} }
            keys %{$Backends}
            )
        {

            $Self->Block(
                Name => 'OverviewNavBarViewMode',
                Data => {
                    %Param,
                    %{ $Backends->{$Backend} },
                    Filter => $Param{Filter},
                    View   => $Backend,
                },
            );
            if ( $View eq $Backend ) {
                $Self->Block(
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
                $Self->Block(
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

        if (%PageNav) {
            $Self->Block(
                Name => 'OverviewNavBarPageNavBar',
                Data => \%PageNav,
            );

            # don't show context settings in AJAX case (e. g. in customer ticket history),
            #   because the submit with page reload will not work there
            if ( !$Param{AJAX} ) {
                $Self->Block(
                    Name => 'ContextSettings',
                    Data => {
                        %PageNav,
                        %Param,
                    },
                );

                # show column filter preferences
                if ( $View eq 'Small' ) {

                    # set preferences keys
                    my $PrefKeyColumns = 'UserFilterColumnsEnabled' . '-' . $Env->{Action};

                    # create extra needed objects
                    my $JSONObject = $Kernel::OM->Get('Kernel::System::JSON');

                    # configure columns
                    my @ColumnsEnabled = @{ $Object->{ColumnsEnabled} };
                    my @ColumnsAvailable;

                    for my $ColumnName ( sort { $a cmp $b } @{ $Object->{ColumnsAvailable} } ) {
                        if ( !grep { $_ eq $ColumnName } @ColumnsEnabled ) {
                            push @ColumnsAvailable, $ColumnName;
                        }
                    }

                    my %Columns;

                    # KIX4OTRS-capeIT
                    # for my $ColumnName ( sort @ColumnsAvailable ) {
                    for my $ColumnName (@ColumnsAvailable) {

                        # EO KIX4OTRS-capeIT
                        $Columns{Columns}->{$ColumnName}
                            = ( grep { $ColumnName eq $_ } @ColumnsEnabled ) ? 1 : 0;
                    }

                    $Self->Block(
                        Name => 'FilterColumnSettings',
                        Data => {
                            Columns          => $JSONObject->Encode( Data => \%Columns ),
                            ColumnsEnabled   => $JSONObject->Encode( Data => \@ColumnsEnabled ),
                            ColumnsAvailable => $JSONObject->Encode( Data => \@ColumnsAvailable ),
                            NamePref         => $PrefKeyColumns,
                            Desc             => 'Shown Columns',
                            Name             => $Env->{Action},
                            View             => $View,
                            GroupName        => 'TicketOverviewFilterSettings',
                            %Param,
                        },
                    );
                }
                }    # end show column filters preferences

                # check if there was stored filters, and print a link to delete them
                if ( IsHashRefWithData( $Object->{StoredFilters} ) ) {
                $Self->Block(
                        Name => 'DocumentActionRowRemoveColumnFilters',
                        Data => {
                            CSS => "ContextSettings RemoveFilters",
                            %Param,
                        },
                    );
            }
        }

        if ( $Param{NavBar} ) {
            if ( $Param{NavBar}->{MainName} ) {
                $Self->Block(
                    Name => 'OverviewNavBarMain',
                    Data => $Param{NavBar},
                );
            }
        }

        my $OutputNavBar = $Self->Output(
            TemplateFile => 'AgentTicketOverviewNavBar',
            Data         => { %Param, },
        );
        my $OutputRaw = '';
        if ( !$Param{Output} ) {
            $Self->Print( Output => \$OutputNavBar );
        }
        else {
            $OutputRaw .= $OutputNavBar;
        }

        # run overview backend module
        my $Output = $Object->Run(
            %Param,
            Config    => $Backends->{$View},
            Limit     => $Limit,
            StartHit  => $StartHit,
            PageShown => $PageShown,
            AllHits   => $Param{Total} || 0,
            Output    => $Param{Output} || '',
        );
        if ( !$Param{Output} ) {
            $Self->Print( Output => \$Output );
        }
        else {
            $OutputRaw .= $Output;
        }

        return $OutputRaw;
    }

    # reset all warnings
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
