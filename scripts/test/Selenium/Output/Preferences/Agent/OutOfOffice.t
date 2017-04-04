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

        my $Helper = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');

        # create and login test user
        $Helper->ConfigSettingChange(
            Valid => 1,
            Key   => 'TimeZoneUser',
            Value => 1,
        );

        # Disable TimeZoneUserBrowserAutoOffset feature.
        $Helper->ConfigSettingChange(
            Valid => 1,
            Key   => 'TimeZoneUserBrowserAutoOffset',
            Value => 0,
        );

        # create and login test user
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

        # go to agent preferences
        $Selenium->VerifiedGet("${ScriptAlias}index.pl?Action=AgentPreferences");

        # wait until form has loaded, if neccessary
        $Selenium->WaitFor( JavaScript => 'return typeof($) === "function" && $("body").length' );

        # get current time stamp
        #   should not be converted to local time zone, see bug#12471.
        $Selenium->execute_script("\$('#UserTimeZone').val('-5').trigger('redraw.InputField').trigger('change');");
        $Selenium->find_element( "#UserTimeZone", 'css' )->VerifiedSubmit();

        # change test user out of office preference
        $Selenium->WaitFor( JavaScript => 'return typeof($) === "function" && $("body").length' );

        # Get current date and time components.
        my $TimeObject = $Kernel::OM->Get('Kernel::System::Time');
        my %Date;
        ( $Date{Sec}, $Date{Min}, $Date{Hour}, $Date{Day}, $Date{Month}, $Date{Year}, $Date{WeekDay} )
            = $TimeObject->SystemTime2Date(
            SystemTime => $TimeObject->SystemTime(),
            );

        # Change test user out of office preference to current date.
        $Selenium->find_element( "#OutOfOfficeOn", 'css' )->VerifiedClick();
        for my $FieldGroup (qw(Start End)) {
            for my $FieldType (qw(Year Month Day)) {
                $Selenium->execute_script(
                    "\$('#OutOfOffice$FieldGroup$FieldType').val($Date{$FieldType}).trigger('change');"
                );
            }
        }
        $Selenium->find_element( "#Update", 'css' )->VerifiedClick();

        # wait until form has loaded, if neccessary
        $Selenium->WaitFor( JavaScript => 'return typeof($) === "function" && $("body").length' );

        # check for update preference message on screen
        my $UpdateMessage = "Preferences updated successfully!";
        $Self->True(
            index( $Selenium->get_page_source(), $UpdateMessage ) > -1,
            'Agent preference out of office time - updated'
        );

        # set start time after end time, see bug #8220
        for my $FieldGroup (qw(Start End)) {
            for my $FieldType (qw(Year Month Day)) {
                $Self->Is(
                    int $Selenium->find_element( "#OutOfOffice$FieldGroup$FieldType", 'css' )->get_value(),
                    int $Date{$FieldType},
                    "Shown OutOfOffice$FieldGroup$FieldType field value"
                );
            }
        }

        # set start time after end time, see bug #8220
        my $StartYear = $Date{Year} + 2;
        $Selenium->execute_script(
            "\$('#OutOfOfficeStartYear').val('$StartYear').trigger('redraw.InputField').trigger('change');"
        );
        $Selenium->find_element( "#Update", 'css' )->VerifiedClick();

        # wait until form has loaded, if neccessary
        $Selenium->WaitFor( JavaScript => 'return typeof($) === "function" && $("body").length' );

        # check for error message on screen
        my $ErrorMessage = "Please specify an end date that is after the start date.";
        $Self->True(
            index( $Selenium->get_page_source(), $ErrorMessage ) > -1,
            'Agent preference out of office time - not updated'
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
