# --
# Copyright (C) 2006-2021 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AgentITSMConfigItemLinkGraphWindow;

use strict;
use warnings;

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    # create needed objects
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # get config of frontend module
    %{$Self->{Config}} = (
        %{$ConfigObject->Get("ITSMConfigItem::Frontend::AgentITSMConfigItemZoomTabLinkGraph")},
        %{$ConfigObject->Get("Frontend::Agent::AgentLinkGraphITSMConfigItem")}
    );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # create needed objects
    my $ConfigObject         = $Kernel::OM->Get('Kernel::Config');
    my $LayoutObject         = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ConfigItemObject     = $Kernel::OM->Get('Kernel::System::ITSMConfigItem');
    my $SessionObject        = $Kernel::OM->Get('Kernel::System::AuthSession');
    my $ParamObject          = $Kernel::OM->Get('Kernel::System::Web::Request');

    # get params
    my %GetParam = ();
    for my $Param ( qw(ConfigItemID Template) ) {
        $GetParam{$Param} = $ParamObject->GetParam( Param => $Param ) || '';
    }

    # check needed stuff
    if ( !$GetParam{ConfigItemID} ) {
        return $LayoutObject->ErrorScreen(
            Message => 'No ConfigItemID is given!',
            Comment => 'Please contact the admin.',
        );
    }

    $SessionObject->UpdateSessionID(
        SessionID => $Self->{SessionID},
        Key       => 'LastScreenView',
        Value     => $Self->{RequestedURL},
    );

    # check for access rights
    my $HasAccess = $ConfigItemObject->Permission(
        Scope  => 'Item',
        ItemID => $GetParam{ConfigItemID},
        UserID => $Self->{UserID},
        Type   => $Self->{Config}->{Permission},
    );
    if ( !$HasAccess ) {

        # error page
        return $LayoutObject->ErrorScreen(
            Message => 'Can\'t show item, no access rights for ConfigItem are given!',
            Comment => 'Please contact the admin.',
        );
    }

    #---------------------------------------------------------------------------
    # generate output...
    my $Output = $LayoutObject->Header( Type => 'Small' );
    $Output .= $LayoutObject->Output(
        TemplateFile => 'AgentITSMConfigItemLinkGraphWindow',
        Data         => {
            %{ $Self->{Config}->{IFrameConfig} },
            %GetParam,
            ObjectType => 'ITSMConfigItem',
        },
    );
    $Output .= $LayoutObject->Footer( Type => 'Small' );
    return $Output;
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
