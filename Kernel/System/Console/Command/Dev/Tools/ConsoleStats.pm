# --
# Modified version of the work: Copyright (C) 2006-2018 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2018 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Dev::Tools::ConsoleStats;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand Kernel::System::Console::Command::List);

our @ObjectDependencies = (
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Print some statistics about available console commands.');

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my @Commands = $Self->ListAllCommands();
    my %OptionsCount;
    my %ArgumentsCount;
    for my $Command (@Commands) {
        my $CommandObject = $Kernel::OM->Get($Command);
        for my $Option ( @{ $CommandObject->{_Options} // [] } ) {
            $OptionsCount{ $Option->{Name} }++;
        }
        for my $Argument ( @{ $CommandObject->{_Arguments} // [] } ) {
            $ArgumentsCount{ $Argument->{Name} }++;
        }
    }
    my $OptionsSort = sub {
        my $ValueResult = $OptionsCount{$b} <=> $OptionsCount{$a};
        return $ValueResult if $ValueResult;
        return $a cmp $b;
    };
    $Self->Print("<yellow>Calculating option frequency...</yellow>\n");
    for my $OptionName ( sort $OptionsSort keys %OptionsCount ) {
        $Self->Print("  $OptionName: <yellow>$OptionsCount{$OptionName}</yellow>\n");
    }

    my $ArgumentsSort = sub {
        my $ValueResult = $ArgumentsCount{$b} <=> $ArgumentsCount{$a};
        return $ValueResult if $ValueResult;
        return $a cmp $b;
    };
    $Self->Print("<yellow>Calculating argument frequency...</yellow>\n");
    for my $ArgumentName ( sort $ArgumentsSort keys %ArgumentsCount ) {
        $Self->Print("  $ArgumentName: <yellow>$ArgumentsCount{$ArgumentName}</yellow>\n");
    }

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
