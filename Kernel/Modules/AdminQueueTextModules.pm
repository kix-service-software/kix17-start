# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AdminQueueTextModules;

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

    # get needed objects
    my $DBObject           = $Kernel::OM->Get('Kernel::System::DB');
    my $QueueObject        = $Kernel::OM->Get('Kernel::System::Queue');
    my $TextModuleObject   = $Kernel::OM->Get('Kernel::System::TextModule');
    my $LayoutObject       = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ParamObject        = $Kernel::OM->Get('Kernel::System::Web::Request');

    my $ID = $ParamObject->GetParam( Param => 'ID' ) || '';
    $ID = $DBObject->Quote( $ID, 'Integer' ) if ($ID);

    # ------------------------------------------------------------ #
    # text module <-> queue 1:n
    # ------------------------------------------------------------ #
    if ( $Self->{Subaction} eq 'TextModule' ) {

        # get text modules data
        my $TextModule = $TextModuleObject->TextModuleLookup( TextModuleID => $ID );

        # get queue data
        my %QueueData = $QueueObject->QueueList( Valid => 1 );

        # get assigned queues for this text module
        my @QueuesToTextArray = @{
            $TextModuleObject->TextModuleObjectLinkGet(
                ObjectType   => 'Queue',
                TextModuleID => $ID,
                )
            };
        my %QueuesToTextHash;
        for my $QueueID (@QueuesToTextArray) {
            $QueuesToTextHash{$QueueID} = $QueueObject->QueueLookup(
                QueueID => $QueueID,
            );
        }

        my $Output = $LayoutObject->Header();
        $Output .= $LayoutObject->NavigationBar();
        $Output .= $Self->_Change(
            Data     => \%QueueData,
            Selected => \%QueuesToTextHash,
            ID       => $ID,
            Name     => $TextModule,
            Type     => 'TextModules',
        );
        $Output .= $LayoutObject->Footer();
        return $Output;
    }

    # ------------------------------------------------------------ #
    # queue <-> text module n:1
    # ------------------------------------------------------------ #
    elsif ( $Self->{Subaction} eq 'Queue' ) {

        # get text modules data
        my %TextModulesData = $TextModuleObject->TextModuleList( ValidID => 1 );

        # get queue data
        my $Queue = $QueueObject->QueueLookup( QueueID => $ID );

        # get assigned text modules for this queue
        my @TextToQueueArray = @{
            $TextModuleObject->TextModuleObjectLinkGet(
                ObjectType => 'Queue',
                ObjectID   => $ID,
                )
            };
        my %TextToQueueHash;
        for my $TextModuleID (@TextToQueueArray) {
            $TextToQueueHash{$TextModuleID} = $TextModuleObject->TextModuleLookup(
                TextModuleID => $TextModuleID,
            );
        }

        my $Output = $LayoutObject->Header();
        $Output .= $LayoutObject->NavigationBar();
        $Output .= $Self->_Change(
            Data     => \%TextModulesData,
            Selected => \%TextToQueueHash,
            ID       => $ID,
            Name     => $Queue,
            Type     => 'Queue',
        );
        $Output .= $LayoutObject->Footer();
        return $Output;
    }

    # ------------------------------------------------------------ #
    # add text module to queues
    # ------------------------------------------------------------ #
    elsif ( $Self->{Subaction} eq 'ChangeQueue' ) {
        my @NewIDs = $ParamObject->GetArray( Param => 'Queue' );

        # remove old relations
        $TextModuleObject->TextModuleObjectLinkDelete(
            ObjectType => 'Queue',
            ObjectID   => $ID,
        );

        # add new relations
        for my $NewID (@NewIDs) {

            # ignore "all"-selector
            next if !$NewID;

            $TextModuleObject->TextModuleObjectLinkCreate(
                ObjectType   => 'Queue',
                ObjectID     => $ID,
                TextModuleID => $NewID,
                UserID       => $Self->{UserID},
            );
        }

        return $LayoutObject->Redirect( OP => "Action=AdminQueueTextModules" );
    }

    # ------------------------------------------------------------ #
    # add queues to text module
    # ------------------------------------------------------------ #
    elsif ( $Self->{Subaction} eq 'ChangeTextModules' ) {
        my @NewIDs = $ParamObject->GetArray( Param => 'TextModules' );

        # remove old relations
        $TextModuleObject->TextModuleObjectLinkDelete(
            ObjectType   => 'Queue',
            TextModuleID => $ID,
        );

        # add new relations
        for my $NewID (@NewIDs) {

            # ignore "all"-selector
            next if !$NewID;

            $TextModuleObject->TextModuleObjectLinkCreate(
                ObjectType   => 'Queue',
                ObjectID     => $NewID,
                TextModuleID => $ID,
                UserID       => $Self->{UserID},
            );
        }

        return $LayoutObject->Redirect( OP => "Action=AdminQueueTextModules" );
    }

    # ------------------------------------------------------------ #
    # overview
    # ------------------------------------------------------------ #
    my $Output = $LayoutObject->Header();
    $Output .= $LayoutObject->NavigationBar();
    $Output .= $Self->_Overview();
    $Output .= $LayoutObject->Footer();
    return $Output;
}

