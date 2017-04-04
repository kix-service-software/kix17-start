# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::QuickLink::Ticket;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::LinkObject',
    'Kernel::System::Log',
    'Kernel::System::Ticket',
);

=head1 NAME

Kernel::System::QuickLink::Ticket

=head1 SYNOPSIS

Ticket backend for the QuickLink ticket object.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $QuickLinkTicketObject = $Kernel::OM->Get('Kernel::System::QuickLink::Ticket');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    # create needed objects
    $Self->{LinkObject} = $Kernel::OM->Get('Kernel::System::LinkObject');
    $Self->{LogObject}  = $Kernel::OM->Get('Kernel::System::Log');
    $Self->{TicketObject}  = $Kernel::OM->Get('Kernel::System::Ticket');

    # return
    return $Self;
}

=item AddLink()

add the object link

    my $Result = $QuickLinkObject->AddLink(
        SourceObject => 'Ticket',
        SourceKey => 123,
        TargetObject => 'Ticket',
        TargetKey => 123,
        LinkType  => '...',
        LinkDirection => '...',
    );

=cut

sub AddLink {
    my ( $Self, %Param ) = @_;

    # get needed params
    for (qw(SourceObject SourceKey TargetObject TargetKey LinkType LinkDirection)) {
        if ( !$Param{$_} ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    # handle TargetKey, because it's the TN not TicketID
    $Param{TargetKey} = $Self->{TicketObject}->TicketIDLookup(
        TicketNumber => $Param{TargetKey},
        UserID       => $Param{UserID},
    );

    my $SourceObject;
    my $SourceKey;
    my $TargetObject;
    my $TargetKey;
    if ( $Param{LinkDirection} eq 'Source' ) {
        $SourceObject = $Param{TargetObject};
        $SourceKey    = $Param{TargetKey};
        $TargetObject = $Param{SourceObject};
        $TargetKey    = $Param{SourceKey};
    }
    else {
        $SourceObject = $Param{SourceObject};
        $SourceKey    = $Param{SourceKey};
        $TargetObject = $Param{TargetObject};
        $TargetKey    = $Param{TargetKey};
    }

    # add link
    return $Self->{LinkObject}->LinkAdd(
        SourceObject => $SourceObject,
        SourceKey    => $SourceKey,
        TargetObject => $TargetObject,
        TargetKey    => $TargetKey,
        Type         => $Param{LinkType},
        State        => 'Valid',
        UserID       => $Param{UserID},
    );
}

=item Search()

Do the search

    my $Result = $QuickLinkObject->Search(
        Term => '...',
        MaxResults => 123,
        SourceObject => 'Ticket',
        SourceKey => 123,
        LinkType  => '...'
    );

=cut

sub Search {
    my ( $Self, %Param ) = @_;
    my %SearchList;

    # get needed params
    for (qw(Term MaxResults SourceObject SourceKey LinkType)) {
        if ( !$Param{$_} ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    # get search attributes
    my @SearchAttributes = split( ',', $Self->{Config}->{SearchAttribute} );

    # get list of already linked tickets
    my $LinkList = $Self->{LinkObject}->LinkList(
        Object    => $Param{SourceObject},
        Key       => $Param{SourceKey},
        Object2   => 'Ticket',
        State     => 'Valid',
        Type      => $Param{LinkType},
        Direction => $Param{LinkDirection},
        UserID    => $Param{UserID},
    );
    my %LinkedTickets;
    for my $TicketID (
        keys %{ $LinkList->{Ticket}->{ $Param{LinkType} }->{ $Param{LinkDirection} } }
        )
    {
        $LinkedTickets{$TicketID} = 1;
    }

    # do search
    for my $Filter (@SearchAttributes) {
        my %SearchHash;
        $SearchHash{$Filter} = $Param{Term};
        $SearchHash{StateType} = 'Open';
        my $ResultHash = $Self->{LinkObject}->ObjectSearch(
            Object       => 'Ticket',
            SearchParams => \%SearchHash,
            UserID       => $Param{UserID},
            LinkType     => 'NOTLINKED',
        );

        # remove doubles
        if ( $ResultHash && $ResultHash->{Ticket} ) {
            for my $LinkType ( keys %{ $ResultHash->{Ticket} } ) {

                # extract link type List
                my $LinkTypeList = $ResultHash->{Ticket}->{$LinkType};
                for my $Direction ( keys %{$LinkTypeList} ) {

                    # remove the source ticket ID
                    delete $LinkTypeList->{$Direction}->{ $Param{SourceKey} };
                    for my $TicketID ( keys %{ $LinkTypeList->{$Direction} } ) {
                        next if $SearchList{$TicketID};

                        # disabled - remove doubles
                        # next if $LinkedTickets{$TicketID};
                        $SearchList{$TicketID}
                            = $LinkTypeList->{$Direction}->{$TicketID}->{Title};
                    }
                }
            }
        }
    }

    # build data
    my @Data;
    my $MaxResultCount = $Param{MaxResults};
    SEARCHID:
    for my $TicketID (
        sort { $SearchList{$a} cmp $SearchList{$b} }
        keys %SearchList
        )
    {
        my %Ticket = $Self->{TicketObject}->TicketGet(
            TicketID => $TicketID,
        );
        push @Data, {
            SearchObjectKey   => $Ticket{TicketNumber},
            SearchObjectValue => $Ticket{Title},
        };
        $MaxResultCount--;
        last if $MaxResultCount == 0;
    }

    return @Data;
}

=item SelectableObjectAccepted()

Check if the selectable objects is configured for quicklink

    my $Result = $QuickLinkObject->SelectableObjectAccepted(
        Object => '...'
    );

=cut

sub SelectableObjectAccepted {
    my ( $Self, %Param ) = @_;

    # get needed params
    for (qw(Object)) {
        if ( !$Param{$_} ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    return if !( $Self->{Config}->{'SearchAttribute'} );

    return 1;
}

1;


=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
