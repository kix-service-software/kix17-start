# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Admin::Migration::DataCheck;

use strict;
use warnings;

use Net::LDAP;
use Net::LDAP::Control::Paged;
use Net::LDAP::Constant qw(LDAP_CONTROL_PAGED);
use Net::LDAP::Util qw(escape_filter_value);

use Kernel::System::EmailParser;
use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Cache',
    'Kernel::System::CustomerCompany',
    'Kernel::System::CustomerUser',
    'Kernel::System::DB',
    'Kernel::System::Encode',
    'Kernel::System::JSON',
    'Kernel::System::Log',
    'Kernel::System::State',
    'Kernel::System::SystemData',
    'Kernel::System::Ticket',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Check data for migration from KIX17 to KIX18.');
    $Self->AddOption(
        Name        => 'fix',
        Description => "Specify one or more known issues to fix. You can specify 'All' to fix all known issues.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.+/smx,
        Multiple    => 1,
    );
    $Self->AddOption(
        Name        => 'ldap-pagesize',
        Description => "Pagesize to use, when syncing ldap backends to database.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/^\d+$/smx,
    );
    $Self->AddOption(
        Name        => 'verbose',
        Description => "Shows list of relevant entries for some checks",
        Required    => 0,
        HasValue    => 0,
    );
    $Self->AddOption(
        Name        => 'internal',
        Description => "Run checks on internal database",
        Required    => 0,
        HasValue    => 0,
    );

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # get options
    my @Fixes = @{ $Self->GetOption('fix') // [] };
    my $Fix      = $Self->GetOption('fix');
    my $PageSize = $Self->GetOption('ldap-pagesize');
    my $Verbose  = $Self->GetOption('verbose');
    my $Internal = $Self->GetOption('internal');

    my %Fixes = ();
    for my $Fix ( @Fixes ) {
        if ( $Fix eq 'All' ) {
            %Fixes = (
                'Placeholder'                 => 1,
                'CustomerUserBackends'        => 1,
                'CustomerCompanyBackends'     => 1,
                'CustomerUserData'            => 1,
                'CustomerUserEmail'           => 1,
                'CustomerCompanyData'         => 1,
                'UserExists'                  => 1,
                'UserEmail'                   => 1,
                'TicketCustomerUserUpdate'    => 1,
                'TicketCustomerUser'          => 1,
                'TicketCustomerCompany'       => 1,
                'TicketData'                  => 1,
                'TicketStateTypes'            => 1,
                'ServiceNames'                => 1,
                'DynamicFieldValues'          => 1,
                'PrepareTicketEscalationData' => 1,
            );

            last;
        }
        else {
            $Fixes{ $Fix } = 1;
        }
    }

    # clear cache before fix
    my $Success = $Self->_ClearCache(
        Fixes => \%Fixes,
    );
    if ( !$Success ) {
        return $Self->ExitCodeError();
    }

    # check placeholder data
    $Success = $Self->_CheckPlaceholderData(
        Fixes   => \%Fixes,
        Verbose => $Verbose,
    );
    if ( !$Success ) {
        return $Self->ExitCodeError();
    }

    # check customer user backends
    $Success = $Self->_CheckCustomerUserBackends(
        Fixes    => \%Fixes,
        PageSize => $PageSize,
        Internal => $Internal,
    );
    if ( !$Success ) {
        return $Self->ExitCodeError();
    }

    # check customer company backends
    $Success = $Self->_CheckCustomerCompanyBackends(
        Fixes    => \%Fixes,
        Internal => $Internal,
    );
    if ( !$Success ) {
        return $Self->ExitCodeError();
    }

    # change customer user and customer company backends to internal database table
    $Success = $Self->_SetInternalCustomerBackends(
        Fixes    => \%Fixes,
        Internal => $Internal,
    );
    if ( !$Success ) {
        return $Self->ExitCodeError();
    }

    # check customer user data
    $Success = $Self->_CheckCustomerUserData(
        Fixes   => \%Fixes,
        Verbose => $Verbose,
    );
    if ( !$Success ) {
        return $Self->ExitCodeError();
    }

    # check customer user email
    $Success = $Self->_CheckCustomerUserEmail(
        Fixes   => \%Fixes,
        Verbose => $Verbose,
    );
    if ( !$Success ) {
        return $Self->ExitCodeError();
    }

    # check customer company data
    $Success = $Self->_CheckCustomerCompanyData(
        Fixes   => \%Fixes,
        Verbose => $Verbose,
    );
    if ( !$Success ) {
        return $Self->ExitCodeError();
    }

    # check all relevant users exist
    $Success = $Self->_CheckUserExists(
        Fixes   => \%Fixes,
        Verbose => $Verbose,
    );
    if ( !$Success ) {
        return $Self->ExitCodeError();
    }

    # check user email
    $Success = $Self->_CheckUserEmail(
        Fixes   => \%Fixes,
        Verbose => $Verbose,
    );
    if ( !$Success ) {
        return $Self->ExitCodeError();
    }

    # check ticket customer user
    $Success = $Self->_CheckTicketCustomerUser(
        Fixes   => \%Fixes,
        Verbose => $Verbose,
    );
    if ( !$Success ) {
        return $Self->ExitCodeError();
    }

    # update ticket customer user
    $Success = $Self->_UpdateTicketCustomerUser(
        Fixes => \%Fixes,
    );
    if ( !$Success ) {
        return $Self->ExitCodeError();
    }

    # check ticket data
    $Success = $Self->_CheckTicketData(
        Fixes   => \%Fixes,
        Verbose => $Verbose,
    );
    if ( !$Success ) {
        return $Self->ExitCodeError();
    }

    # check ticket customer user
    $Success = $Self->_CheckTicketCustomerCompany(
        Fixes   => \%Fixes,
        Verbose => $Verbose,
    );
    if ( !$Success ) {
        return $Self->ExitCodeError();
    }

    # check ticket state types
    $Success = $Self->_CheckTicketStateTypes(
        Fixes   => \%Fixes,
        Verbose => $Verbose,
    );
    if ( !$Success ) {
        return $Self->ExitCodeError();
    }

    # check service names
    $Success = $Self->_CheckServiceNames(
        Fixes   => \%Fixes,
        Verbose => $Verbose,
    );
    if ( !$Success ) {
        return $Self->ExitCodeError();
    }

    # check dynamic field values
    $Success = $Self->_CheckDynamicFieldValues(
        Fixes   => \%Fixes,
    );
    if ( !$Success ) {
        return $Self->ExitCodeError();
    }

    # prepare ticket escalation data
    $Success = $Self->_PrepareTicketEscalationData(
        Fixes   => \%Fixes,
    );
    if ( !$Success ) {
        return $Self->ExitCodeError();
    }

    # clear cache after fix
    $Success = $Self->_ClearCache(
        Fixes => \%Fixes,
    );
    if ( !$Success ) {
        return $Self->ExitCodeError();
    }

    return $Self->ExitCodeOk();
}

### Check Functions ###
sub _CheckPlaceholderData {
    my ( $Self, %Param ) = @_;

    $Self->Print('<yellow>Placeholder</yellow> - Check placeholder data' . "\n");

    # skip this step if fixes are given, but this one is irrelevant
    if (
        IsHashRefWithData( $Param{Fixes} )
        && !$Param{Fixes}->{'Placeholder'}
    ) {
        $Self->Print('<green> - Skip, irrelevant step for this fix run</green>' . "\n");
        return 1;
    }

    # get all table names from DB
    my $TablesRef = $Self->_GetDBTables();

    # init query map
    my %QueryMap = (
        AutoResponseSubject => {
            Label   => 'auto response subjects',
            DataSQL => 'SELECT id, text1 FROM auto_response',
            FixSQL  => 'UPDATE auto_response SET text1 = ? WHERE id = ?',
            Table   => 'auto_response',
        },
        AutoResponseText => {
            Label   => 'auto response text',
            DataSQL => 'SELECT id, text0 FROM auto_response',
            FixSQL  => 'UPDATE auto_response SET text0 = ? WHERE id = ?',
            Table   => 'auto_response',
        },
        GenericAgentBody => {
            Label   => 'generic agent body',
            DataSQL => 'SELECT job_name, job_value FROM generic_agent_jobs WHERE job_key = \'Body\'',
            FixSQL  => 'UPDATE generic_agent_jobs SET job_value = ? WHERE job_name = ? AND  job_key = \'Body\'',
            Table   => 'generic_agent_jobs',
        },
        GenericAgentSubject => {
            Label   => 'generic agent subjects',
            DataSQL => 'SELECT job_name, job_value FROM generic_agent_jobs WHERE job_key = \'Subject\'',
            FixSQL  => 'UPDATE generic_agent_jobs SET job_value = ? WHERE job_name = ? AND  job_key = \'Subject\'',
            Table   => 'generic_agent_jobs',
        },
        NotificationEventSubject => {
            Label   => 'notification event subject',
            DataSQL => 'SELECT id, subject FROM notification_event_message',
            FixSQL  => 'UPDATE notification_event_message SET subject = ? WHERE id = ?',
            Table   => 'notification_event_message',
        },
        NotificationEventText => {
            Label   => 'notification event text',
            DataSQL => 'SELECT id, text FROM notification_event_message',
            FixSQL  => 'UPDATE notification_event_message SET text = ? WHERE id = ?',
            Table   => 'notification_event_message',
        },
        PMTransitionAction => {
            Label   => 'process management transition action',
            DataSQL => 'SELECT id, config FROM pm_transition_action',
            FixSQL  => 'UPDATE pm_transition_action SET config = ? WHERE id = ?',
            Table   => 'pm_transition_action',
        },
        QuickState => {
            Label   => 'quick state',
            DataSQL => 'SELECT id, config FROM kix_quick_state',
            FixSQL  => 'UPDATE kix_quick_state SET config = ? WHERE id = ?',
            Table   => 'kix_quick_state',
        },
        Salutation => {
            Label   => 'salutation',
            DataSQL => 'SELECT id, text FROM salutation',
            FixSQL  => 'UPDATE salutation SET text = ? WHERE id = ?',
            Table   => 'salutation',
        },
        Signature => {
            Label   => 'signature',
            DataSQL => 'SELECT id, text FROM signature',
            FixSQL  => 'UPDATE signature SET text = ? WHERE id = ?',
            Table   => 'signature',
        },
        StandardTemplate => {
            Label   => 'standard template',
            DataSQL => 'SELECT id, text FROM standard_template',
            FixSQL  => 'UPDATE standard_template SET text = ? WHERE id = ?',
            Table   => 'standard_template',
        },
        TextModuleSubject => {
            Label   => 'text module subject',
            DataSQL => 'SELECT id, subject FROM kix_text_module',
            FixSQL  => 'UPDATE kix_text_module SET subject = ? WHERE id = ?',
            Table   => 'kix_text_module',
        },
        TextModuleText => {
            Label   => 'text module text',
            DataSQL => 'SELECT id, text FROM kix_text_module',
            FixSQL  => 'UPDATE kix_text_module SET text = ? WHERE id = ?',
            Table   => 'kix_text_module',
        },
        TicketTemplateBcc => {
            Label   => 'ticket template bcc',
            DataSQL => 'SELECT template_id, preferences_value FROM kix_ticket_template_prefs WHERE preferences_key = \'Bcc\'',
            FixSQL  => 'UPDATE kix_ticket_template_prefs SET preferences_value = ? WHERE template_id = ? AND preferences_key = \'Bcc\'',
            Table   => 'kix_ticket_template_prefs',
        },
        TicketTemplateBody => {
            Label   => 'ticket template body',
            DataSQL => 'SELECT template_id, preferences_value FROM kix_ticket_template_prefs WHERE preferences_key = \'Body\'',
            FixSQL  => 'UPDATE kix_ticket_template_prefs SET preferences_value = ? WHERE template_id = ? AND preferences_key = \'Body\'',
            Table   => 'kix_ticket_template_prefs',
        },
        TicketTemplateCc => {
            Label   => 'ticket template cc',
            DataSQL => 'SELECT template_id, preferences_value FROM kix_ticket_template_prefs WHERE preferences_key = \'Cc\'',
            FixSQL  => 'UPDATE kix_ticket_template_prefs SET preferences_value = ? WHERE template_id = ? AND preferences_key = \'Cc\'',
            Table   => 'kix_ticket_template_prefs',
        },
        TicketTemplateFrom => {
            Label   => 'ticket template from',
            DataSQL => 'SELECT template_id, preferences_value FROM kix_ticket_template_prefs WHERE preferences_key = \'From\'',
            FixSQL  => 'UPDATE kix_ticket_template_prefs SET preferences_value = ? WHERE template_id = ? AND preferences_key = \'From\'',
            Table   => 'kix_ticket_template_prefs',
        },
        TicketTemplateSubject => {
            Label   => 'ticket template subject',
            DataSQL => 'SELECT template_id, preferences_value FROM kix_ticket_template_prefs WHERE preferences_key = \'Subject\'',
            FixSQL  => 'UPDATE kix_ticket_template_prefs SET preferences_value = ? WHERE template_id = ? AND preferences_key = \'Subject\'',
            Table   => 'kix_ticket_template_prefs',
        },
    );

    # prepare patterns
    my @PatternArray = (
        {
            Check   => 'OTRS_',
            Replace => 'KIX_',
        },
        {
            Check   => 'KIX_ARTICLE_DATA_',
            Replace => 'KIX_ARTICLE_',
        },
        {
            Check   => 'KIX_CUSTOMERDATA_User',
            Replace => 'KIX_CONTACT_',
        },
        {
            Check   => 'KIX_CUSTOMERDATA_CustomerCompany',
            Replace => 'KIX_ORG_',
        },
        {
            Check   => 'KIX_CUSTOMER_DATA_User',
            Replace => 'KIX_CONTACT_',
        },
        {
            Check   => 'KIX_CUSTOMER_DATA_CustomerCompany',
            Replace => 'KIX_ORG_',
        },
        {
            Check   => 'KIX_NOTIFICATION_RECIPIENT_',
            Replace => 'KIX_NOTIFICATIONRECIPIENT_',
        },
        {
            Check   => 'KIX_TICKET_OWNER_',
            Replace => 'KIX_TICKETOWNER_',
        },
    );

    # process queries
    for my $Query ( sort( keys( %QueryMap ) ) ) {
        $Self->Print('<yellow> - ' . $QueryMap{ $Query }->{Label} . ': </yellow>');

        # check if table exists
        if ( !$TablesRef->{ $QueryMap{ $Query }->{Table} } ) {
            $Self->Print('<yellow>table does not exist</yellow>' . "\n");

            next;
        }

        # prepare db handle
        return if !$Kernel::OM->Get('Kernel::System::DB')->Prepare(
            SQL => $QueryMap{ $Query }->{DataSQL},
        );

        # fetch data
        my %Data = ();
        while ( my @Row = $Kernel::OM->Get('Kernel::System::DB')->FetchrowArray() ) {
            $Data{ $Row[0] } = $Row[1];
        }

        # process data
        my $Count        = 0;
        my %PatternCount = ();
        for my $DataID ( keys( %Data ) ) {
            next if ( !$Data{ $DataID } );

            for my $PatternEntry ( @PatternArray ) {
                if ( $Data{ $DataID } =~ m/$PatternEntry->{Check}/ ) {
                    # increment count
                    $Count += 1;
                    if ( $PatternCount{ $PatternEntry->{Check} } ) {
                        $PatternCount{ $PatternEntry->{Check} } += 1;
                    }
                    else {
                        $PatternCount{ $PatternEntry->{Check} } = 1;
                    }

                    # check if entry should be fixed
                    if ( $Param{Fixes}->{'Placeholder'} ) {
                        # replace obsolete placeholder
                        $Data{ $DataID } =~ s/$PatternEntry->{Check}/$PatternEntry->{Replace}/g;

                        # prepare bind parameter
                        my @FixBind = ( \$Data{ $DataID }, \$DataID );

                        # execute fix statement
                        return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
                            SQL  => $QueryMap{ $Query }->{FixSQL},
                            Bind => \@FixBind,
                        );
                    }
                }
            }
        }

        # check process result
        if ( $Count ) {
            if ( $Param{Fixes}->{'Placeholder'} ) {
                if ( $Param{Verbose} ) {
                    $Self->Print("\n");
                    for my $PatternEntry ( @PatternArray ) {
                        if ( $PatternCount{ $PatternEntry->{Check} } ) {
                            $Self->Print('<green> - - /' . $PatternEntry->{Check} . '/' . $PatternEntry->{Replace} . '/:' . $PatternCount{ $PatternEntry->{Check} } . ' entries fixed</green>' . "\n");
                        }
                    }
                }
                else {
                    $Self->Print('<green>' . $Count . ' entries fixed</green>' . "\n");
                }
            }
            else {
                if ( $Param{Verbose} ) {
                    $Self->Print("\n");
                    for my $PatternEntry ( @PatternArray ) {
                        if ( $PatternCount{ $PatternEntry->{Check} } ) {
                            $Self->Print('<red> - - /' . $PatternEntry->{Check} . '/' . $PatternEntry->{Replace} . '/:' . $PatternCount{ $PatternEntry->{Check} } . ' entries should be fixed</red>' . "\n");
                        }
                    }
                }
                else {
                    $Self->Print('<red>' . $Count . ' entries should be fixed</red>' . "\n");
                }
            }
        }
        else {
            $Self->Print('<green>No obsolete placeholder</green>' . "\n");
        }
    }

    return 1;
}

