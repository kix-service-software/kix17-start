# --
# Modified version of the work: Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2022 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::CustomerLinkObject;

use strict;
use warnings;

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    my $ConfigObject            = $Kernel::OM->Get('Kernel::Config');
    $Self->{ProtectedLinkTypes} = $ConfigObject->Get('LinkObject::ProtectedLinkTypes');
    $Self->{ProtectOnlyValid}   = $ConfigObject->Get('LinkObject::ProtectOnlyValid');
    $Self->{UserID}             = $ConfigObject->Get('CustomerPanelUserID') || 1;

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # ------------------------------------------------------------ #
    # close
    # ------------------------------------------------------------ #
    if ( $Self->{Subaction} eq 'Close' ) {
        return $LayoutObject->PopupClose(
            Reload => 1,
        );
    }

    # get params
    my %Form;
    my $ParamObject     = $Kernel::OM->Get('Kernel::System::Web::Request');
    $Form{SourceObject} = $ParamObject->GetParam( Param => 'SourceObject' );
    $Form{SourceKey}    = $ParamObject->GetParam( Param => 'SourceKey' );
    $Form{Mode}         = $ParamObject->GetParam( Param => 'Mode' ) || 'Normal';

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    $Self->{Subaction} = $ParamObject->GetParam( Param => 'SubAction' )
        if ( !$Self->{Subaction} );

    # check needed stuff
    if ( !$Form{SourceObject} || !$Form{SourceKey} ) {
        return $LayoutObject->ErrorScreen(
            Message => "Need SourceObject and SourceKey!",
            Comment => 'Please contact the admin.',
        );
    }

    my $LinkObject = $Kernel::OM->Get('Kernel::System::LinkObject');

    # get form params
    $Form{TargetKey}        = $ParamObject->GetParam( Param => 'TargetKey' ) || '';
    $Form{TargetIdentifier} = $ParamObject->GetParam( Param => 'TargetIdentifier' )
        || $ParamObject->GetParam( Param => 'TargetObject' )
        || $Form{SourceObject};

    # investigate the target object
    if ( $Form{TargetIdentifier} =~ m{ \A ( .+? ) :: ( .+ ) \z }xms ) {
        $Form{TargetObject}    = $1;
        $Form{TargetSubObject} = $2;
    }
    else {
        $Form{TargetObject} = $Form{TargetIdentifier};
    }

    # get possible objects list
    my %PossibleObjectsList = $LinkObject->PossibleObjectsList(
        Object => $Form{SourceObject},
        UserID => $Self->{UserID},
    );

    # check if target object is a possible object to link with the source object
    if ( !$PossibleObjectsList{ $Form{TargetObject} } ) {
        my @PossibleObjects = sort { lc $a cmp lc $b } keys %PossibleObjectsList;
        $Form{TargetObject} = $PossibleObjects[0];
    }

    # set mode params
    if ( $Form{Mode} eq 'Temporary' ) {
        $Form{State} = 'Temporary';
    }
    else {
        $Form{Mode}  = 'Normal';
        $Form{State} = 'Valid';
    }

    # get source object description
    my %SourceObjectDescription = $LinkObject->ObjectDescriptionGet(
        Object => $Form{SourceObject},
        Key    => $Form{SourceKey},
        Mode   => $Form{Mode},
        UserID => $Self->{UserID},
    );

    # ------------------------------------------------------------ #
    # delete one single link
    # ------------------------------------------------------------ #
    if ( $Self->{Subaction} && $Self->{Subaction} eq 'SingleLinkDelete' ) {

        # delete all temporary links older than one day
        $LinkObject->LinkCleanup(
            State  => 'Temporary',
            Age    => ( 60 * 60 * 24 ),
            UserID => $Self->{UserID},
        );

        my $DelResult = 0;

        if ( !( $Self->{ProtectOnlyValid} && $Form{State} ne 'Valid' ) ) {
            if (
                $ParamObject->GetParam( Param => 'TargetKey' )
                &&
                $Form{TargetObject}
            ) {

                my $LinkListWithData = $LinkObject->LinkListWithData(
                    Object => $Form{TargetObject},
                    Key    => $Form{TargetKey},
                    State  => $Form{State},
                    UserID => 1,
                );
                for my $LinkedObject ( keys %{$LinkListWithData} ) {
                    next if $LinkedObject ne $Form{SourceObject};
                    LINKTYPE:
                    for my $LinkType ( keys %{ $LinkListWithData->{$LinkedObject} } ) {
                        if (
                            $Self->{ProtectedLinkTypes}
                            && ref( $Self->{ProtectedLinkTypes} ) eq 'HASH'
                            && $Self->{ProtectedLinkTypes}->{$LinkType}
                        ) {
                            next LINKTYPE;
                        }
                        for my $LinkDirection (
                            keys %{ $LinkListWithData->{$LinkedObject}->{$LinkType} }
                        ) {
                            for my $LinkItem (
                                keys
                                %{ $LinkListWithData->{$LinkedObject}->{$LinkType}->{$LinkDirection} }
                            ) {
                                my $DelKey1    = $Form{SourceKey};
                                my $DelObject1 = $Form{SourceObject};
                                my $DelKey2    = $ParamObject->GetParam( Param => 'TargetKey' );
                                my $DelObject2 = $Form{TargetObject};
                                if ( $LinkDirection eq "Source" ) {
                                    $DelKey1    = $ParamObject->GetParam( Param => 'TargetKey' );
                                    $DelObject1 = $Form{TargetObject};
                                    $DelKey2    = $Form{SourceKey};
                                    $DelObject2 = $Form{SourceObject};
                                }

                                # delete link from database
                                $DelResult = $LinkObject->LinkDelete(
                                    Object1 => $Form{SourceObject},
                                    Key1    => $Form{SourceKey},
                                    Object2 => $Form{TargetObject},
                                    Key2    => $ParamObject->GetParam( Param => 'TargetKey' ),
                                    Type    => $LinkType,
                                    UserID  => $Self->{UserID},
                                );
                            }
                        }
                    }
                }
            }
        }

        return $LayoutObject->Attachment(
            ContentType => 'text/plain; charset=' . $LayoutObject->{Charset},
            Content     => $DelResult,
            Type        => 'inline',
            NoCache     => 1,
        );
    }

    # ------------------------------------------------------------ #
    # add one single link
    # ------------------------------------------------------------ #
    elsif ( $Self->{Subaction} && $Self->{Subaction} eq 'SingleLinkAdd' ) {

        my $LinkType = $ParamObject->GetParam( Param => 'LinkType' )
            || $ConfigObject->Get('KIXSidebarConfigItemLink::LinkType')
            || 'Normal';

        my $AddResult = 0;

        # Ticket comes as target
        if (
            $ParamObject->GetParam( Param => 'TargetKey' )
            && $Form{TargetObject}
        ) {

            $AddResult = $LinkObject->LinkAdd(
                SourceObject => $Form{SourceObject},
                SourceKey    => $Form{SourceKey},
                TargetObject => $Form{TargetObject},
                TargetKey    => $ParamObject->GetParam( Param => 'TargetKey' ),
                Type         => $LinkType,
                State        => $Form{State},
                UserID       => $Self->{UserID},
            );
        }

        return $LayoutObject->Attachment(
            ContentType => 'text/plain; charset=' . $LayoutObject->{Charset},
            Content     => $AddResult,
            Type        => 'inline',
            NoCache     => 1,
        );
    }
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
