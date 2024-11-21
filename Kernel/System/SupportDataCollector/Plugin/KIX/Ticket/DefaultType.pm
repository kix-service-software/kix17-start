# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2024 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::SupportDataCollector::Plugin::KIX::Ticket::DefaultType;

use strict;
use warnings;

use base qw(Kernel::System::SupportDataCollector::PluginBase);

use Kernel::Language qw(Translatable);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Type',
);

sub GetDisplayPath {
    return Translatable('KIX');
}

sub Run {
    my $Self = shift;

    # check, if Ticket::Type is enabled
    my $TicketType = $Kernel::OM->Get('Kernel::Config')->Get('Ticket::Type');

    # if not enabled, stop here
    if ( !$TicketType ) {
        return $Self->GetResults();
    }

    my $TypeObject = $Kernel::OM->Get('Kernel::System::Type');

    # get default ticket type from config
    my $DefaultTicketType = $Kernel::OM->Get('Kernel::Config')->Get('Ticket::Type::Default');

    # get list of all ticket types
    my %AllTicketTypes = reverse $TypeObject->TypeList();

    if ( $AllTicketTypes{$DefaultTicketType} ) {
        $Self->AddResultOk(
            Label => Translatable('Default Ticket Type'),
            Value => $DefaultTicketType,
        );
    }
    else {
        $Self->AddResultWarning(
            Label => Translatable('Default Ticket Type'),
            Value => $DefaultTicketType,
            Message =>
                Translatable(
                'The configured default ticket type is invalid or missing. Please change the setting Ticket::Type::Default and select a valid ticket type.'
                ),
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