sub _CheckCustomerUserBackends {
    my ( $Self, %Param ) = @_;

    $Self->Print('<yellow>CustomerUserBackends</yellow> - Check customer user backends' . "\n");

    # skip this step if fixes are given, but this one is irrelevant
    if (
        IsHashRefWithData( $Param{Fixes} )
        && !$Param{Fixes}->{'CustomerUserBackends'}
    ) {
        $Self->Print('<green> - Skip, irrelevant step for this fix run</green>' . "\n");
        return 1;
    }

    if ( $Param{Internal} ) {
        $Self->Print('<green> - Do nothing, when internal flag is set</green>' . "\n");

        return 1;
    }

    # init variables
    my $FixBackendFound = 0;

    # check for column customer_ids
    my $UserCustomerIDs = $Self->_ExistsDBCustomerIDsColumn();
    if ( $UserCustomerIDs ) {
        $Self->Print('<red> - UserCustomerIDs is used. Check that all entries are synced before fix.</red>' . "\n");
    }

    # process customer user backends
    COUNT:
    for my $Count ( '', 1 .. 10 ) {

        my $BackendConfiguration = $Kernel::OM->Get('Kernel::Config')->Get( 'CustomerUser' . $Count );

        next COUNT if ( !$BackendConfiguration->{Module} );

        if ( !$UserCustomerIDs ) {
            for my $Entry ( @{ $BackendConfiguration->{Map} } ) {
                if ( $Entry->[0] eq 'UserCustomerIDs' ) {
                    $Self->Print('<red> - Backend CustomerUser' . $Count . ' uses UserCustomerIDs, but column customer_ids does not exist in kix table customer_user!</red>' . "\n");
                }
            }
        }

        if ( $BackendConfiguration->{Module} ne 'Kernel::System::CustomerUser::LDAP' ) {
            if ( $BackendConfiguration->{Module} ne 'Kernel::System::CustomerUser::DB' ) {
                $FixBackendFound = 1;

                $Self->Print('<red> - Backend CustomerUser' . $Count . ' uses unknown Module. Should be MANUALLY synced to kix table customer_user</red>' . "\n");
            }
            elsif ( $BackendConfiguration->{Params}->{DSN} ) {
                $FixBackendFound = 1;

                if ( $Param{Fixes}->{'CustomerUserBackends'} ) {
                    $Self->Print('<yellow> - Sync Backend CustomerUser' . $Count . ' to kix table customer_user</yellow>' . "\n");

                    my $Success = $Self->_SyncCustomerUserBackendFromDB(
                        Backend         => $BackendConfiguration,
                        UserCustomerIDs => $UserCustomerIDs,
                    );
                    if ( !$Success ) {
                        $Self->PrintError('Error occurred.' . "\n");
                        return;
                    }
                }
                else {
                    $Self->Print('<red> - Backend CustomerUser' . $Count . ' may uses external database. Should be synced to kix table customer_user</red>' . "\n");
                }
            }
            elsif ( $BackendConfiguration->{Params}->{Table} ne 'customer_user' ) {
                $FixBackendFound = 1;

                if ( $Param{Fixes}->{'CustomerUserBackends'} ) {
                    $Self->Print('<yellow> - Sync Backend CustomerUser' . $Count . ' to kix table customer_user</yellow>' . "\n");

                    my $Success = $Self->_SyncCustomerUserBackendFromDB(
                        Backend         => $BackendConfiguration,
                        UserCustomerIDs => $UserCustomerIDs,
                    );
                    if ( !$Success ) {
                        $Self->PrintError('Error occurred.' . "\n");
                        return;
                    }
                }
                else {
                    $Self->Print('<red> - Backend CustomerUser' . $Count . ' uses own table. Should be synced to kix table customer_user</red>' . "\n");
                }
            }
        }
        else {
            $FixBackendFound = 1;

            if ( $Param{Fixes}->{'CustomerUserBackends'} ) {
                $Self->Print('<yellow> - Sync Backend CustomerUser' . $Count . ' to kix table customer_user</yellow>' . "\n");

                my $Success = $Self->_SyncCustomerUserBackendFromLDAP(
                    Backend         => $BackendConfiguration,
                    PageSize        => $Param{PageSize},
                    UserCustomerIDs => $UserCustomerIDs,
                );
                if ( !$Success ) {
                    $Self->PrintError('Error occurred.' . "\n");
                    return;
                }
            }
            else {
                $Self->Print('<red> - Backend CustomerUser' . $Count . ' uses LDAP. Should be synced to kix table customer_user</red>' . "\n");
            }
        }
    }

    if ( !$FixBackendFound ) {
        $Self->Print('<green> - Nothing to do</green>' . "\n");
    }

    return 1;
}

sub _CheckCustomerCompanyBackends {
    my ( $Self, %Param ) = @_;

    $Self->Print('<yellow>CustomerCompanyBackends</yellow> - Check customer company backends' . "\n");

    # skip this step if fixes are given, but this one is irrelevant
    if (
        IsHashRefWithData( $Param{Fixes} )
        && !$Param{Fixes}->{'CustomerCompanyBackends'}
    ) {
        $Self->Print('<green> - Skip, irrelevant step for this fix run</green>' . "\n");
        return 1;
    }

    if ( $Param{Internal} ) {
        $Self->Print('<green> - Do nothing, when internal flag is set</green>' . "\n");

        return 1;
    }

    # init variables
    my $FixBackendFound = 0;

    # process customer company backends
    COUNT:
    for my $Count ( '', 1 .. 10 ) {

        my $BackendConfiguration = $Kernel::OM->Get('Kernel::Config')->Get( 'CustomerCompany' . $Count );

        next COUNT if ( !$BackendConfiguration->{Module} );

        if ( $BackendConfiguration->{Module} ne 'Kernel::System::CustomerCompany::DB' ) {
            $FixBackendFound = 1;

            $Self->Print('<red> - Backend CustomerCompany' . $Count . ' uses unknown Module. Should be MANUALLY synced to kix table customer_company</red>' . "\n");
        }
        elsif ( $BackendConfiguration->{Params}->{DSN} ) {
            $FixBackendFound = 1;

            if ( $Param{Fixes}->{'CustomerCompanyBackends'} ) {
                $Self->Print('<yellow> - Sync Backend CustomerCompany' . $Count . ' to kix table customer_company</yellow>' . "\n");

                my $Success = $Self->_SyncCustomerCompanyBackendFromDB(
                    Backend => $BackendConfiguration,
                );
                if ( !$Success ) {
                    $Self->PrintError('Error occurred.' . "\n");
                    return;
                }
            }
            else {
                $Self->Print('<red> - Backend CustomerCompany' . $Count . ' may uses external database. Should be synced to kix table customer_company</red>' . "\n");
            }
        }
        elsif ( $BackendConfiguration->{Params}->{Table} ne 'customer_company' ) {
            $FixBackendFound = 1;

            if ( $Param{Fixes}->{'CustomerCompanyBackends'} ) {
                $Self->Print('<yellow> - Sync Backend CustomerCompany' . $Count . ' to kix table customer_company</yellow>' . "\n");

                my $Success = $Self->_SyncCustomerCompanyBackendFromDB(
                    Backend => $BackendConfiguration,
                );
                if ( !$Success ) {
                    $Self->PrintError('Error occurred.' . "\n");
                    return;
                }
            }
            else {
                $Self->Print('<red> - Backend CustomerCompany' . $Count . ' uses own table. Should be synced to kix table customer_company</red>' . "\n");
            }
        }
    }

    if ( !$FixBackendFound ) {
        $Self->Print('<green> - Nothing to do</green>' . "\n");
    }

    return 1;
}

sub _SetInternalCustomerBackends {
    my ( $Self, %Param ) = @_;

    # check for column customer_ids
    my $UserCustomerIDs = $Self->_ExistsDBCustomerIDsColumn();

    if (
        $Param{Internal}
        || $Param{Fixes}->{'CustomerCompanyData'}
        || $Param{Fixes}->{'TicketCustomerUser'}
        || $Param{Fixes}->{'TicketCustomerUserUpdate'}
    ) {
        # prepare mapping
        my $Map = [
            [ 'UserFirstname',  'Firstname',  'first_name',  1, 1, 'var', '', 0 ],
            [ 'UserLastname',   'Lastname',   'last_name',   1, 1, 'var', '', 0 ],
            [ 'UserLogin',      'Username',   'login',       1, 1, 'var', '', 0 ],
            [ 'UserEmail',      'Email',      'email',       1, 1, 'var', '', 0 ],
            [ 'UserCustomerID', 'CustomerID', 'customer_id', 0, 1, 'var', '', 0 ],
            [ 'ValidID',        'Valid',      'valid_id',    0, 1, 'int', '', 0 ],
        ];

        # add column for customer ids if needed
        if ( $UserCustomerIDs ) {
            push( @{ $Map }, [ 'UserCustomerIDs', 'CustomerIDs', 'customer_ids', 1, 0, 'var', '', 0 ] );
        }

        # overwrite customer user backends
        $Kernel::OM->Get('Kernel::Config')->Set(
            Key   => 'CustomerUser',
            Value => {
                Name   => 'Temp Database Backend',
                Module => 'Kernel::System::CustomerUser::DB',
                Params => {
                    Table               => 'customer_user',
                    SearchCaseSensitive => 0,
                },

                CustomerKey   => 'login',
                CustomerID    => 'customer_id',
                CustomerValid => 'valid_id',

                CustomerUserListFields             => [ 'first_name', 'last_name', 'email' ],
                CustomerUserSearchFields           => [ 'login', 'first_name', 'last_name', 'customer_id' ],
                CustomerUserSearchPrefix           => '*',
                CustomerUserSearchSuffix           => '*',
                CustomerUserSearchListLimit        => 1_000_000,
                CustomerUserPostMasterSearchFields => [ 'email' ],
                CustomerUserNameFields             => [ 'first_name', 'last_name' ],
                CustomerUserEmailUniqCheck         => 1,

                CustomerCompanySupport => 1,

                Map => $Map,
            },
        );
        for my $Count ( 1 .. 10 ) {
            $Kernel::OM->Get('Kernel::Config')->Set(
                Key   => 'CustomerUser' . $Count,
                Value => undef,
            );
        }
    }

    if (
        $Param{Internal}
        || $Param{Fixes}->{'CustomerCompanyData'}
        || $Param{Fixes}->{'TicketCustomerCompany'}
    ) {
        # prepare mapping
        my $Map = [
            [ 'CustomerID',             'CustomerID', 'customer_id', 0, 1, 'var', '', 0 ],
            [ 'CustomerCompanyName',    'Customer',   'name',        1, 1, 'var', '', 0 ],
            [ 'ValidID',                'Valid',      'valid_id',    0, 1, 'int', '', 0 ],
        ];

        # overwrite customer user backends
        $Kernel::OM->Get('Kernel::Config')->Set(
            Key   => 'CustomerCompany',
            Value => {
                Name   => 'Database Backend',
                Module => 'Kernel::System::CustomerCompany::DB',
                Params => {
                    Table               => 'customer_company',
                    SearchCaseSensitive => 0,
                },

                CustomerCompanyKey             => 'customer_id',
                CustomerCompanyValid           => 'valid_id',
                CustomerCompanyListFields      => [ 'customer_id', 'name' ],
                CustomerCompanySearchFields    => ['customer_id', 'name'],
                CustomerCompanySearchPrefix    => '*',
                CustomerCompanySearchSuffix    => '*',
                CustomerCompanySearchListLimit => 1_000_000,

                Map => $Map,
            },
        );
        for my $Count ( 1 .. 10 ) {
            $Kernel::OM->Get('Kernel::Config')->Set(
                Key   => 'CustomerCompany' . $Count,
                Value => undef,
            );
        }
    }

    return 1;
}

sub _CheckCustomerUserData {
    my ( $Self, %Param ) = @_;

    $Self->Print('<yellow>CustomerUserData</yellow> - Check customer user data of internal database table' . "\n");

    # skip this step if fixes are given, but this one is irrelevant
    if (
        IsHashRefWithData( $Param{Fixes} )
        && !$Param{Fixes}->{'CustomerUserData'}
    ) {
        $Self->Print('<green> - Skip, irrelevant step for this fix run</green>' . "\n");
        return 1;
    }

    # init query map
    my %QueryMap = (
        '0001' => {
            'Label'     => 'customer user with same value for login and customer company',
            'SelectSQL' => 'SELECT login FROM customer_user WHERE login = customer_id AND login != \'Unbekannt\'',
        },
        '0002' => {
            'Label'     => 'customer user without customer company',
            'SelectSQL' => 'SELECT login FROM customer_user WHERE customer_id = \'\' OR customer_id IS NULL',
            'FixSQL'    => 'UPDATE customer_user SET customer_id = \'Unbekannt\' WHERE customer_id = \'\' OR customer_id IS NULL',
            'Create'    => 'CustomerCompany',
        },
        '0003' => {
            'Label'     => 'customer user without first name',
            'SelectSQL' => 'SELECT login FROM customer_user WHERE first_name = \'\' OR first_name IS NULL',
            'FixSQL'    => 'UPDATE customer_user SET first_name = \'_\' WHERE first_name = \'\' OR first_name IS NULL',
        },
        '0004' => {
            'Label'     => 'customer user without last name',
            'SelectSQL' => 'SELECT login FROM customer_user WHERE last_name = \'\' OR last_name IS NULL',
            'FixSQL'    => 'UPDATE customer_user SET last_name = \'_\' WHERE last_name = \'\' OR last_name IS NULL',
        },
        '0005' => {
            'Label'     => 'customer user without email',
            'SelectSQL' => 'SELECT login FROM customer_user WHERE email = \'\' OR email IS NULL',
            'FixSQL'    => 'UPDATE customer_user SET email = \'dummy@localhost\' WHERE email = \'\' OR email IS NULL',
        },
        '0006' => {
            'Label'     => 'customer user with same email as an user, but different firstname or lastname',
            'SelectSQL' => 'SELECT cu.login FROM customer_user cu, users u, user_preferences up WHERE lower(cu.email) = lower(up.preferences_value) AND up.preferences_key = \'UserEmail\' AND up.user_id = u.id AND (cu.first_name != u.first_name OR cu.last_name != u.last_name)',
        },
        '0007' => {
            'Label'     => 'customer user with same email as an user, but different login',
            'SelectSQL' => 'SELECT cu.login FROM customer_user cu, users u, user_preferences up WHERE lower(cu.email) = lower(up.preferences_value) AND up.preferences_key = \'UserEmail\' AND up.user_id = u.id AND cu.login != u.login',
        },
    );

    # process queries
    for my $Query ( sort( keys( %QueryMap ) ) ) {
        $Self->Print('<yellow> - ' . $QueryMap{ $Query }->{Label} . ': </yellow>');

        # prepare db handle
        return if !$Kernel::OM->Get('Kernel::System::DB')->Prepare(
            SQL => $QueryMap{ $Query }->{SelectSQL},
        );

        # fetch data
        my %Data = ();
        while ( my @Row = $Kernel::OM->Get('Kernel::System::DB')->FetchrowArray() ) {
            $Data{ $Row[0] } = 1;
        }

        # process result
        if (
            %Data
            && scalar( keys( %Data ) )
        ) {
            # check if entry should be fixed
            if (
                $Param{Fixes}->{'CustomerUserData'}
                && $QueryMap{ $Query }->{FixSQL}
            ) {
                # execute fix statement
                return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
                    SQL  => $QueryMap{ $Query }->{FixSQL},
                );

                if ( $QueryMap{ $Query }->{Create} ) {
                    if ( $QueryMap{ $Query }->{Create} eq 'CustomerCompany' ) {
                        # prepare data
                        my %CustomerCompany = (
                            'Unbekannt' => {
                                CustomerID          => 'Unbekannt',
                                CustomerCompanyName => 'Unbekannt',
                                ValidID             => '1',
                            }
                        );

                        # add customer company 'Unbekannt'
                        $Self->_ProcessCustomerCompanyData(
                            CustomerCompany => \%CustomerCompany,
                            SkipExisting    => 1,
                            Silent          => 1,
                        );
                    }
                }

                $Self->Print('<green>' . scalar( keys( %Data ) ) . ' entries fixed</green>' . "\n");
            }
            else {
                if ( $Param{Verbose} ) {
                    $Self->Print("\n" . '<red>Entries to fix:</red> (' . scalar( keys( %Data ) ) . ')' . "\n");

                    for my $CustomerUserLogin ( sort( keys( %Data ) ) ) {
                        $Self->Print($CustomerUserLogin . "\n");
                    }
                }
                else {
                    $Self->Print('<red>' . scalar( keys( %Data ) ) . ' entries should be fixed</red>' . "\n");
                }
            }
        }
        else {
            $Self->Print('<green>Nothing to do</green>' . "\n");
        }
    }

    return 1;
}

