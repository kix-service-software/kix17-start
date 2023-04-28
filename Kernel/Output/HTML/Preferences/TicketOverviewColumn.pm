# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::Preferences::TicketOverviewColumn;

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

sub Param {
    my ( $Self, %Param ) = @_;

    my @Params = ();

    return @Params;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $ParamObject  = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $UserObject   = $Param{UserObject} || $Kernel::OM->Get('Kernel::System::CustomerUser');

    my $SelectedColumnsStrg = $ParamObject->GetParam( Param => 'SelectedColumns' );
    my $CallingAction       = $ParamObject->GetParam( Param => 'CallingAction' );

    my @SelectedColumns = split( /,/, $SelectedColumnsStrg );

    my @ColumnStringArray;
    my $ColumnString = '';

    for my $Column (@SelectedColumns) {
        push @ColumnStringArray, $Column;
    }

    $ColumnString = join( ",", @ColumnStringArray );

    if ( !$ConfigObject->Get('DemoSystem') ) {
        $UserObject->SetPreferences(
            UserID => $Self->{UserID},
            Key    => 'UserCustomTLV' . $CallingAction,
            Value  => $ColumnString,
        );
    }

    $Self->{Message} = 'Preferences updated successfully!';
    return 1;
}

sub Error {
    my ( $Self, %Param ) = @_;

    return $Self->{Error} || '';
}

sub Message {
    my ( $Self, %Param ) = @_;

    return $Self->{Message} || '';
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
