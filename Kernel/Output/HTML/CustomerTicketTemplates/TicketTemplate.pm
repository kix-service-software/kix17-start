# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::CustomerTicketTemplates::TicketTemplate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);
use Kernel::Language qw(Translatable);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Log',
    'Kernel::System::Ticket',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{ConfigObject} = $Kernel::OM->Get('Kernel::Config');
    $Self->{LogObject}    = $Kernel::OM->Get('Kernel::System::Log');
    $Self->{TicketObject} = $Kernel::OM->Get('Kernel::System::Ticket');

    return $Self;
}

sub TicketTemplateList {
    my ( $Self, %Param ) = @_;
    my %Result;

    # get ticket templates from database
    my @Templates = $Self->{TicketObject}->TicketTemplateList(
        Frontend => 'Customer',
        Result   => 'ID',
        UserID   => $Param{UserID},
    );

    foreach my $TemplateID (@Templates) {
        my %Template = $Self->{TicketObject}->TicketTemplateGet(
            ID => $TemplateID,
        );
        $Template{PortalGroupID} = $Template{CustomerPortalGroupID};
        $Template{Link}          = "Action=CustomerTicketMessage;DefaultSet=$TemplateID";
        $Result{$TemplateID}     = \%Template;
    }

    return %Result;
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
