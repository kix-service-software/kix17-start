# --
# Copyright (C) 2006-2018 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AgentLinkObjectUtils;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # create needed objects
    my $DocumentObject = $Kernel::OM->Get('Kernel::System::Document');
    my $LinkObject     = $Kernel::OM->Get('Kernel::System::LinkObject');
    my $TicketObject   = $Kernel::OM->Get('Kernel::System::Ticket');
    my $ParamObject        = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $LayoutObject       = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    my $RedirectParams;
    my %GetParam;

    if ( !$Self->{Subaction} ) {
        return $LayoutObject
            ->ErrorScreen( Message => 'AgentLinkObjectUtils: No Subaction given!' );
    }
    elsif ( $Self->{Subaction} eq 'DownloadDocument' ) {
        for (qw(DocumentID)) {
            $GetParam{$_} = $ParamObject->GetParam( Param => $_ );
            if ( !$GetParam{$_} ) {
                return $LayoutObject->ErrorScreen( Message => 'Need ' . $_ . '!' );
            }
        }

        my $Permission = $DocumentObject->DocumentCheckPermission(
            DocumentID => $GetParam{DocumentID},
            UserID     => $Self->{UserID}
        );
        if ( $Permission eq 'Access' ) {
            my %DocumentData = $DocumentObject->DocumentGet(
                DocumentID => $GetParam{DocumentID}
            );

            return $LayoutObject->Attachment(
                Filename    => $DocumentData{Name},
                ContentType => 'application/unknown',
                Content     => $DocumentData{Content},
                Type        => 'inline',
            );
        }
        else {
            return $LayoutObject
                ->ErrorScreen( Message => 'AgentLinkObjectUtils: No Permission!' );
        }
    }
    elsif ( $Self->{Subaction} eq 'DeleteLink' ) {
        for (qw(IsAJAXCall)) {
            $GetParam{$_} = $ParamObject->GetParam( Param => $_ );
        }

        for (qw(OrgAction SourceObject SourceKey)) {
            $GetParam{$_} = $ParamObject->GetParam( Param => $_ );
            if ( !$GetParam{$_} ) {
                return $LayoutObject
                    ->ErrorScreen( Message => 'AgentLinkObjectUtils: Need ' . $_ . '!' );
            }
        }

        for (qw(TargetObject TargetKey LinkType)) {
            $GetParam{$_} = $ParamObject->GetParam( Param => $_ );
            if ( !$GetParam{$_} ) {
                return $LayoutObject
                    ->ErrorScreen( Message => 'AgentLinkObjectUtils: Need ' . $_ . '!' );
            }
        }

        # delete the specified linked object
        $LinkObject->LinkDelete(
            Object1 => $GetParam{SourceObject},
            Key1    => $GetParam{SourceKey},
            Object2 => $GetParam{TargetObject},
            Key2    => $GetParam{TargetKey},
            Type    => $GetParam{LinkType},
            UserID  => $Self->{UserID},
        );

        if ( $GetParam{SourceObject} eq 'Ticket' ) {
            $TicketObject->HistoryAdd(
                Name => 'removed LinkObject '
                    . $GetParam{TargetObject} . ' '
                    . $GetParam{TargetKey},
                HistoryType  => 'TicketLinkDelete',
                TicketID     => $GetParam{SourceKey},
                CreateUserID => $Self->{UserID},
            );
            $RedirectParams = 'TicketID=' . $GetParam{SourceKey};
        }
        elsif ( $GetParam{SourceObject} eq 'ITSMConfigItem' ) {
            $RedirectParams = 'ConfigItemID=' . $GetParam{SourceKey};
        }
        elsif ( $GetParam{SourceObject} eq 'ITSMChange' ) {
            $RedirectParams = 'ChangeID=' . $GetParam{SourceKey};
        }
        elsif ( $GetParam{SourceObject} eq 'ITSMWorkOrder' ) {
            $RedirectParams = 'WorkOrderID=' . $GetParam{SourceKey};
        }
        elsif ( $GetParam{SourceObject} eq 'Service' ) {
            $RedirectParams = 'ServiceID=' . $GetParam{SourceKey};
        }

        if ( !$GetParam{IsAJAXCall} ) {

            # redirect
            return $LayoutObject->Redirect(
                OP => 'Action=' . $GetParam{OrgAction} . ';' . $RedirectParams
            );
        }
        else {

            # Action called from AJAX function, return pseudo attachment
            return $LayoutObject->Attachment(
                ContentType => 'text/plain; charset=' . $LayoutObject->{Charset},
                Content     => '<br/>',
                Type        => 'inline',
                NoCache     => 1,
            );
        }
    }
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
