# --
# Modified version of the work: Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2022 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AgentTicketZoomTabLinkedObjects;

use strict;
use warnings;

our $ObjectManagerDisabled = 1;

use POSIX qw/ceil/;

use Kernel::Language qw(Translatable);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    # set debug
    $Self->{Debug} = 0;

    # get needed objects
    my $ParamObject  = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    # ticket id lookup
    if ( !$Self->{TicketID} && $ParamObject->GetParam( Param => 'TicketNumber' ) ) {
        $Self->{TicketID} = $TicketObject->TicketIDLookup(
            TicketNumber => $ParamObject->GetParam( Param => 'TicketNumber' ),
            UserID       => $Self->{UserID},
        );
    }

    $Self->{CallingAction}    = $ParamObject->GetParam( Param => 'CallingAction' )    || '';
    $Self->{DirectLinkAnchor} = $ParamObject->GetParam( Param => 'DirectLinkAnchor' ) || '';
    $Self->{Config} = $ConfigObject->Get('Ticket::Frontend::AgentTicketZoomTabLinkedObjects');
    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # get layout object
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # check needed stuff
    if ( !$Self->{TicketID} ) {
        return $LayoutObject->ErrorScreen(
            Message => Translatable('No TicketID is given!'),
            Comment => Translatable('Please contact the administrator.'),
        );
    }

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    # check permissions
    my $Access = $TicketObject->TicketPermission(
        Type     => 'ro',
        TicketID => $Self->{TicketID},
        UserID   => $Self->{UserID}
    );

    # error screen, don't show ticket
    return $LayoutObject->NoPermission(
        Message => Translatable(
            'We are sorry, you do not have permissions anymore to access this ticket in its current state.'
        ),
        WithHeader => 'yes',
    ) if !$Access;

    # get ticket attributes
    my %Ticket = $TicketObject->TicketGet(
        TicketID      => $Self->{TicketID},
        DynamicFields => 1,
    );

    # get ACL restrictions
    my %PossibleActions;
    my $Counter = 0;

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # get all registered Actions
    if ( ref $ConfigObject->Get('Frontend::Module') eq 'HASH' ) {

        my %Actions = %{ $ConfigObject->Get('Frontend::Module') };

        # only use those Actions that stats with Agent
        %PossibleActions = map { ++$Counter => $_ }
            grep { substr( $_, 0, length 'Agent' ) eq 'Agent' }
            sort keys %Actions;
    }

    my $ACL = $TicketObject->TicketAcl(
        Data          => \%PossibleActions,
        Action        => $Self->{Action},
        TicketID      => $Self->{TicketID},
        ReturnType    => 'Action',
        ReturnSubType => '-',
        UserID        => $Self->{UserID},
    );

    my %AclAction = %PossibleActions;
    if ($ACL) {
        %AclAction = $TicketObject->TicketAclActionData();
    }

    # check if ACL restrictions exist
    my %AclActionLookup = reverse %AclAction;

    # show error screen if ACL prohibits this action
    if ( !$AclActionLookup{ $Self->{Action} } ) {
        return $LayoutObject->NoPermission( WithHeader => 'yes' );
    }

    # generate output
    my $Output = $Self->MaskAgentZoomTabLinkedObjects(
        Ticket    => \%Ticket,
        AclAction => \%AclAction
    );

    $Output .= $LayoutObject->Footer( Type => 'TicketZoomTab' );
    return $Output;
}

