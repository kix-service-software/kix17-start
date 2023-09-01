# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2023 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::PostMaster::LoopProtection::FS;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Log',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # get config options
    $Self->{LoopProtectionLog} = $ConfigObject->Get('LoopProtectionLog')
        || die 'No Config option "LoopProtectionLog"!';

    $Self->{PostmasterMaxEmails} = $ConfigObject->Get('PostmasterMaxEmails') || 40;

    # create logfile name
    my ( $Sec, $Min, $Hour, $Day, $Month, $Year ) = localtime(time);
    $Year = $Year + 1900;
    $Month++;
    $Self->{LoopProtectionLog} .= '-' . $Year . '-' . $Month . '-' . $Day . '.log';

    return $Self;
}

sub SendEmail {
    my ( $Self, %Param ) = @_;

    my $To = $Param{To} || return;

    # write log
    if ( open( my $Out, '>>', $Self->{LoopProtectionLog} ) ) {
        print $Out "$To;" . localtime() . ";\n";
        close($Out);
    }
    else {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "LoopProtection! Can't write '$Self->{LoopProtectionLog}': $!!",
        );
    }

    return 1;
}

sub Check {
    my ( $Self, %Param ) = @_;

    my $To = $Param{To} || return;
    my $Count = 0;

    # check existing logfile
    if ( open( my $In, '<', $Self->{LoopProtectionLog} ) ) {
        # open old log file
        while (<$In>) {
            my @Data = split( /;/, $_ );
            if ( $Data[0] eq $To ) {
                $Count++;
            }
        }
        close($In);
    }
    else {
        # create new log file
        if ( open( my $Out, '>', $Self->{LoopProtectionLog} ) ) {
            close($Out);
        } else {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "LoopProtection! Can't write '$Self->{LoopProtectionLog}': $!!",
            );
        }
    }

    # check possible loop
    if ( $Count >= $Self->{PostmasterMaxEmails} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'notice',
            Message =>
                "LoopProtection: send no more emails to '$To'! Max. count of $Self->{PostmasterMaxEmails} has been reached!",
        );
        return;
    }

    return 1;
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
