# --
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Rene(dot)Boehm(at)cape(dash)it(dot)de
#
# --
# $Id$
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see http://www.gnu.org/licenses/gpl-2.0.txt.
# --
package Kernel::Language::en_KIXBase;

use strict;
use warnings;
use utf8;

use vars qw($VERSION);
$VERSION = qw($Revision$) [1];

# --
sub Data {
    my $Self = shift;

    my $Lang = $Self->{Translation};

    return if ref $Lang ne 'HASH';

    # $$START$$

    $Lang->{'Print Richtext'} = 'HTML Print';
    $Lang->{'Print Standard'} = 'PDF Print';

    # $$STOP$$

    return 0;
}

1;