sub _CheckCustomerUserEmail {
    my ( $Self, %Param ) = @_;

    $Self->Print('<yellow>CustomerUserEmail</yellow> - Check customer user email of internal database table to be unique' . "\n");

    # skip this step if fixes are given, but this one is irrelevant
    if (
        IsHashRefWithData( $Param{Fixes} )
        && !$Param{Fixes}->{'CustomerUserEmail'}
    ) {
        $Self->Print('<green> - Skip, irrelevant step for this fix run</green>' . "\n");
        return 1;
    }

    # prepare db handle
    return if !$Kernel::OM->Get('Kernel::System::DB')->Prepare(
        SQL => 'SELECT id, lower(email) FROM customer_user',
    );

    # fetch data
    my %Data  = ();
    my %Exist = ();
    while ( my @Row = $Kernel::OM->Get('Kernel::System::DB')->FetchrowArray() ) {
        $Data{ $Row[0] }  = lc( $Row[1] );
        $Exist{ lc( $Row[1] ) } = 1;
    }
    
    # process data
    my %Lookup = ();
    my $Count  = 0;
    for my $DataID ( sort( keys( %Data ) ) ) {
        next if ( !$Data{ $DataID } );

        if ( !$Lookup{ $Data{ $DataID } } ) {
            $Lookup{ $Data{ $DataID } } = 1;
        }
        else {
            if ( $Lookup{ $Data{ $DataID } } == 1 ) {
                if (
                    $Count == 0
                    && $Param{Verbose}
                ) {
                    $Self->Print('<red> - Multiple used email addresses:</red>' . "\n");
                }
                $Count += 2;

                if (
                    !$Param{Fixes}->{'CustomerUserEmail'}
                    && $Param{Verbose}
                ) {
                    $Self->Print($Data{ $DataID } . "\n");
                }
            }
            else {
                $Count += 1;
            }

            $Lookup{ $Data{ $DataID } } += 1;

            if ( $Param{Fixes}->{'CustomerUserEmail'} ) {
                # init prefix count
                my $PrefixCount = 1;

                # split old mail
                my ( $Prefix, $Suffix ) = split( '@', $Data{ $DataID }, 2 );

                # prepare new mail
                my $NewEmail;
                do {
                    $NewEmail = $Prefix . '-' . $PrefixCount . '@' . $Suffix;

                    $PrefixCount += 1;
                } while (
                    $Lookup{ $NewEmail }
                    || $Exist{ $NewEmail }
                );

                # prepare bind
                my @Bind = ( \$NewEmail, \$DataID );

                # execute fix statement
                return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
                    SQL  => 'UPDATE customer_user SET email = ? WHERE id = ?',
                    Bind => \@Bind,
                );

                # remember new email
                $Lookup{ $NewEmail } = 1;
            }
        }
    }

    # check process result
    if ( $Count ) {
        if ( $Param{Fixes}->{'CustomerUserEmail'} ) {
            $Self->Print('<green> - ' . $Count . ' entries fixed</green>' . "\n");
        }
        else {
            $Self->Print('<red> - ' . $Count . ' entries should be fixed</red>' . "\n");
        }
    }
    else {
        $Self->Print('<green> - No duplicated emails</green>' . "\n");
    }

    return 1;
}

sub _CheckCustomerCompanyData {
    my ( $Self, %Param ) = @_;

    $Self->Print('<yellow>CustomerCompanyData</yellow> - Check customer company data of backends' . "\n");

    # skip this step if fixes are given, but this one is irrelevant
    if (
        IsHashRefWithData( $Param{Fixes} )
        && !$Param{Fixes}->{'CustomerCompanyData'}
    ) {
        $Self->Print('<green> - Skip, irrelevant step for this fix run</green>' . "\n");
        return 1;
    }

    $Self->Print('<yellow> - unknown customer companies in customer user backends: </yellow>');

    # get list of customer company ids from customer user backends
    my @CustomerCompanyIDsByCustomerUser = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerIDList(
        Valid => 0,
    );

    # get list of customer company ids from customer company backends
    my %CustomerCompanyIDsByCustomerCompany = $Kernel::OM->Get('Kernel::System::CustomerCompany')->CustomerCompanyList(
        Valid => 0,
        Limit => 0,
    );

    # process customer company ids from customer user backends
    my $Count = 0;
    ID:
    for my $CustomerCompanyID ( @CustomerCompanyIDsByCustomerUser ) {
        # skip known customer companies
        next ID if ( $CustomerCompanyIDsByCustomerCompany{ $CustomerCompanyID } );

        # check if entry should be fixed
        if ( $Param{Fixes}->{'CustomerCompanyData'} ) {
            # add customer company
            return if !$Kernel::OM->Get('Kernel::System::CustomerCompany')->CustomerCompanyAdd(
                CustomerID          => $CustomerCompanyID,
                CustomerCompanyName => $CustomerCompanyID,
                ValidID             => 1,
                UserID              => 1,
            );
        }
        elsif( $Param{Verbose} ) {
            if ( $Count == 0 ) {
                $Self->Print('<red>Unknown customer company ids:</red>' . "\n");
            }
            $Self->Print($CustomerCompanyID . "\n");
        }

        # increment count
        $Count += 1;
    }

    # check process result
    if ( $Count ) {
        if ( $Param{Fixes}->{'CustomerCompanyData'} ) {
            $Self->Print('<green>' . $Count . ' entries fixed</green>' . "\n");
        }
        else {
            $Self->Print('<red>' . $Count . ' entries should be fixed</red>' . "\n");
        }
    }
    else {
        $Self->Print('<green>No unknown customer companies</green>' . "\n");
    }

    return 1;
}

