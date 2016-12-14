# --
# Kernel/Modules/AgentServiceSearch.pm - a module used for the autocomplete feature
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Martin(dot)Balzarek(at)cape(dash)it(dot)de
# * Mario(dot)Illinger(at)cape(dash)it(dot)de
# * Andreas(dot)Hergert(at)cape(dash)it(dot)de
#
# --
# $Id$
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AgentServiceSearch;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Output::HTML::Layout',
    'Kernel::System::Encode',
    'Kernel::System::Service',
    'Kernel::System::Web::Request'
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    $Self->{LayoutObject}  = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    $Self->{EncodeObject}  = $Kernel::OM->Get('Kernel::System::Encode');
    $Self->{ServiceObject} = $Kernel::OM->Get('Kernel::System::Service');
    $Self->{ParamObject}   = $Kernel::OM->Get('Kernel::System::Web::Request');

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $JSON = '';

    # get needed params
    my $Search = $Self->{ParamObject}->GetParam( Param => 'Term' ) || '';


    # get queue list
    # search for name....
    my @ServiceIDs = $Self->{ServiceObject}->ServiceSearch(
        Name   => '*' . $Search . '*',
        UserID => 1,
    );
    
    # build data
    my @Data;
    for my $CurrKey (@ServiceIDs) {
        my %ServiceData = $Self->{ServiceObject}->ServiceGet(
            ServiceID => $CurrKey,
            UserID    => 1,
        );
        next if ( !%ServiceData );
        push @Data, {
            ServiceKey   => $CurrKey,
            ServiceValue => $ServiceData{Name},
        };
    }

    # build JSON output
    $JSON = $Self->{LayoutObject}->JSONEncode(
        Data => \@Data,
    );

    # send JSON response
    return $Self->{LayoutObject}->Attachment(
        ContentType => 'application/json; charset=' . $Self->{LayoutObject}->{Charset},
        Content     => $JSON || '',
        Type        => 'inline',
        NoCache     => 1,
    );
}

1;
