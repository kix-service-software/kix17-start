# --
# Modified version of the work: Copyright (C) 2006-2023 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2023 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Admin::Package::GetInstalledVersion;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Cache',
    'Kernel::System::Main',
    'Kernel::System::Package',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Get version of an installed package.');

    $Self->AddOption(
        Name        => 'package-name',
        Description => '(Part of) package name to filter for. Omit to show all installed packages.',
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/,
    );

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my @Packages = $Kernel::OM->Get('Kernel::System::Package')->RepositoryList();

    my $PackageNameOption = $Self->GetOption('package-name');

    # Get package object
    my $PackageObject = $Kernel::OM->Get('Kernel::System::Package');

    PACKAGE:
    for my $Package (sort {$a->{Name}->{Content} cmp $b->{Name}->{Content}} @Packages) {

        if ( defined $PackageNameOption && length $PackageNameOption ) {
            next PACKAGE if $Package->{Name}->{Content} !~ m{^$PackageNameOption$}i;
        }

        my %Data = $Self->_PackageMetadataGet(
            Tag       => $Package->{Description},
            StripHTML => 0,
        );
        $Self->Print($Package->{Name}->{Content}.": ".$Package->{Version}->{Content}."\n");
    }

    return $Self->ExitCodeOk();
}

=item _PackageMetadataGet()

locates information in tags that are language specific.
First, 'en' is looked for, if that is not present, the first found language will be used.

    my %Data = $CommandObject->_PackageMetadataGet(
        Tag       => $Package->{Description},
        StripHTML => 1,         # optional, perform HTML->ASCII conversion (default 1)
    );

    my %Data = $Self->_PackageMetadataGet(
        Tag => $Structure{IntroInstallPost},
        AttributeFilterKey   => 'Type',
        AttributeFilterValue =>  'pre',
    );

Returns the content and the title of the tag in a hash:

    my %Result = (
        Description => '...',   # tag content
        Title       => '...',   # tag title
    );

=cut

sub _PackageMetadataGet {
    my ( $Self, %Param ) = @_;

    return if !ref $Param{Tag};

    my $AttributeFilterKey   = $Param{AttributeFilterKey};
    my $AttributeFilterValue = $Param{AttributeFilterValue};

    my $Title       = '';
    my $Description = '';

    TAG:
    for my $Tag ( @{ $Param{Tag} } ) {
        if ($AttributeFilterKey) {
            if ( lc $Tag->{$AttributeFilterKey} ne lc $AttributeFilterValue ) {
                next TAG;
            }
        }
        if ( !$Description && $Tag->{Lang} && $Tag->{Lang} eq 'en' ) {
            $Description = $Tag->{Content} || '';
            $Title       = $Tag->{Title}   || '';
        }
    }
    if ( !$Description ) {
        TAG:
        for my $Tag ( @{ $Param{Tag} } ) {
            if ($AttributeFilterKey) {
                if ( lc $Tag->{$AttributeFilterKey} ne lc $AttributeFilterValue ) {
                    next TAG;
                }
            }
            if ( !$Description ) {
                $Description = $Tag->{Content} || '';
                $Title       = $Tag->{Title}   || '';
            }
        }
    }

    if ( !defined $Param{StripHTML} || $Param{StripHTML} ) {
        $Title =~ s/(.{4,78})(?:\s|\z)/| $1\n/gm;
        $Description =~ s/^\s*//mg;
        $Description =~ s/\n/ /gs;
        $Description =~ s/\r/ /gs;
        $Description =~ s/\<style.+?\>.*\<\/style\>//gsi;
        $Description =~ s/\<br(\/|)\>/\n/gsi;
        $Description =~ s/\<(hr|hr.+?)\>/\n\n/gsi;
        $Description =~ s/\<(\/|)(pre|pre.+?|p|p.+?|table|table.+?|code|code.+?)\>/\n\n/gsi;
        $Description =~ s/\<(tr|tr.+?|th|th.+?)\>/\n\n/gsi;
        $Description =~ s/\.+?<\/(td|td.+?)\>/ /gsi;
        $Description =~ s/\<.+?\>//gs;
        $Description =~ s/  / /mg;
        $Description =~ s/&amp;/&/g;
        $Description =~ s/&lt;/</g;
        $Description =~ s/&gt;/>/g;
        $Description =~ s/&quot;/"/g;
        $Description =~ s/&nbsp;/ /g;
        $Description =~ s/^\s*\n\s*\n/\n/mg;
        $Description =~ s/(.{4,78})(?:\s|\z)/| $1\n/gm;
    }
    return (
        Description => $Description,
        Title       => $Title,
    );
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