sub _CheckUserExists {
    my ( $Self, %Param ) = @_;

    $Self->Print('<yellow>UserExists</yellow> - Check all used users exist' . "\n");

    # skip this step if fixes are given, but this one is irrelevant
    if (
        IsHashRefWithData( $Param{Fixes} )
        && !$Param{Fixes}->{'UserExists'}
    ) {
        $Self->Print('<green> - Skip, irrelevant step for this fix run</green>' . "\n");
        return 1;
    }

    # get all table names from DB
    my $TablesRef = $Self->_GetDBTables();

    # init map to fix by deleting entries
    my %DeleteMap = (
        '0001' => {
            'Table'  => 'user_preferences',
            'Column' => 'user_id',
        },
        '0002' => {
            'Table'  => 'group_user',
            'Column' => 'user_id',
        },
        '0003' => {
            'Table'  => 'role_user',
            'Column' => 'user_id',
        },
        '0004' => {
            'Table'  => 'personal_queues',
            'Column' => 'user_id',
        },
        '0005' => {
            'Table'  => 'personal_services',
            'Column' => 'user_id',
        },
        '0006' => {
            'Table'  => 'ticket_flag',
            'Column' => 'create_by',
        },
        '0007' => {
            'Table'  => 'ticket_watcher',
            'Column' => 'user_id',
        },
        '0008' => {
            'Table'  => 'article_flag',
            'Column' => 'create_by',
        },
        '0009' => {
            'Table'  => 'kix_article_flag',
            'Column' => 'create_by',
        },
        '0010' => {
            'Table'  => 'overlay_agent',
            'Column' => 'user_id',
        },
    );

    # init map to fix by setting root
    my %SetRootMap = (
        '0001' => {
            'Table'  => 'acl',
            'Column' => 'create_by',
        },
        '0002' => {
            'Table'  => 'acl',
            'Column' => 'change_by',
        },
        '0003' => {
            'Table'  => 'valid',
            'Column' => 'create_by',
        },
        '0004' => {
            'Table'  => 'valid',
            'Column' => 'change_by',
        },
        '0005' => {
            'Table'  => 'users',
            'Column' => 'create_by',
        },
        '0006' => {
            'Table'  => 'users',
            'Column' => 'change_by',
        },
        '0007' => {
            'Table'  => 'groups',
            'Column' => 'create_by',
        },
        '0008' => {
            'Table'  => 'groups',
            'Column' => 'change_by',
        },
        '0009' => {
            'Table'  => 'group_user',
            'Column' => 'create_by',
        },
        '0010' => {
            'Table'  => 'group_user',
            'Column' => 'change_by',
        },
        '0011' => {
            'Table'  => 'group_role',
            'Column' => 'create_by',
        },
        '0012' => {
            'Table'  => 'group_role',
            'Column' => 'change_by',
        },
        '0013' => {
            'Table'  => 'group_customer_user',
            'Column' => 'create_by',
        },
        '0014' => {
            'Table'  => 'group_customer_user',
            'Column' => 'change_by',
        },
        '0015' => {
            'Table'  => 'roles',
            'Column' => 'create_by',
        },
        '0016' => {
            'Table'  => 'roles',
            'Column' => 'change_by',
        },
        '0017' => {
            'Table'  => 'role_user',
            'Column' => 'create_by',
        },
        '0018' => {
            'Table'  => 'role_user',
            'Column' => 'change_by',
        },
        '0019' => {
            'Table'  => 'salutation',
            'Column' => 'create_by',
        },
        '0020' => {
            'Table'  => 'salutation',
            'Column' => 'change_by',
        },
        '0021' => {
            'Table'  => 'signature',
            'Column' => 'create_by',
        },
        '0022' => {
            'Table'  => 'signature',
            'Column' => 'change_by',
        },
        '0023' => {
            'Table'  => 'system_address',
            'Column' => 'create_by',
        },
        '0024' => {
            'Table'  => 'system_address',
            'Column' => 'change_by',
        },
        '0025' => {
            'Table'  => 'system_maintenance',
            'Column' => 'create_by',
        },
        '0026' => {
            'Table'  => 'system_maintenance',
            'Column' => 'change_by',
        },
        '0027' => {
            'Table'  => 'follow_up_possible',
            'Column' => 'create_by',
        },
        '0028' => {
            'Table'  => 'follow_up_possible',
            'Column' => 'change_by',
        },
        '0029' => {
            'Table'  => 'queue',
            'Column' => 'create_by',
        },
        '0030' => {
            'Table'  => 'queue',
            'Column' => 'change_by',
        },
        '0031' => {
            'Table'  => 'ticket_priority',
            'Column' => 'create_by',
        },
        '0032' => {
            'Table'  => 'ticket_priority',
            'Column' => 'change_by',
        },
        '0033' => {
            'Table'  => 'ticket_type',
            'Column' => 'create_by',
        },
        '0034' => {
            'Table'  => 'ticket_type',
            'Column' => 'change_by',
        },
        '0035' => {
            'Table'  => 'ticket_lock_type',
            'Column' => 'create_by',
        },
        '0036' => {
            'Table'  => 'ticket_lock_type',
            'Column' => 'change_by',
        },
        '0037' => {
            'Table'  => 'ticket_state',
            'Column' => 'create_by',
        },
        '0038' => {
            'Table'  => 'ticket_state',
            'Column' => 'change_by',
        },
        '0039' => {
            'Table'  => 'ticket_state_type',
            'Column' => 'create_by',
        },
        '0040' => {
            'Table'  => 'ticket_state_type',
            'Column' => 'change_by',
        },
        '0041' => {
            'Table'  => 'ticket',
            'Column' => 'create_by',
        },
        '0042' => {
            'Table'  => 'ticket',
            'Column' => 'change_by',
        },
        '0043' => {
            'Table'  => 'ticket',
            'Column' => 'user_id',
        },
        '0044' => {
            'Table'  => 'ticket',
            'Column' => 'responsible_user_id',
        },
        '0045' => {
            'Table'  => 'ticket_history',
            'Column' => 'owner_id',
        },
        '0046' => {
            'Table'  => 'ticket_history',
            'Column' => 'create_by',
        },
        '0047' => {
            'Table'  => 'ticket_history',
            'Column' => 'change_by',
        },
        '0048' => {
            'Table'  => 'ticket_history_type',
            'Column' => 'create_by',
        },
        '0049' => {
            'Table'  => 'ticket_history_type',
            'Column' => 'change_by',
        },
        '0050' => {
            'Table'  => 'ticket_watcher',
            'Column' => 'create_by',
        },
        '0051' => {
            'Table'  => 'ticket_watcher',
            'Column' => 'change_by',
        },
        '0052' => {
            'Table'  => 'article_type',
            'Column' => 'create_by',
        },
        '0053' => {
            'Table'  => 'article_type',
            'Column' => 'change_by',
        },
        '0054' => {
            'Table'  => 'article_sender_type',
            'Column' => 'create_by',
        },
        '0055' => {
            'Table'  => 'article_sender_type',
            'Column' => 'change_by',
        },
        '0056' => {
            'Table'  => 'article',
            'Column' => 'create_by',
        },
        '0057' => {
            'Table'  => 'article',
            'Column' => 'change_by',
        },
        '0058' => {
            'Table'  => 'article_plain',
            'Column' => 'create_by',
        },
        '0059' => {
            'Table'  => 'article_plain',
            'Column' => 'change_by',
        },
        '0060' => {
            'Table'  => 'article_attachment',
            'Column' => 'create_by',
        },
        '0061' => {
            'Table'  => 'article_attachment',
            'Column' => 'change_by',
        },
        '0062' => {
            'Table'  => 'time_accounting',
            'Column' => 'create_by',
        },
        '0063' => {
            'Table'  => 'time_accounting',
            'Column' => 'change_by',
        },
        '0064' => {
            'Table'  => 'standard_template',
            'Column' => 'create_by',
        },
        '0065' => {
            'Table'  => 'standard_template',
            'Column' => 'change_by',
        },
        '0066' => {
            'Table'  => 'queue_standard_template',
            'Column' => 'create_by',
        },
        '0067' => {
            'Table'  => 'queue_standard_template',
            'Column' => 'change_by',
        },
        '0068' => {
            'Table'  => 'standard_attachment',
            'Column' => 'create_by',
        },
        '0069' => {
            'Table'  => 'standard_attachment',
            'Column' => 'change_by',
        },
        '0070' => {
            'Table'  => 'standard_template_attachment',
            'Column' => 'create_by',
        },
        '0071' => {
            'Table'  => 'standard_template_attachment',
            'Column' => 'change_by',
        },
        '0072' => {
            'Table'  => 'auto_response_type',
            'Column' => 'create_by',
        },
        '0073' => {
            'Table'  => 'auto_response_type',
            'Column' => 'change_by',
        },
        '0074' => {
            'Table'  => 'auto_response',
            'Column' => 'create_by',
        },
        '0075' => {
            'Table'  => 'auto_response',
            'Column' => 'change_by',
        },
        '0076' => {
            'Table'  => 'queue_auto_response',
            'Column' => 'create_by',
        },
        '0077' => {
            'Table'  => 'queue_auto_response',
            'Column' => 'change_by',
        },
        '0078' => {
            'Table'  => 'service',
            'Column' => 'create_by',
        },
        '0079' => {
            'Table'  => 'service',
            'Column' => 'change_by',
        },
        '0080' => {
            'Table'  => 'service_customer_user',
            'Column' => 'create_by',
        },
        '0081' => {
            'Table'  => 'sla',
            'Column' => 'create_by',
        },
        '0082' => {
            'Table'  => 'sla',
            'Column' => 'change_by',
        },
        '0083' => {
            'Table'  => 'customer_user',
            'Column' => 'create_by',
        },
        '0084' => {
            'Table'  => 'customer_user',
            'Column' => 'change_by',
        },
        '0085' => {
            'Table'  => 'customer_company',
            'Column' => 'create_by',
        },
        '0086' => {
            'Table'  => 'customer_company',
            'Column' => 'change_by',
        },
        '0087' => {
            'Table'  => 'oauth2_profile',
            'Column' => 'create_by',
        },
        '0088' => {
            'Table'  => 'oauth2_profile',
            'Column' => 'change_by',
        },
        '0089' => {
            'Table'  => 'mail_account',
            'Column' => 'create_by',
        },
        '0090' => {
            'Table'  => 'mail_account',
            'Column' => 'change_by',
        },
        '0091' => {
            'Table'  => 'notification_event',
            'Column' => 'create_by',
        },
        '0092' => {
            'Table'  => 'notification_event',
            'Column' => 'change_by',
        },
        '0093' => {
            'Table'  => 'link_type',
            'Column' => 'create_by',
        },
        '0094' => {
            'Table'  => 'link_type',
            'Column' => 'change_by',
        },
        '0095' => {
            'Table'  => 'link_state',
            'Column' => 'create_by',
        },
        '0096' => {
            'Table'  => 'link_state',
            'Column' => 'change_by',
        },
        '0097' => {
            'Table'  => 'link_relation',
            'Column' => 'create_by',
        },
        '0098' => {
            'Table'  => 'system_data',
            'Column' => 'create_by',
        },
        '0099' => {
            'Table'  => 'system_data',
            'Column' => 'change_by',
        },
        '0100' => {
            'Table'  => 'package_repository',
            'Column' => 'create_by',
        },
        '0101' => {
            'Table'  => 'package_repository',
            'Column' => 'change_by',
        },
        '0102' => {
            'Table'  => 'gi_webservice_config',
            'Column' => 'create_by',
        },
        '0103' => {
            'Table'  => 'gi_webservice_config',
            'Column' => 'change_by',
        },
        '0104' => {
            'Table'  => 'gi_webservice_config_history',
            'Column' => 'create_by',
        },
        '0105' => {
            'Table'  => 'gi_webservice_config_history',
            'Column' => 'change_by',
        },
        '0106' => {
            'Table'  => 'smime_signer_cert_relations',
            'Column' => 'create_by',
        },
        '0107' => {
            'Table'  => 'smime_signer_cert_relations',
            'Column' => 'change_by',
        },
        '0108' => {
            'Table'  => 'dynamic_field',
            'Column' => 'create_by',
        },
        '0109' => {
            'Table'  => 'dynamic_field',
            'Column' => 'change_by',
        },
        '0110' => {
            'Table'  => 'pm_process',
            'Column' => 'create_by',
        },
        '0111' => {
            'Table'  => 'pm_process',
            'Column' => 'change_by',
        },
        '0112' => {
            'Table'  => 'pm_activity',
            'Column' => 'create_by',
        },
        '0113' => {
            'Table'  => 'pm_activity',
            'Column' => 'change_by',
        },
        '0114' => {
            'Table'  => 'pm_activity_dialog',
            'Column' => 'create_by',
        },
        '0115' => {
            'Table'  => 'pm_activity_dialog',
            'Column' => 'change_by',
        },
        '0116' => {
            'Table'  => 'pm_transition',
            'Column' => 'create_by',
        },
        '0117' => {
            'Table'  => 'pm_transition',
            'Column' => 'change_by',
        },
        '0118' => {
            'Table'  => 'pm_transition_action',
            'Column' => 'create_by',
        },
        '0119' => {
            'Table'  => 'pm_transition_action',
            'Column' => 'change_by',
        },
        '0120' => {
            'Table'  => 'faq_category',
            'Column' => 'created_by',
        },
        '0121' => {
            'Table'  => 'faq_category',
            'Column' => 'changed_by',
        },
        '0122' => {
            'Table'  => 'faq_category_group',
            'Column' => 'created_by',
        },
        '0123' => {
            'Table'  => 'faq_category_group',
            'Column' => 'changed_by',
        },
        '0124' => {
            'Table'  => 'faq_item',
            'Column' => 'created_by',
        },
        '0125' => {
            'Table'  => 'faq_item',
            'Column' => 'changed_by',
        },
        '0126' => {
            'Table'  => 'faq_history',
            'Column' => 'created_by',
        },
        '0127' => {
            'Table'  => 'faq_history',
            'Column' => 'changed_by',
        },
        '0128' => {
            'Table'  => 'faq_attachment',
            'Column' => 'created_by',
        },
        '0129' => {
            'Table'  => 'faq_attachment',
            'Column' => 'changed_by',
        },
        '0130' => {
            'Table'  => 'general_catalog',
            'Column' => 'create_by',
        },
        '0131' => {
            'Table'  => 'general_catalog',
            'Column' => 'change_by',
        },
        '0132' => {
            'Table'  => 'imexport_template',
            'Column' => 'create_by',
        },
        '0133' => {
            'Table'  => 'imexport_template',
            'Column' => 'change_by',
        },
        '0134' => {
            'Table'  => 'cip_allocate',
            'Column' => 'create_by',
        },
        '0135' => {
            'Table'  => 'cip_allocate',
            'Column' => 'change_by',
        },
        '0136' => {
            'Table'  => 'configitem',
            'Column' => 'create_by',
        },
        '0137' => {
            'Table'  => 'configitem',
            'Column' => 'change_by',
        },
        '0138' => {
            'Table'  => 'configitem_definition',
            'Column' => 'create_by',
        },
        '0139' => {
            'Table'  => 'configitem_version',
            'Column' => 'create_by',
        },
        '0140' => {
            'Table'  => 'configitem_history_type',
            'Column' => 'create_by',
        },
        '0141' => {
            'Table'  => 'configitem_history_type',
            'Column' => 'change_by',
        },
        '0142' => {
            'Table'  => 'configitem_history',
            'Column' => 'create_by',
        },
        '0143' => {
            'Table'  => 'attachment_directory',
            'Column' => 'create_by',
        },
        '0144' => {
            'Table'  => 'attachment_directory',
            'Column' => 'change_by',
        },
        '0145' => {
            'Table'  => 'kix_dep_dynamic_field',
            'Column' => 'create_by',
        },
        '0146' => {
            'Table'  => 'kix_dep_dynamic_field',
            'Column' => 'change_by',
        },
        '0147' => {
            'Table'  => 'kix_text_module',
            'Column' => 'create_by',
        },
        '0148' => {
            'Table'  => 'kix_text_module',
            'Column' => 'change_by',
        },
        '0149' => {
            'Table'  => 'kix_text_module_object_link',
            'Column' => 'create_by',
        },
        '0150' => {
            'Table'  => 'kix_text_module_object_link',
            'Column' => 'change_by',
        },
        '0151' => {
            'Table'  => 'kix_ticket_notes',
            'Column' => 'create_by',
        },
        '0152' => {
            'Table'  => 'kix_ticket_notes',
            'Column' => 'change_by',
        },
        '0153' => {
            'Table'  => 'kix_ticket_template',
            'Column' => 'create_by',
        },
        '0154' => {
            'Table'  => 'kix_ticket_template',
            'Column' => 'change_by',
        },
        '0155' => {
            'Table'  => 'kix_text_module_category',
            'Column' => 'create_by',
        },
        '0156' => {
            'Table'  => 'kix_text_module_category',
            'Column' => 'change_by',
        },
        '0157' => {
            'Table'  => 'kix_link_graph',
            'Column' => 'create_by',
        },
        '0158' => {
            'Table'  => 'kix_link_graph',
            'Column' => 'change_by',
        },
        '0159' => {
            'Table'  => 'customer_portal_group',
            'Column' => 'create_by',
        },
        '0160' => {
            'Table'  => 'customer_portal_group',
            'Column' => 'change_by',
        },
        '0161' => {
            'Table'  => 'kix_quick_state',
            'Column' => 'create_by',
        },
        '0162' => {
            'Table'  => 'kix_quick_state',
            'Column' => 'change_by',
        },
        '0163' => {
            'Table'  => 'kix_quick_state_attachment',
            'Column' => 'create_by',
        },
        '0164' => {
            'Table'  => 'kix_quick_state_attachment',
            'Column' => 'change_by',
        },
        '0165' => {
            'Table'  => 'kix_system_message',
            'Column' => 'create_by',
        },
        '0166' => {
            'Table'  => 'kix_system_message',
            'Column' => 'change_by',
        },
        '0167' => {
            'Table'  => 'conversation_guides',
            'Column' => 'create_by',
        },
        '0168' => {
            'Table'  => 'conversation_guides',
            'Column' => 'change_by',
        },
        '0169' => {
            'Table'  => 'conversation_guides_response',
            'Column' => 'create_by',
        },
        '0170' => {
            'Table'  => 'conversation_guides_version',
            'Column' => 'create_by',
        },
        '0171' => {
            'Table'  => 'conversation_guides_version',
            'Column' => 'change_by',
        },
        '0172' => {
            'Table'  => 'logbook',
            'Column' => 'create_by',
        },
        '0173' => {
            'Table'  => 'logbook',
            'Column' => 'change_by',
        },
        '0174' => {
            'Table'  => 'logbook_class',
            'Column' => 'create_by',
        },
        '0175' => {
            'Table'  => 'fieldservice_tour',
            'Column' => 'assigned_user_id',
        },
        '0176' => {
            'Table'  => 'fieldservice_tour',
            'Column' => 'responsible_user_id',
        },
        '0177' => {
            'Table'  => 'fieldservice_tour',
            'Column' => 'create_by',
        },
        '0178' => {
            'Table'  => 'fieldservice_tour',
            'Column' => 'change_by',
        },
    );

    # prepare db handle
    return if !$Kernel::OM->Get('Kernel::System::DB')->Prepare(
        SQL => 'SELECT id FROM users ORDER BY id ASC',
    );

    # fetch data
    my @UserIDs = ();
    while ( my @Row = $Kernel::OM->Get('Kernel::System::DB')->FetchrowArray() ) {
        push( @UserIDs, $Row[0] );
    }

    # init hash for prepared conditions
    my %ConditionHash = ();

    # process delete queries
    for my $Query ( sort( keys( %DeleteMap ) ) ) {
        # check if table exists
        next if ( !$TablesRef->{ $DeleteMap{ $Query }->{Table} } );

        if ( !defined( $ConditionHash{ $DeleteMap{ $Query }->{Column} } ) ) {
            my @SQLStrings  = ();
            my @TempUserIDs = @UserIDs;
            while ( scalar( @TempUserIDs ) ) {

                # remove section in the array
                my @UserIDsPart = splice( @TempUserIDs, 0, 900 );

                # link together IDs
                my $IDString = join( ', ', @UserIDsPart );

                # prepare sql condition
                my $SQLString = $DeleteMap{ $Query }->{Column} . ' NOT IN (' . $IDString . ')';

                # add new statement
                push( @SQLStrings, $SQLString );
            }
            if ( scalar( @SQLStrings ) ) {
                # combine statements
                $ConditionHash{ $DeleteMap{ $Query }->{Column} } = join( ' AND ', @SQLStrings );
            }
        }

        # prepare sql for selection
        my $SelectSQL = 'SELECT ' . $DeleteMap{ $Query }->{Column} . ' FROM ' . $DeleteMap{ $Query }->{Table} . ' WHERE ' . $ConditionHash{ $DeleteMap{ $Query }->{Column} };

        # prepare db handle
        return if !$Kernel::OM->Get('Kernel::System::DB')->Prepare(
            SQL => $SelectSQL,
        );

        # fetch data
        my %Data = ();
        while ( my @Row = $Kernel::OM->Get('Kernel::System::DB')->FetchrowArray() ) {
            $Data{ $Row[0] } = 1;
        }

        # process result
        if (
            %Data
            && scalar( keys( %Data ) )
        ) {
            # check if entry should be fixed
            if ( $Param{Fixes}->{'UserExists'} ) {
                # prepare sql for fix
                my $FixSQL = 'DELETE FROM ' . $DeleteMap{ $Query }->{Table} . ' WHERE ' . $ConditionHash{ $DeleteMap{ $Query }->{Column} };

                # execute fix statement
                return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
                    SQL  => $FixSQL,
                );

                $Self->Print('<yellow> - ' . $DeleteMap{ $Query }->{Table} . ' / ' . $DeleteMap{ $Query }->{Column} . ': </yellow><green>Entries fixed (Deleted)</green>' . "\n");
            }
            else {
                if ( $Param{Verbose} ) {
                    $Self->Print('<yellow> - ' . $DeleteMap{ $Query }->{Table} . ' / ' . $DeleteMap{ $Query }->{Column} . ' (Delete Entries) </yellow>' . "\n" . '<red>Entries to fix:</red> (' . scalar( keys( %Data ) ) . ')' . "\n");

                    for my $UserID ( sort( keys( %Data ) ) ) {
                        $Self->Print($UserID . "\n");
                    }
                }
            }
        }
    }

    # process set root queries
    my $NewUserID = 1;
    for my $Query ( sort( keys( %SetRootMap ) ) ) {
        # check if table exists
        next if ( !$TablesRef->{ $SetRootMap{ $Query }->{Table} } );

        if ( !defined( $ConditionHash{ $SetRootMap{ $Query }->{Column} } ) ) {
            my @SQLStrings  = ();
            my @TempUserIDs = @UserIDs;
            while ( scalar( @TempUserIDs ) ) {

                # remove section in the array
                my @UserIDsPart = splice( @TempUserIDs, 0, 900 );

                # link together IDs
                my $IDString = join( ', ', @UserIDsPart );

                # prepare sql condition
                my $SQLString = $SetRootMap{ $Query }->{Column} . ' NOT IN (' . $IDString . ')';

                # add new statement
                push( @SQLStrings, $SQLString );
            }
            if ( scalar( @SQLStrings ) ) {
                # combine statements
                $ConditionHash{ $SetRootMap{ $Query }->{Column} } = join( ' AND ', @SQLStrings );
            }
        }

        # prepare sql for selection
        my $SelectSQL = 'SELECT ' . $SetRootMap{ $Query }->{Column} . ' FROM ' . $SetRootMap{ $Query }->{Table} . ' WHERE ' . $ConditionHash{ $SetRootMap{ $Query }->{Column} };

        # prepare db handle
        return if !$Kernel::OM->Get('Kernel::System::DB')->Prepare(
            SQL => $SelectSQL,
        );

        # fetch data
        my %Data = ();
        while ( my @Row = $Kernel::OM->Get('Kernel::System::DB')->FetchrowArray() ) {
            $Data{ $Row[0] } = 1;
        }

        # process result
        if (
            %Data
            && scalar( keys( %Data ) )
        ) {
            # check if entry should be fixed
            if ( $Param{Fixes}->{'UserExists'} ) {
                # prepare sql for fix
                my $FixSQL = 'UPDATE ' . $SetRootMap{ $Query }->{Table} . ' SET ' . $SetRootMap{ $Query }->{Column} . ' = ? WHERE ' . $ConditionHash{ $SetRootMap{ $Query }->{Column} };

                # prepare bind
                my @FixBind = ( \$NewUserID );

                # execute fix statement
                return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
                    SQL  => $FixSQL,
                    Bind => \@FixBind,
                );

                $Self->Print('<yellow> - ' . $SetRootMap{ $Query }->{Table} . ' / ' . $SetRootMap{ $Query }->{Column} . ': </yellow><green>Entries fixed (Set to ID 1)</green>' . "\n");
            }
            else {
                if ( $Param{Verbose} ) {
                    $Self->Print('<yellow> - ' . $SetRootMap{ $Query }->{Table} . ' / ' . $SetRootMap{ $Query }->{Column} . ' (Set to ID 1)</yellow>' . "\n" . '<red>Entries to fix:</red> (' . scalar( keys( %Data ) ) . ')' . "\n");

                    for my $UserID ( sort( keys( %Data ) ) ) {
                        $Self->Print($UserID . "\n");
                    }
                }
            }
        }
    }

    $Self->Print('<green>Done</green>' . "\n");

    return 1;
}

sub _CheckUserEmail {
    my ( $Self, %Param ) = @_;

    $Self->Print('<yellow>UserEmail</yellow> - Check user email of internal database table to be unique' . "\n");

    # skip this step if fixes are given, but this one is irrelevant
    if (
        IsHashRefWithData( $Param{Fixes} )
        && !$Param{Fixes}->{'UserEmail'}
    ) {
        $Self->Print('<green> - Skip, irrelevant step for this fix run</green>' . "\n");
        return 1;
    }

    # prepare db handle
    my $PrefKey    = 'UserEmail';
    my @SelectBind = ( \$PrefKey );
    return if !$Kernel::OM->Get('Kernel::System::DB')->Prepare(
        SQL  => 'SELECT user_id, lower(preferences_value) FROM user_preferences WHERE preferences_key = ?',
        Bind => \@SelectBind,
    );

    # fetch data
    my %Data  = ();
    my %Exist = ();
    while ( my @Row = $Kernel::OM->Get('Kernel::System::DB')->FetchrowArray() ) {
        $Data{ $Row[0] }  = lc( $Row[1] );
        $Exist{ lc( $Row[1] ) } = 1;
    }
    
    # process data
    my %Lookup = ();
    my $Count  = 0;
    for my $DataID ( sort( keys( %Data ) ) ) {
        next if ( !$Data{ $DataID } );

        if ( !$Lookup{ $Data{ $DataID } } ) {
            $Lookup{ $Data{ $DataID } } = 1;
        }
        else {
            if ( $Lookup{ $Data{ $DataID } } == 1 ) {
                if (
                    $Count == 0
                    && $Param{Verbose}
                ) {
                    $Self->Print('<red> - Multiple used email addresses:</red>' . "\n");
                }
                $Count += 2;

                if (
                    !$Param{Fixes}->{'UserEmail'}
                    && $Param{Verbose}
                ) {
                    $Self->Print($Data{ $DataID } . "\n");
                }
            }
            else {
                $Count += 1;
            }

            $Lookup{ $Data{ $DataID } } += 1;

            if ( $Param{Fixes}->{'UserEmail'} ) {
                # init prefix count
                my $PrefixCount = 1;

                # split old mail
                my ( $Prefix, $Suffix ) = split( '@', $Data{ $DataID }, 2 );

                # prepare new mail
                my $NewEmail;
                do {
                    $NewEmail = $Prefix . '-' . $PrefixCount . '@' . $Suffix;

                    $PrefixCount += 1;
                } while (
                    $Lookup{ $NewEmail }
                    || $Exist{ $NewEmail }
                );

                # prepare bind
                my @Bind = ( \$NewEmail, \$DataID, \$PrefKey );

                # execute fix statement
                return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
                    SQL  => 'UPDATE user_preferences SET preferences_value = ? WHERE user_id = ? AND preferences_key = ?',
                    Bind => \@Bind,
                );

                # remember new email
                $Lookup{ $NewEmail } = 1;
            }
        }
    }

    # check process result
    if ( $Count ) {
        if ( $Param{Fixes}->{'UserEmail'} ) {
            $Self->Print('<green> - ' . $Count . ' entries fixed</green>' . "\n");
        }
        else {
            $Self->Print('<red> - ' . $Count . ' entries should be fixed</red>' . "\n");
        }
    }
    else {
        $Self->Print('<green> - No duplicated emails</green>' . "\n");
    }

    return 1;
}

