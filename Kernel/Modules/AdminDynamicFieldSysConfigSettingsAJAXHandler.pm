# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AdminDynamicFieldSysConfigSettingsAJAXHandler;

use strict;
use warnings;

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = { %Param };
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $LayoutObject    = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $SysConfigObject = $Kernel::OM->Get('Kernel::System::SysConfig');
    my $ParamObject     = $Kernel::OM->Get('Kernel::System::Web::Request');

    # get data
    my $Name = $ParamObject->GetParam(
        Param => 'Name',
    );
    if ( !$Name ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need DynamicField Name!',
        );
        return;
    }

    my @SelectedFrontends = $ParamObject->GetArray(
        Param => 'AvailableFrontends',
    );
    my @Mandatory = $ParamObject->GetArray(
        Param => 'MandatoryFrontends',
    );

    # get available frontends - necessary to disable dynamic field in not selected frontends
    my %Result = $Self->_GetAllAvailableFrontendModules(
        Name => $Name,
    );
    my %AvailableFrontends = %{ $Result{AvailableFrontends} };

    FRONTEND:
    for my $Frontend ( keys( %AvailableFrontends ) ) {
        # get all set attributes for this frontend
        my %ItemHash;
        my $ItemKey = '';

        # exception for process tab
        if ( $Frontend eq 'AgentTicketZoomTabProcess' ) {
            $ItemKey  = 'Ticket::Frontend::AgentTicketZoom###ProcessWidgetDynamicField';
            %ItemHash = $SysConfigObject->ConfigItemGet(
                Name => $ItemKey,
            );
        }
        # exception for FollowUpDynamicField
        elsif ( $Frontend eq 'CustomerTicketZoomFollowUp' ) {
            $ItemKey  = 'Ticket::Frontend::CustomerTicketZoom###FollowUpDynamicField';
            %ItemHash = $SysConfigObject->ConfigItemGet(
                Name => $ItemKey,
            );
        }
        else {
            $ItemKey  = 'Ticket::Frontend::' . $Frontend . '###DynamicField';
            %ItemHash = $SysConfigObject->ConfigItemGet(
                Name => $ItemKey,
            );
        }

        # if frontend not found try admin and agent frontend
        if ( !keys( %ItemHash ) ) {
            for my $Item ( qw(Admin Agent) ) {
                $ItemKey  = $Item . '::Frontend::' . $Frontend . '###DynamicField';
                %ItemHash = $SysConfigObject->ConfigItemGet(
                    Name => $ItemKey,
                );
                last if ( keys( %ItemHash ) );
            }
        }

        # try next frontend if no hash detected
        next FRONTEND if ( !keys( %ItemHash ) );

        # create hash from old values
        my %Content;
        for my $Item ( @{ $ItemHash{Setting}->[1]->{Hash}->[1]->{Item} } ) {
            next if ( !defined( $Item->{Key} ) );
            $Content{ $Item->{Key} } = $Item->{Content};
        }

        # disable dynamic field
        $Content{ $Name } = 0;

        # enable if selected
        if ( grep { $_ eq $Frontend }( @SelectedFrontends ) ) {
            # set to value = 2 if mandatory
            if ( grep { $_ eq $Frontend }( @Mandatory ) ) {
                $Content{ $Name } = 2;
            }
            # set to value 1 for display
            else {
                $Content{ $Name } = 1;
            }
        }

        # update sysconfig settings
        my $Update = $SysConfigObject->ConfigItemUpdate(
            Key   => $ItemKey,
            Value => \%Content,
            Valid => 1,
        );

        if ( !$Update ) {
            $LayoutObject->FatalError(
                Message => 'Can not write ConfigItem!',
            );
        }
    }

    # submit config changes
    $SysConfigObject->CreateConfig();

    # if running under PerlEx, reload the application (and thus the configuration)
    if (
        exists( $ENV{'GATEWAY_INTERFACE'} )
        && $ENV{'GATEWAY_INTERFACE'} eq 'CGI-PerlEx'
    ) {
        PerlEx::ReloadAll();
    }

    return $LayoutObject->Attachment(
        ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
        Content     => '1',
        Type        => 'inline',
        NoCache     => 1,
    );
}

