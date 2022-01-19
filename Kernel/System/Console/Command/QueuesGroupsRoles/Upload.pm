# --
# Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::QueuesGroupsRoles::Upload;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::System::QueuesGroupsRoles',
);
use utf8;

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Upload of KIX queues-groups-roles schema from CSV-file');
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
    $Self->Print("<yellow>Uploading queues-groups-roles schema from CSV-file...</yellow>\n");
    my $QGRObject = $Kernel::OM->Get('Kernel::System::QueuesGroupsRoles');

    my $CSV;
    my $FileName = $Self->GetArgument('filename');
    my @Content;

    #-------------------------------------------------------------------------------
    # check CSV...
    open( $CSV, "<", $FileName ) or die "\nCould not open file: <$FileName> ($!).\n";

    #-------------------------------------------------------------------------------
    # process CSV...
    $Self->_ReadContent(
        FileHandle => $CSV,
        Content    => \@Content,
    );
    close( $CSV );

    my $Result = $QGRObject->Upload(
        MessageToSTDERR => 1,
        Content         => \@Content
    );
    if ($Result) {
        $Self->Print("<green>Import done!<$FileName>.</green>\n");
    }
    else {
        $Self->Print("<red>Import failed!<$FileName>.</red>\n");
    }
    $Self->Print("<green>Done.</green>\n");
    return $Self->ExitCodeOk();
}

sub _ReadContent {
    my ( $Self, %Param ) = @_;

    while (<$Param{FileHandle}>) {
        chomp($_);
        my $currLine = $_;
        utf8::decode($currLine);
        $currLine =~ s/"//g;
        push( @{$Param{Content}}, $currLine )
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
