# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::Layout::KIX;

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

    my @UploadedAtm;
    if (defined $Param{FormID}
        && $Param{FormID}
    ) {
        @UploadedAtm = $Kernel::OM->Get('Kernel::System::Web::UploadCache')->FormIDGetAllFilesMeta(
            FormID => $Param{FormID},
        );
    }

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
    ) {
        my $IsChecked = '';
        if ( scalar @UploadedAtm ) {
            UPLOADEDATM:
            for my $UpAtm ( @UploadedAtm ) {
                if ( $UpAtm->{Filename} eq $AttachmentList{$AttachmentID}->{Filename}) {
                    $IsChecked = 'checked="checked"';
                    last UPLOADEDATM;
                }
            }
        }

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
                IsChecked           => $IsChecked || ''
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
        my %Customer = $Kernel::OM->Get('Kernel::System::CustomerCompany')->CustomerCompanyGet(
            CustomerID => $CustomerID,
        );

        $Self->Block(
            Name => 'CustomerIDRow',
            Data => {
                %Customer,
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
        ) {
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
                    my $UserBackend = 'UserIsGroup[' . $Group . ']';
                    next BACKEND if !$Self->{$UserBackend};
                    next BACKEND if $Self->{$UserBackend} ne 'Yes';
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
        ) {
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
            return 'Need Data Ref in AgentListOptionJSON()!';
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

## DEPRECATED ##
sub AgentQueueListOptionJSON {
    my ( $Self, $Array, %Param ) = @_;

    $Self->AgentListOptionJSON(
        $Array
    );

    return 1;
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
        ) {
            if ( $#SelectedSplit >= $#Split ) {
                $ListClass   .= ' Active';
                $AnchorClass .= ' selected';
            }
        }

        if ( $ObjectName =~ m/(.*?)\|(.*)/ ) {
            $ObjectName = $1 . '::' . $2;
        }

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
1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
