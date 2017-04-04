# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::Event::RemoveArticleFlagsOnTicketClose;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::DB',
    'Kernel::System::Log',
    'Kernel::System::State',
    'Kernel::System::Ticket',
    'Kernel::System::User',
);

=item new()

create an object.

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # create needed objects
    $Self->{ConfigObject} = $Kernel::OM->Get('Kernel::Config');
    $Self->{DBObject}     = $Kernel::OM->Get('Kernel::System::DB');
    $Self->{LogObject}    = $Kernel::OM->Get('Kernel::System::Log');
    $Self->{StateObject}  = $Kernel::OM->Get('Kernel::System::State');
    $Self->{TicketObject} = $Kernel::OM->Get('Kernel::System::Ticket');
    $Self->{UserObject}   = $Kernel::OM->Get('Kernel::System::User');

    return $Self;
}

=item Run()

Run - contains the actions performed by this event handler.

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Data}->{TicketID} ) {
        $Self->{LogObject}->Log( Priority => 'error', Message => "Need ArticleID!" );
        return;
    }

    # get config
    my $Config = $Self->{ConfigObject}->Get('Ticket::Frontend::AgentTicketZoomTabArticle');

    return 1
        if (
        !defined $Config->{ArticleFlagsRemoveOnTicketClose}
        || ref $Config->{ArticleFlagsRemoveOnTicketClose} ne 'HASH'
        );

    # get ticket data and check ticket state
    my %Ticket = $Self->{TicketObject}->TicketGet( TicketID => $Param{Data}->{TicketID} );
    my %State = $Self->{StateObject}->StateGet(
        ID => $Ticket{StateID},
    );

    # check whether state type is closed
    return 1 if $State{TypeName} !~ /^close/i;

    my @ArticleIDs = $Self->{TicketObject}->ArticleIndex(
        TicketID => $Param{Data}->{TicketID},
    );

    my %ArticleFlags = ();
    if ( defined $Self->{Config}->{ArticleFlags} && ref %{ $Self->{Config}->{ArticleFlags} } eq 'HASH' ) {
        %ArticleFlags = %{ $Self->{Config}->{ArticleFlags} };
    }

    for my $Flag ( keys %ArticleFlags ) {

        # mode: system
        if (
            defined $Config->{ArticleFlagsRemoveOnTicketClose}->{$Flag}
            && $Config->{ArticleFlagsRemoveOnTicketClose}->{$Flag} =~ m/^1$/i
            )
        {

            for my $ArticleID (@ArticleIDs) {

                # delete article flags
                $Self->{TicketObject}->ArticleFlagDelete(
                    ArticleID => $ArticleID,
                    Key       => $Flag,
                    AllUsers  => 1,
                );

                # delete article flag data
                $Self->{TicketObject}->ArticleFlagDataDelete(
                    ArticleID => $ArticleID,
                    Key       => $Flag,
                    AllUsers  => 1,
                );
            }

            # nothing to do with this flag any more
            delete $ArticleFlags{$Flag};
        }
        elsif (
            !defined $Config->{ArticleFlagsRemoveOnTicketClose}->{$Flag}
            || $Config->{ArticleFlagsRemoveOnTicketClose}->{$Flag} =~ m/^0$/i
            )
        {

            # keep flag data
            delete $ArticleFlags{$Flag};
        }
    }

    # mode: user
    my %FlagsByArticle;
    for my $ArticleID (@ArticleIDs) {

        # get all set article flags for this article
        next if !$Self->{DBObject}->Prepare(
            SQL =>
                "SELECT article_key, create_by FROM article_flag WHERE article_id = ? AND article_value = '1'",
            Bind => [ \$ArticleID ],
        );

        # assign flags for each article to one user ( flags in user-mode only )
        while ( my @Data = $Self->{DBObject}->FetchrowArray() ) {

            # ignore 'seen'
            next if $Data[0] eq 'Seen';

            # ignore if flag already treated
            next if !$ArticleFlags{ $Data[0] };

            push( @{ $FlagsByArticle{ $Data[1] }->{$ArticleID} }, $Data[0] );
        }

        # look up user preferences for each affected user and delete flags or not
        for my $UserID ( keys %FlagsByArticle ) {

            # get user preferences
            my %UserPreferences
                = $Self->{UserObject}->GetPreferences( UserID => $UserID );

            # if user preferences are set split preferences string
            my @ArticleFlagsDeleteOnCloseArray;
            if (
                defined $UserPreferences{ArticleFlagsRemoveOnClose}
                && $UserPreferences{ArticleFlagsRemoveOnClose}
                )
            {
                @ArticleFlagsDeleteOnCloseArray
                    = split( /\;/, $UserPreferences{ArticleFlagsRemoveOnClose} );
            }

            # use user preferences or default from sysconfig
            my %ArticleFlagsDeleteOnClose;
            for my $UserPreferencesFlag ( keys %ArticleFlags ) {

                # user preferences
                if ( grep { $_ eq $UserPreferencesFlag } @ArticleFlagsDeleteOnCloseArray ) {
                    $ArticleFlagsDeleteOnClose{$UserPreferencesFlag} = 1;
                    next;
                }
            }

            # delete flags
            for my $ArticleID ( keys %{ $FlagsByArticle{$UserID} } ) {
                for my $Flag ( @{ $FlagsByArticle{$UserID}->{$ArticleID} } ) {

                    # delete only flags which are marked as deletable
                    next if !$ArticleFlagsDeleteOnClose{$Flag};

                    # delete article flag and flag data
                    $Self->{TicketObject}->ArticleFlagDelete(
                        ArticleID => $ArticleID,
                        Key       => $Flag,
                        UserID    => $UserID,
                    );

                    # delete article flag data
                    $Self->{TicketObject}->ArticleFlagDataDelete(
                        ArticleID => $ArticleID,
                        Key       => $Flag,
                        UserID    => $UserID,
                    );

                }
            }

        }
    }

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
