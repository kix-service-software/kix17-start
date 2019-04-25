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

    for my $Needed (qw(Subaction SearchProfile)) {
        $Param{$Needed} = $ParamObject->GetParam( Param => $Needed ) || '';
        if ( !$Param{$Needed} ) {
            return $LayoutObject->ErrorScreen( Message => "Need $Needed!", );
        }
    }

    my $Config = $ConfigObject->Get('ToolbarSearchProfile');
    my %SearchProfileData;

    my ( $Module, $ClassID, $Profile ) = $Param{SearchProfile} =~ /(.*?)Search(.*?)::(.*)/;
    my @Modules = split( /::/, $Config->{$Module}->{Module} );
    $SearchProfileData{Action}    = $Modules[2];
    $SearchProfileData{Subaction} = $Config->{$Module}->{Subaction};
    $SearchProfileData{Profile}   = $Profile;

    if ($ClassID) {
        $SearchProfileData{ClassID} = $ClassID;
    }

    if ( $Module ne 'Ticket' ) {
        my @TmpArray = split( /::/, $Profile );
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
