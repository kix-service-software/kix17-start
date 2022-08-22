# --
# Modified version of the work: Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2022 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::LinkObject::Ticket;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Log',
    'Kernel::System::Ticket',
);

=head1 NAME

Kernel::System::LinkObject::Ticket

=head1 SYNOPSIS

Ticket backend for the ticket link object.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $LinkObjectTicketObject = $Kernel::OM->Get('Kernel::System::LinkObject::Ticket');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=item LinkListWithData()

fill up the link list with data

    $Success = $LinkObjectBackend->LinkListWithData(
        LinkList                     => $HashRef,
        IgnoreLinkedTicketStateTypes => 0|1,        # (optional) default 0
        UserID                       => 1,
    );

=cut

sub LinkListWithData {
    my ( $Self, %Param ) = @_;

    # get needed object
    my $TicketObject          = $Kernel::OM->Get('Kernel::System::Ticket');
    my $LogObject             = $Kernel::OM->Get('Kernel::System::Log');
    my $ConfigObject          = $Kernel::OM->Get('Kernel::Config');
    my $CustomerUserObject    = $Kernel::OM->Get('Kernel::System::CustomerUser');
    my $CustomerCompanyObject = $Kernel::OM->Get('Kernel::System::CustomerCompany');

    # check needed stuff
    for my $Argument (qw(LinkList UserID)) {
        if ( !$Param{$Argument} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # check link list
    if ( ref $Param{LinkList} ne 'HASH' ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'LinkList must be a hash reference!',
        );
        return;
    }

    # get config, which ticket state types should not be included in linked tickets overview
    my @IgnoreLinkedTicketStateTypes = @{
        $ConfigObject->Get('LinkObject::IgnoreLinkedTicketStateTypes')
            // []
    };

    my %IgnoreLinkTicketStateTypesHash;
    map { $IgnoreLinkTicketStateTypesHash{$_}++ } @IgnoreLinkedTicketStateTypes;

    for my $LinkType ( keys %{ $Param{LinkList} } ) {

        for my $Direction ( keys %{ $Param{LinkList}->{$LinkType} } ) {

            TICKETID:
            for my $TicketID ( keys %{ $Param{LinkList}->{$LinkType}->{$Direction} } ) {
                # get ticket data
                my %TicketData = $TicketObject->TicketGet(
                    TicketID      => $TicketID,
                    UserID        => $Param{UserID},
                    DynamicFields => 1,
                );

                # remove id from hash if ticket can not get
                if ( !%TicketData ) {
                    delete $Param{LinkList}->{$LinkType}->{$Direction}->{$TicketID};
                    next TICKETID;
                }

                # if param is set, remove entries from hash with configured ticket state types
                if (
                    $Param{IgnoreLinkedTicketStateTypes}
                    && $IgnoreLinkTicketStateTypesHash{ $TicketData{StateType} }
                ) {
                    delete $Param{LinkList}->{$LinkType}->{$Direction}->{$TicketID};
                    next TICKETID;
                }

                if (
                    $TicketData{CustomerUserID}
                    && !$TicketData{CustomerName}
                ) {
                    $TicketData{CustomerName} = $CustomerUserObject->CustomerName(
                        UserLogin => $TicketData{CustomerUserID},
                    );

                    if ( !$TicketData{CustomerName} ) {
                        my %CustomerUsers = $CustomerUserObject->CustomerSearch(
                            PostMasterSearch => $TicketData{CustomerUserID},
                        );

                        if ( %CustomerUsers ) {
                            my @CustomerUserIDs = keys %CustomerUsers;

                            $TicketData{CustomerName} = $CustomerUserObject->CustomerName(
                                UserLogin => $CustomerUserIDs[0],
                            );
                        }
                    }

                    if ( !$TicketData{CustomerName} ) {
                        $TicketData{CustomerName} = $TicketData{CustomerUserID};
                    }
                }

                if (
                    $TicketData{CustomerID}
                    && !$TicketData{CustomerCompanyName}
                ) {
                    my %CustomerCompanyData = $CustomerCompanyObject->CustomerCompanyGet(
                        CustomerID => $TicketData{CustomerID},
                    );
                    if ( %CustomerCompanyData ) {
                        $TicketData{CustomerCompanyName} = $CustomerCompanyData{CustomerCompanyName};
                    }
                }

                # add ticket data
                $Param{LinkList}->{$LinkType}->{$Direction}->{$TicketID} = \%TicketData;
            }
        }
    }

    return 1;
}

=item ObjectPermission()

checks read permission for a given object and UserID.

    $Permission = $LinkObject->ObjectPermission(
        Object  => 'Ticket',
        Key     => 123,
        UserID  => 1,
    );

=cut

sub ObjectPermission {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(Object Key UserID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # special handling for form ids
    return 1 if ( $Param{Key} =~ m/\d+\.\d+\.\d+/ );

    return $Kernel::OM->Get('Kernel::System::Ticket')->TicketPermission(
        Type     => 'ro',
        TicketID => $Param{Key},
        UserID   => $Param{UserID},
        LogNo    => 1,
    );
}

=item ObjectDescriptionGet()

return a hash of object descriptions

Return
    %Description = (
        Normal => "Ticket# 1234455",
        Long   => "Ticket# 1234455: The Ticket Title",
    );

    %Description = $LinkObject->ObjectDescriptionGet(
        Key     => 123,
        Mode    => 'Temporary',  # (optional)
        UserID  => 1,
    );

=cut

sub ObjectDescriptionGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(Object Key UserID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # create description
    my %Description = (
        Normal => 'Ticket',
        Long   => 'Ticket',
    );

    return %Description if $Param{Mode} && $Param{Mode} eq 'Temporary';

    # get ticket
    my %Ticket = $Kernel::OM->Get('Kernel::System::Ticket')->TicketGet(
        TicketID      => $Param{Key},
        UserID        => $Param{UserID},
        DynamicFields => 0,
    );

    return if !%Ticket;

    my $ParamHook = $Kernel::OM->Get('Kernel::Config')->Get('Ticket::Hook') || 'Ticket#';
    $ParamHook .= $Kernel::OM->Get('Kernel::Config')->Get('Ticket::HookDivider') || '';

    # create description
    %Description = (
        Normal => $ParamHook . "$Ticket{TicketNumber}",
        Long   => $ParamHook . "$Ticket{TicketNumber}: $Ticket{Title}",
    );

    return %Description;
}

=item ObjectSearch()

return a hash list of the search results

Return
    $SearchList = {
        NOTLINKED => {
            Source => {
                12  => $DataOfItem12,
                212 => $DataOfItem212,
                332 => $DataOfItem332,
            },
        },
    };

    $SearchList = $LinkObjectBackend->ObjectSearch(
        SubObject    => 'Bla',     # (optional)
        SearchParams => $HashRef,  # (optional)
        UserID       => 1,
    );

=cut

sub ObjectSearch {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{UserID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need UserID!',
        );
        return;
    }

    # set default params
    $Param{SearchParams} ||= {};

    # set focus
    my %Search;
    if ( $Param{SearchParams}->{TicketFulltext} ) {
        %Search = (
            From          => '*' . $Param{SearchParams}->{TicketFulltext} . '*',
            To            => '*' . $Param{SearchParams}->{TicketFulltext} . '*',
            Cc            => '*' . $Param{SearchParams}->{TicketFulltext} . '*',
            Subject       => '*' . $Param{SearchParams}->{TicketFulltext} . '*',
            Body          => '*' . $Param{SearchParams}->{TicketFulltext} . '*',
            ContentSearch => 'OR',
        );
    }
    if ( $Param{SearchParams}->{TicketTitle} ) {
        $Search{Title} = '*' . $Param{SearchParams}->{TicketTitle} . '*';
    }

    if ( IsArrayRefWithData( $Param{SearchParams}->{ArchiveID} ) ) {
        if ( $Param{SearchParams}->{ArchiveID}->[0] eq 'AllTickets' ) {
            $Search{ArchiveFlags} = [ 'y', 'n' ];
        }
        elsif ( $Param{SearchParams}->{ArchiveID}->[0] eq 'NotArchivedTickets' ) {
            $Search{ArchiveFlags} = ['n'];
        }
        elsif ( $Param{SearchParams}->{ArchiveID}->[0] eq 'ArchivedTickets' ) {
            $Search{ArchiveFlags} = ['y'];
        }
    }

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    # search the tickets
    my @TicketIDs = $TicketObject->TicketSearch(
        %{ $Param{SearchParams} },
        %Search,
        Limit               => 50,
        Result              => 'ARRAY',
        ConditionInline     => 1,
        ContentSearchPrefix => '*',
        ContentSearchSuffix => '*',
        FullTextIndex       => 1,
        OrderBy             => 'Down',
        SortBy              => 'Age',
        UserID              => $Param{UserID},
    );

    my %SearchList;
    TICKETID:
    for my $TicketID (@TicketIDs) {

        # get ticket data
        my %TicketData = $TicketObject->TicketGet(
            TicketID      => $TicketID,
            UserID        => $Param{UserID},
            DynamicFields => 0,
        );

        next TICKETID if !%TicketData;

        # add ticket data
        $SearchList{NOTLINKED}->{Source}->{$TicketID} = \%TicketData;
    }

    return \%SearchList;
}

=item LinkAddPre()

link add pre event module

    $True = $LinkObject->LinkAddPre(
        Key          => 123,
        SourceObject => 'Ticket',
        SourceKey    => 321,
        Type         => 'Normal',
        State        => 'Valid',
        UserID       => 1,
    );

    or

    $True = $LinkObject->LinkAddPre(
        Key          => 123,
        TargetObject => 'Ticket',
        TargetKey    => 321,
        Type         => 'Normal',
        State        => 'Valid',
        UserID       => 1,
    );

=cut

sub LinkAddPre {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(Key Type State UserID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    return 1 if $Param{State} eq 'Temporary';

    return 1;
}

=item LinkAddPost()

link add pre event module

    $True = $LinkObject->LinkAddPost(
        Key          => 123,
        SourceObject => 'Ticket',
        SourceKey    => 321,
        Type         => 'Normal',
        State        => 'Valid',
        UserID       => 1,
    );

    or

    $True = $LinkObject->LinkAddPost(
        Key          => 123,
        TargetObject => 'Ticket',
        TargetKey    => 321,
        Type         => 'Normal',
        State        => 'Valid',
        UserID       => 1,
    );

=cut

sub LinkAddPost {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(Key Type State UserID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    return 1 if $Param{State} eq 'Temporary';

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    if ( $Param{SourceObject} && $Param{SourceObject} eq 'Ticket' && $Param{SourceKey} ) {

        # lookup ticket number
        my $TicketNumber = $TicketObject->TicketNumberLookup(
            TicketID => $Param{SourceKey},
            UserID   => $Param{UserID},
        );

        # add ticket history entry
        $TicketObject->HistoryAdd(
            TicketID     => $Param{Key},
            CreateUserID => $Param{UserID},
            HistoryType  => 'TicketLinkAdd',
            Name         => "\%\%$TicketNumber\%\%$Param{SourceKey}\%\%$Param{Key}",
        );

        # ticket event
        $TicketObject->EventHandler(
            Event => 'TicketSlaveLinkAdd' . $Param{Type},
            Data  => {
                TicketID => $Param{Key},
            },
            UserID => $Param{UserID},
        );

        return 1;
    }

    if ( $Param{TargetObject} && $Param{TargetObject} eq 'Ticket' && $Param{TargetKey} ) {

        # lookup ticket number
        my $TicketNumber = $TicketObject->TicketNumberLookup(
            TicketID => $Param{TargetKey},
            UserID   => $Param{UserID},
        );

        # add ticket history entry
        $TicketObject->HistoryAdd(
            TicketID     => $Param{Key},
            CreateUserID => $Param{UserID},
            HistoryType  => 'TicketLinkAdd',
            Name         => "\%\%$TicketNumber\%\%$Param{TargetKey}\%\%$Param{Key}",
        );

        # ticket event
        $TicketObject->EventHandler(
            Event  => 'TicketMasterLinkAdd' . $Param{Type},
            UserID => $Param{UserID},
            Data   => {
                TicketID => $Param{Key},
            },
        );

        return 1;
    }

    # do action for other link objects (document, change, CI)
    if ( $Param{TargetObject} ) {

        # add ticket history entry
        $TicketObject->HistoryAdd(
            TicketID     => $Param{Key},
            CreateUserID => $Param{UserID},
            HistoryType  => 'TicketLinkAdd',
            Name         => "\%\%$Param{TargetObject}\%\%$Param{TargetObject}\%\%$Param{Key}",
        );

        $TicketObject->EventHandler(
            Event  => 'TicketMasterLinkAdd' . $Param{Type},
            UserID => $Param{UserID},
            Data   => {
                TicketID => $Param{Key},
            },
        );
    }
    elsif ( $Param{SourceObject} ) {

        # add ticket history entry
        $TicketObject->HistoryAdd(
            TicketID     => $Param{Key},
            CreateUserID => $Param{UserID},
            HistoryType  => 'TicketLinkAdd',
            Name         => "\%\%$Param{SourceObject}\%\%$Param{SourceObject}\%\%$Param{Key}",
        );

        # ticket event
        $TicketObject->EventHandler(
            Event => 'TicketSlaveLinkAdd' . $Param{Type},
            Data  => {
                TicketID => $Param{Key},
            },
            UserID => $Param{UserID},
        );
    }

    return 1;
}

=item LinkDeletePre()

link delete pre event module

    $True = $LinkObject->LinkDeletePre(
        Key          => 123,
        SourceObject => 'Ticket',
        SourceKey    => 321,
        Type         => 'Normal',
        State        => 'Valid',
        UserID       => 1,
    );

    or

    $True = $LinkObject->LinkDeletePre(
        Key          => 123,
        TargetObject => 'Ticket',
        TargetKey    => 321,
        Type         => 'Normal',
        State        => 'Valid',
        UserID       => 1,
    );

=cut

sub LinkDeletePre {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(Key Type State UserID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    return 1 if $Param{State} eq 'Temporary';

    return 1;
}

=item LinkDeletePost()

link delete post event module

    $True = $LinkObject->LinkDeletePost(
        Key          => 123,
        SourceObject => 'Ticket',
        SourceKey    => 321,
        Type         => 'Normal',
        State        => 'Valid',
        UserID       => 1,
    );

    or

    $True = $LinkObject->LinkDeletePost(
        Key          => 123,
        TargetObject => 'Ticket',
        TargetKey    => 321,
        Type         => 'Normal',
        State        => 'Valid',
        UserID       => 1,
    );

=cut

sub LinkDeletePost {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(Key Type State UserID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    return 1 if $Param{State} eq 'Temporary';

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    if ( $Param{SourceObject} && $Param{SourceObject} eq 'Ticket' && $Param{SourceKey} ) {

        # lookup ticket number
        my $TicketNumber = $TicketObject->TicketNumberLookup(
            TicketID => $Param{SourceKey},
            UserID   => $Param{UserID},
        );

        # add ticket history entry
        $TicketObject->HistoryAdd(
            TicketID     => $Param{Key},
            CreateUserID => $Param{UserID},
            HistoryType  => 'TicketLinkDelete',
            Name         => "\%\%$TicketNumber\%\%$Param{SourceKey}\%\%$Param{Key}",
        );

        # ticket event
        $TicketObject->EventHandler(
            Event => 'TicketSlaveLinkDelete' . $Param{Type},
            Data  => {
                TicketID => $Param{Key},
            },
            UserID => $Param{UserID},
        );

        return 1;
    }

    if ( $Param{TargetObject} && $Param{TargetObject} eq 'Ticket' && $Param{TargetKey} ) {

        # lookup ticket number
        my $TicketNumber = $TicketObject->TicketNumberLookup(
            TicketID => $Param{TargetKey},
            UserID   => $Param{UserID},
        );

        # add ticket history entry
        $TicketObject->HistoryAdd(
            TicketID     => $Param{Key},
            CreateUserID => $Param{UserID},
            HistoryType  => 'TicketLinkDelete',
            Name         => "\%\%$TicketNumber\%\%$Param{TargetKey}\%\%$Param{Key}",
        );

        # ticket event
        $TicketObject->EventHandler(
            Event => 'TicketMasterLinkDelete' . $Param{Type},
            Data  => {
                TicketID => $Param{Key},
            },
            UserID => $Param{UserID},
        );

        return 1;
    }

    # do action for other link objects (document, change, CI)
    if ( $Param{TargetObject} ) {

        # add ticket history entry
        $TicketObject->HistoryAdd(
            TicketID     => $Param{Key},
            CreateUserID => $Param{UserID},
            HistoryType  => 'TicketLinkDelete',
            Name         => "\%\%$Param{TargetObject}\%\%$Param{TargetObject}\%\%$Param{Key}",
        );

        # ticket event
        $TicketObject->EventHandler(
            Event  => 'TicketMasterLinkDelete' . $Param{Type},
            UserID => $Param{UserID},
            Data   => {
                TicketID => $Param{Key},
            },
        );
    }
    elsif ( $Param{SourceObject} ) {

        # add ticket history entry
        $TicketObject->HistoryAdd(
            TicketID     => $Param{Key},
            CreateUserID => $Param{UserID},
            HistoryType  => 'TicketLinkDelete',
            Name         => "\%\%$Param{SourceObject}\%\%$Param{SourceObject}\%\%$Param{Key}",
        );

        # ticket event
        $TicketObject->EventHandler(
            Event  => 'TicketSlaveLinkDelete' . $Param{Type},
            UserID => $Param{UserID},
            Data   => {
                TicketID => $Param{Key},
            },
        );
    }

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
