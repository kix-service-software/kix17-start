# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::ServiceAssignedQueueAJAXHandler;

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
    my $ServiceObject = $Kernel::OM->Get('Kernel::System::Service');
    my $LayoutObject  = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ParamObject   = $Kernel::OM->Get('Kernel::System::Web::Request');

    for my $Needed (qw(ServiceID)) {
        $Param{$Needed} = $ParamObject->GetParam( Param => $Needed ) || '';
        if ( !$Param{$Needed} ) {
            return $LayoutObject->ErrorScreen( Message => "Need $Needed!", );
        }
    }

    my %ServiceData = $ServiceObject->ServiceGet(
        ServiceID => $Param{ServiceID},
        UserID    => 1,
    );

    my %NewData;
    if ( $ServiceData{AssignedQueueID} ) {
        $NewData{AssignedQueue} = $ServiceData{AssignedQueueID};

        # prepare signature
        my $TemplateGenerator = $Kernel::OM->Get('Kernel::System::TemplateGenerator');
        $NewData{Signature} = $TemplateGenerator->Signature(
            QueueID => $NewData{AssignedQueue},
            Data    => \%Param,
            UserID  => $Self->{UserID},

            # KIX4OTRS-capeIT
            TicketID => $Param{TicketID},

            # EO KIX4OTRS-capeIT
        );

    }

    my $JSONData = $LayoutObject->JSONEncode(
        Data => \%NewData,
    );

    return $LayoutObject->Attachment(
        ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
        Content     => $JSONData,
        Type        => 'inline',
        NoCache     => 1,
    );
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
