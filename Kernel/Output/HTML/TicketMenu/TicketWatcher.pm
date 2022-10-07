# --
# Modified version of the work: Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2022 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::TicketMenu::TicketWatcher;

use strict;
use warnings;

use Kernel::Language qw(Translatable);

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::Config',
    'Kernel::System::Ticket',
    'Kernel::Output::HTML::Layout',
);

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

    # check needed stuff
    if ( !$Param{Ticket} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need Ticket!'
        );
        return;
    }

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # check if feature is active
    return if !$ConfigObject->Get('Ticket::Watcher');

    # check if frontend module registered, if not, do not show action
    if ( $Param{Config}->{Action} ) {
        my $Module = $ConfigObject->Get('Frontend::Module')->{ $Param{Config}->{Action} };
        return if !$Module;
    }

    # check acl
    my %ACLLookup = reverse( %{ $Param{ACL} || {} } );
    return if ( !$ACLLookup{ $Param{Config}->{Action} } );

    # check access
    my @Groups;
    if ( $ConfigObject->Get('Ticket::WatcherGroup') ) {
        @Groups = @{ $ConfigObject->Get('Ticket::WatcherGroup') };
    }

    my $Access = 1;
    if (@Groups) {
        $Access = 0;
        GROUP:
        for my $Group (@Groups) {

            # get layout object
            my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

            next GROUP if !$LayoutObject->{"UserIsGroup[$Group]"};
            if ( $LayoutObject->{"UserIsGroup[$Group]"} eq 'Yes' ) {
                $Access = 1;
                last GROUP;
            }
        }
    }
    return if !$Access;

    # check if ticket get's watched right now
    my %Watch = $Kernel::OM->Get('Kernel::System::Ticket')->TicketWatchGet(
        TicketID => $Param{Ticket}->{TicketID},
    );

    # show subscribe action
    if ( $Watch{ $Self->{UserID} } ) {
        $Param{Ticket}->{HTMLLink} = $Kernel::OM->GetNew('Kernel::Output::HTML::Layout')->Output(
            Template => '<a href="[% Env("Baselink") %][% Data.Link | Interpolate %]" class="[% Data.Class %]" [% Data.LinkParam %] title="[% Translate(Data.Description) | html %]">[% Translate(Data.Name) | html %]</a>',
            Data     => {
                %{ $Param{Config} },
                %{ $Param{Ticket} },
                %Param,
                Name        => Translatable('Unwatch'),
                Description => Translatable('Remove from list of watched tickets'),
                Link        => 'Action=AgentTicketWatcher;Subaction=Unsubscribe;TicketID=[% Data.TicketID | uri %];[% Env("ChallengeTokenParam") | html %]',
            },
        );
        my %Safe = $Kernel::OM->Get('Kernel::System::HTMLUtils')->Safety(
            String       => $Param{Ticket}->{HTMLLink},
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
            $Param{Ticket}->{HTMLLink} = $Safe{String};
        }

        return {
            %{ $Param{Config} },
            %{ $Param{Ticket} },
            %Param,
            Name        => Translatable('Unwatch'),
            Description => Translatable('Remove from list of watched tickets'),
            Link        => 'Action=AgentTicketWatcher;Subaction=Unsubscribe;TicketID=[% Data.TicketID | uri %];[% Env("ChallengeTokenParam") | html %]',
        };
    }

    $Param{Ticket}->{HTMLLink} = $Kernel::OM->GetNew('Kernel::Output::HTML::Layout')->Output(
        Template => '<a href="[% Env("Baselink") %][% Data.Link | Interpolate %]" class="[% Data.Class %]" [% Data.LinkParam %] title="[% Translate(Data.Description) | html %]">[% Translate(Data.Name) | html %]</a>',
        Data     => {
            %{ $Param{Config} },
            %{ $Param{Ticket} },
            %Param,
            Name        => Translatable('Watch'),
            Description => Translatable('Add to list of watched tickets'),
            Link        => 'Action=AgentTicketWatcher;Subaction=Subscribe;TicketID=[% Data.TicketID | uri %];[% Env("ChallengeTokenParam") | html %]',
        },
    );
    my %Safe = $Kernel::OM->Get('Kernel::System::HTMLUtils')->Safety(
        String       => $Param{Ticket}->{HTMLLink},
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
        $Param{Ticket}->{HTMLLink} = $Safe{String};
    }

    # show unsubscribe action
    return {
        %{ $Param{Config} },
        %{ $Param{Ticket} },
        %Param,
        Name        => Translatable('Watch'),
        Description => Translatable('Add to list of watched tickets'),
        Link        => 'Action=AgentTicketWatcher;Subaction=Subscribe;TicketID=[% Data.TicketID | uri %];[% Env("ChallengeTokenParam") | html %]',
    };
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
