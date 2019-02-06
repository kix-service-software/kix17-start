# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::CustomerTicketTemplates::TicketProcess;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);
use Kernel::Language qw(Translatable);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Log',
    'Kernel::System::ProcessManagement::Process',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{ConfigObject}  = $Kernel::OM->Get('Kernel::Config');
    $Self->{LogObject}     = $Kernel::OM->Get('Kernel::System::Log');
    $Self->{ProcessObject} = $Kernel::OM->Get('Kernel::System::ProcessManagement::Process');
    $Self->{TicketObject}  = $Kernel::OM->Get('Kernel::System::Ticket');

    return $Self;
}

sub TicketTemplateList {
    my ( $Self, %Param ) = @_;
    my %Result;
    
    # get the list of processes that customer can start
    my $ProcessListRef = $Self->{ProcessObject}->ProcessList(
        ProcessState => ['Active'],
        Interface    => ['CustomerInterface'],
        Silent       => 1,
    );
    return %Result if !IsHashRefWithData($ProcessListRef);

    # filter ProcessList through ACLs 
    my %ProcessListACL = map { $_ => $_ } sort keys %{$ProcessListRef};
    my $ACL = $Self->{TicketObject}->TicketAcl(
        ReturnType     => 'Process',
        ReturnSubType  => '-',
        Data           => \%ProcessListACL,
        CustomerUserID => $Param{UserID},
    );

    if ( $ACL ) {
        my %ACLData = $Self->{TicketObject}->TicketAclData();
        %Result = map { $_ => $ProcessListRef->{$_} } sort keys %ACLData;
    }
    else {
        %Result = %{$ProcessListRef};
    }

    foreach my $ProcessID (keys %Result) {
        my $Process = $Self->{ProcessObject}->ProcessGet(
            ProcessEntityID => $ProcessID,
        );

        # ignore all processes not starting in customer frontend
        if (!$Process->{CustomerPortalGroupID}) {
            delete $Result{$ProcessID};
            next;
        }
        
        my %Data = (
            PortalGroupID   => $Process->{CustomerPortalGroupID},
            Name            => $Result{$ProcessID},
            Link            => "Action=CustomerTicketProcess;Subaction=DisplayActivityDialog;ProcessEntityID=$ProcessID;IsMainWindow=1",
            LinkClass       => "AsPopup",
        );
        $Result{$ProcessID} = \%Data;
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
