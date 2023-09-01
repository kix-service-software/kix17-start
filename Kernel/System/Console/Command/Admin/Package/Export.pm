# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2023 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Admin::Package::Export;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::System::Main',
    'Kernel::System::Package',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Export the contents of an KIX package to a directory.');
    $Self->AddOption(
        Name        => 'target-directory',
        Description => "Export contents of the package to the specified directory.",
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddArgument(
        Name        => 'source-path',
        Description => "Specify the path to an KIX package (opm) file that should be exported.",
        Required    => 1,
        ValueRegex  => qr/.*/smx,
    );

    return;
}

sub PreRun {
    my ( $Self, %Param ) = @_;

    my $SourcePath = $Self->GetArgument('source-path');
    if ( $SourcePath && !-r $SourcePath ) {
        die "File $SourcePath does not exist / can not be read.\n";
    }

    my $TargetDirectory = $Self->GetOption('target-directory');
    if ( $TargetDirectory && !-d $TargetDirectory ) {
        die "Directory $TargetDirectory does not exist.\n";
    }

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Exporting package contents...</yellow>\n");

    my $SourcePath = $Self->GetArgument('source-path');

    my $FileString;
    my $ContentRef = $Kernel::OM->Get('Kernel::System::Main')->FileRead(
        Location => $SourcePath,
        Mode     => 'utf8',        # optional - binmode|utf8
        Result   => 'SCALAR',      # optional - SCALAR|ARRAY
    );
    if ( !$ContentRef || ref $ContentRef ne 'SCALAR' ) {
        $Self->PrintError("File $SourcePath is empty / could not be read.");
        return $Self->ExitCodeError();
    }
    $FileString = ${$ContentRef};

    my %Structure = $Kernel::OM->Get('Kernel::System::Package')->PackageParse(
        String => $FileString,
    );

    # just export files if PackageIsDownloadable flag is enable
    if (
        defined $Structure{PackageIsDownloadable}
        && !$Structure{PackageIsDownloadable}->{Content}
    ) {
        $Self->PrintError("Files cannot be exported.\n");
        return $Self->ExitCodeError();
    }

    my $TargetDirectory = $Self->GetOption('target-directory');
    my $Success         = $Kernel::OM->Get('Kernel::System::Package')->PackageExport(
        String => $FileString,
        Home   => $TargetDirectory,
    );

    if ($Success) {
        $Self->Print("<green>Exported files of package $SourcePath to $TargetDirectory.</green>\n");
        return $Self->ExitCodeOk();
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
