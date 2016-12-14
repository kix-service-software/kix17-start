# --
# Kernel/Output/HTML/ITSMConfigItemLayoutDummyX.pm - layout backend module
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Martin(dot)Balzarek(at)cape(dash)it(dot)de
# * Dorothea(dot)Doerffel(at)cape(dash)it(dot)de
# * Mario(dot)Illinger(at)cape(dash)it(dot)de
#
# --
# based upon ITSMConfigItemLayoutDummy.pm - 1.8 2008/04/03 by mh
# $Id$
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::ITSMConfigItem::LayoutDummyX;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::System::Web::Request'
);

=head1 NAME

Kernel::Output::HTML::ITSMConfigItemLayoutDummy - layout backend module

=head1 SYNOPSIS

All layout functions of DummyX objects

=over 4

=cut

=item new()

create an object

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $BackendObject = $Kernel::OM->Get('Kernel::Output::HTML::ITSMConfigItemLayoutDummyX');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{LogObject}   = $Kernel::OM->Get('Kernel::System::Log');
    $Self->{ParamObject} = $Kernel::OM->Get('Kernel::System::Web::Request');

    return $Self;
}

=item OutputStringCreate()

create output string

    my $Value = $BackendObject->OutputStringCreate();

=cut

sub OutputStringCreate {
    return ' ';
}

=item FormDataGet()

get form data as hash reference

    my $FormDataRef = $BackendObject->FormDataGet();

=cut

sub FormDataGet {

    # capeIT
    #return {};
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(Key)) {
        if ( !$Param{$Argument} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "ITSMConfigItemLayoutDummyX: Need $Argument!",
            );
            return;
        }
    }

    # get form data
    my %FormData;
    $FormData{Value} = $Self->{ParamObject}->GetParam( Param => $Param{Key} );
    return \%FormData;

    # EO capeIT
}

=item InputCreate()

create a input string

    my $Value = $BackendObject->InputCreate();

=cut

sub InputCreate {

    # capeIT
    #return '&nbsp;';
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(Key Item)) {
        if ( !$Param{$Argument} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "ITSMConfigItemLayoutDummyX: Need $Argument!",
            );
            return;
        }
    }

    my $String
        = '<input type="hidden" name="'
        . $Param{Key}
        . '" value="'
        . $Param{Item}->{Key}
        . '"/>'
        . '<div class="Clear"></div>';

    return $String;

    # EO capeIT
}

=item SearchFormDataGet()

get search form data

    my $Value = $BackendObject->SearchFormDataGet();

=cut

sub SearchFormDataGet {
    return [];
}

=item SearchInputCreate()

create a serch input string

    my $Value = $BackendObject->SearchInputCreate();

=cut

sub SearchInputCreate {
    return '&nbsp;';
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
