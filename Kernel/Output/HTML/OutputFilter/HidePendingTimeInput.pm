# --
# Kernel/Output/HTML/OutputFilter/HidePendingTimeInput.pm - output filter to hide/show pending time input field depending on state selection
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Anna(dot)Litvinova(at)cape(dash)it(dot)de
# * Andreas(dot)Hergert(at)cape(dash)it(dot)de
# * Torsten(dot)Thau(at)cape(dash)it(dot)de
# * Frank(dot)Jacquemin(at)cape(dash)it(dot)de
#
# --
# $Id$
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --
package Kernel::Output::HTML::OutputFilter::HidePendingTimeInput;

use strict;
use warnings;
use Kernel::System::State;

use vars qw($VERSION);

$VERSION = qw($Revision$) [1];

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Encode',
    'Kernel::System::Log',
    'Kernel::System::Main',
    'Kernel::System::Layout',
    'Kernel::System::JSON'
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );
    if ( !$Param{UserType} || ( $Param{UserType} ne 'User' && $Param{UserType} ne 'Customer' ) ) {
        return $Self;
    }

    # create needed objects
    $Self->{StateObject} = Kernel::System::State->new( %{$Self} );

    # get needed objects
    $Self->{ConfigObject} = $Kernel::OM->Get('Kernel::Config');
    $Self->{LayoutObject} = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    $Self->{JSONObject}   = $Kernel::OM->Get('Kernel::System::JSON');
    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # check if state field exists
    # .{2} fmatches '="'
    # .{0,7} matches '' or 'New' or 'Next' or 'Compose'
    my $MatchStr = '<label.for.{2}(.{0,7}StateID)">';
    if ( ${ $Param{Data} } =~ m{$MatchStr}ixms ) {
        my $StateField = $1;

        # get all states
        my %StateList = $Self->{StateObject}->StateList(
            UserID => 1,
            Valid  => 0,
        );
        my %Data                = ();
        my $HidePendingTimeStrg = '';
        if (%StateList) {
            for my $StateID ( sort keys %StateList ) {

                # get state data
                my %State = $Self->{StateObject}->StateGet( ID => $StateID );

                # get state type data
                my $StateType = $Self->{StateObject}->StateTypeLookup(
                    StateTypeID => $State{TypeID},
                );

                # get configuration
                my $Config = $Self->{ConfigObject}->Get('HidePendingTimeInput') || undef;

                # check if PendingUntil input field should be shown for this state type
                my $Result = 0;
                if ( ( ref($Config) eq 'HASH' ) && @{ $Config->{StateTypes} } ) {
                    for my $ConfiguredStateType ( @{ $Config->{StateTypes} } ) {
                        if ( $StateType eq $ConfiguredStateType ) {
                            $Result = 1;
                            last;
                        }
                    }
                }
                $Data{$StateID} = $Result;
            }
        }
        my $JSONStrg    = $Self->{JSONObject}->Encode(Data => \%Data);
        my $JSDocument  = <<END;
    \$('#Year').parent('div').addClass('HidePendingTimeInput');
    \$('#Year').parent('div').prev('label').addClass('HidePendingTimeInput');
    Core.Agent.HidePendingTimeInput.Init($JSONStrg,'$StateField');
END
        $Self->{LayoutObject}->AddJSOnDocumentComplete( Code => $JSDocument);
    }

    return 1;
}
1;
