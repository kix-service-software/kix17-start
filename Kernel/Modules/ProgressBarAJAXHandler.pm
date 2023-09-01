# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
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
    } elsif ( $Self->{Subaction} eq 'ProgressAbort' ) {

        my $Count       = 0;
        my @List        = $SchedulerDBObject->TaskList(
            Type => $Param{TaskType},
        );

        for my $Task ( @List ) {
            if ( $Task->{Name} eq $Param{TaskName} ) {
                $SchedulerDBObject->TaskDelete(
                    TaskID => $Task->{TaskID}
                );
            }
        }

        # send JSON response
        return $LayoutObject->Attachment(
            ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
            Content     => 1,
            Type        => 'inline',
            NoCache     => 1,
        );
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
