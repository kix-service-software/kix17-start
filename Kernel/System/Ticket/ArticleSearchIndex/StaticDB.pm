# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2023 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::ArticleSearchIndex::StaticDB;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::DB',
    'Kernel::System::Log',
);

## no critic qw(Subroutines::ProhibitUnusedPrivateSubroutines)

sub ArticleIndexBuild {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(ArticleID UserID)) {
        if ( !$Param{ $Needed } ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => 'Need ' . $Needed . '!',
            );
            return;
        }
    }

    # get article data
    my %Article = $Self->ArticleGet(
        ArticleID     => $Param{ArticleID},
        UserID        => $Param{UserID},
        DynamicFields => 0,
    );

    # prepare index data
    my $HasContent = 0;
    for my $Key (qw(From To Cc Subject Body)) {
        if ( $Article{ $Key } ) {
            $Article{ $Key } = eval {
                $Self->_ArticleIndexString(
                    String => $Article{$Key},
                );
            };

            if ( $Article{ $Key } ) {
                $HasContent = 1;
            }
        }
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # update search index table
    $DBObject->Do(
        SQL  => 'DELETE FROM article_search WHERE id = ?',
        Bind => [ \$Article{ArticleID}, ],
    );

    # return if no content exists
    return 1 if !$HasContent;

    # insert search index
    $DBObject->Do(
        SQL  => 'INSERT INTO article_search (id, ticket_id, article_type_id, article_sender_type_id, a_from, a_to, a_cc, a_subject, a_body, incoming_time)'
              . ' VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        Bind => [
            \$Article{ArticleID},    \$Article{TicketID}, \$Article{ArticleTypeID},
            \$Article{SenderTypeID}, \$Article{From},     \$Article{To},
            \$Article{Cc},           \$Article{Subject},  \$Article{Body},
            \$Article{IncomingTime},
        ],
    );

    return 1;
}

sub ArticleIndexDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(ArticleID UserID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    # delete articles
    return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL  => 'DELETE FROM article_search WHERE id = ?',
        Bind => [ \$Param{ArticleID} ],
    );

    return 1;
}

sub ArticleIndexDeleteTicket {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(TicketID UserID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    # delete articles
    return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL  => 'DELETE FROM article_search WHERE ticket_id = ?',
        Bind => [ \$Param{TicketID} ],
    );

    return 1;
}

sub _ArticleIndexQuerySQL {
    my ( $Self, %Param ) = @_;

    if ( !$Param{Data} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Need Data!"
        );
        return;
    }

    # use also article table if required
    for (
        qw(
        From To Cc Subject Body
        ArticleCreateTimeOlderMinutes ArticleCreateTimeNewerMinutes
        ArticleCreateTimeOlderDate ArticleCreateTimeNewerDate
        )
    ) {
        if ( $Param{Data}->{$_} ) {
            return ' INNER JOIN article_search art ON st.id = art.ticket_id ';
        }
    }

    return '';
}

sub _ArticleIndexQuerySQLExt {
    my ( $Self, %Param ) = @_;

    if ( !$Param{Data} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Need Data!"
        );
        return;
    }

    my %FieldSQLMapFullText = (
        From    => 'art.a_from',
        To      => 'art.a_to',
        Cc      => 'art.a_cc',
        Subject => 'art.a_subject',
        Body    => 'art.a_body',
    );

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    my $SQLExt      = '';
    my $FullTextSQL = '';
    KEY:
    for my $Key ( sort keys %FieldSQLMapFullText ) {

        next KEY if !$Param{Data}->{$Key};

        # prepare search string
        $Param{Data}->{$Key} = eval {
            $Self->_ArticleIndexString(
                String => $Param{Data}->{$Key},
            );
        };

        next KEY if !$Param{Data}->{$Key};

        # replace * by % for SQL like
        $Param{Data}->{$Key} =~ s/\*/%/gi;

        # check search attribute, we do not need to search for *
        next KEY if $Param{Data}->{$Key} =~ /^\%{1,3}$/;

        if ($FullTextSQL) {
            $FullTextSQL .= ' ' . $Param{Data}->{ContentSearch} . ' ';
        }

        $FullTextSQL .= $DBObject->QueryCondition(
            Key           => $FieldSQLMapFullText{$Key},
            Value         => lc $Param{Data}->{$Key},
            SearchPrefix  => $Param{Data}->{ContentSearchPrefix} || '*',
            SearchSuffix  => $Param{Data}->{ContentSearchSuffix} || '*',
            Extended      => 1,
            CaseSensitive => 1,    # data in article_search are already stored in lower cases
            StaticDB      => 1,    # tell QueryCondition method to regard StaticDB advantages
        );
    }

    if ($FullTextSQL) {
        $SQLExt = ' AND (' . $FullTextSQL . ')';
    }

    return $SQLExt;
}

