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

# get selenium object
my $Selenium = $Kernel::OM->Get('Kernel::System::UnitTest::Selenium');

$Selenium->RunTest(
    sub {

        # get helper object
        my $Helper = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');

        # get config object
        my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

        # enable tool bar AgentTicketEmail
        my %AgentTicketEmail = (
            Action   => 'AgentTicketEmail',
            CssClass => 'EmailTicket',
            Icon     => 'fa fa-envelope',
            Link     => 'Action=AgentTicketEmail',
            Module   => 'Kernel::Output::HTML::ToolBar::Link',
            Name     => 'New email ticket',
            Priority => '1020020',
        );

        $Helper->ConfigSettingChange(
            Key   => 'Frontend::ToolBarModule###5-Ticket::AgentTicketEmail',
            Value => \%AgentTicketEmail,
        );

        $Helper->ConfigSettingChange(
            Valid => 1,
            Key   => 'Frontend::ToolBarModule###5-Ticket::AgentTicketEmail',
            Value => \%AgentTicketEmail
        );

        # create test user and login
        my $TestUserLogin = $Helper->TestUserCreate(
            Groups => [ 'admin', 'users' ],
        ) || die "Did not get test user";

        $Selenium->Login(
            Type     => 'Agent',
            User     => $TestUserLogin,
            Password => $TestUserLogin,
        );

        # click on tool bar AgentTicketEmail
        $Selenium->find_element("//a[contains(\@title, \'New email ticket:\' )]")->VerifiedClick();

        # verify that test is on the correct screen
        my $ScriptAlias = $ConfigObject->Get('ScriptAlias');
        my $ExpectedURL = "${ScriptAlias}index.pl?Action=AgentTicketEmail";

        $Self->True(
            index( $Selenium->get_current_url(), $ExpectedURL ) > -1,
            "ToolBar AgentTicketEmail shortcut - success",
        );
    }
);

1;


=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
