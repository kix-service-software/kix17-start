# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2023 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::ITSMServiceMenu::Link;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::Output::HTML::Layout',
    'Kernel::System::LinkObject',
    'Kernel::System::Log',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # check UserID param
    $Self->{UserID} = $Param{UserID} || die "Got no UserID!";

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Service} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need Service!'
        );
        return;
    }

    # get groups
    my $GroupsRw = $Kernel::OM->Get('Kernel::Config')->Get('Frontend::Module')->{ $Param{Config}->{Action} }->{Group}
        || [];

    # set access
    my $Access = 1;

    # get layout object
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # check permission
    if ( $Param{Config}->{Action} && @{$GroupsRw} ) {

        # set access
        $Access = 0;

        # find read write groups
        RWGROUP:
        for my $RwGroup ( @{$GroupsRw} ) {

            next RWGROUP if !$LayoutObject->{"UserIsGroup[$RwGroup]"};
            next RWGROUP if $LayoutObject->{"UserIsGroup[$RwGroup]"} ne 'Yes';

            # set access
            $Access = 1;
            last RWGROUP;
        }
    }

    return $Param{Counter} if !$Access;

    # check if services can be linked with other objects
    my %PossibleObjects = $Kernel::OM->Get('Kernel::System::LinkObject')->PossibleObjectsList(
        Object => 'Service',
        UserID => $Self->{UserID},
    );

    # don't show link menu item if there are no linkable objects
    return if !%PossibleObjects;

    $Param{Service}->{HTMLLink} = $Kernel::OM->GetNew('Kernel::Output::HTML::Layout')->Output(
        Template => '<a href="[% Env("Baselink") %][% Data.Link | Interpolate %]" class="[% Data.MenuClass | html %]" title="[% Translate(Data.Description) | html %]">[% Translate(Data.Name) | html %]</a>',
        Data     => {
            %Param,
            %{ $Param{Service} },
            %{ $Param{Config} },
        },
    );
    my %Safe = $Kernel::OM->Get('Kernel::System::HTMLUtils')->Safety(
        String       => $Param{Service}->{HTMLLink},
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
        $Param{Service}->{HTMLLink} = $Safe{String};
    }

    $LayoutObject->Block(
        Name => 'MenuItem',
        Data => {
            %Param,
            %{ $Param{Service} },
            %{ $Param{Config} },
        },
    );

    $Param{Counter}++;

    return $Param{Counter};
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
