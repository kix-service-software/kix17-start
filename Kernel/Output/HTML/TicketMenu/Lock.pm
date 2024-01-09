# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2024 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::TicketMenu::Lock;

use strict;
use warnings;

use Kernel::Language qw(Translatable);

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::Config',
    'Kernel::System::Ticket',
    'Kernel::System::Group',
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

    # get needed objects
    my $ConfigObject    = $Kernel::OM->Get('Kernel::Config');
    my $GroupObject     = $Kernel::OM->Get('Kernel::System::Group');
    my $HTMLUtilsObject = $Kernel::OM->Get('Kernel::System::HTMLUtils');
    my $TicketObject    = $Kernel::OM->Get('Kernel::System::Ticket');

    # get isolated layout object for link safety checks
    my $HTMLLinkLayoutObject = $Kernel::OM->GetNew('Kernel::Output::HTML::Layout');

    # check if frontend module registered, if not, do not show action
    if ( $Param{Config}->{Action} ) {
        my $Module = $ConfigObject->Get('Frontend::Module')->{ $Param{Config}->{Action} };
        return if !$Module;
    }

    # check lock permission
    my $AccessOk = $TicketObject->TicketPermission(
        Type     => 'lock',
        TicketID => $Param{Ticket}->{TicketID},
        UserID   => $Self->{UserID},
        LogNo    => 1,
    );
    return if !$AccessOk;

    # check permission
    if ( $TicketObject->TicketLockGet( TicketID => $Param{Ticket}->{TicketID} ) ) {
        my $HasAccess = $TicketObject->OwnerCheck(
            TicketID => $Param{Ticket}->{TicketID},
            OwnerID  => $Self->{UserID},
        );
        return if !$HasAccess;
    }

    # group check
    if ( $Param{Config}->{Group} ) {

        my @Items = split /;/, $Param{Config}->{Group};

        my $HasAccess;
        ITEM:
        for my $Item (@Items) {

            my ( $Permission, $Name ) = split /:/, $Item;

            if ( !$Permission || !$Name ) {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message  => "Invalid config for Key Group: '$Item'! "
                        . "Need something like '\$Permission:\$Group;'",
                );
            }

            my %Groups = $GroupObject->PermissionUserGet(
                UserID => $Self->{UserID},
                Type   => $Permission,
            );

            next ITEM if !%Groups;

            my %GroupsReverse = reverse %Groups;

            next ITEM if !$GroupsReverse{$Name};

            $HasAccess = 1;

            last ITEM;
        }

        return if !$HasAccess;
    }

    # check acl
    my %ACLLookup = reverse( %{ $Param{ACL} || {} } );
    return if ( !$ACLLookup{ $Param{Config}->{Action} } );

    # if ticket is locked
    if ( $Param{Ticket}->{Lock} eq 'lock' ) {

        # if it is locked for somebody else
        return if $Param{Ticket}->{OwnerID} ne $Self->{UserID};

        my $HTMLLink = $HTMLLinkLayoutObject->Output(
            Template => '<a href="[% Env("Baselink") %][% Data.Link | Interpolate %]" class="[% Data.Class %]" [% Data.LinkParam %] title="[% Translate(Data.Description) | html %]">[% Translate(Data.Name) | html %]</a>',
            Data     => {
                %{ $Param{Config} },
                %{ $Param{Ticket} },
                %Param,
                Name        => Translatable('Unlock'),
                Description => Translatable('Unlock to give it back to the queue'),
                Link        => 'Action=AgentTicketLock;Subaction=Unlock;TicketID=[% Data.TicketID | uri %];[% Env("ChallengeTokenParam") | html %]',
            },
        );
        my %Safe = $HTMLUtilsObject->Safety(
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

        # show unlock action
        return {
            %{ $Param{Config} },
            %{ $Param{Ticket} },
            %Param,
            Name        => Translatable('Unlock'),
            Description => Translatable('Unlock to give it back to the queue'),
            Link        => 'Action=AgentTicketLock;Subaction=Unlock;TicketID=[% Data.TicketID | uri %];[% Env("ChallengeTokenParam") | html %]',
            HTMLLink    => $HTMLLink,
        };
    }

    my $HTMLLink = $HTMLLinkLayoutObject->Output(
        Template => '<a href="[% Env("Baselink") %][% Data.Link | Interpolate %]" class="[% Data.Class %]" [% Data.LinkParam %] title="[% Translate(Data.Description) | html %]">[% Translate(Data.Name) | html %]</a>',
        Data     => {
            %{ $Param{Config} },
            %{ $Param{Ticket} },
            %Param,
            Name        => Translatable('Lock'),
            Description => Translatable('Lock it to work on it'),
            Link        => 'Action=AgentTicketLock;Subaction=Lock;TicketID=[% Data.TicketID | uri %];[% Env("ChallengeTokenParam") | html %]',
        },
    );
    my %Safe = $HTMLUtilsObject->Safety(
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

    # if ticket is unlocked
    return {
        %{ $Param{Config} },
        %{ $Param{Ticket} },
        %Param,
        Name        => Translatable('Lock'),
        Description => Translatable('Lock it to work on it'),
        Link        => 'Action=AgentTicketLock;Subaction=Lock;TicketID=[% Data.TicketID | uri %];[% Env("ChallengeTokenParam") | html %]',
        HTMLLink    => $HTMLLink,
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
