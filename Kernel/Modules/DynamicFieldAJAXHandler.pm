# --
# Kernel/Modules/DynamicFieldAJAXHandler.pm - AJAX support module for KIXSidebarRemoteDB
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Stefan(dot)Mehlig(at)cape(dash)it(dot)de
# * Torsten(dot)Thau(at)cape(dash)it(dot)de
# * Mario(dot)Illinger(at)cape(dash)it(dot)de
# --
# $Id$
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::DynamicFieldAJAXHandler;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Output::HTML::Layout',
    'Kernel::System::DynamicField',
    'Kernel::System::DynamicField::Backend',
    'Kernel::System::Web::Request'
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    $Self->{LayoutObject}       = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    $Self->{DynamicFieldObject} = $Kernel::OM->Get('Kernel::System::DynamicField');
    $Self->{BackendObject}      = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');
    $Self->{ParamObject}        = $Kernel::OM->Get('Kernel::System::Web::Request');

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    for (
        qw{ObjectID Value DynamicField}
        )
    {
        $Param{$_} = $Self->{ParamObject}->GetParam( Param => $_ ) || '';
    }

    if ( $Param{ObjectID} && $Param{DynamicField} ) {
        my $DynamicFieldConfig = $Self->{DynamicFieldObject}->DynamicFieldGet(
            Name => $Param{DynamicField},
        );
        return if !$DynamicFieldConfig;
        return if ref($DynamicFieldConfig) ne 'HASH';
        return if !$DynamicFieldConfig->{ObjectType};
        return if $DynamicFieldConfig->{ObjectType} ne 'Ticket';

        my $Success = $Self->{BackendObject}->ValueSet(
            DynamicFieldConfig => $DynamicFieldConfig,
            ObjectID           => $Param{ObjectID},
            Value              => $Param{Value} || '',
            UserID             => 1,
        );
        return if ( !$Success );

        return $Self->{LayoutObject}->Attachment(
            ContentType => 'application/json; charset='
                . $Self->{LayoutObject}->{Charset},
            Content => "OK",
            Type    => 'inline',
            NoCache => 1,
        );
    }

    return;
}

1;
