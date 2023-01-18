# --
# Copyright (C) 2006-2023 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::BulkTextModuleAJAXHandler;

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
    my $TextModuleObject = $Kernel::OM->Get('Kernel::System::TextModule');
    my $LayoutObject     = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ParamObject      = $Kernel::OM->Get('Kernel::System::Web::Request');

    my $Result;

    for my $Needed (qw(Subaction)) {
        $Param{$Needed} = $ParamObject->GetParam( Param => $Needed ) || '';
        if ( !$Param{$Needed} ) {
            return $LayoutObject->ErrorScreen( Message => "Need $Needed!", );
        }
    }

    if ( $Param{Subaction} eq 'LoadTextModules' ) {

        $Result = $LayoutObject->ShowAllBulkTextModules(
            UserLastname   => $Self->{UserLastname},
            UserFirstname  => $Self->{UserFirstname},
            Agent          => '1',
            UserID         => $Self->{UserID},
        );
    }
    elsif ( $Param{Subaction} eq 'LoadTextModule' ) {

        # get params
        my $ID = $ParamObject->GetParam( Param => 'ID' ) || '';

        # load TextModule
        my %TextModule = $TextModuleObject->TextModuleGet(
            ID => $ID,
        );

        # build JSON output
        $Result = $LayoutObject->JSONEncode(
            Data => {
                %TextModule,
            },
        );
    }

    return $LayoutObject->Attachment(
        ContentType => 'text/plain; charset=' . $LayoutObject->{Charset},
        Content     => $Result || "<br/>",
        Type        => 'inline',
        NoCache     => 1,
    );
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