# sub MaskAgentZoom {
sub MaskAgentZoomTabLinkedObjects {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $ParamObject  = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');


    my %Ticket    = %{ $Param{Ticket} };
    my %AclAction = %{ $Param{AclAction} };

    # get linked objects
    my $LinkListWithData = $Kernel::OM->Get('Kernel::System::LinkObject')->LinkListWithData(
        Object           => 'Ticket',
        Key              => $Self->{TicketID},
        State            => 'Valid',
        UserID           => $Self->{UserID},
        ObjectParameters => {
            Ticket => {
                IgnoreLinkedTicketStateTypes => 1,
            },
        },
    );

    # get count method
    my $Result;
    my $TicketZoomBackendRef = $ConfigObject->Get('AgentTicketZoomBackend');
    if (
        $TicketZoomBackendRef->{'0120-LinkedObjects'}->{CountMethod}
        =~ /CallMethod::(\w+)::(\w+)::(\w+)/
        || $TicketZoomBackendRef->{'0120-LinkedObjects'}->{CountMethod}
        =~ /CallMethod::(\w+)::(\w+)/
    ) {
        my $Object     = $1;
        my $Method     = $2;
        my $Hashresult = $3;

        my $DisplayResult;
        if ( $Hashresult && $Hashresult ne '' ) {
            eval {
                $DisplayResult
                    = { $$Object->$Method( %Param, %Ticket, UserID => $Self->{UserID} ) }
                    ->{$Hashresult};
            };
        }
        else {
            eval {
                $DisplayResult
                    = $$Object->$Method( %Param, %Ticket, UserID => $Self->{UserID} );
            };
        }

        if ($DisplayResult) {
            $Result = $DisplayResult;
        }
    }

    my $Count = 0;
    for my $LinkObject ( keys %{$LinkListWithData} ) {
        for my $LinkType ( keys %{ $LinkListWithData->{$LinkObject} } ) {
            for my $LinkDirection ( keys %{ $LinkListWithData->{$LinkObject}->{$LinkType} } ) {
                for my $LinkItem (
                    keys %{ $LinkListWithData->{$LinkObject}->{$LinkType}->{$LinkDirection} }
                ) {
                    $LinkListWithData->{$LinkObject}->{$LinkType}->{$LinkDirection}->{$LinkItem}
                        ->{SourceObject} = 'Ticket';
                    $LinkListWithData->{$LinkObject}->{$LinkType}->{$LinkDirection}->{$LinkItem}
                        ->{SourceKey} = $Self->{TicketID};
                    $Count++;
                }
            }
        }
    }

    # get link table view mode
    my $LinkTableViewMode = $ConfigObject->Get('LinkObject::ViewMode');

    # add quicklink if enabled
    if ( $Self->{Config}->{QuickLink} ) {
        my $QuickLinkStrg = $LayoutObject->BuildQuickLinkHTML(
            Object     => 'Ticket',
            Key        => $Ticket{TicketID},
            RefreshURL => "Action=$Self->{Action};TicketID=$Self->{TicketID}",
        );
        $LayoutObject->Block(
            Name => 'QuickLink',
            Data => {
                QuickLinkContent => $QuickLinkStrg,
            },
        );
    }

    # create the link table
    my $LinkTableStrg = $LayoutObject->LinkObjectTableCreate(
        LinkListWithData => $LinkListWithData,
        ViewMode         => $LinkTableViewMode . 'Delete',
        Subaction        => $Self->{Subaction},
        TicketID         => $Self->{TicketID},
        GetPreferences   => 0,
    );

    # create the link table preferences
    my $PreferencesLinkTableStrg = $LayoutObject->LinkObjectTableCreate(
        LinkListWithData => $LinkListWithData,
        ViewMode         => $LinkTableViewMode . 'Delete',
        Subaction        => $Self->{Subaction},
        TicketID         => $Self->{TicketID},
        GetPreferences   => 1,
        QuickLink        => $Self->{Config}->{QuickLink},
    );

    $LayoutObject->Block(
        Name => 'TabContent',
        Data => {
            %Ticket,
            %Param,
            %AclAction,
            LinkTableStrg            => $LinkTableStrg,
            PreferencesLinkTableStrg => $PreferencesLinkTableStrg,
        },
    );

    # output the link table
    if ($LinkTableStrg) {
        $LayoutObject->Block(
            Name => 'LinkTable',
            Data => {
                LinkTableStrg => $LinkTableStrg,
            },
        );
    }

    $Param{UserLanguage} = $LayoutObject->{UserLanguage};

    # return output
    return $LayoutObject->Output(
        TemplateFile => 'AgentTicketZoomTabLinkedObjects',
        Data         => {
            %Param,
            %Ticket,
            %AclAction
        },
    );
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
