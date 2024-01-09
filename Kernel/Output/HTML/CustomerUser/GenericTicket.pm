# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2024 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::CustomerUser::GenericTicket;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData);

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get UserID param
    $Self->{UserID} = $Param{UserID} || die "Got no UserID!";

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # get layout object
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # don't show ticket search links in the print views
    if ( $LayoutObject->{Action} =~ m{Print$}smx ) {
        return;
    }

    # get ticket search config
    my $AgentTicketSearchConfig = $ConfigObject->Get("Ticket::Frontend::AgentTicketSearch");

    # lookup map
    my %Lookup = (
        Types => {
            Object => 'Kernel::System::Type',
            Return => 'TypeIDs',
            Input  => 'Type',
            Method => 'TypeLookup',
        },
        Queues => {
            Object => 'Kernel::System::Queue',
            Return => 'QueueIDs',
            Input  => 'Queue',
            Method => 'QueueLookup',
        },
        States => {
            Object => 'Kernel::System::State',
            Return => 'StateIDs',
            Input  => 'State',
            Method => 'StateLookup',
        },
        Priorities => {
            Object => 'Kernel::System::Priority',
            Return => 'PriorityIDs',
            Input  => 'Priority',
            Method => 'PriorityLookup',
        },
        Locks => {
            Object => 'Kernel::System::Lock',
            Return => 'LockIDs',
            Input  => 'Lock',
            Method => 'LockLookup',
        },
        Services => {
            Object => 'Kernel::System::Service',
            Return => 'ServiceIDs',
            Input  => 'Name',
            Method => 'ServiceLookup',
        },
        SLAs => {
            Object => 'Kernel::System::SLA',
            Return => 'SLAIDs',
            Input  => 'Name',
            Method => 'SLALookup',
        },
    );

    # get all attributes
    my %TicketSearch = ();
    my @Params = split /;/, $Param{Config}->{Attributes};
    STRING:
    for my $String (@Params) {
        next STRING if !$String;
        my ( $Key, $Value ) = split /=/, $String;

        # do lookups
        if ( $Lookup{$Key} ) {
            next STRING if !$Kernel::OM->Get('Kernel::System::Main')->Require( $Lookup{$Key}->{Object} );
            my $Object = $Lookup{$Key}->{Object}->new( %{$Self} );
            my $Method = $Lookup{$Key}->{Method};
            $Value = $Object->$Method( $Lookup{$Key}->{Input} => $Value );
            $Key = $Lookup{$Key}->{Return};
        }

        # build link and search attributes
        if ( $Key =~ /IDs$/ ) {
            if ( !$TicketSearch{$Key} ) {
                $TicketSearch{$Key} = [$Value];
            }
            else {
                push @{ $TicketSearch{$Key} }, $Value;
            }
        }
        elsif ( !defined $TicketSearch{$Key} ) {
            $TicketSearch{$Key} = $Value;
        }
        elsif ( !ref $TicketSearch{$Key} ) {
            my $ValueTmp = $TicketSearch{$Key};
            $TicketSearch{$Key} = [$ValueTmp];
        }
        else {
            push @{ $TicketSearch{$Key} }, $Value;
        }
    }

    # build URL

    # note:
    # "special characters" in customer id have to be escaped, so that DB::QueryCondition works
    my $CustomerIDRaw = $Param{Data}->{CustomerID} || $Param{Data}->{UserCustomerID};

    my $Action    = $Param{Config}->{Action};
    my $Subaction = $Param{Config}->{Subaction};
    my $URL       = $LayoutObject->{Baselink} . "Action=$Action;Subaction=$Subaction";

    if ( $ConfigObject->Get("Frontend::CustomerUser::CustomerInfoTicketCount") ) {
        $TicketSearch{CustomerID} = $Param{Data}->{CustomerID} || $Param{Data}->{UserCustomerID} || '';
    }
    else {
        $TicketSearch{CustomerUserLogin} = $Param{Data}->{UserLogin} || '';
    }

    for my $Key ( sort keys %TicketSearch ) {
        if ( ref $TicketSearch{$Key} eq 'ARRAY' ) {
            for my $Value ( @{ $TicketSearch{$Key} } ) {
                $URL .= ';' . $Key . '=' . $LayoutObject->LinkEncode($Value);
            }
        }
        else {
            $URL .= ';' . $Key . '=' . $LayoutObject->LinkEncode( $TicketSearch{$Key} );
        }
    }

    if ( defined $Param{Config}->{CustomerUserLogin} && $Param{Config}->{CustomerUserLogin} ) {
        my $CustomerUserLoginEscaped = $Kernel::OM->Get('Kernel::System::DB')->QueryStringEscape(
            QueryString => $Param{Data}->{UserLogin},
        );

        $TicketSearch{CustomerUserLogin} = $CustomerUserLoginEscaped;
        $URL .= ';CustomerUserLoginRaw='
            . $LayoutObject->LinkEncode($CustomerUserLoginEscaped);
    }

    my $StateObject = $Kernel::OM->Get('Kernel::System::State');

    # replace StateType to StateIDs for the count numbers in customer information links
    if ( $TicketSearch{StateType} ) {
        my @StateIDs;

        if ( $TicketSearch{StateType} eq 'Open' ) {
            @StateIDs = $StateObject->StateGetStatesByType(
                Type   => 'Viewable',
                Result => 'ID',
            );
        }
        elsif ( $TicketSearch{StateType} eq 'Closed' ) {
            my %ViewableStateOpenLookup = $StateObject->StateGetStatesByType(
                Type   => 'Viewable',
                Result => 'HASH',
            );

            my %StateList = $StateObject->StateList( UserID => $Self->{UserID} );
            for my $Item ( sort keys %StateList ) {
                if ( !$ViewableStateOpenLookup{$Item} ) {
                    push @StateIDs, $Item;
                }
            }
        }

        # current ticket state type
        else {
            @StateIDs = $StateObject->StateGetStatesByType(
                StateType => $TicketSearch{StateType},
                Result    => 'ID',
            );
        }

        # merge with StateIDs
        if ( @StateIDs && IsArrayRefWithData( $TicketSearch{StateIDs} ) ) {
            my %StateIDs = map { $_ => 1 } @StateIDs;
            @StateIDs = grep { exists $StateIDs{$_} } @{ $TicketSearch{StateIDs} };
        }

        if (@StateIDs) {
            $TicketSearch{StateIDs} = \@StateIDs;
        }
    }

    my %TimeMap = (
        ArticleCreate    => 'ArticleTime',
        TicketCreate     => 'Time',
        TicketChange     => 'ChangeTime',
        TicketLastChange => 'LastChangeTime',
        TicketClose      => 'CloseTime',
        TicketEscalation => 'EscalationTime',
    );

    for my $TimeType ( sort keys %TimeMap ) {

        # get create time settings
        if ( !$TicketSearch{ $TimeMap{$TimeType} . 'SearchType' } ) {

            # do nothing with time stuff
        }
        elsif ( $TicketSearch{ $TimeMap{$TimeType} . 'SearchType' } eq 'TimeSlot' ) {
            for my $Key (qw(Month Day)) {
                $TicketSearch{ $TimeType . 'TimeStart' . $Key }
                    = sprintf( "%02d", $TicketSearch{ $TimeType . 'TimeStart' . $Key } );
                $TicketSearch{ $TimeType . 'TimeStop' . $Key }
                    = sprintf( "%02d", $TicketSearch{ $TimeType . 'TimeStop' . $Key } );
            }
            if (
                $TicketSearch{ $TimeType . 'TimeStartDay' }
                && $TicketSearch{ $TimeType . 'TimeStartMonth' }
                && $TicketSearch{ $TimeType . 'TimeStartYear' }
            ) {
                $TicketSearch{ $TimeType . 'TimeNewerDate' } = $TicketSearch{ $TimeType . 'TimeStartYear' } . '-'
                    . $TicketSearch{ $TimeType . 'TimeStartMonth' } . '-'
                    . $TicketSearch{ $TimeType . 'TimeStartDay' }
                    . ' 00:00:00';
            }
            if (
                $TicketSearch{ $TimeType . 'TimeStopDay' }
                && $TicketSearch{ $TimeType . 'TimeStopMonth' }
                && $TicketSearch{ $TimeType . 'TimeStopYear' }
            ) {
                $TicketSearch{ $TimeType . 'TimeOlderDate' } = $TicketSearch{ $TimeType . 'TimeStopYear' } . '-'
                    . $TicketSearch{ $TimeType . 'TimeStopMonth' } . '-'
                    . $TicketSearch{ $TimeType . 'TimeStopDay' }
                    . ' 23:59:59';
            }
        }
        elsif ( $TicketSearch{ $TimeMap{$TimeType} . 'SearchType' } eq 'TimePoint' ) {
            if (
                $TicketSearch{ $TimeType . 'TimePoint' }
                && $TicketSearch{ $TimeType . 'TimePointStart' }
                && $TicketSearch{ $TimeType . 'TimePointFormat' }
            ) {
                my $Time = 0;
                if ( $TicketSearch{ $TimeType . 'TimePointFormat' } eq 'minute' ) {
                    $Time = $TicketSearch{ $TimeType . 'TimePoint' };
                }
                elsif ( $TicketSearch{ $TimeType . 'TimePointFormat' } eq 'hour' ) {
                    $Time = $TicketSearch{ $TimeType . 'TimePoint' } * 60;
                }
                elsif ( $TicketSearch{ $TimeType . 'TimePointFormat' } eq 'day' ) {
                    $Time = $TicketSearch{ $TimeType . 'TimePoint' } * 60 * 24;
                }
                elsif ( $TicketSearch{ $TimeType . 'TimePointFormat' } eq 'week' ) {
                    $Time = $TicketSearch{ $TimeType . 'TimePoint' } * 60 * 24 * 7;
                }
                elsif ( $TicketSearch{ $TimeType . 'TimePointFormat' } eq 'month' ) {
                    $Time = $TicketSearch{ $TimeType . 'TimePoint' } * 60 * 24 * 30;
                }
                elsif ( $TicketSearch{ $TimeType . 'TimePointFormat' } eq 'year' ) {
                    $Time = $TicketSearch{ $TimeType . 'TimePoint' } * 60 * 24 * 365;
                }
                if ( $TicketSearch{ $TimeType . 'TimePointStart' } eq 'Before' ) {

                    # more than ... ago
                    $TicketSearch{ $TimeType . 'TimeOlderMinutes' } = $Time;
                }
                elsif ( $TicketSearch{ $TimeType . 'TimePointStart' } eq 'Next' ) {

                    # within next
                    $TicketSearch{ $TimeType . 'TimeNewerMinutes' } = 0;
                    $TicketSearch{ $TimeType . 'TimeOlderMinutes' } = -$Time;
                }
                else {

                    # within last ...
                    $TicketSearch{ $TimeType . 'TimeOlderMinutes' } = 0;
                    $TicketSearch{ $TimeType . 'TimeNewerMinutes' } = $Time;
                }
            }
        }
    }

    my $Count = $Kernel::OM->Get('Kernel::System::Ticket')->TicketSearch(

        # result (required)
        %TicketSearch,
        CustomerIDRaw => $CustomerIDRaw,
        CacheTTL      => 60 * 2,
        Result        => 'COUNT',
        Permission    => 'ro',
        UserID        => $Self->{UserID},
        Limit         => $AgentTicketSearchConfig->{SearchLimit} || 10000,
    ) || 0;

    if ( $TicketSearch{LinkedTickets} ) {

        my @LinkedTicketIDs = $Kernel::OM->Get('Kernel::System::Ticket')->GetLinkedTickets(
            UserID   => $Self->{UserID},
            Customer => $Param{Data}->{UserLogin},
        );

        $TicketSearch{CustomerID}        = '';
        $TicketSearch{CustomerUserLogin} = '';

        my @ViewableTicketIDs = $Kernel::OM->Get('Kernel::System::Ticket')->TicketSearch(

            # result (required)
            %TicketSearch,
            CacheTTL   => 60 * 2,
            Result     => 'ARRAY',
            Permission => 'ro',
            UserID     => $Self->{UserID},
        );

        my %ViewableTicketIDs;
        my @ViewableTicketsTmp;
        foreach my $ID (@ViewableTicketIDs) {
            $ViewableTicketIDs{$ID} = 1;
        }

        # check what tickets are open
        for my $TicketID (@LinkedTicketIDs) {
            next if !$ViewableTicketIDs{$TicketID};
            push @ViewableTicketsTmp, $TicketID;
        }
        @ViewableTicketIDs = @ViewableTicketsTmp;

        $Count = scalar(@ViewableTicketIDs);
        my $UserLogin = $Param{Data}->{UserLogin} || '';
        $URL .= ';CustomerUser=' . $UserLogin;
    }

    my $CSSClass = $Param{Config}->{CSSClassNoOpenTicket};
    if ($Count) {
        $CSSClass = $Param{Config}->{CSSClassOpenTicket};
    }

    my $IconName = $Param{Config}->{IconNameNoOpenTicket};
    if ($Count) {
        $IconName = $Param{Config}->{IconNameOpenTicket};
    }

    my $HTMLLink = $Kernel::OM->GetNew('Kernel::Output::HTML::Layout')->Output(
        Template => <<'END',
<a class="[% Data.CSSClass %]" [% FOREACH Attribute IN Data.HTMLData %]data-[% Attribute.key | html %]="[% Attribute.value | html %]" [% END %]href="[% Data.URL %]" target="[% Data.Target %]" title="[% Translate(Data.Text) | html %]">
    [% Translate(Data.Text) | html %][% Data.Extension | html %]
</a>
END
        Data     => {
            %{ $Param{Config} },
            CSSClass  => $CSSClass,
            Extension => " (" . ( $Count || '0' ) . ")",
            Count     => $Count,
            URL       => $URL,
            IconName  => $IconName,
        },
    );
    my %Safe = $Kernel::OM->Get('Kernel::System::HTMLUtils')->Safety(
        String       => $HTMLLink,
        NoApplet     => 1,
        NoObject     => 1,
        NoEmbed      => 1,
        NoSVG        => 1,
        NoImg        => 1,
        NoIntSrcLoad => 0,
        NoExtSrcLoad => 1,
        NoJavaScript => 1,
    );
    if ( $Safe{Replace} ) {
        $HTMLLink = $Safe{String};
    }

    # generate block
    $LayoutObject->Block(
        Name => 'CustomerItemRow',
        Data => {
            %{ $Param{Config} },
            CSSClass  => $CSSClass,
            Extension => " (" . ( $Count || '0' ) . ")",
            Count     => $Count,
            URL       => $URL,
            IconName  => $IconName,
            HTMLLink  => $HTMLLink,
        },
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
