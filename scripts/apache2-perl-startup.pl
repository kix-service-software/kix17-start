#!/usr/bin/perl
# --
# Modified version of the work: Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2019 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;

# Make sure we are in a sane environment.
$ENV{MOD_PERL} =~ /mod_perl/ || die "MOD_PERL not used!";

BEGIN {

    # switch to unload_package_xs, the PP version is broken in Perl 5.10.1.
    # see http://rt.perl.org/rt3//Public/Bug/Display.html?id=72866
    $ModPerl::Util::DEFAULT_UNLOAD_METHOD = 'unload_package_xs';    ## no critic

    # set $0 to index.pl if it is not an existing file:
    # on Fedora, $0 is not a path which would break OTRS.
    # see bug # 8533
    if ( !-e $0 ) {
        $0 = '/opt/otrs/bin/cgi-bin/index.pl';
    }
}

use Apache2::RequestRec;
use ModPerl::Util;

use lib "/opt/otrs/";
use lib "/opt/otrs/Kernel/cpan-lib";
use lib "/opt/otrs/Custom";

# Preload frequently used modules to speed up client spawning.
use CGI ();
CGI->compile(':cgi');
use CGI::Carp ();

use Apache::DBI;

# enable this if you use mysql
#use DBD::mysql ();
#use Kernel::System::DB::mysql;

# enable this if you use postgresql
#use DBD::Pg ();
#use Kernel::System::DB::postgresql;

# enable this if you use oracle
#use DBD::Oracle ();
#use Kernel::System::DB::oracle;

# preload Net::DNS if it is installed. It is important to preload Net::DNS because otherwise it
# can be that loading of Net::DNS tooks more than 30 seconds.
eval { require Net::DNS };

use Encode qw(:all);

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