sub _UpdateTicketCustomerUser {
    my ( $Self, %Param ) = @_;

    $Self->Print('<yellow>TicketCustomerUserUpdate</yellow> - Update ticket customer user' . "\n");

    # skip this step if fixes are given, but this one is irrelevant
    if (
        IsHashRefWithData( $Param{Fixes} )
        && !$Param{Fixes}->{'TicketCustomerUserUpdate'}
    ) {
        $Self->Print('<green> - Skip, irrelevant step for this fix run</green>' . "\n");
        return 1;
    }

    if ( $Param{Fixes}->{'TicketCustomerUserUpdate'} ) {

        $Self->Print('<yellow> - get all ticket ids: </yellow>');

        # prepare sql statement to get ticket ids with customer user and customer company
        my $SQL = "SELECT id, customer_user_id, customer_id FROM ticket";
        $Kernel::OM->Get('Kernel::System::DB')->Prepare(
            SQL => $SQL
        );

        # get ticket ids with customer user and customer company
        my %TicketCustomerHash;
        while ( my @Row = $Kernel::OM->Get('Kernel::System::DB')->FetchrowArray() ) {
            $TicketCustomerHash{ $Row[0] } = {
                CustomerUserID => $Row[1],
                CustomerID     => $Row[2]
            };
        }

        $Self->Print('<green>Done</green>' . "\n");

        $Self->Print('<yellow> - update tickets: </yellow>' . "\n");

        # process tickets
        my %CustomerUserCache;
        my %CustomerUserSkip;
        my $Count = 0;
        my $TicketCount = scalar( keys( %TicketCustomerHash ) );
        TICKETID:
        for my $TicketID ( sort( keys( %TicketCustomerHash ) ) ) {
            $Count += 1;
            if ( $Count % 2000 == 0 ) {
                my $Percent = int( $Count / ( $TicketCount / 100 ) );
                $Self->Print(' - - <yellow>' . $Count . '</yellow> of <yellow>' . $TicketCount . '</yellow> processed (<yellow>' . $Percent . '%</yellow>)' . "\n");
            }

            my $CustomerUserID = $TicketCustomerHash{ $TicketID }->{CustomerUserID};

            # check for empty customer user to skip
            next TICKETID if ( !$CustomerUserID );

            # check for unknown customer user to skip
            next TICKETID if ( $CustomerUserSkip{ $CustomerUserID } );

            # check if customer user is already cached
            if ( ref( $CustomerUserCache{ $CustomerUserID } ) ne 'HASH' ) {
                # get customer user data
                my %CustomerUserData = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerUserDataGet(
                    User => $CustomerUserID,
                );

                if ( !%CustomerUserData ) {
                    # try to find customer user via email
                    my %CustomerUserList = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerSearch(
                        PostMasterSearch => $CustomerUserID,
                        Valid            => 0,
                        Limit            => 1,
                    );

                    # unique customer user found
                    if ( %CustomerUserList ) {
                        for my $EmailCustomerUserID ( keys( %CustomerUserList ) ) {
                            # get customer user data
                            %CustomerUserData = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerUserDataGet(
                                User => $EmailCustomerUserID,
                            );

                            last;
                        }
                    }
                }

                if ( %CustomerUserData ) {
                    # cache customer user login to set for tickets
                    $CustomerUserCache{ $CustomerUserID }->{UserLogin} = $CustomerUserData{UserLogin};

                    # cache main customer id to set for tickets
                    $CustomerUserCache{ $CustomerUserID }->{CustomerID} = $CustomerUserData{UserCustomerID};

                    # cache main customer id as possible customer id
                    $CustomerUserCache{ $CustomerUserID }->{CustomerIDs}->{ $CustomerUserData{UserCustomerID} } = 1;

                    # get customer ids
                    my @CustomerIDs = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerIDs(
                        User => $CustomerUserData{UserLogin},
                    );

                    # add customer ids to possible list
                    for my $CustomerID ( @CustomerIDs ) {
                        $CustomerUserCache{ $CustomerUserID }->{CustomerIDs}->{ $CustomerID } = 1;
                    }
                }
                # if no entry is found, remember to skip
                else {
                    $CustomerUserSkip{ $CustomerUserID } = 1;

                    next TICKETID;
                }

            }

            # skip if ticket has already a valid customer set and correct customer user id
            my $CustomerID = $TicketCustomerHash{ $TicketID }->{CustomerID} || '';
            next TICKETID if (
                $CustomerUserID eq $CustomerUserCache{ $CustomerUserID }->{UserLogin}
                && $CustomerID
                && $CustomerUserCache{ $CustomerUserID }->{CustomerIDs}->{ $CustomerID }
            );

            # update customer
            $Kernel::OM->Get('Kernel::System::Ticket')->TicketCustomerSet(
                User     => $CustomerUserCache{ $CustomerUserID }->{UserLogin},
                No       => $CustomerUserCache{ $CustomerUserID }->{CustomerID},
                TicketID => $TicketID,
                UserID   => 1,
            );

            # discard ticket object to empty event queue every 100 changes
            if ( $Count % 100 == 0 ) {
                $Kernel::OM->ObjectsDiscard(
                    Objects => ['Kernel::System::Ticket'],
                );

                $Kernel::OM->Get('Kernel::System::Ticket') = $Kernel::OM->Get('Kernel::System::Ticket');
            }
        }

        $Self->Print('<green>Done</green>' . "\n");
    }
    else {
        $Self->Print('<green> - Only when using --fix for this step</green>' . "\n");
    }

    return 1;
}

sub _CheckTicketData {
    my ( $Self, %Param ) = @_;

    $Self->Print('<yellow>TicketData</yellow> - Check ticket data' . "\n");

    # skip this step if fixes are given, but this one is irrelevant
    if (
        IsHashRefWithData( $Param{Fixes} )
        && !$Param{Fixes}->{'TicketData'}
    ) {
        $Self->Print('<green> - Skip, irrelevant step for this fix run</green>' . "\n");
        return 1;
    }

    # init variables
    my $UserCustomerIDs = $Self->_ExistsDBCustomerIDsColumn();

    # init query map
    my %QueryMap = (
        '0001' => {
            'Label'     => 'tickets with same value for customer user and customer company',
            'SelectSQL' => 'SELECT id FROM ticket WHERE customer_user_id = customer_id AND customer_user_id != \'Unbekannt\'',
        },
        '0002' => {
            'Label'     => 'tickets without customer user',
            'SelectSQL' => 'SELECT id FROM ticket where customer_user_id = \'\' OR customer_user_id IS NULL',
            'FixSQL'    => 'UPDATE ticket SET customer_user_id = \'Unbekannt\' WHERE customer_user_id = \'\' OR customer_user_id IS NULL',
            'Create'    => 'CustomerUser',
        },
        '0003' => {
            'Label'     => 'tickets without customer company',
            'SelectSQL' => 'SELECT id FROM ticket WHERE customer_id = \'\' OR customer_id IS NULL',
            'FixSQL'    => 'UPDATE ticket SET customer_id = \'Unbekannt\' WHERE customer_id = \'\' OR customer_id IS NULL',
            'Create'    => 'CustomerCompany',
        },
    );

    # process queries
    for my $Query ( sort( keys( %QueryMap ) ) ) {
        $Self->Print('<yellow> - ' . $QueryMap{ $Query }->{Label} . ': </yellow>');

        # prepare db handle
        return if !$Kernel::OM->Get('Kernel::System::DB')->Prepare(
            SQL => $QueryMap{ $Query }->{SelectSQL},
        );

        # fetch data
        my %Data = ();
        while ( my @Row = $Kernel::OM->Get('Kernel::System::DB')->FetchrowArray() ) {
            $Data{ $Row[0] } = 1;
        }
        # process result
        if (
            %Data
            && scalar( keys( %Data ) )
        ) {
            # check if entry should be fixed
            if (
                $Param{Fixes}->{'TicketData'}
                && $QueryMap{ $Query }->{FixSQL}
            ) {
                # execute fix statement
                return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
                    SQL  => $QueryMap{ $Query }->{FixSQL},
                );

                $Self->Print('<green>' . scalar( keys( %Data ) ) . ' entries fixed</green>' . "\n");

                if ( $QueryMap{ $Query }->{Create} ) {
                    if ( $QueryMap{ $Query }->{Create} eq 'CustomerCompany' ) {
                        # prepare data
                        my %CustomerCompany = (
                            'Unbekannt' => {
                                CustomerID          => 'Unbekannt',
                                CustomerCompanyName => 'Unbekannt',
                                ValidID             => '1',
                            }
                        );

                        # add customer company 'Unbekannt'
                        $Self->_ProcessCustomerCompanyData(
                            CustomerCompany => \%CustomerCompany,
                            SkipExisting    => 1,
                        );
                    }
                    elsif ( $QueryMap{ $Query }->{Create} eq 'CustomerUser' ) {
                        # prepare data
                        my %CustomerUser = (
                            'Unbekannt' => {
                                UserFirstname   => 'Unbekannt',
                                UserLastname    => 'Unbekannt',
                                UserLogin       => 'Unbekannt',
                                UserEmail       => 'Unbekannt@localhost',
                                UserCustomerID  => 'Unbekannt',
                                ValidID         => '1',
                            }
                        );
                        if ( $UserCustomerIDs ) {
                            $CustomerUser{'Unbekannt'}->{UserCustomerIDs} = 'Unbekannt';
                        }

                        # check for column customer_ids
                        my $UserCustomerIDs = $Self->_ExistsDBCustomerIDsColumn();
                        if ( $UserCustomerIDs ) {
                            $CustomerUser{'Unbekannt'}->{UserCustomerIDs} = 'Unbekannt';
                        }

                        # add customer user 'Unbekannt'
                        $Self->_ProcessCustomerUserData(
                            CustomerUser => \%CustomerUser,
                            SkipExisting => 1,
                        );
                    }
                }
            }
            else {
                if ( $Param{Verbose} ) {
                    $Self->Print("\n" . '<red>TicketIDs to fix:</red> (' . scalar( keys( %Data ) ) . ')' . "\n");

                    for my $TicketID ( sort { $a <=> $b } ( keys( %Data ) ) ) {
                        $Self->Print($TicketID . "\n");
                    }
                }
                else {
                    $Self->Print('<red>' . scalar( keys( %Data ) ) . ' entries should be fixed</red>' . "\n");
                }
            }
        }
        else {
            $Self->Print('<green>Nothing to do</green>' . "\n");
        }
    }

    return 1;
}

sub _CheckTicketCustomerUser {
    my ( $Self, %Param ) = @_;

    $Self->Print('<yellow>TicketCustomerUser</yellow> - Check tickets for unknown customer users' . "\n");

    # skip this step if fixes are given, but this one is irrelevant
    if (
        IsHashRefWithData( $Param{Fixes} )
        && !$Param{Fixes}->{'TicketCustomerUser'}
    ) {
        $Self->Print('<green> - Skip, irrelevant step for this fix run</green>' . "\n");
        return 1;
    }

    # check for column customer_ids
    my $UserCustomerIDs = $Self->_ExistsDBCustomerIDsColumn();

    $Self->Print('<yellow> - get unknown customer_user_id entries from ticket table: </yellow>');

    # prepare db handle
    return if !$Kernel::OM->Get('Kernel::System::DB')->Prepare(
        SQL => 'SELECT DISTINCT customer_user_id FROM ticket WHERE customer_user_id NOT IN (SELECT login FROM customer_user)',
    );

    # fetch data
    my %Data = ();
    while ( my @Row = $Kernel::OM->Get('Kernel::System::DB')->FetchrowArray() ) {
        if ( $Row[0] ) {
            $Data{ $Row[0] } = 1;
        }
    }

    $Self->Print('<green>Done</green>' . "\n");

    # process result
    my $Count = 0;
    if (
        %Data
        && scalar( keys( %Data ) )
    ) {
        # create email parser object
        my $EmailParserObject = Kernel::System::EmailParser->new(
            Mode  => 'Standalone',
            Debug => 0,
        );

        my $Counter           = 0;
        my $CustomerUserCount = scalar( keys( %Data ) );
        CUSTOMERUSER:
        for my $CustomerUserID ( sort( keys( %Data ) ) ) {
            $Counter += 1;
            if ( $Counter % 2000 == 0 ) {
                my $Percent = int( $Counter / ( $CustomerUserCount / 100 ) );
                $Self->Print(' - <yellow>' . $Counter . '</yellow> of <yellow>' . $CustomerUserCount . '</yellow> processed (<yellow>' . $Percent . '%</yellow>)' . "\n");
            }

            # skip empty customer user id
            next CUSTOMERUSER if ( !$CustomerUserID );

            # get customer user data
            my %CustomerUserData = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerUserDataGet(
                User => $CustomerUserID,
            );
            if ( !%CustomerUserData ) {
                if ( $Param{Fixes}->{'TicketCustomerUser'} ) {

                    # prepare data
                    my $CustomerUserEmail;
                    my $CustomerUserName;
                    if ( $CustomerUserID !~ m/@/ ) {
                        $CustomerUserEmail = $CustomerUserID . '@localhost';
                        $CustomerUserName  = $CustomerUserID;
                    }
                    else {
                        my @EmailParts = $EmailParserObject->SplitAddressLine(
                            Line => $CustomerUserID,
                        );

                        for my $EmailPart (@EmailParts) {
                            $CustomerUserEmail = $EmailParserObject->GetEmailAddress(
                                Email => $EmailPart,
                            );

                            $CustomerUserName = $CustomerUserEmail;
                            $CustomerUserName =~ s/@.+$//;
                        }
                    }

                    # try to find customer user via email
                    my %CustomerUserList = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerSearch(
                        PostMasterSearch => $CustomerUserEmail,
                        Valid            => 0,
                        Limit            => 1,
                    );

                    # no customer user found in customer user backend, try agent data
                    if ( !%CustomerUserList ) {
                        # init list
                        my %CustomerUser;
                        my $NewCustomerUserID;

                        # try to find user via email
                        my %UserList = $Kernel::OM->Get('Kernel::System::User')->UserSearch(
                            PostMasterSearch => $CustomerUserEmail,
                            Valid            => 0,
                            Limit            => 1,
                        );
                        # found user via email
                        if ( %UserList ) {
                            for my $UserID ( keys( %UserList ) ) {
                                # get user data
                                my %UserData = $Kernel::OM->Get('Kernel::System::User')->GetUserData(
                                    UserID => $UserID,
                                );
                                
                                %CustomerUser = (
                                    $UserData{UserLogin} => {
                                        UserFirstname   => $UserData{UserFirstname},
                                        UserLastname    => $UserData{UserLastname},
                                        UserLogin       => $UserData{UserLogin},
                                        UserEmail       => $UserData{UserEmail},
                                        UserCustomerID  => 'Unbekannt',
                                        ValidID         => '1',
                                    }
                                );
                                if ( $UserCustomerIDs ) {
                                    $CustomerUser{ $UserData{UserLogin} }->{UserCustomerIDs} = 'Unbekannt';
                                }

                                $NewCustomerUserID = $UserData{UserLogin};

                                last;
                            }
                        }
                        # try to find user via login
                        else {
                            %UserList = $Kernel::OM->Get('Kernel::System::User')->UserSearch(
                                UserLogin => $CustomerUserID,
                                Valid     => 0,
                                Limit     => 1,
                            );
                            if ( %UserList ) {
                                for my $UserID ( keys( %UserList ) ) {
                                    # get user data
                                    my %UserData = $Kernel::OM->Get('Kernel::System::User')->GetUserData(
                                        UserID => $UserID,
                                    );
                                    
                                    %CustomerUser = (
                                        $UserData{UserLogin} => {
                                            UserFirstname   => $UserData{UserFirstname},
                                            UserLastname    => $UserData{UserLastname},
                                            UserLogin       => $UserData{UserLogin},
                                            UserEmail       => $UserData{UserEmail},
                                            UserCustomerID  => 'Unbekannt',
                                            ValidID         => '1',
                                        }
                                    );
                                    if ( $UserCustomerIDs ) {
                                        $CustomerUser{ $UserData{UserLogin} }->{UserCustomerIDs} = 'Unbekannt';
                                    }

                                    $NewCustomerUserID = $UserData{UserLogin};

                                    last;
                                }
                            }
                        }

                        # try to find user via login
                        if ( !%CustomerUser ) {

                            # prepare data
                            %CustomerUser = (
                                $CustomerUserEmail => {
                                    UserFirstname   => $CustomerUserName,
                                    UserLastname    => $CustomerUserName,
                                    UserLogin       => $CustomerUserEmail,
                                    UserEmail       => $CustomerUserEmail,
                                    UserCustomerID  => 'Unbekannt',
                                    ValidID         => '1',
                                }
                            );
                            if ( $UserCustomerIDs ) {
                                $CustomerUser{ $CustomerUserEmail }->{UserCustomerIDs} = 'Unbekannt';
                            }

                            $NewCustomerUserID = $CustomerUserEmail;
                        }

                        # add customer user
                        $Self->_ProcessCustomerUserData(
                            CustomerUser => \%CustomerUser,
                            SkipExisting => 1,
                            Silent       => 1,
                        );

                        # prepare data for company
                        my %CustomerCompany = (
                            'Unbekannt' => {
                                CustomerID          => 'Unbekannt',
                                CustomerCompanyName => 'Unbekannt',
                                ValidID             => '1',
                            }
                        );

                        # add customer company 'Unbekannt'
                        $Self->_ProcessCustomerCompanyData(
                            CustomerCompany => \%CustomerCompany,
                            SkipExisting    => 1,
                            Silent          => 1,
                        );

                        # prepare bind
                        my @Bind = (
                            \$NewCustomerUserID,
                            \$CustomerUser{ $NewCustomerUserID }->{UserCustomerID},
                            \$CustomerUserID
                        );
                        # execute fix statement
                        return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
                            SQL  => 'UPDATE ticket SET customer_user_id = ?, customer_id = ? WHERE LOWER(customer_user_id) = LOWER(?)',
                            Bind => \@Bind,
                        );

                        if ( $Param{Verbose} ) {
                            if ( $Count == 0 ) {
                                $Self->Print('<red>Unknown customer user ids:</red>' . "\n");
                            }
                            $Self->Print($CustomerUserID . ' - Created -' . "\n");
                        }
                    }
                    # unique customer user found
                    else {
                        for my $EmailCustomerUserID ( keys( %CustomerUserList ) ) {
                            # get customer user data
                            my %EmailCustomerUserData = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerUserDataGet(
                                User => $EmailCustomerUserID,
                            );

                            # prepare bind
                            my @Bind = (
                                \$EmailCustomerUserData{UserLogin},
                                \$EmailCustomerUserData{UserCustomerID},
                                \$CustomerUserID
                            );
                            # execute fix statement
                            return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
                                SQL  => 'UPDATE ticket SET customer_user_id = ?, customer_id = ? WHERE LOWER(customer_user_id) = LOWER(?)',
                                Bind => \@Bind,
                            );

                            if ( $Param{Verbose} ) {
                                if ( $Count == 0 ) {
                                    $Self->Print('<red>Unknown customer user ids:</red>' . "\n");
                                }
                                $Self->Print($CustomerUserID . ' > ' . $EmailCustomerUserData{UserLogin} . "\n");
                            }

                            last;
                        }
                    }
                }
                else {
                    if ( $Param{Verbose} ) {
                        if ( $Count == 0 ) {
                            $Self->Print('<red>Unknown customer user ids:</red>' . "\n");
                        }
                        $Self->Print($CustomerUserID . "\n");
                    }
                }

                # increment count
                $Count += 1;
            }
        }
    }

    # check process result
    if ( $Count ) {
        if ( $Param{Fixes}->{'TicketCustomerUser'} ) {
            $Self->Print('<green>' . $Count . ' entries fixed</green>' . "\n");
        }
        else {
            $Self->Print('<red>' . $Count . ' entries should be fixed</red>' . "\n");
        }
    }
    else {
        $Self->Print('<green>No unknown customer users</green>' . "\n");
    }

    return 1;
}

