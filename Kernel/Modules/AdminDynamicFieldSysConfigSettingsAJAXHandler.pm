# --
# Kernel/Modules/AdminDynamicFieldSysConfigSettingsAJAXHandler.pm - save frontend settings for dynamic fields
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Dorothea(dot)Doerffel(at)cape(dash)it(dot)de
# --
# $Id$
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AdminDynamicFieldSysConfigSettingsAJAXHandler;

use strict;
use warnings;

our $ObjectManagerDisabled = 1;

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
    my $LogObject       = $Kernel::OM->Get('Kernel::System::Log');
    my $SysConfigObject = $Kernel::OM->Get('Kernel::System::SysConfig');
    my $LayoutObject    = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ParamObject     = $Kernel::OM->Get('Kernel::System::Web::Request');

    # get data
    my $Name = $ParamObject->GetParam( Param => 'Name' );
    if ( !defined $Name || !$Name ) {
        $LogObject->Log( Priority => 'error', Message => "Need DynamicField Name!" );
        return;
    }

    my @SelectedFrontends = $ParamObject->GetArray( Param => 'AvailableFrontends' );
    my @Mandatory         = $ParamObject->GetArray( Param => 'MandatoryFrontends' );

    # get available frontends - necessary to disable dynamic field in not selected frontends
    my %Result = $Self->_GetAllAvailableFrontendModules( Name => $Name );
    my %AvailableFrontends = %{ $Result{AvailableFrontends} };

    for my $Frontend ( keys %AvailableFrontends ) {

        # get all set attributes for this frontend
        my %ItemHash;
        if ( $Frontend eq 'CustomerTicketZoomFollowUp' ) {
            %ItemHash = $SysConfigObject
                ->ConfigItemGet(
                Name => 'Ticket::Frontend::CustomerTicketZoom###FollowUpDynamicField' );
        }
        else {
            %ItemHash = $SysConfigObject
                ->ConfigItemGet( Name => 'Ticket::Frontend::' . $Frontend . '###DynamicField' );
        }

        # create hash from old values
        my %Content;
        for my $Item ( @{ $ItemHash{Setting}->[1]->{Hash}->[1]->{Item} } ) {
            next if !defined $Item->{Key};
            $Content{ $Item->{Key} } = $Item->{Content};
        }

        # disable dynamic field
        $Content{$Name} = 0;

        # enable if selected
        if ( grep { $_ eq $Frontend } @SelectedFrontends ) {
            $Content{$Name} = 1;

            # set to value = 2 if mandatory
            if ( grep { $_ eq $Frontend } @Mandatory ) {
                $Content{$Name} = 2;
            }
        }

        # update sysconfig settings
        my $Update = 0;
        if ( $Frontend eq 'CustomerTicketZoomFollowUp' ) {
            $Update = $SysConfigObject->ConfigItemUpdate(
                Key   => 'Ticket::Frontend::CustomerTicketZoom###FollowUpDynamicField',
                Value => \%Content,
                Valid => 1,
            );
        }
        else {
            $Update = $SysConfigObject->ConfigItemUpdate(
                Key   => 'Ticket::Frontend::' . $Frontend . '###DynamicField',
                Value => \%Content,
                Valid => 1,
            );
        }

        if ( !$Update ) {
            $LayoutObject->FatalError( Message => "Can't write ConfigItem!" );
        }
    }

    # submit config changes
    $SysConfigObject->CreateConfig();

    # if running under PerlEx, reload the application (and thus the configuration)
    if (
        exists $ENV{'GATEWAY_INTERFACE'}
        && $ENV{'GATEWAY_INTERFACE'} eq "CGI-PerlEx"
        )
    {
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
    my %ConfigHash = ( %{$ConfigHashAgent}, %{$ConfigHashCustomer} );

    # get all tabs
    my $ConfigHashTabs = $ConfigObject->Get('AgentTicketZoomBackend');
    for my $Item ( keys %{$ConfigHashTabs} ) {

        # if no link is given
        next if !defined $ConfigHashTabs->{$Item}->{Link};

        # look for PretendAction
        $ConfigHashTabs->{$Item}->{Link} =~ /^(.*?)\;PretendAction=(.*?)\;(.*)$/;
        next if ( !$2 || $ConfigHash{$2} );

     # if given and not already registered as frontend module - add width empty value to config hash
        $ConfigHash{$2} = '';
    }

    # ticket overview - add width empty value to config hash
    $ConfigHash{'OverviewCustom'}  = '';
    $ConfigHash{'OverviewSmall'}   = '';
    $ConfigHash{'OverviewMedium'}  = '';
    $ConfigHash{'OverviewPreview'} = '';

    # KIXSidebars - add width empty value to config hash
    foreach my $Frontend (qw(Frontend CustomerFrontend)) {
        my $SidebarConfig
            = $ConfigObject->Get( $Frontend . '::KIXSidebarBackend' );
        if ( $SidebarConfig && ref($SidebarConfig) eq 'HASH' ) {
            foreach my $Key ( sort keys %{$SidebarConfig} ) {
                my $SidebarBackendConfig = $ConfigObject
                    ->Get( 'Ticket::Frontend::KIXSidebar' . $Key );
                if ( exists( $SidebarBackendConfig->{DynamicField} ) ) {
                    $ConfigHash{ 'KIXSidebar' . $Key } = '';
                }
            }
        }
    }

    my %AvailableFrontends;
    my @SelectedFrontends  = ();
    my @MandatoryFrontends = ();

    $AvailableFrontends{CustomerTicketZoomFollowUp} = 'CustomerTicketZoomFollowUp';

    # get all frontend modules with dynamic field config
    for my $Item ( keys %ConfigHash ) {
        my $ItemConfig = $ConfigObject->Get( "Ticket::Frontend::" . $Item );

        # if dynamic field config exists
        next if !( defined $ItemConfig && defined $ItemConfig->{DynamicField} );
        $AvailableFrontends{$Item} = $Item;

        # if dynamic field is activated
        # for CustomerTicketZoom check also FollowUpDynamicFields
        if ( $Item eq 'CustomerTicketZoom'
            && defined $ItemConfig->{FollowUpDynamicField}->{ $Param{Name} } )
        {
            if ( $ItemConfig->{FollowUpDynamicField}->{ $Param{Name} } eq '1' ) {
                push @SelectedFrontends, 'CustomerTicketZoomFollowUp';
            }
            elsif ( $ItemConfig->{FollowUpDynamicField}->{ $Param{Name} } eq '2' ) {
                push @SelectedFrontends,  'CustomerTicketZoomFollowUp';
                push @MandatoryFrontends, 'CustomerTicketZoomFollowUp';
            }
        }

        # if dynamic field is activated
        next
            if (
            !defined $ItemConfig->{DynamicField}->{ $Param{Name} }
            || $ItemConfig->{DynamicField}->{ $Param{Name} } eq '0'
            );
        push @SelectedFrontends, $Item;

        # if dynamic field is mandatory
        next if $ItemConfig->{DynamicField}->{ $Param{Name} } ne '2';
        push @MandatoryFrontends, $Item;
    }

    # return result
    $Result{AvailableFrontends} = \%AvailableFrontends;
    $Result{SelectedFrontends}  = \@SelectedFrontends;
    $Result{MandatoryFrontends} = \@MandatoryFrontends;

    return %Result;
}

1;
