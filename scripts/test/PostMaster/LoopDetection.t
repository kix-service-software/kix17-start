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

use Kernel::System::PostMaster;

# get helper object
$Kernel::OM->ObjectParamAdd(
    'Kernel::System::UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');

# This test checks if OTRS correctly detects that an email must not be auto-responded to.
my @Tests = (
    {
        Name => 'Regular mail',
        Email =>
            'From: test@home.com
To: test@home.com
Subject: Testmail

Body
',
        EmailParams => {
            From          => 'test@home.com',
#rbo - T2016121190001552 - renamed X-KIX headers
            'X-KIX-Loop' => '',
        },
    },
    {
        Name => 'Precedence',
        Email =>
            'From: test@home.com
To: test@home.com
Precedence: bulk
Subject: Testmail

Body
',
        EmailParams => {
            From          => 'test@home.com',
#rbo - T2016121190001552 - renamed X-KIX headers
            'X-KIX-Loop' => 'yes',
        },
    },
    {
        Name => 'X-Loop',
        Email =>
            'From: test@home.com
To: test@home.com
X-Loop: yes
Subject: Testmail

Body
',
        EmailParams => {
            From          => 'test@home.com',
#rbo - T2016121190001552 - renamed X-KIX headers
            'X-KIX-Loop' => 'yes',
        },
    },
    {
        Name => 'X-No-Loop',
        Email =>
            'From: test@home.com
To: test@home.com
X-No-Loop: yes
Subject: Testmail

Body
',
        EmailParams => {
            From          => 'test@home.com',
#rbo - T2016121190001552 - renamed X-KIX headers
            'X-KIX-Loop' => 'yes',
        },
    },
    {
        Name => 'X-KIX-Loop',
        Email =>
            'From: test@home.com
To: test@home.com
X-KIX-Loop: yes
Subject: Testmail

Body
',
        EmailParams => {
            From          => 'test@home.com',
#rbo - T2016121190001552 - renamed X-KIX headers
            'X-KIX-Loop' => 'yes',
        },
    },
    {
        Name => 'Auto-submitted: auto-generated',
        Email =>
            'From: test@home.com
To: test@home.com
Auto-submitted: auto-generated
Subject: Testmail

Body
',
        EmailParams => {
            From          => 'test@home.com',
#rbo - T2016121190001552 - renamed X-KIX headers
            'X-KIX-Loop' => 'yes',
        },
    },
    {
        Name => 'Auto-Submitted: auto-replied',
        Email =>
            'From: test@home.com
To: test@home.com
Auto-Submitted: auto-replied
Subject: Testmail

Body
',
        EmailParams => {
            From          => 'test@home.com',
#rbo - T2016121190001552 - renamed X-KIX headers
            'X-KIX-Loop' => 'yes',
        },
    },
    {
        Name => 'Auto-submitted: no',
        Email =>
            'From: test@home.com
To: test@home.com
Auto-submitted: no
Subject: Testmail

Body
',
        EmailParams => {
            From          => 'test@home.com',
#rbo - T2016121190001552 - renamed X-KIX headers
            'X-KIX-Loop' => '',
        },
    },
);

for my $Test (@Tests) {

    my @Email = split( /\n/, $Test->{Email} );

    my $PostMasterObject = Kernel::System::PostMaster->new(
        Email => \@Email,
    );

    my $EmailParams = $PostMasterObject->GetEmailParams();

    for my $EmailParam ( sort keys %{ $Test->{EmailParams} } ) {
        $Self->Is(
            $EmailParams->{$EmailParam},
            $Test->{EmailParams}->{$EmailParam},
            "$Test->{Name} - $EmailParam",
        );
    }
}

# cleanup cache is done by RestoreDatabase

1;


=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