sub _CheckTicketCustomerCompany {
    my ( $Self, %Param ) = @_;

    $Self->Print('<yellow>TicketCustomerCompany</yellow> - Check tickets for unknown customer companies' . "\n");

    # skip this step if fixes are given, but this one is irrelevant
    if (
        IsHashRefWithData( $Param{Fixes} )
        && !$Param{Fixes}->{'TicketCustomerCompany'}
    ) {
        $Self->Print('<green> - Skip, irrelevant step for this fix run</green>' . "\n");
        return 1;
    }

    $Self->Print('<yellow> - get unknown customer_id entries from ticket table: </yellow>');

    # prepare db handle
    return if !$Kernel::OM->Get('Kernel::System::DB')->Prepare(
        SQL => 'SELECT DISTINCT customer_id FROM ticket WHERE customer_id NOT IN (SELECT customer_id FROM customer_company)',
    );

    # fetch data
    my %Data = ();
    while ( my @Row = $Kernel::OM->Get('Kernel::System::DB')->FetchrowArray() ) {
        if ( $Row[0] ) {
            $Data{ $Row[0] } = 1;
        }
    }

    $Self->Print('<green>Done</green>' . "\n");

    # process result
    my $Count = 0;
    if (
        %Data
        && scalar( keys( %Data ) )
    ) {
        my $Counter              = 0;
        my $CustomerCompanyCount = scalar( keys( %Data ) );
        CUSTOMERCOMPANY:
        for my $CustomerCompanyID ( sort( keys( %Data ) ) ) {
            $Counter += 1;
            if ( $Counter % 2000 == 0 ) {
                my $Percent = int( $Counter / ( $CustomerCompanyCount / 100 ) );
                $Self->Print(' - <yellow>' . $Counter . '</yellow> of <yellow>' . $CustomerCompanyCount . '</yellow> processed (<yellow>' . $Percent . '%</yellow>)' . "\n");
            }

            # skip empty customer company id
            next CUSTOMERCOMPANY if ( !$CustomerCompanyID );

            # get customer company data
            my %CustomerCompanyData = $Kernel::OM->Get('Kernel::System::CustomerCompany')->CustomerCompanyGet(
                CustomerID => $CustomerCompanyID,
            );
            if ( !%CustomerCompanyData ) {
                if ( $Param{Fixes}->{'TicketCustomerCompany'} ) {
                    # prepare data
                    my %CustomerCompany = (
                        $CustomerCompanyID => {
                            CustomerID          => $CustomerCompanyID,
                            CustomerCompanyName => $CustomerCompanyID,
                            ValidID             => '1',
                        }
                    );

                    # add customer company 'Unbekannt'
                    $Self->_ProcessCustomerCompanyData(
                        CustomerCompany => \%CustomerCompany,
                        SkipExisting    => 1,
                        Silent          => 1,
                    );
                }
                elsif ( $Param{Verbose} ) {
                    if ( $Count == 0 ) {
                        $Self->Print('<red>Unknown customer company ids:</red>' . "\n");
                    }
                    $Self->Print($CustomerCompanyID . "\n");
                }

                # increment count
                $Count += 1;
            }
        }
    }

    # check process result
    if ( $Count ) {
        if ( $Param{Fixes}->{'TicketCustomerCompany'} ) {
            $Self->Print('<green>' . $Count . ' entries fixed</green>' . "\n");
        }
        else {
            $Self->Print('<red>' . $Count . ' entries should be fixed</red>' . "\n");
        }
    }
    else {
        $Self->Print('<green>No unknown customer companies</green>' . "\n");
    }

    return 1;
}

sub _CheckTicketStateTypes {
    my ( $Self, %Param ) = @_;

    $Self->Print('<yellow>TicketStateTypes</yellow> - Check ticket state types' . "\n");

    # skip this step if fixes are given, but this one is irrelevant
    if (
        IsHashRefWithData( $Param{Fixes} )
        && !$Param{Fixes}->{'TicketStateTypes'}
    ) {
        $Self->Print('<green> - Skip, irrelevant step for this fix run</green>' . "\n");
        return 1;
    }

    # get state type list
    my %StateTypeList = $Kernel::OM->Get('Kernel::System::State')->StateTypeList(
        UserID => 1,
    );

    # process state type list
    my @CustomStateTypes = ();
    my $StateTypeIDOpen  = 0;
    for my $StateTypeID ( sort( keys( %StateTypeList ) ) ) {
        if (
            $StateTypeList{ $StateTypeID } ne 'new'
            && $StateTypeList{ $StateTypeID } ne 'open'
            && $StateTypeList{ $StateTypeID } ne 'closed'
            && $StateTypeList{ $StateTypeID } ne 'pending reminder'
            && $StateTypeList{ $StateTypeID } ne 'pending auto'
            && $StateTypeList{ $StateTypeID } ne 'removed'
            && $StateTypeList{ $StateTypeID } ne 'merged'
        ) {
            push( @CustomStateTypes, $StateTypeID );
        }
        elsif ( $StateTypeList{ $StateTypeID } eq 'open' ) {
            $StateTypeIDOpen = $StateTypeID;
        }
    }

    # check that state type 'open' was found
    if ( !$StateTypeIDOpen ) {
        $Self->PrintError('State type "open" is missing!' . "\n");
        return;
    }

    $Self->Print('<yellow> - Custom state types found: ' . scalar( @CustomStateTypes ) . '</yellow>' . "\n");

    # process state type result
    if (
        @CustomStateTypes
        && scalar( @CustomStateTypes )
    ) {
        # prepare select statement
        my $SelectSQL = 'SELECT id, name FROM ticket_state WHERE type_id IN (' . join ( ',', @CustomStateTypes ) . ')';

        # prepare db handle
        return if !$Kernel::OM->Get('Kernel::System::DB')->Prepare(
            SQL => $SelectSQL,
        );

        # fetch data
        my %Data = ();
        while ( my @Row = $Kernel::OM->Get('Kernel::System::DB')->FetchrowArray() ) {
            $Data{ $Row[0] } = $Row[1];
        }

        # process state result
        if (
            %Data
            && scalar( keys( %Data ) )
        ) {
            # check if entry should be fixed
            if ( $Param{Fixes}->{'TicketStateTypes'} ) {
                # convert hash to array
                my @StateIDs = sort( keys( %Data ) );

                # prepare fix statement
                my $FixSQL = 'UPDATE ticket_state SET type_id = ? WHERE id IN (' . join ( ',', @StateIDs ) . ')';

                # execute fix statement
                return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
                    SQL  => $FixSQL,
                    Bind => [ \$StateTypeIDOpen ]
                );

                $Self->Print('<green>' . scalar( keys( %Data ) ) . ' entries fixed</green>' . "\n");
            }
            else {
                if ( $Param{Verbose} ) {
                    $Self->Print('<red> - Ticket states to fix:</red> (' . scalar( keys( %Data ) ) . ')' . "\n");

                    for my $StateID ( sort { $a <=> $b } ( keys( %Data ) ) ) {
                        $Self->Print($Data{ $StateID } . "\n");
                    }
                }
                else {
                    $Self->Print('<red> - ' . scalar( keys( %Data ) ) . ' entries should be fixed</red>' . "\n");
                }
            }
        }
        else {
            $Self->Print('<green>Nothing to do</green>' . "\n");
        }
    }
    else {
        $Self->Print('<green>Nothing to do</green>' . "\n");
    }

    return 1;
}

sub _CheckServiceNames {
    my ( $Self, %Param ) = @_;

    $Self->Print('<yellow>ServiceNames</yellow> - Check service names to be unique on every level' . "\n");

    # skip this step if fixes are given, but this one is irrelevant
    if (
        IsHashRefWithData( $Param{Fixes} )
        && !$Param{Fixes}->{'ServiceNames'}
    ) {
        $Self->Print('<green> - Skip, irrelevant step for this fix run</green>' . "\n");
        return 1;
    }

    # prepare db handle
    return if !$Kernel::OM->Get('Kernel::System::DB')->Prepare(
        SQL => 'SELECT id, name FROM service',
    );

    # fetch data
    my %Data  = ();
    my %Exist = ();
    while ( my @Row = $Kernel::OM->Get('Kernel::System::DB')->FetchrowArray() ) {
        my $TopLevelName = $Row[1];
        $TopLevelName =~ s/.+:://;
        $Data{ $Row[0] }              = lc( $TopLevelName );
        $Exist{ lc( $TopLevelName ) } = 1;
    }
    
    # process data
    my %Lookup = ();
    my $Count  = 0;
    for my $DataID ( sort( keys( %Data ) ) ) {
        next if ( !$Data{ $DataID } );

        if ( !$Lookup{ $Data{ $DataID } } ) {
            $Lookup{ $Data{ $DataID } } = 1;
        }
        else {
            if ( $Lookup{ $Data{ $DataID } } == 1 ) {
                if (
                    $Count == 0
                    && $Param{Verbose}
                ) {
                    $Self->Print('<red> - Multiple used service names:</red>' . "\n");
                }
                $Count += 2;

                if (
                    !$Param{Fixes}->{'ServiceNames'}
                    && $Param{Verbose}
                ) {
                    $Self->Print($Data{ $DataID } . "\n");
                }
            }
            else {
                $Count += 1;
            }

            $Lookup{ $Data{ $DataID } } += 1;

            if ( $Param{Fixes}->{'ServiceNames'} ) {
                my %ServiceData = $Kernel::OM->Get('Kernel::System::Service')->ServiceGet(
                    ServiceID => $DataID,
                    UserID    => 1,
                );

                # init prefix count
                my $PrefixCount = 1;

                # prepare new mail
                my $NewServiceName;
                do {
                    $NewServiceName = $ServiceData{NameShort} . '-' . $PrefixCount;

                    $PrefixCount += 1;
                } while (
                    $Lookup{ $NewServiceName }
                    || $Exist{ $NewServiceName }
                );

                # update service
                my $Success = $Kernel::OM->Get('Kernel::System::Service')->ServiceUpdate(
                    %ServiceData,
                    ServiceID => $DataID,
                    Name      => $NewServiceName,
                    UserID    => 1,
                );

                # remember new service name
                $Lookup{ $NewServiceName } = 1;
            }
        }
    }

    # check process result
    if ( $Count ) {
        if ( $Param{Fixes}->{'ServiceNames'} ) {
            $Self->Print('<green> - ' . $Count . ' entries fixed</green>' . "\n");
        }
        else {
            $Self->Print('<red> - ' . $Count . ' entries should be fixed</red>' . "\n");
        }
    }
    else {
        $Self->Print('<green> - No duplicated service names</green>' . "\n");
    }

    return 1;
}

sub _CheckDynamicFieldValues {
    my ( $Self, %Param ) = @_;

    $Self->Print('<yellow>DynamicFieldValues</yellow> - Check for orphaned dynamic field values' . "\n");

    # skip this step if fixes are given, but this one is irrelevant
    if (
        IsHashRefWithData( $Param{Fixes} )
        && !$Param{Fixes}->{'DynamicFieldValues'}
    ) {
        $Self->Print('<green> - Skip, irrelevant step for this fix run</green>' . "\n");
        return 1;
    }

    # init query map
    my %QueryMap = (
        '0001' => {
            'Label'     => 'orphaned ticket dynamic field values',
            'SelectSQL' => 'SELECT dfv.id FROM dynamic_field_value dfv, dynamic_field df WHERE df.object_type = \'Ticket\' AND dfv.field_id = df.id AND dfv.object_id NOT IN ( SELECT id FROM ticket )',
            'FixSQL'    => 'DELETE FROM dynamic_field_value WHERE object_id NOT IN ( SELECT id FROM ticket ) AND field_id IN ( SELECT id FROM dynamic_field WHERE object_type = \'Ticket\' )',,
        },
        '0002' => {
            'Label'     => 'orphaned article dynamic field values',
            'SelectSQL' => 'SELECT dfv.id FROM dynamic_field_value dfv, dynamic_field df WHERE df.object_type = \'Article\' AND dfv.field_id = df.id AND dfv.object_id NOT IN ( SELECT id FROM article )',
            'FixSQL'    => 'DELETE FROM dynamic_field_value WHERE object_id NOT IN ( SELECT id FROM article ) AND field_id IN ( SELECT id FROM dynamic_field WHERE object_type = \'Article\' )',
        },
        '0003' => {
            'Label'     => 'orphaned faq dynamic field values',
            'SelectSQL' => 'SELECT dfv.id FROM dynamic_field_value dfv, dynamic_field df WHERE df.object_type = \'FAQ\' AND dfv.field_id = df.id AND dfv.object_id NOT IN ( SELECT id FROM faq_item )',
            'FixSQL'    => 'DELETE FROM dynamic_field_value WHERE object_id NOT IN ( SELECT id FROM faq_item ) AND field_id IN ( SELECT id FROM dynamic_field WHERE object_type = \'FAQ\' )',
        },
        '0004' => {
            'Label'        => 'orphaned customer user dynamic field values',
            'SelectSQL'    => 'SELECT dfv.id FROM dynamic_field_value dfv, dynamic_field df WHERE df.object_type = \'CustomerUser\' AND dfv.field_id = df.id AND dfv.object_id_text NOT IN ( SELECT login FROM customer_user )',
            'FixSQL'       => 'DELETE FROM dynamic_field_value WHERE object_id_text NOT IN ( SELECT login FROM customer_user ) AND field_id IN ( SELECT id FROM dynamic_field WHERE object_type = \'CustomerUser\' )',
            'ObjectIDText' => 1,
        },
        '0005' => {
            'Label'        => 'orphaned customer company dynamic field values',
            'SelectSQL'    => 'SELECT dfv.id FROM dynamic_field_value dfv, dynamic_field df WHERE df.object_type = \'CustomerCompany\' AND dfv.field_id = df.id AND dfv.object_id_text NOT IN ( SELECT customer_id FROM customer_company )',
            'FixSQL'       => 'DELETE FROM dynamic_field_value WHERE object_id_text NOT IN ( SELECT customer_id FROM customer_company ) AND field_id IN ( SELECT id FROM dynamic_field WHERE object_type = \'CustomerCompany\' )',
            'ObjectIDText' => 1,
        },
    );

    # init variables
    my $ObjectIDText = 0;

    # check for column customer_ids
    $Kernel::OM->Get('Kernel::System::DB')->Prepare(
        SQL   => 'SELECT * FROM dynamic_field_value',
        Limit => 1
    );
    my @ColumnNames = $Kernel::OM->Get('Kernel::System::DB')->GetColumnNames();
    for my $ColumnName ( @ColumnNames ) {
        if ( $ColumnName eq 'object_id_text' ) {
            $ObjectIDText = 1;

            last;
        }
    }

    # process queries
    for my $Query ( sort( keys( %QueryMap ) ) ) {
        next if (
            $QueryMap{ $Query }->{ObjectIDText}
            && !$ObjectIDText
        );

        $Self->Print('<yellow> - ' . $QueryMap{ $Query }->{Label} . ': </yellow>');

        # prepare db handle
        return if !$Kernel::OM->Get('Kernel::System::DB')->Prepare(
            SQL => $QueryMap{ $Query }->{SelectSQL},
        );

        # fetch data
        my %Data = ();
        while ( my @Row = $Kernel::OM->Get('Kernel::System::DB')->FetchrowArray() ) {
            $Data{ $Row[0] } = 1;
        }

        # process result
        if (
            %Data
            && scalar( keys( %Data ) )
        ) {
            # check if entry should be fixed
            if (
                $Param{Fixes}->{'DynamicFieldValues'}
                && $QueryMap{ $Query }->{FixSQL}
            ) {
                # execute fix statement
                return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
                    SQL  => $QueryMap{ $Query }->{FixSQL},
                );

                $Self->Print('<green>' . scalar( keys( %Data ) ) . ' entries fixed</green>' . "\n");
            }
            else {
                $Self->Print('<red>' . scalar( keys( %Data ) ) . ' entries should be fixed</red>' . "\n");
            }
        }
        else {
            $Self->Print('<green>Nothing to do</green>' . "\n");
        }
    }

    return 1;
}

