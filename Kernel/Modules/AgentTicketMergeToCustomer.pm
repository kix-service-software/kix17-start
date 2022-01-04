# --
# Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AgentTicketMergeToCustomer;
use strict;
use warnings;

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
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ParamObject  = $Kernel::OM->Get('Kernel::System::Web::Request');

    # get config
    my $Config = $ConfigObject->Get("Ticket::Frontend::$Self->{Action}");

    $Param{CustomerUserID} = $ParamObject->GetParam(
        Param => 'CustomerUserID'
    );
    $Param{MainTicketID} = $ParamObject->GetParam(
        Param => 'MainTicketID'
    );
    $Param{SelectMergeMainTicketID} = $ParamObject->GetParam(
        Param => 'SelectMergeMainTicketID'
    );
    my @SelectedTicketIDs = $ParamObject->GetArray(
        Param => 'SelectedTicketID'
    );

    my @SelectHistoryOptions = @{
        $ConfigObject->Get('Ticket::Frontend::AgentTicketMergeToCustomer')
            ->{'AnsweredHistoryType'}
        };

    # check required params...
    if ( !$Param{MainTicketID} ) {

        # error page
        return $LayoutObject->ErrorScreen(
            Message => "No TicketID is given!",
            Comment => 'Please contact the admin.',
        );
    }

    # check permissions
    my $Access = $TicketObject->TicketPermission(
        Type     => $Config->{Permission},
        TicketID => $Param{MainTicketID},
        UserID   => $Self->{UserID}
    );

    # error screen, don't show ticket
    if ( !$Access ) {
        return $LayoutObject->NoPermission(
            Message    => "You need $Config->{Permission} permissions!",
            WithHeader => 'yes',
        );
    }

    # get lock state && write (lock) permissions
    if ( $Config->{RequiredLock} ) {
        if ( !$TicketObject->TicketLockGet( TicketID => $Param{MainTicketID} ) ) {
            $TicketObject->TicketLockSet(
                TicketID => $Param{MainTicketID},
                Lock     => 'lock',
                UserID   => $Self->{UserID}
            );
            if (
                $TicketObject->TicketOwnerSet(
                    TicketID  => $Param{MainTicketID},
                    UserID    => $Self->{UserID},
                    NewUserID => $Self->{UserID},
                )
            ) {

                # show lock state
                $LayoutObject->Block(
                    Name => 'PropertiesLock',
                    Data => { %Param, TicketID => $Param{MainTicketID}, },
                );
            }
        }
        else {
            my $AccessOk = $TicketObject->OwnerCheck(
                TicketID => $Param{MainTicketID},
                OwnerID  => $Self->{UserID},
            );
            if ( !$AccessOk ) {
                my $TicketNumber = $TicketObject->TicketNumberLookup(
                    TicketID => $Param{MainTicketID},
                    OwnerID  => $Self->{UserID},
                );
                my $Output = $LayoutObject->Header(
                    Value => $TicketNumber,
                    Type  => 'Small',
                );
                $Output .= $LayoutObject->Warning(
                    Message => "Sorry, you need to be the owner to do this action!",
                    Comment => 'Please change the owner first.',
                );
                $Output .= $LayoutObject->Footer(
                    Type => 'Small',
                );
                return $Output;
            }

            # show back link
            $LayoutObject->Block(
                Name => 'TicketBack',
                Data => { %Param, TicketID => $Param{MainTicketID} },
            );
        }
    }

    # SUBACTION - merge all selected tickets...
    if ( $Self->{Subaction} eq 'Merge' ) {
        @SelectedTicketIDs = sort { $a <=> $b } @SelectedTicketIDs;

        # merge to newest ticket...
        if (
            $Param{SelectMergeMainTicketID}
            && $Param{SelectMergeMainTicketID} eq 'N'
        ) {

            # newest ticket = highest ticket ID
            $Param{SelectMergeMainTicketID} = pop(@SelectedTicketIDs);
        }

        # merge to oldest ticket...
        elsif (
            $Param{SelectMergeMainTicketID}
            && $Param{SelectMergeMainTicketID} eq 'O'
        ) {

            # oldest ticket = lowest ticket ID
            $Param{SelectMergeMainTicketID} = shift(@SelectedTicketIDs);
        }

        for my $SelectedTicket (@SelectedTicketIDs) {
            if ( $SelectedTicket != $Param{SelectMergeMainTicketID} ) {
                $TicketObject->TicketMerge(
                    MainTicketID  => $Param{SelectMergeMainTicketID},
                    MergeTicketID => $SelectedTicket,
                    UserID        => $Self->{UserID},
                );
            }
        }

        # redirect to merged ticket
        return $LayoutObject->PopupClose(
            URL => "Action=AgentTicketZoom&TicketID=$Param{SelectMergeMainTicketID}",
        );
    }

    # search all open Tickets for this customer...
    my @StateTypes = $ConfigObject->Get('Ticket::Frontend::AgentTicketMergeToCustomer')
        ->{'StateTypes'};
    my @TicketIDs = $TicketObject->TicketSearch(
        Result            => 'ARRAY',
        CustomerUserLogin => $Param{CustomerUserID},
        StateType         => @StateTypes,
        UserID            => $Self->{UserID},
    );

    # get ticket data...
    my %Ticket      = ();
    my %HistoryData = ();

    for my $TicketID (@TicketIDs) {
        %Ticket = $TicketObject->TicketGet( TicketID => $TicketID );

        # history data get
        my @HistoryData = $TicketObject->HistoryGet(
            TicketID => $TicketID,
            UserID   => $Param{CustomerUserID},
        );

        for my $Line ( sort @HistoryData ) {
            my $RightsItem = $Line->{HistoryType};
            if ( grep( {/^$RightsItem$/} @SelectHistoryOptions ) ) {
                $Ticket{Image}   = 'Answered';
                $Ticket{Checked} = '';
                last;
            }
            else {
                $Ticket{Image}   = '';
                $Ticket{Checked} = 'checked="checked"';
            }
        }
        $LayoutObject->Block(
            Name => 'Row',
            Data => {
                %Param,
                %Ticket,
            },
        );
    }
    $Param{MergeDestStrg} = $LayoutObject->BuildSelection(
        Data => {
            $Param{MainTicketID} => 'current ticket',
            'N'                  => 'newest ticket',
            'O'                  => 'oldest ticket'
        },
        Name => 'SelectMergeMainTicketID',
        SelectedID => $Param{SelectMergeMainTicketID} || 'O',
    );

    my $Output = $LayoutObject->Header(
        Type => 'Small',
    );
    $Output .= $LayoutObject->Output(
        TemplateFile => 'AgentTicketMergeToCustomer',
        Data         => {
            %Param,
            CssClass => $Self->{CssClass},
        },
    );
    $Output .= $LayoutObject->Footer( Type => 'Small', );

    return $Output;
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
