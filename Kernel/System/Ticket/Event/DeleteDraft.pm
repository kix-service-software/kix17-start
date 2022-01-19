# --
# Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::Event::DeleteDraft;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::System::Web::Request',
    'Kernel::System::Web::UploadCache'
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=item Run()

Run - contains the actions performed by this event handler.

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(Event UserID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => 'Need ' . $Needed . '!',
            );
            return;
        }
    }

    # only handle ArticleCreate events
    if ( $Param{Event} ne 'ArticleCreate' ) {
        return 1;
    }

    # create needed objects
    my $ParamObject       = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $UploadCacheObject = $Kernel::OM->Get('Kernel::System::Web::UploadCache');

    # get needed params
    my $Action   = $ParamObject->GetParam( Param => 'Action' );
    my $TicketID = $ParamObject->GetParam( Param => 'TicketID' ) || 0;

    # check if Action is given
    if ( !$Action ) {
        return 1;
    }

    # the hardcoded unix timestamp 2147483646 is necessary for UploadCache FS backend
    my $FormID = '2147483646.SaveAsDraftAJAXHandler.'
               . $Action . '.'
               . $Param{UserID} . '.'
               . $TicketID;

    # delete draft
    return $UploadCacheObject->FormIDRemove( FormID => $FormID );
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