sub _PrepareTicketEscalationData {
    my ( $Self, %Param ) = @_;

    $Self->Print('<yellow>PrepareTicketEscalationData</yellow> - prepare ticket escalation data' . "\n");

    # skip this step if fixes are given, but this one is irrelevant
    if (
        IsHashRefWithData( $Param{Fixes} )
        && !$Param{Fixes}->{'PrepareTicketEscalationData'}
    ) {
        $Self->Print('<green> - Skip, irrelevant step for this fix run</green>' . "\n");
        return 1;
    }

    if ( $Param{Fixes}->{'PrepareTicketEscalationData'} ) {
        $Self->Print('<yellow> - get all ticket ids: </yellow>');

        # prepare sql statement to get ticket ids with SLA
        $Kernel::OM->Get('Kernel::System::DB')->Prepare(
            SQL => "SELECT id FROM ticket WHERE sla_id IS NOT NULL ORDER BY id"
        );

        my @TicketIDs;
        while ( my @Row = $Kernel::OM->Get('Kernel::System::DB')->FetchrowArray() ) {
            push @TicketIDs, $Row[0];
        }
        $Self->Print('<green>Done</green>' . "\n");

        $Self->Print('<yellow> - calculate escalation data: </yellow>' . "\n");

        my %Data;
        my $Count = 0;
        my $TicketCount = scalar @TicketIDs;
        TICKETID:
        for my $TicketID ( @TicketIDs ) {
            $Count += 1;
            if ( $Count % 2000 == 0 ) {
                my $Percent = int( $Count / ( $TicketCount / 100 ) );
                $Self->Print(' - - <yellow>' . $Count . '</yellow> of <yellow>' . $TicketCount . '</yellow> processed (<yellow>' . $Percent . '%</yellow>)' . "\n");
            }

            my %Ticket = $Kernel::OM->Get('Kernel::System::Ticket')->TicketGet(
                TicketID => $TicketID,
            );
            next TICKETID if !%Ticket;

            my %FirstResponseDone = $Kernel::OM->Get('Kernel::System::Ticket')->_TicketGetFirstResponse(
                TicketID => $TicketID,
                Ticket   => \%Ticket,
            );

            my %SolutionDone = $Kernel::OM->Get('Kernel::System::Ticket')->_TicketGetClosed(
                TicketID => $TicketID,
                Ticket   => \%Ticket,
            );

            my $TotalSolutionSuspensionTime = $Kernel::OM->Get('Kernel::System::Ticket')->GetTotalNonEscalationRelevantBusinessTime(
                TicketID      => $TicketID,
                StopTimestamp => $SolutionDone{SolutionTime},
            );

            my %LastSuspensionTimes = $Self->_GetTicketLastSuspension(
                TicketID => $TicketID,
            );

            $Data{$TicketID} = {
                %LastSuspensionTimes,
                TotalSolutionSuspensionTime => $TotalSolutionSuspensionTime / 60,
                FirstResponse               => $FirstResponseDone{FirstResponse},
                Solution                    => $SolutionDone{SolutionTime},
            };
        }

        my $JSON = $Kernel::OM->Get('Kernel::System::JSON')->Encode(
            Data => \%Data
        );

        my $SystemDataKey = 'TicketEscalationDataForMigration';

        my $Exists = $Kernel::OM->Get('Kernel::System::SystemData')->SystemDataGet( Key => $SystemDataKey );
        if ( $Exists ) {
            $Kernel::OM->Get('Kernel::System::SystemData')->SystemDataDelete(
                Key    => $SystemDataKey,
                UserID => 1,
            );
        }
        my $Result = $Kernel::OM->Get('Kernel::System::SystemData')->SystemDataAdd(
            Key    => $SystemDataKey,
            Value  => $JSON,
            UserID => 1,
        );
        if ( !$Result ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => 'Can\'t store prepared ticket escalation data!',
            );
            return;
        }

        $Self->Print('<green>Done</green>' . "\n");
        }
    else {
        $Self->Print('<green> - Only when using --fix for this step</green>' . "\n");
    }

    return 1;
}

sub _ClearCache {
    my ( $Self, %Param ) = @_;

    $Self->Print('<yellow>Clear cache before/after fix</yellow>' . "\n");

    if ( IsHashRefWithData( $Param{Fixes} ) ) {

        $Self->Print('<yellow> - Cleanup: </yellow>');

        # cleanup cache
        my $Success = $Kernel::OM->Get('Kernel::System::Cache')->CleanUp();
        if ( !$Success ) {
            $Self->PrintError('Error occurred.' . "\n");
            return;
        }

        $Self->Print('<green>Done</green>' . "\n");
    }
    else {
        $Self->Print('<green> - Only when using --fix</green>' . "\n");
    }

    return 1;
}
### EO Check Functions ###

### Internal Functions of _CheckCustomerUserBackends ###
sub _SyncCustomerUserBackendFromDB {
    my ( $Self, %Param ) = @_;

    # get data from LDAP
    $Self->Print('<yellow> - - Fetch customer user data</yellow>' . "\n");
    my $CustomerUserRef = $Self->_GetCustomerUserDBData(
        Backend         => $Param{Backend},
        UserCustomerIDs => $Param{UserCustomerIDs},
    );
    if (
        ref( $CustomerUserRef ) ne 'HASH'
        || !%{ $CustomerUserRef }
    ) {
        $Self->PrintError('Error occurred.' . "\n");
        return;
    }

    # process data
    $Self->Print('<yellow> - - Processing customer user data</yellow>' . "\n");
    my $Success = $Self->_ProcessCustomerUserData(
        CustomerUser => $CustomerUserRef,
    );
    if ( !$Success ) {
        $Self->PrintError('Error occurred.' . "\n");
        return;
    }

    return 1;
}

sub _SyncCustomerUserBackendFromLDAP {
    my ( $Self, %Param ) = @_;

    # get data from LDAP
    $Self->Print('<yellow> - - Fetch customer user data</yellow>' . "\n");
    my $CustomerUserRef = $Self->_GetCustomerUserLDAPData(
        Backend         => $Param{Backend},
        PageSize        => $Param{PageSize},
        UserCustomerIDs => $Param{UserCustomerIDs},
    );
    if (
        ref( $CustomerUserRef ) ne 'HASH'
        || !%{ $CustomerUserRef }
    ) {
        $Self->PrintError('Error occurred.' . "\n");
        return;
    }

    # process GroupDN
    if ( $Param{Backend}->{Params}->{GroupDN} ) {
        $Self->Print('<yellow> - - Filter customer user data by GroupDN "' . $Param{Backend}->{Params}->{GroupDN} . '"' . "\n");
        my $Success = $Self->_FilterCustomerUserByGroupDN(
            Backend      => $Param{Backend},
            CustomerUser => $CustomerUserRef,
        );
        if ( !$Success ) {
            $Self->PrintError('Error occurred.' . "\n");
            return;
        }
    }

    # process data
    $Self->Print('<yellow> - - Processing customer user data</yellow>' . "\n");
    my $Success = $Self->_ProcessCustomerUserData(
        CustomerUser => $CustomerUserRef,
    );
    if ( !$Success ) {
        $Self->PrintError('Error occurred.' . "\n");
        return;
    }

    return 1;
}

sub _GetCustomerUserDBData {
    my ( $Self, %Param ) = @_;

    # init result
    my %CustomerUser = ();

    # prepare columns to fetch
    my @DBColumns   = ();
    my $LoginColumn = '';
    ENTRY:
    for my $MapEntry ( @{ $Param{Backend}->{Map} } ) {
        next ENTRY if (
            $MapEntry->[0] ne 'UserFirstname'
            && $MapEntry->[0] ne 'UserLastname'
            && $MapEntry->[0] ne 'UserLogin'
            && $MapEntry->[0] ne 'UserEmail'
            && $MapEntry->[0] ne 'UserCustomerID'
            && $MapEntry->[0] ne 'UserCustomerIDs'
            && $MapEntry->[0] ne 'ValidID'
        );

        next ENTRY if (
            !$Param{UserCustomerIDs}
            && $MapEntry->[0] eq 'UserCustomerIDs'
        );

        if ( $MapEntry->[0] eq 'UserLogin' ) {
            $LoginColumn = $MapEntry->[2];
        }

        push( @DBColumns, $MapEntry->[2] );
    }

    # create DB object
    my $DBObject;
    if ( $Param{Backend}->{Params}->{DSN} ) {
        $DBObject = Kernel::System::DB->new(
            %{ $Param{Backend}->{Params} },
            DatabaseDSN  => $Param{Backend}->{Params}->{DSN},
            DatabaseUser => $Param{Backend}->{Params}->{User},
            DatabasePw   => $Param{Backend}->{Params}->{Password},
        )
    }
    else {
        $DBObject = $Kernel::OM->Get('Kernel::System::DB');
    }
    if ( !$DBObject ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Can\'t connect to database!',
        );
        return;
    }
    
    # build select
    my $SQL = 'SELECT ' . $LoginColumn . ',' . join( ',', @DBColumns )
            . ' FROM ' . $Param{Backend}->{Params}->{Table};

    # prepare statement
    return if !$DBObject->Prepare(
        SQL => $SQL,
    );

    # fetch the result
    my %Data;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        my $MapCounter = 1;
        ENTRY:
        for my $MapEntry ( @{ $Param{Backend}->{Map} } ) {
            next ENTRY if (
                $MapEntry->[0] ne 'UserFirstname'
                && $MapEntry->[0] ne 'UserLastname'
                && $MapEntry->[0] ne 'UserLogin'
                && $MapEntry->[0] ne 'UserEmail'
                && $MapEntry->[0] ne 'UserCustomerID'
                && $MapEntry->[0] ne 'UserCustomerIDs'
                && $MapEntry->[0] ne 'ValidID'
            );

            next ENTRY if (
                !$Param{UserCustomerIDs}
                && $MapEntry->[0] eq 'UserCustomerIDs'
            );

            $CustomerUser{ $Row[0] }->{ $MapEntry->[0] } = $Row[ $MapCounter ] || $MapEntry->[8] || '';

            $MapCounter += 1;
        }
    }

    # delete object to clean up connection for external db
    $DBObject = undef;

    return \%CustomerUser;
}

sub _GetCustomerUserLDAPData {
    my ( $Self, %Param ) = @_;

    # init result
    my %CustomerUser = ();

    # init search attributes
    my %SearchAttributes = ();

    # add base
    if ( $Param{Backend}->{Params}->{BaseDN} ) {
        $SearchAttributes{base} = $Param{Backend}->{Params}->{BaseDN};
    }

    # add filter
    if ( $Param{Backend}->{Params}->{AlwaysFilter} ) {
        $SearchAttributes{filter} = $Param{Backend}->{Params}->{AlwaysFilter};
    }
    else {
        $SearchAttributes{filter} = '(' . $Param{Backend}->{CustomerKey} . '=*)';
    }

    # add scope
    if ( $Param{Backend}->{Params}->{SSCOPE} ) {
        $SearchAttributes{scope} = $Param{Backend}->{Params}->{SSCOPE};
    }

    # add attrs
    $SearchAttributes{attrs} = [];
    my %LDAPAttributeMap     = ();
    ENTRY:
    for my $MapEntry ( @{ $Param{Backend}->{Map} } ) {
        next ENTRY if (
            $MapEntry->[0] ne 'UserFirstname'
            && $MapEntry->[0] ne 'UserLastname'
            && $MapEntry->[0] ne 'UserLogin'
            && $MapEntry->[0] ne 'UserEmail'
            && $MapEntry->[0] ne 'UserCustomerID'
            && $MapEntry->[0] ne 'UserCustomerIDs'
        );

        next ENTRY if (
            !$Param{UserCustomerIDs}
            && $MapEntry->[0] eq 'UserCustomerIDs'
        );

        $LDAPAttributeMap{ $MapEntry->[0] } = $MapEntry->[2];

        if ( $MapEntry->[2] ) {
            push( @{ $SearchAttributes{attrs} }, $MapEntry->[2] );
        }
    }

    # add pagination
    my $PageControl;
    my $Cookie;
    if ( $Param{PageSize} ) {
        # get page control
        $PageControl = Net::LDAP::Control::Paged->new( size => $Param{PageSize} );
        if ( !$PageControl ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => 'Can\'t create Net::LDAP::Control::Paged: ' . $@,
            );
            return;
        }
        $SearchAttributes{control} = [ $PageControl ];
    }

    # create object from Net::LDAP
    my $LDAPObject = Net::LDAP->new(
        $Param{Backend}->{Params}->{Host},
        %{ $Param{Backend}->{Params}->{Params} }
    );
    if ( !$LDAPObject ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Can\'t connect to ' . $Param{Backend}->{Params}->{Host} . ': ' . $@,
        );
        return;
    }

    # bind to ldap
    my $BindResult;
    # bind with user and password
    if (
        $Param{Backend}->{Params}->{UserDN}
        && $Param{Backend}->{Params}->{UserPw}
    ) {
        $BindResult = $LDAPObject->bind(
            dn       => $Param{Backend}->{Params}->{UserDN},
            password => $Param{Backend}->{Params}->{UserPw},
        );
    }
    # anonymous bind
    else {
        $BindResult = $LDAPObject->bind();
    }
    # check bind
    if ( $BindResult->code() ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'First bind failed! ' . $BindResult->error(),
        );
        $LDAPObject->disconnect();
        return;
    }

    # process search
    my $ResultCount = 0;
    while(1) {
        # perform search
        my $SearchResult = $LDAPObject->search( %SearchAttributes );
        if ( $SearchResult->code() ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => 'Search failed! ' . $SearchResult->error(),
            );
            $LDAPObject->unbind();
            $LDAPObject->disconnect();
            return;
        }

        # check if there are results
        if ( $SearchResult->count() == 0 ) {
            last;
        }

        my $FirstEntry = $ResultCount + 1;
        $ResultCount  += $SearchResult->count();
        my $LastEntry  = $ResultCount;

        # process entries
        $Self->Print('<yellow> - - - Fetching result entries ' . $FirstEntry . ' to ' . $LastEntry . '...' . "\n");
        for my $ResultEntry ( $SearchResult->entries() ) {
            # check entry
            if ( !$ResultEntry ) {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message  => 'Empty entry!',
                );
                $LDAPObject->unbind();
                $LDAPObject->disconnect();
                return;
            }

            # get user login
            my $UserLogin = $Self->_ConvertLDAPData(
                Text        => $ResultEntry->get_value( $LDAPAttributeMap{UserLogin} ),
                LDAPCharset => $Param{Backend}->{Params}->{SourceCharset} || '',
            );
            if ( $UserLogin ) {
                MAPENTRY:
                for my $Entry ( @{ $Param{Backend}->{Map} } ) {
                    next MAPENTRY if( !defined( $LDAPAttributeMap{ $Entry->[0] } ) );

                    my $Value = '';
                    if ( $Entry->[2] ) {
                        if ( $Entry->[5] && $Entry->[5] =~ /^ArrayIndex\[(\d+)\]$/ ) {
                            my $Index       = $1;
                            my @ResultArray = $ResultEntry->get_value( $Entry->[2] );
                            $Value = $Self->_ConvertLDAPData(
                                Text        => $ResultArray[$Index],
                                LDAPCharset => $Param{Backend}->{Params}->{SourceCharset} || '',
                            );
                        }
                        elsif ( $Entry->[5] && $Entry->[5] =~ /^ArrayJoin\[(.+)\]$/ ) {
                            my $JoinStrg    = $1;
                            my @ResultArray = $ResultEntry->get_value( $Entry->[2] );
                            $Value = $Self->_ConvertLDAPData(
                                Text        => join( $JoinStrg, @ResultArray ),
                                LDAPCharset => $Param{Backend}->{Params}->{SourceCharset} || '',
                            );
                        }
                        else {
                            my $RawValue = $ResultEntry->get_value( $Entry->[2] );
                            $Value = $Self->_ConvertLDAPData(
                                Text        => $RawValue,
                                LDAPCharset => $Param{Backend}->{Params}->{SourceCharset} || '',
                            );
                        }

                        if (
                            $Value
                            && $Entry->[2] =~ /^targetaddress$/i
                        ) {
                            $Value =~ s/SMTP:(.*)/$1/;
                        }
                    }

                    if (
                        !$Value
                        && $Entry->[8]
                    ) {
                        $Value = $Entry->[8];
                    }

                    $CustomerUser{ $UserLogin }->{ $Entry->[0] } = $Value;
                }
            }
        }

        # handle paging
        my ($ControlResponse) = $SearchResult->control(LDAP_CONTROL_PAGED) or last;
        $Cookie = $ControlResponse->cookie or last;
        $PageControl->cookie($Cookie);
    }

    # check for abnormal exit
    if($Cookie) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Abnormal exit of ldap search',
        );
        $PageControl->cookie($Cookie);
        $PageControl->size(0);
        $LDAPObject->search( %SearchAttributes );
        $LDAPObject->unbind();
        $LDAPObject->disconnect();
        return;
    }

    # unbind and disconnect from ldap
    $LDAPObject->unbind();
    $LDAPObject->disconnect();

    return \%CustomerUser;
}

