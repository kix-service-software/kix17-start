# --
# Kernel/System/ITSMConfigItem/DefinitionX.pm - additional sub module of ITSMConfigItem.pm with definition functions
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Torsten(dot)Thau(at)cape(dash)it(dot)de
# * Rene(dot)Boehm(at)cape(dash)it(dot)de
# * Martin(dot)Balzarek(at)cape(dash)it(dot)de
# * Ralf(dot)Boehm(at)cape(dash)it(dot)de
# * Dorothea(dot)Doerffel(at)cape(dash)it(dot)de
#
# --
# $Id$
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::ITSMConfigItem::DefinitionX;

use strict;
use warnings;

=head1 NAME

Kernel::System::ITSMConfigItem::Definition - sub module of Kernel::System::ITSMConfigItem

=head1 SYNOPSIS

All definition functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item DefinitionAdd()

add a new definition

    my $DefinitionID = $ConfigItemObject->DefinitionAdd(
        ClassID    => 123,
        Definition => 'the definition code',
        UserID     => 1,
    );

=cut

sub DefinitionAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(ClassID Definition UserID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # check definition
    my $Check = $Self->DefinitionCheck(
        Definition => $Param{Definition},
    );

    return if !$Check;

    # get last definition
    my $LastDefinition = $Self->DefinitionGet(
        ClassID => $Param{ClassID},
    );

    # stop add, if definition was not changed
    if ( $LastDefinition->{DefinitionID} && $LastDefinition->{Definition} eq $Param{Definition} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Can't add new definition! The definition was not changed.",
        );
        return;
    }

    #---------------------------------------------------------------------------
    # KIX4OTRS-capeIT
    # trigger Pre-DefinitionCreate event
    my $Result = $Self->PreEventHandler(
        Event => 'DefinitionCreate',
        Data  => {
            ClassID          => $Param{ClassID},
            DefinitionID     => $Param{Definition},
            LastDefinitionID => $LastDefinition,
            UserID           => $Param{UserID},
        },
        UserID => $Param{UserID},
    );
    if ( ( ref($Result) eq 'HASH' ) && ( $Result->{Error} ) ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'notice',
            Message  => "Pre-DefinitionCreate refused DefinitionAdd.",
        );
        return $Result;
    }
    elsif ( ref($Result) eq 'HASH' ) {
        for my $ResultKey ( keys %{$Result} ) {
            $Param{$ResultKey} = $Result->{$ResultKey};
        }
    }

    # EO KIX4OTRS-capeIT
    #---------------------------------------------------------------------------

    # set version
    my $Version = 1;
    if ( $LastDefinition->{Version} ) {
        $Version = $LastDefinition->{Version};
        $Version++;
    }

    # insert new definition
    my $Success = $Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL => 'INSERT INTO configitem_definition '
            . '(class_id, configitem_definition, version, create_time, create_by) VALUES '
            . '(?, ?, ?, current_timestamp, ?)',
        Bind => [ \$Param{ClassID}, \$Param{Definition}, \$Version, \$Param{UserID} ],
    );

    return if !$Success;

    # get id of new definition
    $Kernel::OM->Get('Kernel::System::DB')->Prepare(
        SQL => 'SELECT id FROM configitem_definition WHERE '
            . 'class_id = ? AND version = ? '
            . 'ORDER BY version DESC',
        Bind => [ \$Param{ClassID}, \$Version ],
        Limit => 1,
    );

    # fetch the result
    my $DefinitionID;
    while ( my @Row = $Kernel::OM->Get('Kernel::System::DB')->FetchrowArray() ) {
        $DefinitionID = $Row[0];
    }

    # trigger DefinitionCreate event
    $Self->EventHandler(
        Event => 'DefinitionCreate',
        Data  => {
            Comment => $DefinitionID,
        },
        UserID => $Param{UserID},
    );

    return $DefinitionID;
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the OTRS project (http://otrs.org/).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see http://www.gnu.org/licenses/agpl.txt.

=cut

=head1 VERSION

$Revision$ $Date$

=cut
