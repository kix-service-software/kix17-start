# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::ProgressBarAJAXHandler;

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

    # get needed objects
    my $LayoutObject        = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ParamObject         = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $JSONObject          = $Kernel::OM->Get('Kernel::System::JSON');
    my $SchedulerDBObject   = $Kernel::OM->Get('Kernel::System::Daemon::SchedulerDB');

    my $Result;

    for my $Parameter ( qw(TaskType TaskName) ) {
        $Param{$Parameter} = $ParamObject->GetParam( Param => $Parameter );
    }

    if ( $Self->{Subaction} eq 'AJAXUpdate' ) {

        my $Count       = 0;
        my @List        = $SchedulerDBObject->TaskList(
            Type => $Param{TaskType},
        );

        for my $Task ( @List ) {
            if ( $Task->{Name} eq $Param{TaskName} ) {
                $Count++;
            }
        }

        my $JSON = $LayoutObject->JSONEncode(
            Data => {
                Count    => $Count,
            }
        );

        # send JSON response
        return $LayoutObject->Attachment(
            ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
            Content     => $JSON || '',
            Type        => 'inline',
            NoCache     => 1,
        );
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
