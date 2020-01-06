# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::QuickLink::Person;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::LinkObject',
    'Kernel::System::Log',
);

=head1 NAME

Kernel::System::QuickLink::Person

=head1 SYNOPSIS

Ticket backend for the QuickLink Person object.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $QuickLinkPersonObject = $Kernel::OM->Get('Kernel::System::QuickLink::Person');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    # create needed objects
    $Self->{LinkObject} = $Kernel::OM->Get('Kernel::System::LinkObject');
    $Self->{LogObject}  = $Kernel::OM->Get('Kernel::System::Log');

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

    # search for customers if linktype is 3rdParty
    if ( $Param{LinkType} eq '3rdParty' ) {
        $Param{LinkType} = 'Customer';
    }

    # get list of already linked persons
    my $LinkList = $Self->{LinkObject}->LinkList(
        Object    => $Param{SourceObject},
        Key       => $Param{SourceKey},
        Object2   => 'Person',
        State     => 'Valid',
        Type      => $Param{LinkType},
        Direction => $Param{LinkDirection},
        UserID    => $Param{UserID},
    );
    my %LinkedPersons;
    for my $UserID (
        keys %{ $LinkList->{Person}->{ $Param{LinkType} }->{ $Param{LinkDirection} } }
    ) {
        $LinkedPersons{$UserID} = 1;
    }

    # define person type (e.g. Agent, Customer, ...)
    my @PersonType;
    push @PersonType, $Param{LinkType};

    # do search
    for my $Filter (@SearchAttributes) {
        my %SearchHash;
        $SearchHash{$Filter} = $Param{Term};
        $SearchHash{PersonType} = \@PersonType;
        my $ResultHash = $Self->{LinkObject}->ObjectSearch(
            Object       => 'Person',
            SearchParams => \%SearchHash,
            UserID       => $Param{UserID},
            LinkType     => 'NOTLINKED',
        );

        # remove doubles
        if ( $ResultHash && $ResultHash->{Person} ) {
            for my $LinkType ( keys %{ $ResultHash->{Person} } ) {

                # extract link type List
                my $LinkTypeList = $ResultHash->{Person}->{$LinkType};
                for my $Direction ( keys %{$LinkTypeList} ) {

                    # remove the source ticket ID
                    for my $UserLogin ( keys %{ $LinkTypeList->{$Direction} } ) {
                        next if $SearchList{$UserLogin};

                        # disabled - remove doubles
                        # next if $LinkedPersons{$UserLogin};
                        $SearchList{$UserLogin}
                            = $LinkTypeList->{$Direction}->{$UserLogin}->{UserFirstname} . ' '
                            . $LinkTypeList->{$Direction}->{$UserLogin}->{UserLastname};
                    }
                }
            }
        }
    }

    # build data
    my @Data;
    my $MaxResultCount = $Param{MaxResults};
    SEARCHID:
    for my $SearchID (
        sort { $SearchList{$a} cmp $SearchList{$b} }
        keys %SearchList
    ) {
        push @Data, {
            SearchObjectKey   => $SearchID,
            SearchObjectValue => $SearchList{$SearchID},
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
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
