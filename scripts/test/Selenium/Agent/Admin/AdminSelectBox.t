# --
# Modified version of the work: Copyright (C) 2006-2018 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2018 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

# get selenium object
my $Selenium = $Kernel::OM->Get('Kernel::System::UnitTest::Selenium');

$Selenium->RunTest(
    sub {

        # get helper object
        my $Helper = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');

        # create test user and login
        my $TestUserLogin = $Helper->TestUserCreate(
            Groups => ['admin'],
        ) || die "Did not get test user";

        $Selenium->Login(
            Type     => 'Agent',
            User     => $TestUserLogin,
            Password => $TestUserLogin,
        );

        # get script alias
        my $ScriptAlias = $Kernel::OM->Get('Kernel::Config')->Get('ScriptAlias');

        # navigate to AdminSelectBox screen
        $Selenium->VerifiedGet("${ScriptAlias}index.pl?Action=AdminSelectBox");

        # empty SQL statement, check client side validation
        $Selenium->find_element( "#SQL", 'css' )->clear();
        $Selenium->find_element( "#SQL", 'css' )->VerifiedSubmit();
        $Self->Is(
            $Selenium->execute_script(
                "return \$('#SQL').hasClass('Error')"
            ),
            '1',
            'Client side validation correctly detected missing input value for #SQL',
        );

        # wrong SQL statement, check server side validation
        $Selenium->find_element( "#SQL", 'css' )->clear();
        $Selenium->find_element( "#SQL", 'css' )->send_keys("SELECT * FROM");
        $Selenium->find_element( "#SQL", 'css' )->VerifiedSubmit();
        $Self->Is(
            $Selenium->execute_script(
                "return \$('#SQL').hasClass('ServerError')"
            ),
            '1',
            'Server side validation correctly detected missing input value for #SQL',
        );

        # correct SQL statement
        $Selenium->find_element( "#SQL", 'css' )->clear();
        $Selenium->find_element( "#SQL", 'css' )->send_keys("SELECT * FROM valid");
        $Selenium->find_element( "#SQL", 'css' )->VerifiedSubmit();

        # verify results
        my @Elements = $Selenium->find_elements( 'table thead tr', 'css' );
        $Self->Is(
            scalar @Elements,
            1,
            "Result table header row found",
        );

        @Elements = $Selenium->find_elements( 'table tbody tr', 'css' );
        $Self->Is(
            scalar @Elements,
            3,
            "Result table body rows found",
        );
    }
);

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