sub _ArticleIndexString {
    my ( $Self, %Param ) = @_;

    if ( !defined( $Param{String} ) ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Need String!",
        );
        return;
    }

    # init SearchIndexConfig
    if ( !$Self->{SearchIndexConfig} ) {
        my $SearchIndexAttributes = $Kernel::OM->Get('Kernel::Config')->Get('Ticket::SearchIndex::Attribute');

        $Self->{SearchIndexConfig} = {
            WordCountMax  => $SearchIndexAttributes->{WordCountMax}  || 1000,
            WordLengthMin => $SearchIndexAttributes->{WordLengthMin} || 3,
            WordLengthMax => $SearchIndexAttributes->{WordLengthMax} || 30,
            SplitPattern  => $SearchIndexAttributes->{SplitPattern}  || '\s+',
        };
    }

    # init SearchIndexStopWords
    if ( !$Self->{SearchIndexStopWords} ) {
        my $StopWordRaw = $Kernel::OM->Get('Kernel::Config')->Get('Ticket::SearchIndex::StopWords') || {};
        if (
            !$StopWordRaw
            || ref( $StopWordRaw ) ne 'HASH'
        ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => 'Invalid config option Ticket::SearchIndex::StopWords! Please reset the search index options to reactivate the factory defaults.',
            );

            return;
        }

        LANGUAGE:
        for my $Language ( keys( %{ $StopWordRaw } ) ) {
            if (
                !$Language
                || !$StopWordRaw->{ $Language }
                || ref( $StopWordRaw->{ $Language } ) ne 'ARRAY'
            ) {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message  => 'Invalid config option Ticket::SearchIndex::StopWords###' . $Language . '! Please reset this option to reactivate the factory defaults.',
                );

                next LANGUAGE;
            }

            WORD:
            for my $Word ( @{ $StopWordRaw->{ $Language } } ) {
                next WORD if(
                    !defined( $Word )
                    || !length( $Word )
                );

                $Word = lc( $Word );

                $Self->{SearchIndexStopWords}->{ $Word } = 1;
            }
        }
    }

    # init SearchIndexFilters
    if ( !$Self->{SearchIndexFilters} ) {
        $Self->{SearchIndexFilters} = $Kernel::OM->Get('Kernel::Config')->Get('Ticket::SearchIndex::Filters') || [];
    }

    # prepare word list
    my %Words = ();
    WORD:
    for my $Word ( split( /$Self->{SearchIndexConfig}->{SplitPattern}/, lc( $Param{String} ) ) ) {
        next WORD if (
            !defined( $Word )
            || !length( $Word )
        );

        # apply filters
        for my $Filter ( @{ $Self->{SearchIndexFilters} } ) {
            $Word =~ s/$Filter//g;
        }
        next WORD if ( !defined( $Word ) );

        # get length of word
        my $Length = length( $Word );
        next WORD if ( !$Length );

        # check for stop word
        next WORD if( $Self->{SearchIndexStopWords}->{ $Word } );

        # check for known word
        next WORD if( $Words{ $Word } );

        # check word length boundaries
        next WORD if( $Length < $Self->{SearchIndexConfig}->{WordLengthMin} );
        next WORD if( $Length > $Self->{SearchIndexConfig}->{WordLengthMax} );

        $Words{ $Word } = 1;

        if ( keys( %Words ) >= $Self->{SearchIndexConfig}->{WordCountMax} ) {
            last WORD;
        }
    }

    return join( ' ', keys( %Words ) );
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
