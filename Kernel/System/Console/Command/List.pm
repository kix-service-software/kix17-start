# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::List;

use strict;
use warnings;

use Kernel::System::Console::InterfaceConsole;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Main',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Lists available commands.');
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $ProductName    = $Kernel::OM->Get('Kernel::Config')->Get('ProductName');
    my $ProductVersion = $Kernel::OM->Get('Kernel::Config')->Get('Version');

    my $UsageText = "<green>$ProductName</green> (<yellow>$ProductVersion</yellow>)\n\n";
    $UsageText .= "<yellow>Usage:</yellow>\n";
    $UsageText .= " kix.Console.pl command [options] [arguments]\n";
    $UsageText .= "\n<yellow>Options:</yellow>\n";
    GLOBALOPTION:
    for my $Option ( @{ $Self->{_GlobalOptions} // [] } ) {
        next GLOBALOPTION if $Option->{Invisible};
        my $OptionShort = "[--$Option->{Name}]";
        $UsageText .= sprintf " <green>%-40s</green> - %s", $OptionShort, $Option->{Description} . "\n";
    }
    $UsageText .= "\n<yellow>Available commands:</yellow>\n";

    my $PreviousCommandNameSpace = '';

    COMMAND:
    for my $Command ( $Self->ListAllCommands() ) {

        # KIXCore-capeIT
        if ( $Kernel::OM->Get('Kernel::System::Main')->Require( $Command, Silent => 1 ) ) {

            # EO KIXCore-capeIT

            my $CommandObject = $Kernel::OM->Get($Command);
            my $CommandName   = $CommandObject->Name();

            # Group by toplevel namespace
            my ($CommandNamespace) = $CommandName =~ m/^([^:]+)::/smx;
            $CommandNamespace //= '';
            if ( $CommandNamespace ne $PreviousCommandNameSpace ) {
                $UsageText .= "<yellow>$CommandNamespace</yellow>\n";
                $PreviousCommandNameSpace = $CommandNamespace;
            }
            $UsageText .= sprintf( " <green>%-40s</green> - %s\n",
                $CommandName, $CommandObject->Description() );

            # KIXCore-capeIT
        }

        # EO KIXCore-capeIT
    }

    $Self->Print($UsageText);

    return $Self->ExitCodeOk();
}

# =item ListAllCommands()
#
# returns all available commands, sorted first by directory and then by file name.
#
#     my @Commands = $CommandObject->ListAllCommands();
#
# returns
#
#     (
#         'Kernel::System::Console::Command::Help',
#         'Kernel::System::Console::Command::List',
#         ...
#     )
#
# =cut

sub ListAllCommands {
    my ( $Self, %Param ) = @_;

    # KIXCore-capeIT
    my $Home = $Kernel::OM->Get('Kernel::Config')->Get('Home');

    my @KIXFolders = ( $Home . '/Kernel/System/Console/Command' );
    foreach my $TmpDir (@INC) {
        last if $TmpDir =~ /\/Custom$/;
        my $NewDir = $TmpDir."/Kernel/System/Console/Command";
        next if !( -e $NewDir );
        push @KIXFolders, $NewDir;
    }

    my @CommandFiles = ();
    for my $CommandDirectory (@KIXFolders) {

        # my @CommandFiles = $Kernel::OM->Get('Kernel::System::Main')->DirectoryRead(
        #     Directory => $Kernel::OM->Get('Kernel::Config')->Get('Home') . '/Kernel/System/Console/Command',
        my @CommandFilesTmp = $Kernel::OM->Get('Kernel::System::Main')->DirectoryRead(
            Directory => $CommandDirectory,
            Filter    => '*.pm',
            Recursive => 1,
        );

        @CommandFiles = ( @CommandFiles, @CommandFilesTmp );
    }

    # EO KIXCore-capeIT

    my @Commands;

    COMMAND_FILE:
    for my $CommandFile (@CommandFiles) {
        next COMMAND_FILE if ( $CommandFile =~ m{/Internal/}xms );
        $CommandFile =~ s{^.*(Kernel/System.*)[.]pm$}{$1}xmsg;
        $CommandFile =~ s{/+}{::}xmsg;
        push @Commands, $CommandFile;
    }

    # Sort first by directory, then by File
    my $Sort = sub {
        my ( $DirA, $FileA ) = split( /::(?=[^:]+$)/smx, $a );
        my ( $DirB, $FileB ) = split( /::(?=[^:]+$)/smx, $b );
        return $DirA cmp $DirB || $FileA cmp $FileB;
    };

    @Commands = sort $Sort @Commands;

    return @Commands;
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
