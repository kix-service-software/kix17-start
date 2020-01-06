# --
# Modified version of the work: Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2020 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Internal::BashCompletion;

use strict;
use warnings;

use Kernel::System::Console::InterfaceConsole;

use base qw(Kernel::System::Console::BaseCommand Kernel::System::Console::Command::List);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Main',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Handles bash autocompletion.');

    $Self->AddArgument(
        Name        => 'command',
        Description => ".",
        Required    => 0,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddArgument(
        Name        => 'current-word',
        Description => ".",
        Required    => 0,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddArgument(
        Name        => 'previous-word',
        Description => ".",
        Required    => 0,
        ValueRegex  => qr/.*/smx,
    );
    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $CurrentWord  = $Self->GetArgument('current-word');
    my $PreviousWord = $Self->GetArgument('previous-word');

    # We are looking for the command name
    if ( $PreviousWord =~ m/kix\.Console\.pl/xms ) {

        # Get all matching commands
        my @CommandList = $Self->ListAllCommands();
        for my $Command ( @CommandList ) {
            $Command =~ s/^Kernel::System::Console::Command:://xms;
        }
        if ($CurrentWord) {
            @CommandList = grep { $_ =~ m/\Q$CurrentWord\E/xms } @CommandList;
        }
        print join( "\n", @CommandList );
    }

    # We are looking for an option/argument
    else {
        # We need to extract the command name from the command line if present.
        my $CompLine = $ENV{COMP_LINE};
        if ( !$CompLine || !$CompLine =~ m/kix\.Console\.pl/ ) {
            $Self->ExitCodeError()
        }
        $CompLine =~ s/.*kix\.Console\.pl\s*//xms;
        my @Elements = split( m/\s+/, $CompLine );

        # Try to create the command object to get its options
        my $CommandName = $Elements[0];
        my $CommandPath = 'Kernel::System::Console::Command::' . $CommandName;
        if ( !$Kernel::OM->Get('Kernel::System::Main')->Require( $CommandPath, Silent => 1 ) ) {
            return $Self->ExitCodeOk();
        }
        my $Command = $Kernel::OM->Get($CommandPath);
        my @Options = @{ $Command->{_Options} // [] };

        # Select matching options
        @Options = map { '--' . $_->{Name} } @Options;
        if ($CurrentWord) {
            @Options = grep { $_ =~ m/\Q$CurrentWord\E/xms } @Options;
        }

        # Hide options that are already on the commandline
        @Options = grep { $CompLine !~ m/(?:^|\s)\Q$_\E(?:\s|=|$)/xms } @Options;

        print join( "\n", @Options );
    }

    return $Self->ExitCodeOk();

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
