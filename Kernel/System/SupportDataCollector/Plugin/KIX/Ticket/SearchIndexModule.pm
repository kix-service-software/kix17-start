# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::SupportDataCollector::Plugin::KIX::Ticket::SearchIndexModule;

use strict;
use warnings;

use base qw(Kernel::System::SupportDataCollector::PluginBase);

use Kernel::Language qw(Translatable);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::DB',
);

sub GetDisplayPath {
    return Translatable('KIX');
}

sub Run {
    my $Self = shift;

    my $Module = $Kernel::OM->Get('Kernel::Config')->Get('Ticket::SearchIndexModule');

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    my $ArticleCount;
    $DBObject->Prepare( SQL => 'SELECT count(*) FROM article' );

    while ( my @Row = $DBObject->FetchrowArray() ) {
        $ArticleCount = $Row[0];
    }

    if ( $ArticleCount > 50_000 && $Module =~ /RuntimeDB/ ) {
        $Self->AddResultWarning(
            Label => Translatable('Ticket Search Index Module'),
            Value => $Module,
            Message =>
                Translatable(
                'You have more than 50,000 articles and should use the StaticDB backend. See admin manual (Performance Tuning) for more information.'
                ),
        );
    }
    else {
        $Self->AddResultOk(
            Label => Translatable('Ticket Search Index Module'),
            Value => $Module,
        );
    }

    return $Self->GetResults();
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