sub _FilterCustomerUserByGroupDN {
    my ( $Self, %Param ) = @_;

    # create object from Net::LDAP
    my $LDAPObject = Net::LDAP->new(
        $Param{Backend}->{Params}->{Host},
        %{ $Param{Backend}->{Params}->{Params} }
    );
    if ( !$LDAPObject ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Can\'t connect to ' . $Param{Backend}->{Params}->{Host} . ': ' . $@,
        );
        return;
    }

    # bind to ldap
    my $BindResult;
    # bind with user and password
    if (
        $Param{Backend}->{Params}->{UserDN}
        && $Param{Backend}->{Params}->{UserPw}
    ) {
        $BindResult = $LDAPObject->bind(
            dn       => $Param{Backend}->{Params}->{UserDN},
            password => $Param{Backend}->{Params}->{UserPw},
        );
    }
    # anonymous bind
    else {
        $BindResult = $LDAPObject->bind();
    }
    # check bind
    if ( $BindResult->code() ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'First bind failed! ' . $BindResult->error(),
        );
        $LDAPObject->disconnect();
        return;
    }

    # process customer user
    for my $UserLogin ( keys( %{ $Param{CustomerUser} } ) ) {
        my $Result = $LDAPObject->search(
            base      => $Param{Backend}->{Params}->{GroupDN},
            scope     => $Param{Backend}->{Params}->{SSCOPE},
            filter    => 'memberUid=' . escape_filter_value($UserLogin),
            sizelimit => 1,
            attrs     => ['1.1'],
        );

        if ( !$Result->all_entries() ) {
            delete( $Param{CustomerUser}->{ $UserLogin } );
        }
    }

    # unbind and disconnect from ldap
    $LDAPObject->unbind();
    $LDAPObject->disconnect();

    return 1;
}

sub _ProcessCustomerUserData {
    my ( $Self, %Param ) = @_;

    # init db attribute mapping
    my %DBAttributeMap = (
        UserFirstname   => 'first_name',
        UserLastname    => 'last_name',
        UserLogin       => 'login',
        UserEmail       => 'email',
        UserCustomerID  => 'customer_id',
        UserCustomerIDs => 'customer_ids',
        ValidID         => 'valid_id',
    );

    # process customer user
    for my $UserLogin ( sort( keys( %{ $Param{CustomerUser} } ) ) ) {
        # check if login exists in db
        my $Type = 'INSERT';
        return if !$Kernel::OM->Get('Kernel::System::DB')->Prepare(
            SQL   => 'SELECT login FROM customer_user WHERE login = ?',
            Bind  => [ \$UserLogin ],
            Limit => 1,
        );
        while ( my @Row = $Kernel::OM->Get('Kernel::System::DB')->FetchrowArray() ) {
            $Type = 'UPDATE';
        }
        if (
            $Param{SkipExisting}
            && $Type eq 'UPDATE'
        ) {
            next;
        }

        if ( !defined( $Param{CustomerUser}->{ $UserLogin }->{ValidID} ) ) {
            $Param{CustomerUser}->{ $UserLogin }->{ValidID} = 1;
        }

        for my $Attribute ( qw(UserFirstname UserLastname) ) {
            if (
                defined( $Param{CustomerUser}->{ $UserLogin }->{ $Attribute } )
                && length ( $Param{CustomerUser}->{ $UserLogin }->{ $Attribute } ) > 100
            ) {
                $Param{CustomerUser}->{ $UserLogin }->{ $Attribute } = substr( $Param{CustomerUser}->{ $UserLogin }->{ $Attribute }, 0, 97 ) . '...';
            }
        }

        # prepare data for sql
        my $SQLPre  = '';
        my $SQLPost = '';
        my @SQLBind = ();
        for my $Key ( sort( keys( %{ $Param{CustomerUser}->{ $UserLogin } } ) ) ) {
            my $Value = $Kernel::OM->Get('Kernel::System::DB')->Quote( $Param{CustomerUser}->{ $UserLogin }->{ $Key } );

            if ( $Type eq 'UPDATE' ) {
                if ($SQLPre) {
                    $SQLPre .= ', ';
                }
                $SQLPre .= $DBAttributeMap{ $Key } . ' = ?';
            }
            else {
                if ($SQLPre) {
                    $SQLPre .= ', ';
                }
                $SQLPre .= $DBAttributeMap{ $Key };

                if ($SQLPost) {
                    $SQLPost .= ', ';
                }
                $SQLPost .= '?';
            }

            push( @SQLBind, \$Value );
        }

        # prepare sql
        my $SQL = '';
        if ( $Type eq 'UPDATE' ) {
            $SQL = 'UPDATE customer_user'
                    . ' SET ' . $SQLPre . ', change_time = current_timestamp, change_by = 1'
                    . ' WHERE login = ?';

            push( @SQLBind, \$UserLogin );
        }
        else {
            $SQL = 'INSERT INTO customer_user (' . $SQLPre . ', create_time, create_by, change_time, change_by)'
                    . ' VALUES (' . $SQLPost . ', current_timestamp, 1, current_timestamp, 1)';
        }

        if ( !$Param{Silent} ) {
            $Self->Print('<yellow> - - - ' . $Type . ': ' . $UserLogin . '</yellow>' . "\n");
        }

        # execut sql
        return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
            SQL  => $SQL,
            Bind => \@SQLBind,
        );
    }

    return 1;
}

sub _ConvertLDAPData {
    my ( $Self, %Param ) = @_;

    return '' if( !$Param{Text} );

    return $Param{Text} if( !$Param{LDAPCharset} );

    return $Kernel::OM->Get('Kernel::System::Encode')->Convert(
        Text => $Param{Text},
        From => $Param{LDAPCharset},
        To   => 'utf-8',
    );
}
### EO Internal Functions of _CheckCustomerUserBackends ###

### Internal Functions of _CheckCustomerCompanyBackends ###
sub _SyncCustomerCompanyBackendFromDB {
    my ( $Self, %Param ) = @_;

    # get data from LDAP
    $Self->Print('<yellow> - - Fetch customer company data</yellow>' . "\n");
    my $CustomerCompanyRef = $Self->_GetCustomerCompanyDBData(
        Backend => $Param{Backend},
    );
    if (
        ref( $CustomerCompanyRef ) ne 'HASH'
        || !%{ $CustomerCompanyRef }
    ) {
        $Self->PrintError('Error occurred.' . "\n");
        return;
    }

    # process data
    $Self->Print('<yellow> - - Processing customer company data</yellow>' . "\n");
    my $Success = $Self->_ProcessCustomerCompanyData(
        CustomerCompany => $CustomerCompanyRef,
    );
    if ( !$Success ) {
        $Self->PrintError('Error occurred.' . "\n");
        return;
    }

    return 1;
}

sub _GetCustomerCompanyDBData {
    my ( $Self, %Param ) = @_;

    # init result
    my %CustomerCompany = ();

    # prepare columns to fetch
    my @DBColumns        = ();
    my $CustomerIDColumn = '';
    ENTRY:
    for my $MapEntry ( @{ $Param{Backend}->{Map} } ) {
        next ENTRY if (
            $MapEntry->[0] ne 'CustomerID'
            && $MapEntry->[0] ne 'CustomerCompanyName'
            && $MapEntry->[0] ne 'ValidID'
        );

        if ( $MapEntry->[0] eq 'CustomerID' ) {
            $CustomerIDColumn = $MapEntry->[2];
        }

        push( @DBColumns, $MapEntry->[2] );
    }

    # create DB object
    my $DBObject;
    if ( $Param{Backend}->{Params}->{DSN} ) {
        $DBObject = Kernel::System::DB->new(
            %{ $Param{Backend}->{Params} },
            DatabaseDSN  => $Param{Backend}->{Params}->{DSN},
            DatabaseUser => $Param{Backend}->{Params}->{User},
            DatabasePw   => $Param{Backend}->{Params}->{Password},
        )
    }
    else {
        $DBObject = $Kernel::OM->Get('Kernel::System::DB');
    }
    if ( !$DBObject ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Can\'t connect to database!',
        );
        return;
    }
    
    # build select
    my $SQL = 'SELECT ' . $CustomerIDColumn . ',' . join( ',', @DBColumns )
            . ' FROM ' . $Param{Backend}->{Params}->{Table};

    # prepare statement
    return if !$DBObject->Prepare(
        SQL => $SQL,
    );

    # fetch the result
    my %Data;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        my $MapCounter = 1;
        ENTRY:
        for my $MapEntry ( @{ $Param{Backend}->{Map} } ) {
            next ENTRY if (
                $MapEntry->[0] ne 'CustomerID'
                && $MapEntry->[0] ne 'CustomerCompanyName'
                && $MapEntry->[0] ne 'ValidID'
            );

            $CustomerCompany{ $Row[0] }->{ $MapEntry->[0] } = $Row[ $MapCounter ] || '';

            $MapCounter += 1;
        }
    }

    # delete object to clean up connection for external db
    $DBObject = undef;

    return \%CustomerCompany;
}

sub _ProcessCustomerCompanyData {
    my ( $Self, %Param ) = @_;

    # init db attribute mapping
    my %DBAttributeMap = (
        CustomerID          => 'customer_id',
        CustomerCompanyName => 'name',
        ValidID             => 'valid_id',
    );

    # process customer company
    for my $CustomerID ( sort( keys( %{ $Param{CustomerCompany} } ) ) ) {
        # check if customer id exists in db
        my $Type = 'INSERT';
        return if !$Kernel::OM->Get('Kernel::System::DB')->Prepare(
            SQL   => 'SELECT customer_id FROM customer_company WHERE customer_id = ?',
            Bind  => [ \$CustomerID ],
            Limit => 1,
        );
        while ( my @Row = $Kernel::OM->Get('Kernel::System::DB')->FetchrowArray() ) {
            $Type = 'UPDATE';
        }
        if (
            $Param{SkipExisting}
            && $Type eq 'UPDATE'
        ) {
            next;
        }

        if ( !defined( $Param{CustomerCompany}->{ $CustomerID }->{ValidID} ) ) {
            $Param{CustomerCompany}->{ $CustomerID }->{ValidID} = 1;
        }

        # prepare data for sql
        my $SQLPre  = '';
        my $SQLPost = '';
        my @SQLBind = ();
        for my $Key ( sort( keys( %{ $Param{CustomerCompany}->{ $CustomerID } } ) ) ) {
            my $Value = $Kernel::OM->Get('Kernel::System::DB')->Quote( $Param{CustomerCompany}->{ $CustomerID }->{ $Key } );

            if ( $Type eq 'UPDATE' ) {
                if ($SQLPre) {
                    $SQLPre .= ', ';
                }
                $SQLPre .= $DBAttributeMap{ $Key } . ' = ?';
            }
            else {
                if ($SQLPre) {
                    $SQLPre .= ', ';
                }
                $SQLPre .= $DBAttributeMap{ $Key };

                if ($SQLPost) {
                    $SQLPost .= ', ';
                }
                $SQLPost .= '?';
            }

            push( @SQLBind, \$Value );
        }

        # prepare sql
        my $SQL = '';
        if ( $Type eq 'UPDATE' ) {
            $SQL = 'UPDATE customer_company'
                    . ' SET ' . $SQLPre . ', change_time = current_timestamp, change_by = 1'
                    . ' WHERE customer_id = ?';

            push( @SQLBind, \$CustomerID );
        }
        else {
            $SQL = 'INSERT INTO customer_company (' . $SQLPre . ', create_time, create_by, change_time, change_by)'
                    . ' VALUES (' . $SQLPost . ', current_timestamp, 1, current_timestamp, 1)';
        }

        if ( !$Param{Silent} ) {
            $Self->Print('<yellow> - - - ' . $Type . ': ' . $CustomerID . '</yellow>' . "\n");
        }

        # execut sql
        return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
            SQL  => $SQL,
            Bind => \@SQLBind,
        );
    }

    return 1;
}
### EO Internal Functions of _CheckCustomerCompanyBackends ###

### Internal Functions of _PrepareTicketEscalationData ###
sub _GetTicketLastSuspension {
    my ( $Self, %Param ) = @_;

    my %StateListReverse = reverse $Kernel::OM->Get('Kernel::System::State')->StateList( UserID => 1 );

    my $RelevantStates = $Kernel::OM->Get('Kernel::Config')->Get('Ticket::EscalationDisabled::RelevantStates');
    my @RelevantStateIDs;
    foreach my $State ( @{$RelevantStates||[]} ) {
        push @RelevantStateIDs, $StateListReverse{$State}
    }

    my %Result = ();

    return %Result if ( !@RelevantStateIDs );

    my @Bind = map { \$_ } @RelevantStateIDs;

    my $SQL = "SELECT max(th.create_time) FROM ticket_history th, ticket_history_type tht "
            . "WHERE "
            . "th.ticket_id = $Param{TicketID} AND "
            . "th.history_type_id = tht.id AND "
            . "tht.name IN ('StateUpdate', 'WebRequestCustomer', 'PhoneCallCustomer') AND "
            . "th.state_id IN (".(join( ',', map { '?' } @RelevantStateIDs)).')';

    # get last suspension start
    return %Result if !$Kernel::OM->Get('Kernel::System::DB')->Prepare(
        SQL => $SQL,
        Bind => \@Bind,
    );

    while ( my @Row = $Kernel::OM->Get('Kernel::System::DB')->FetchrowArray() ) {
        $Result{LastSolutionSuspensionStartTime} = $Row[0];
    }

    # get last suspension start
    if ( $Result{LastSolutionSuspensionStartTime} ) {
        $SQL = "SELECT max(th.create_time) FROM ticket_history th, ticket_history_type tht "
             . "WHERE "
             . "th.ticket_id = $Param{TicketID} AND "
             . "th.history_type_id = tht.id AND "
             . "tht.name IN ('StateUpdate', 'WebRequestCustomer', 'PhoneCallCustomer') AND "
             . "th.state_id NOT IN (".(join( ',', map { '?' } @RelevantStateIDs)).') AND '
             . "th.create_time > '$Result{LastSolutionSuspensionStartTime}'";

        return %Result if !$Kernel::OM->Get('Kernel::System::DB')->Prepare(
            SQL => $SQL,
            Bind => \@Bind,
        );

        while ( my @Row = $Kernel::OM->Get('Kernel::System::DB')->FetchrowArray() ) {
            $Result{LastSolutionSuspensionStopTime} = $Row[0];
        }
    }

    return %Result;
}
### EO Internal Functions of _PrepareTicketEscalationData ###

### Other Internal Functions ###
sub _GetDBTables {
    my ( $Self, %Param ) = @_;

    # get all table names from DB
    $Kernel::OM->Get('Kernel::System::DB')->Connect() || die "Unable to connect to database!";
    my %Tables = map { my $Table = (split(/\./, $_))[1]; $Table =~ s/\`//g; $Table => 1 } $Kernel::OM->Get('Kernel::System::DB')->{dbh}->tables('', $Kernel::OM->Get('Kernel::System::DB')->{'DB::Type'} eq 'postgresql' ? 'public' : '', '', 'TABLE');

    return \%Tables;
}

sub _ExistsDBCustomerIDsColumn {
    my ( $Self, %Param ) = @_;

    # check for column customer_ids
    $Kernel::OM->Get('Kernel::System::DB')->Prepare(
        SQL   => 'SELECT * FROM customer_user',
        Limit => 1
    );
    my @ColumnNames = $Kernel::OM->Get('Kernel::System::DB')->GetColumnNames();
    for my $ColumnName ( @ColumnNames ) {
        if ( $ColumnName eq 'customer_ids' ) {
            return 1;
        }
    }

    return 0;
}
### EO Other Internal Functions ###

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
