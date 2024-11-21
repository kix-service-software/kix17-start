# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2024 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::CustomerAccept;

use strict;
use warnings;

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    $Self->{InfoKey}  = $ConfigObject->Get('CustomerPanel::InfoKey');
    $Self->{InfoFile} = $ConfigObject->Get('CustomerPanel::InfoFile');

    return $Self;
}

sub PreRun {
    my ( $Self, %Param ) = @_;

    my $Output;
    if ( !$Self->{RequestedURL} ) {
        $Self->{RequestedURL} = 'Action=';
    }

    my $Panels = $Kernel::OM->Get('Kernel::Config')->Get('CustomerPanelPreApplicationModule');

    return if $Self->{ $Self->{InfoKey} };
    return if $Panels->{$Self->{Action}} || $Self->{'Action'} eq 'CustomerAccept';

    # remove requested url from session storage
    $Kernel::OM->Get('Kernel::System::AuthSession')->UpdateSessionID(
        SessionID => $Self->{SessionID},
        Key       => 'UserRequestedURL',
        Value     => $Self->{RequestedURL},
    );

    return $Kernel::OM->Get('Kernel::Output::HTML::Layout')->Redirect( OP => 'Action=CustomerAccept' );
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $Output;
    if ( !$Self->{RequestedURL} ) {
        $Self->{RequestedURL} = 'Action=';
    }
    my $Accept        = $Kernel::OM->Get('Kernel::System::Web::Request')->GetParam( Param => 'Accept' ) || '';
    my $LayoutObject  = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $SessionObject = $Kernel::OM->Get('Kernel::System::AuthSession');

    if ( $Self->{ $Self->{InfoKey} } ) {

        # remove requested url from session storage
        $SessionObject->UpdateSessionID(
            SessionID => $Self->{SessionID},
            Key       => 'UserRequestedURL',
            Value     => '',
        );

        # redirect
        return $LayoutObject->Redirect( OP => "$Self->{UserRequestedURL}" );
    }
    elsif ($Accept) {

        # set session
        $SessionObject->UpdateSessionID(
            SessionID => $Self->{SessionID},
            Key       => $Self->{InfoKey},
            Value     => 1,
        );

        # set preferences
        $Kernel::OM->Get('Kernel::System::CustomerUser')->SetPreferences(
            UserID => $Self->{UserID},
            Key    => $Self->{InfoKey},
            Value  => 1,
        );

        # remove requested url from session storage
        $SessionObject->UpdateSessionID(
            SessionID => $Self->{SessionID},
            Key       => 'UserRequestedURL',
            Value     => '',
        );

        # redirect
        return $LayoutObject->Redirect( OP => "$Self->{RequestedURL}" );
    }
    else {

        # show info
        $Output = $LayoutObject->CustomerHeader(
            NoSystemMessage => 1
        );
        $Output
            .= $LayoutObject->Output(
            TemplateFile => $Self->{InfoFile},
            Data         => \%Param
            );
        $Output .= $LayoutObject->CustomerFooter();
        return $Output;
    }
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
