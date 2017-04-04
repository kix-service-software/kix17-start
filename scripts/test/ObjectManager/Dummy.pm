# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package scripts::test::ObjectManager::Dummy;    ## no critic

use strict;
use warnings;

## nofilter(TidyAll::Plugin::OTRS::Perl::ObjectDependencies)
our @ObjectDependencies = ();                   # we want to use an undeclared dependency for testing

sub new {
    my ( $Class, %Param ) = @_;

    bless \%Param, $Class;
}

sub Data {
    my ($Self) = @_;
    return $Self->{Data};
}

sub DESTROY {

    # Request this object (undeclared dependency) in the desctructor.
    #   This will create it again in the OM to test that ObjectsDiscard will still work.
    $Kernel::OM->Get('scripts::test::ObjectManager::Dummy2');
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