sub _GetAllAvailableFrontendModules {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    my %Result;

    # get all frontend modules
    # get agent frontend modules
    my $ConfigHashAgent = $ConfigObject->Get('Frontend::Module');

    # get customer frontend modules
    my $ConfigHashCustomer = $ConfigObject->Get('CustomerFrontend::Module');
    my %ConfigHash         = ( %{ $ConfigHashAgent }, %{ $ConfigHashCustomer } );

    # get all tabs
    my $ConfigHashTabs = $ConfigObject->Get('AgentTicketZoomBackend');
    for my $Item ( keys( %{ $ConfigHashTabs } ) ) {

        # if no link is given
        next if ( !defined( $ConfigHashTabs->{ $Item }->{Link} ) );

        # look for PretendAction
        if ( $ConfigHashTabs->{ $Item }->{Link} =~ /^(.*?)\;PretendAction=(.*?)\;(.*)$/ ) {
            next if (
                !$2
                || $ConfigHash{ $2 }
            );

            # if given and not already registered as frontend module - add width empty value to config hash
            $ConfigHash{ $2 } = '';
        }
    }

    # ticket overview - add width empty value to config hash
    $ConfigHash{'OverviewSmall'}   = '';
    $ConfigHash{'OverviewMedium'}  = '';
    $ConfigHash{'OverviewPreview'} = '';

    # KIXSidebars - add width empty value to config hash
    for my $Frontend ( qw(Frontend CustomerFrontend) ) {
        my $SidebarConfig = $ConfigObject->Get( $Frontend . '::KIXSidebarBackend' );
        if (
            $SidebarConfig
            && ref( $SidebarConfig ) eq 'HASH'
        ) {
            for my $Key ( sort( keys( %{ $SidebarConfig } ) ) ) {
                my $SidebarBackendConfig = $ConfigObject->Get( 'Ticket::Frontend::KIXSidebar' . $Key );
                if ( exists( $SidebarBackendConfig->{DynamicField} ) ) {
                    $ConfigHash{ 'KIXSidebar' . $Key } = '';
                }
            }
        }
    }

    # init result params
    my %AvailableFrontends;
    my @SelectedFrontends  = ();
    my @MandatoryFrontends = ();

    # handle dynamic field for process tab
    if (
        defined( $ConfigObject->Get( 'Ticket::Frontend::AgentTicketZoom' ) )
        && defined( $ConfigObject->Get( 'Ticket::Frontend::AgentTicketZoom' )->{ProcessWidgetDynamicField} )
    ) {
        $AvailableFrontends{AgentTicketZoomTabProcess} = 'AgentTicketZoomTabProcess';

        my $ConfigRef = $ConfigObject->Get( 'Ticket::Frontend::AgentTicketZoom' )->{ProcessWidgetDynamicField}->{ $Param{Name} };
        if ( !$ConfigRef ) {
            # nothing to do
        }
        elsif ( $ConfigRef eq '1' ) {
            push( @SelectedFrontends, 'AgentTicketZoomTabProcess' );
        }
        elsif ( $ConfigRef eq '2' ) {
            push( @SelectedFrontends,  'AgentTicketZoomTabProcess' );
            push( @MandatoryFrontends, 'AgentTicketZoomTabProcess' );
        }
    }

    # handle followup dynamic field for customer frontend
    if (
        defined( $ConfigObject->Get( 'Ticket::Frontend::CustomerTicketZoom' ) )
        && defined( $ConfigObject->Get( 'Ticket::Frontend::CustomerTicketZoom' )->{FollowUpDynamicField} )
    ) {
        $AvailableFrontends{CustomerTicketZoomFollowUp} = 'CustomerTicketZoomFollowUp';

        my $ConfigRef = $ConfigObject->Get( 'Ticket::Frontend::CustomerTicketZoom' )->{FollowUpDynamicField}->{ $Param{Name} };
        if ( !$ConfigRef ) {
            # nothing to do
        }
        elsif ( $ConfigRef eq '1' ) {
            push( @SelectedFrontends, 'CustomerTicketZoomFollowUp' );
        }
        elsif ( $ConfigRef eq '2' ) {
            push( @SelectedFrontends,  'CustomerTicketZoomFollowUp' );
            push( @MandatoryFrontends, 'CustomerTicketZoomFollowUp' );
        }
    }

    # get all frontend modules with dynamic field config
    for my $Item ( keys( %ConfigHash ) ) {
        my $ItemConfig = $ConfigObject->Get( 'Ticket::Frontend::' . $Item );

        # if dynamic field config not exists try admin and agent frontend for other modules
        # integration of CustomerUserDynamicField and CustomerCompanyDynamicField
        if (
            !defined( $ItemConfig )
            || !defined( $ItemConfig->{DynamicField} )
        ) {
            for my $Frontend ( qw(Admin Agent) ) {
                $ItemConfig = $ConfigObject->Get( $Frontend . '::Frontend::' . $Item );
                last if (
                    defined( $ItemConfig )
                    && defined( $ItemConfig->{DynamicField} )
                );
            }
        }

        # next if no config found
        next if (
            !defined( $ItemConfig )
            || !defined( $ItemConfig->{DynamicField} )
        );

        # add available frontend
        $AvailableFrontends{ $Item } = $Item;

        # next if not selected
        next if ( !$ItemConfig->{DynamicField}->{ $Param{Name} } );

        # add seleclted frontend
        push( @SelectedFrontends, $Item );

        # next if not mandatory
        next if ( $ItemConfig->{DynamicField}->{ $Param{Name} } ne '2' );

        # add mandatory frontend
        push( @MandatoryFrontends, $Item );
    }

    # return result
    $Result{AvailableFrontends} = \%AvailableFrontends;
    $Result{SelectedFrontends}  = \@SelectedFrontends;
    $Result{MandatoryFrontends} = \@MandatoryFrontends;

    return %Result;
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
