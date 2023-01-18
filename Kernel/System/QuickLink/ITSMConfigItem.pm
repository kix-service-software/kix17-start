# --
# Copyright (C) 2006-2023 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::QuickLink::ITSMConfigItem;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::ITSMConfigItem',
    'Kernel::System::GeneralCatalog',
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
    $Self->{ConfigItemObject}     = $Kernel::OM->Get('Kernel::System::ITSMConfigItem');
    $Self->{GeneralCatalogObject} = $Kernel::OM->Get('Kernel::System::GeneralCatalog');
    $Self->{LinkObject}           = $Kernel::OM->Get('Kernel::System::LinkObject');
    $Self->{LogObject}            = $Kernel::OM->Get('Kernel::System::Log');

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

    # handle TargetKey, because it's the ConfigItemNumber not ConfigItemID
    $Param{TargetKey} = $Self->{ConfigItemObject}->ConfigItemLookup(
        ConfigItemNumber => $Param{TargetKey},
    );

    ( $Param{TargetObject}, $Param{ClassID} ) = split( '::', $Param{TargetObject} );

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
    for (qw(Term MaxResults SourceObject SourceKey TargetObject LinkType)) {
        if ( !$Param{$_} ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    # get class
    my $ClassID = '';
    if ( $Param{TargetObject} =~ /(.*)::(.*)/ ) {
        $ClassID = $2;
    }

    # get class list
    my @SearchAttributes;
    my $Item;
    if ( $ClassID ne 'All' ) {
        $Item = $Self->{GeneralCatalogObject}->ItemGet(
            ItemID => $ClassID,
        );
    }
    else {
        $Item->{Name} = 'All';
    }

    # get search attributes
    my $SearchAttribute
        = $Self->{Config}->{ 'SearchAttribute::' . $Item->{Name} }
        || $Self->{Config}->{SearchAttribute};
    @SearchAttributes = split( ',', $SearchAttribute );

    # do search
    for my $Filter (@SearchAttributes) {
        my %SearchHash;
        $SearchHash{$Filter} = $Param{Term};

        # do object search
        my $ResultHash = $Self->{LinkObject}->ObjectSearch(
            Object       => 'ITSMConfigItem',
            SubObject    => $ClassID,
            SearchParams => \%SearchHash,
            UserID       => $Param{UserID},
        );

        for my $LinkType ( keys %{ $ResultHash->{ITSMConfigItem} } ) {

            # extract link type List
            my $LinkTypeList = $ResultHash->{ITSMConfigItem}->{$LinkType};
            for my $Direction ( keys %{$LinkTypeList} ) {
                for my $ConfigItemID ( keys %{ $LinkTypeList->{$Direction} } ) {
                    next if $SearchList{$ConfigItemID};

                    # check ro permission on CI
                    my $ROCheck = $Self->{ConfigItemObject}->Permission(
                        Scope  => 'Item',
                        ItemID => $ConfigItemID,
                        UserID => $Param{UserID},
                        Type   => 'ro',
                    ) || 0;
                    next if !$ROCheck;

                    $SearchList{$ConfigItemID} = $LinkTypeList->{$Direction}->{$ConfigItemID}->{Name};
                }
            }
        }
    }

    # build data
    my @Data;
    my $MaxResultCount = $Param{MaxResults};
    SEARCHID:
    for my $ConfigItemID (
        sort { $SearchList{$a} cmp $SearchList{$b} }
        keys %SearchList
    ) {
        my $ConfigItem = $Self->{ConfigItemObject}->ConfigItemGet(
            ConfigItemID => $ConfigItemID,
        );
        push @Data, {
            SearchObjectKey   => $ConfigItem->{Number},
            SearchObjectID    => $ConfigItemID,
            SearchObjectValue => $SearchList{$ConfigItemID},
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
    for (qw(Object SubObject)) {
        if ( !$Param{$_} ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    # get Classname for ClassID (SubObject)
    my $Item;
    if ( $Param{SubObject} ne 'All' ) {
        $Item = $Self->{GeneralCatalogObject}->ItemGet(
            ItemID => $Param{SubObject},
        );
    }
    else {
        $Item->{Name} = 'All';
    }
    return 0 if !$Item;

    # filter out all the classes we don't have a searchconfig for
    my %SearchClasses = map { $_ => 1 } split( ',', $Self->{Config}->{SearchClass} );
    return 0
        if (
        !$SearchClasses{ $Item->{Name} }
        || (
            !$Self->{Config}->{ 'SearchAttribute::' . $Item->{Name} }
            && !$Self->{Config}->{SearchAttribute}
        )
        );

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