sub _Change {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $LayoutObject       = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    my %Data   = %{ $Param{Data} };
    my $Type   = $Param{Type} || 'TextModules';
    my $NeType = $Type eq 'Queue' ? 'TextModules' : 'Queue';

    my %VisibleType = ( TextModules => 'Text modules', Queue => 'Queue', );

    my $MyType = $VisibleType{$Type};

    $LayoutObject->Block( Name => 'Overview' );
    $LayoutObject->Block( Name => 'ActionList' );
    $LayoutObject->Block( Name => 'ActionOverview' );
    $LayoutObject->Block( Name => 'Filter' );

    #fixed link
    my $QueueTag = $Type eq 'Queue' ? 'Queue' : '';

    $LayoutObject->Block(
        Name => 'Change',
        Data => {
            %Param,
            ActionHome    => 'Admin' . $Type,
            NeType        => $NeType,
            VisibleType   => $VisibleType{$Type},
            VisibleNeType => $VisibleType{$NeType},
            Queue         => $QueueTag,
        },
    );

    $LayoutObject->Block( Name => "ChangeHeader$VisibleType{$NeType}" );

    $LayoutObject->Block(
        Name => 'ChangeHeader',
        Data => {
            %Param,
            Type          => $Type,
            NeType        => $NeType,
            VisibleType   => $VisibleType{$Type},
            VisibleNeType => $VisibleType{$NeType},
        },
    );

    for my $ID ( sort { uc( $Data{$a} ) cmp uc( $Data{$b} ) } keys %Data ) {

        # set output class
        my $Selected = $Param{Selected}->{$ID} ? ' checked="checked"' : '';

        $QueueTag = $Type ne 'Queue' ? 'Queue' : '';

        $LayoutObject->Block(
            Name => 'ChangeRow',
            Data => {
                %Param,
                Name          => $Data{$ID},
                NeType        => $NeType,
                Type          => $Type,
                ID            => $ID,
                Selected      => $Selected,
                VisibleType   => $VisibleType{$Type},
                VisibleNeType => $VisibleType{$NeType},
                Queue         => $QueueTag,
            },
        );
    }

    return $LayoutObject->Output(
        TemplateFile => 'AdminQueueTextModules',
        Data         => \%Param,
        VisibleType  => $MyType,

    );
}

sub _Overview {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $QueueObject        = $Kernel::OM->Get('Kernel::System::Queue');
    my $TextModuleObject   = $Kernel::OM->Get('Kernel::System::TextModule');
    my $LayoutObject       = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    $LayoutObject->Block(
        Name => 'Overview',
        Data => {},
    );

    # no actions in action list
    #    $LayoutObject->Block(Name=>'ActionList');
    $LayoutObject->Block( Name => 'FilterTextModule' );
    $LayoutObject->Block( Name => 'FilterQueue' );
    $LayoutObject->Block( Name => 'OverviewResult' );

    # get text modules data
    my %TextModulesData = $TextModuleObject->TextModuleList( ValidID => 1 );

    # if there are results to show
    if (%TextModulesData) {
        for my $TextModuleID (
            sort { uc( $TextModulesData{$a} ) cmp uc( $TextModulesData{$b} ) }
            keys %TextModulesData
            )
        {

            # set output class
            $LayoutObject->Block(
                Name => 'List1n',
                Data => {
                    Name      => $TextModulesData{$TextModuleID},
                    Subaction => 'TextModule',
                    ID        => $TextModuleID,
                },
            );
        }
    }

    # otherwise it displays a no data found message
    else {
        $LayoutObject->Block(
            Name => 'NoTextModulesFoundMsg',
            Data => {},
        );
    }

    # get queue data
    my %QueueData = $QueueObject->QueueList( Valid => 1 );

    # if there are results to show
    if (%QueueData) {
        for my $QueueID ( sort { uc( $QueueData{$a} ) cmp uc( $QueueData{$b} ) } keys %QueueData ) {

            # set output class
            $LayoutObject->Block(
                Name => 'Listn1',
                Data => {
                    Name      => $QueueData{$QueueID},
                    Subaction => 'Queue',
                    ID        => $QueueID,
                },
            );
        }
    }

    # otherwise it displays a no data found message
    else {
        $LayoutObject->Block(
            Name => 'NoQueuesFoundMsg',
            Data => {},
        );
    }

    # return output
    return $LayoutObject->Output(
        TemplateFile => 'AdminQueueTextModules',
        Data         => \%Param,
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
