# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AgentGenericAutoCompleteSearch;

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
    my $Search;
    my $JSON = '';
    my %SearchList;

    # create needed objects
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $EncodeObject = $Kernel::OM->Get('Kernel::System::Encode');
    my $GroupObject  = $Kernel::OM->Get('Kernel::System::Group');
    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');
    my $QueueObject  = $Kernel::OM->Get('Kernel::System::Queue');
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');
    my $UserObject   = $Kernel::OM->Get('Kernel::System::User');
    my $LayoutObject       = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ParamObject        = $Kernel::OM->Get('Kernel::System::Web::Request');

    # search
    if ( !$Self->{Subaction} ) {

        for (qw(Term TicketID Module MaxResults ElementID)) {
            $Param{$_} = $ParamObject->GetParam( Param => $_ ) || '';
        }

        my $Config     = $ConfigObject->Get('Ticket::Frontend::GenericAutoCompleteSearch');
        my $SearchType = $Config->{SearchTypeMapping};

        # get needed params
        for (qw(TicketID Module ElementID)) {
            if ( !$Param{$_} ) {
                $LogObject->Log( Priority => 'error', Message => "Need $_!" );
                return;
            }
        }

        # workaround, all auto completion requests get posted by utf8 anyway
        # convert any to 8bit string if application is not running in utf8
        $Param{Term} = $EncodeObject->Convert(
            Text => $Param{Term},
            From => 'utf-8',
            To   => $LayoutObject->{UserCharset},
        );

        # remove leading and ending spaces
        if ( $Param{Term} ) {

            # remove leading and ending spaces
            $Param{Term} =~ s/^\s+//;
            $Param{Term} =~ s/\s+$//;

            # handle wildcards
            $Param{Term} =~ s /\*/.*?/g;
        }

        if ( $SearchType->{ $Param{Module} . ":::" . $Param{ElementID} } =~ /(Owner|Responsible)/g )
        {

            # get QueueID
            my $QueueID = $TicketObject->TicketQueueID(
                TicketID => $Param{TicketID},
            );

            # get owner and responsible
            my %Users;
            my %ResponsibleUsers;

            my %AllGroupsMembers = $UserObject->UserList(
                Type  => 'Long',
                Valid => 1,
            );

            if ( $ConfigObject->Get('Ticket::ChangeOwnerToEveryone') ) {
                if ( $SearchType->{ $Param{Module} . ":::" . $Param{ElementID} } eq 'Owner' ) {
                    %Users      = %AllGroupsMembers;
                    %SearchList = %Users;
                }
                elsif (
                    $SearchType->{ $Param{Module} . ":::" . $Param{ElementID} } eq 'Responsible'
                    )
                {
                    %ResponsibleUsers = %AllGroupsMembers;
                    %SearchList       = %ResponsibleUsers;
                }
            }
            else {

                # get owner
                if ( $SearchType->{ $Param{Module} . ":::" . $Param{ElementID} } ne 'Owner' ) {
                    my $GID = $QueueObject->GetQueueGroupID( QueueID => $QueueID );
                    my %MemberList = $GroupObject->GroupMemberList(
                        GroupID => $GID,
                        Type    => 'owner',
                        Result  => 'HASH',
                        Cached  => 1,
                    );

                    for my $UserID ( keys %MemberList ) {
                        $Users{$UserID} = $AllGroupsMembers{$UserID};
                    }
                    %SearchList = %Users;
                }

                # get responsible
                elsif (
                    $SearchType->{ $Param{Module} . ":::" . $Param{ElementID} } ne 'Responsible'
                    )
                {
                    my $GID = $QueueObject->GetQueueGroupID( QueueID => $QueueID );
                    my %MemberList = $GroupObject->GroupMemberList(
                        GroupID => $GID,
                        Type    => 'responsible',
                        Result  => 'HASH',
                        Cached  => 1,
                    );

                    for my $UserID ( keys %MemberList ) {
                        $ResponsibleUsers{$UserID} = $AllGroupsMembers{$UserID};
                    }
                    %SearchList = %ResponsibleUsers;
                }
            }
        }
        elsif ( $SearchType->{ $Param{Module} . ":::" . $Param{ElementID} } eq 'Queue' ) {

            # get queues are you can move
            my %MemberList = $TicketObject->MoveList(
                TicketID => $Param{TicketID},
                UserID   => $Self->{UserID},
                Action   => $Param{Module},
                Type     => 'move_into',
            );
            %SearchList = %MemberList;
        }
        else {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Missing configuration for '$Param{Module}:::$Param{ElementID}'!"
            );
        }

        # build data
        my @Data;
        my $MaxResultCount = $Param{MaxResults};

        SEARCHID:
        for my $SearchID (
            sort { $SearchList{$a} cmp $SearchList{$b} }
            keys %SearchList
            )
        {
            if ( $SearchList{$SearchID} =~ /^.*?$Param{Term}.*?/i ) {
                push @Data, {
                    SearchObjectKey   => $SearchID,
                    SearchObjectValue => $SearchList{$SearchID},
                };
                if ($MaxResultCount) {
                    $MaxResultCount--;
                    last SEARCHID if $MaxResultCount <= 0;
                }
            }
        }

        # build JSON output
        $JSON = $LayoutObject->JSONEncode(
            Data => \@Data,
        );
    }

    # send JSON response
    return $LayoutObject->Attachment(
        ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
        Content     => $JSON || '',
        Type        => 'inline',
        NoCache     => 1,
    );

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
