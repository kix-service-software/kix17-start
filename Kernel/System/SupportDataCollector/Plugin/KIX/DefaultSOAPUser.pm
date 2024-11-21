# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2024 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::SupportDataCollector::Plugin::KIX::DefaultSOAPUser;

use strict;
use warnings;

use base qw(Kernel::System::SupportDataCollector::PluginBase);

use Kernel::Language qw(Translatable);

our @ObjectDependencies = (
    'Kernel::Config',
);

sub GetDisplayPath {
    return Translatable('KIX');
}

sub Run {
    my $Self = shift;

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    my $SOAPUser     = $ConfigObject->Get('SOAP::User')     || '';
    my $SOAPPassword = $ConfigObject->Get('SOAP::Password') || '';

    if ( $SOAPUser eq 'some_user' && ( $SOAPPassword eq 'some_pass' || $SOAPPassword eq '' ) ) {
        $Self->AddResultProblem(
            Label => Translatable('Default SOAP Username And Password'),
            Value => '',
            Message =>
                Translatable(
                'Security risk: you use the default setting for SOAP::User and SOAP::Password. Please change it.'
                ),
        );
    }
    else {
        $Self->AddResultOk(
            Label => Translatable('Default SOAP Username And Password'),
            Value => '',
        );
    }

    return $Self->GetResults();
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
