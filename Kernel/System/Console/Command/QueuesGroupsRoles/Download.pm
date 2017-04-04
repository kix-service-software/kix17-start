# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::QueuesGroupsRoles::Download;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::System::QueuesGroupsRoles',

);
use utf8;

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Download of KIX queues-groups-roles schema into CSV-file');
    my @HeadlineKeys = qw{
        SalutationID SignatureID FollowUpID FollowUpLock UnlockTimeout
        FirstResponseTime FirstResponseNotify UpdateTime UpdateNotify
        SolutionTime SolutionNotify Calendar Validity SystemAddress
    };
    $Self->AddArgument(
        Name => 'filename',
        Description =>
            "/path/to/QGRdescription.csv\n"
            . " CSV-file must be semicolon separated, needs UTF8 encoding and has to be in a format like:\n"
            . "   QCRCSV-FILE     ::= <HEADLINE> <DESC_LINE>\n"
            . "   <HEADLINE>      ::= <QUEUE> <QUEUE_PARAMS> <GROUP> n*{<ROLEn_NAME>}\n"
            . "   <DESC_LINE>     ::= {<QUEUE_NAME>; <GROUP_NAME>; n*{<ROLEn_RIGHTS>} }\n"
            . "   <ROLE_RIGHTS>   ::= RO,MO,CR,OW,PR,NO,RW,\n"
            . "   <GROUP_NAME>    ::= {(<Alphanum>)}\n"
            . "   <QUEUE_NAME>    ::= {<Alphanum>}\n"
            . "   <QUEUE_PARAMS>  ::= {" . join( ";", @HeadlineKeys ) . "}\n"
            . "   <SystemAddress> ::= {<SystemAddressID>||<Emailstring>}\n"
            . "   <Validity>      ::= {<ValidID>||<valid>||<invalid>||<invalid-temporarily>}\n"
            . "   <ROLEn_NAME>    ::= {<Alphanum>}\n\n"
            . " NOTE: Headlines which do not denote a role name are not used."
            . " The order of the columns is important!\n\n",
        Required   => 1,
        ValueRegex => qr/.*/smx,
    );
    return;
}

sub Run {
    my ( $Self, %Param ) = @_;
    $Self->Print("<yellow>Downloading queues-groups-roles schema into CSV-file...</yellow>\n");
    my $QGRObject = $Kernel::OM->Get('Kernel::System::QueuesGroupsRoles');

    my $currLine = undef;
    my $CSV;
    my $FileName = $Self->GetArgument('filename');

    #-------------------------------------------------------------------------------
    # check CSV...
    if ( !open( $CSV, "<", $FileName ) ) {
        die "\nCould not open file: <$FileName> ($!).\n";
    }

    #-------------------------------------------------------------------------------
    # process CSV...
    my @Result = $QGRObject->QGRShow();
    my @Head   = @{ $Result[0] };
    my @Data   = @{ $Result[1] };

    my $Result = $QGRObject->Download(
        Head => \@Head,
        Data => \@Data,
    );

    my $OutputFile = $Kernel::OM->Get('Kernel::System::Main')->FileWrite(
        Location   => $FileName,
        Content    => \$Result,
        Mode       => 'utf8',
        Type       => 'Local',
        Permission => '644',
    );
    if ($OutputFile) {
        $Self->Print("<green>Export written to <$OutputFile>.</green>\n");
    }
    else {
        $Self->Print("<red>Could not write export to <$FileName>.</red>\n");
    }
    $Self->Print("<green>Done.</green>\n");
    return $Self->ExitCodeOk();
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
