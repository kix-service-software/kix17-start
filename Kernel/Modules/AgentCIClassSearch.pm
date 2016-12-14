# --
# Kernel/Modules/AgentCIClassSearch.pm - a module used for the autocomplete feature
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

package Kernel::Modules::AgentCIClassSearch;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Output::HTML::Layout',
    'Kernel::System::Encode',
    'Kernel::System::ITSMConfigItem',
    'Kernel::System::Web::Request'
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    $Self->{LayoutObject}     = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    $Self->{EncodeObject}     = $Kernel::OM->Get('Kernel::System::Encode');
    $Self->{ConfigItemObject} = $Kernel::OM->Get('Kernel::System::ITSMConfigItem');
    $Self->{ParamObject}      = $Kernel::OM->Get('Kernel::System::Web::Request');

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $JSON = '';

    # get needed params
    my $Search  = $Self->{ParamObject}->GetParam( Param => 'Term' )    || '';
    my $ClassID = $Self->{ParamObject}->GetParam( Param => 'ClassID' ) || 0;


    # get CI Class list
    #-----------------------------------------------------------------------
    # search for name....
    my @Data;
    my $CISearchListRef = $Self->{ConfigItemObject}->ConfigItemSearchExtended(
        Name     => '*' . $Search . '*',
        ClassIDs => [$ClassID],
    );
    my %FoundCIHash = ();

    # build data
    for my $SearchResult ( @{$CISearchListRef} ) {
        my $CurrVersionData = $Self->{ConfigItemObject}->VersionGet(
            ConfigItemID => $SearchResult,
            XMLDataGet   => 0,
        );
        if (
            $CurrVersionData
            &&
            ( ref($CurrVersionData) eq 'HASH' ) &&
            $CurrVersionData->{Name} &&
            $CurrVersionData->{Number}
            )
        {
            push @Data, {
                CIClassKey   => $SearchResult,
                CIClassValue => $CurrVersionData->{Name} . ' (' . $CurrVersionData->{Number} . ')',
            };

            $FoundCIHash{$SearchResult} = 1;
        }
    }

    # search for number....
    $CISearchListRef = $Self->{ConfigItemObject}->ConfigItemSearchExtended(
        Number   => '*' . $Search . '*',
        ClassIDs => [$ClassID],
    );

    for my $SearchResult ( @{$CISearchListRef} ) {

        # prevent double hits...
        next if ( $FoundCIHash{$SearchResult} );

        my $CurrVersionData = $Self->{ConfigItemObject}->VersionGet(
            ConfigItemID => $SearchResult,
            XMLDataGet   => 0,
        );
        if (
            $CurrVersionData
            &&
            ( ref($CurrVersionData) eq 'HASH' ) &&
            $CurrVersionData->{Name} &&
            $CurrVersionData->{Number}
            )
        {
            push @Data, {
                CIClassKey   => $SearchResult,
                CIClassValue => $CurrVersionData->{Name} . ' (' . $CurrVersionData->{Number} . ')',
            };

            $FoundCIHash{$SearchResult} = 1;
        }
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
