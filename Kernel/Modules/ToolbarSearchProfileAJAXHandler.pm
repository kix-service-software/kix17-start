# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::ToolbarSearchProfileAJAXHandler;

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
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ParamObject  = $Kernel::OM->Get('Kernel::System::Web::Request');

    my $Result;

    for my $Needed (qw(Subaction SearchProfile)) {
        $Param{$Needed} = $ParamObject->GetParam( Param => $Needed ) || '';
        if ( !$Param{$Needed} ) {
            return $LayoutObject->ErrorScreen( Message => "Need $Needed!", );
        }
    }

    my $Config = $ConfigObject->Get('ToolbarSearchProfile');
    my %SearchProfileData;

    $Param{SearchProfile} =~ /(.*?)Search(.*?)::(.*)/;
    my @Module = split( /::/, $Config->{$1}->{Module} );
    $SearchProfileData{Action}    = $Module[2];
    $SearchProfileData{Subaction} = $Config->{$1}->{Subaction};
    $SearchProfileData{Profile}   = $3;

    if ($2) {
        $SearchProfileData{ClassID} = $2;
    }

    if ( $1 ne 'Ticket' ) {
        my @TmpArray = split( /::/, $3 );
        pop(@TmpArray);
        $SearchProfileData{Profile} = join( "::", @TmpArray );
    }

    my $JSON = $LayoutObject->JSONEncode(
        Data => \%SearchProfileData,
    );

    return $LayoutObject->Attachment(
        ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
        Content     => $JSON,
        Type        => 'inline',
        NoCache     => 1,
    );
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
