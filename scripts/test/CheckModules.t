# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

# get needed objects
my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

my $Home = $ConfigObject->Get('Home');
my $TmpSumString;

#rbo - T2016121190001552 - renamed OTRS to KIX
if ( open( $TmpSumString, '-|', "$^X $Home/bin/kix.CheckModules.pl --all NoColors" ) )
{    ## no critic

    LINE:
    while (<$TmpSumString>) {
        my $TmpLine = $_;
        $TmpLine =~ s/\n//g;
        next LINE if !$TmpLine;
        next LINE if $TmpLine !~ /^\s*o\s\w\w/;
        if ( $TmpLine =~ m{ok|optional}ismx ) {
            $Self->True(
                $TmpLine,
                "$TmpLine",
            );
        }
        else {
            $Self->False(
                $TmpLine,
                "Error in your installed perl modules: $TmpLine",
            );
        }
    }
    close($TmpSumString);

}
else {
    $Self->False(
        1,
        'Unable to check Perl modules',
    );
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
