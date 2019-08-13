# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::ITSMConfigItem::LayoutGeoCoordinate;

use strict;
use warnings;
use utf8;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::Output::HTML::Layout',
    'Kernel::System::GeoCoordinate',
    'Kernel::System::Log',
    'Kernel::System::Web::Request',
);

=head1 NAME

Kernel::Output::HTML::ITSMConfigItem::LayoutCalculation - layout backend module

=head1 SYNOPSIS

All layout functions of text objects

=over 4

=cut

=item new()

create an object

    $BackendObject = Kernel::Output::HTML::ITSMConfigItem::LayoutGeoCoordinate->new(
        %Param,
    );

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=item OutputStringCreate()

create output string

    my $Value = $BackendObject->OutputStringCreate(
        Value => 11,       # (optional)
        Item => $ItemRef,
    );

=cut

sub OutputStringCreate {
    my ( $Self, %Param ) = @_;

    my $ConfigObject        = $Kernel::OM->Get('Kernel::Config');
    my $LayoutObject        = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $GeoCoordinateObject = $Kernel::OM->Get('Kernel::System::GeoCoordinate');
    my $LogObject           = $Kernel::OM->Get('Kernel::System::Log');

    # check needed stuff
    if ( !$Param{Item} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Need Item!',
        );
        return;
    }

    return '' if ( !defined $Param{Value} );

    my $Config = $ConfigObject->Get('ITSMConfigItem::GeoCoordinate');

    my $Format   = $Param{Item}->{Input}->{DisplayFormat} || $Config->{DisplayFormat} || 'DecimalDegree';
    my $Link     = $Param{Item}->{Input}->{Link}          || $Config->{Link}          || '';
    my $Function = 'To' . $Format;
    my $Value    = $GeoCoordinateObject->$Function(
        Coordinates => $Param{Value},
        Result      => 'Display',
    ) || '';

    if ( $Link ) {
        my @Coordinates = split(' ', $Param{Value});
        $Link =~ s/<LATITUDE>/$Coordinates[0]/g;
        $Link =~ s/<LONGITUDE>/$Coordinates[1]/g;

        my $LinkStrg = '<a href="' . $Link . '" target="_blank">' . $Value . '</a>';

        return $LinkStrg;
    }

    return $Value;
}

=item FormDataGet()

get form data as hash reference

    my $FormDataRef = $BackendObject->FormDataGet(
        Key => 'Item::1::Node::3',
        Item => $ItemRef,
    );

=cut

sub FormDataGet {
    my ( $Self, %Param ) = @_;

    my $ConfigObject        = $Kernel::OM->Get('Kernel::Config');
    my $LayoutObject        = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $GeoCoordinateObject = $Kernel::OM->Get('Kernel::System::GeoCoordinate');
    my $LogObject           = $Kernel::OM->Get('Kernel::System::Log');

    # check needed stuff
    for my $Argument (qw(Key Item)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    my $ParamObject = $Kernel::OM->Get('Kernel::System::Web::Request');

    my $Format = $Param{Item}->{Input}->{InputFormat} || 'DecimalDegree';
    my %FormData;
    my %Values;

    for my $Prefix (
        qw(
            Lat Long
        )
    ) {
        if ( $Format eq 'Degree' ) {
            for my $Key (
                qw(
                    Degree Minute Second DecimalSec
                )
            ) {
                $Values{$Prefix . $Key} = $ParamObject->GetParam( Param => $Param{Key} . '::' . $Prefix . $Key );
                return if ( !defined ($Values{$Prefix . $Key}) );
            }
        } elsif ( $Format eq 'DecimalDegree' ) {

            for my $Key (
                qw(
                    Degree DecimalDeg
                )
            ) {
                $Values{$Prefix . $Key} = $ParamObject->GetParam( Param => $Param{Key} . '::' . $Prefix . $Key );
                return if ( !defined ($Values{$Prefix . $Key}) );
            }
        }
    }

    $FormData{Value} = $GeoCoordinateObject->ToDecimalDegree(
        Result => 'Store',
        Values => \%Values,
        Format => $Format
    );

    return \%FormData;
}

=item InputCreate()

create a input string

    my $Value = $BackendObject->InputCreate(
        Key => 'Item::1::Node::3',
        Value => 11,                # (optional)
        Item => $ItemRef,
    );

=cut

sub InputCreate {
    my ( $Self, %Param ) = @_;

    my $ConfigObject        = $Kernel::OM->Get('Kernel::Config');
    my $LayoutObject        = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $GeoCoordinateObject = $Kernel::OM->Get('Kernel::System::GeoCoordinate');
    my $LogObject           = $Kernel::OM->Get('Kernel::System::Log');

    # check needed stuff
    for my $Argument (qw(Key Item)) {
        if ( !$Param{$Argument} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    my $Config = $ConfigObject->Get('ITSMConfigItem::GeoCoordinate');

    my $Output   = '';
    my $Format   = $Param{Item}->{Input}->{InputFormat} || $Config->{InputFormat} || 'DecimalDegree';
    my $Function = 'To' . $Format;
    my $Key      = $Param{Key};
    my $Value    = $Param{Value};

    if ( !defined $Param{Value} ) {
        $Value = $Param{Item}->{Input}->{ValueDefault} || '';
    }

    if ( !$Value ) {
        $Value = '+00.000000 +000.000000';
    }

    my %Coordinates = $GeoCoordinateObject->$Function(
        Coordinates => $Value,
        Result      => 'Input',
    );

    return if !%Coordinates;

    for my $CoordKey ( qw(Lat Long) ) {
        my $Label      = $CoordKey . 'itude:';
        my $MaxLength  = $Coordinates{$CoordKey}->{MaxLength}  || 4;
        my $Degree     = $Coordinates{$CoordKey}->{Degree};
        my $Minute     = $Coordinates{$CoordKey}->{Minute};
        my $Second     = $Coordinates{$CoordKey}->{Second};
        my $DecimalSec = $Coordinates{$CoordKey}->{DecimalSec};
        my $DecimalDeg = $Coordinates{$CoordKey}->{DecimalDeg};

        my $DegreeKey     = $Key . '::' . $CoordKey .'Degree';
        my $MinuteKey     = $Key . '::' . $CoordKey .'Minute';
        my $SecondKey     = $Key . '::' . $CoordKey .'Second';
        my $DecimalSecKey = $Key . '::' . $CoordKey .'DecimalSec';
        my $DecimalDegKey = $Key . '::' . $CoordKey .'DecimalDeg';

        my $DegreeFollow     = $MinuteKey;
        my $MinuteFollow     = $SecondKey;
        my $SecondFollow     = $DecimalSecKey;
        my $DecimalSecFollow = '';
        my $DecimalDegFollow = '';

        if ( $Format eq 'DecimalDegree' ) {
            $DegreeFollow = $DecimalDegKey;
            if ( $CoordKey eq 'Long' ) {
                $DecimalDegFollow = $Key . '::' . 'LatDegree';
            }
        } else {
            if ( $CoordKey eq 'Long' ) {
                $DecimalSecFollow = $Key . '::' . 'LatDegree';
            }
        }

        $Output .= <<"END";
<div class="CoordinateBox">
    <label>$Label</label>
    <input type="text" name="$DegreeKey" id="$DegreeKey" value="$Degree" size="4" maxlength="$MaxLength" data-id="CoordDegree" data-followup="$DegreeFollow"/>
END
        if ( $Format eq 'DecimalDegree' ) {
            $Output .= <<"END";
    <span class="CoorSymDecimal">.</span>
    <input type="text" name="$DecimalDegKey" id="$DecimalDegKey" value="$DecimalDeg" size="6" maxlength="6" data-id="CoordDecimalDeg" data-followup="$DecimalDegFollow"/>
    <span class="CoorSymDegree">°</span>
END
        } else {
            $Output .= <<"END";
    <span class="CoorSymDegree">°</span>
    <input type="text" name="$MinuteKey" id="$MinuteKey" value="$Minute" size="2" maxlength="2"  data-id="CoordMinute" data-followup="$MinuteFollow"/>
    <span class="CoorSymMinutes">'</span>
    <input type="text" name="$SecondKey" id="$SecondKey" value="$Second" size="2" maxlength="2"  data-id="CoordSecond" data-followup="$SecondFollow"/>
    <span class="CoorSymDecimal">.</span>
    <input type="text" name="$DecimalSecKey" id="$DecimalSecKey" value="$DecimalSec" size="3" maxlength="3"  data-id="CoordDecimalSec" data-followup="$DecimalSecFollow"/>
    <span class="CoorSymSeconds">"</span>
END
        }

        $Output .= <<"END";
</div>
<div class="Clear"></div>
END
    }

    if ( !$Param{Search} ) {
        my $OutputJS = <<'END';
Core.UI.GeoCoordinate.CoordinateInputInit();
END
        $LayoutObject->AddJSOnDocumentComplete( Code => $OutputJS );
    }

    return $Output;
}

=item SearchFormDataGet()

get search form data

    my $Value = $BackendObject->SearchFormDataGet(
        Key => 'Item::1::Node::3',
        Item => $ItemRef,
    );

=cut

sub SearchFormDataGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Key} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need Key!',
        );
        return;
    }

    # create input field
    my $Value = $Self->FormDataGet(
        Key    => $Param{Key},
        Item   => $Param{Item},
    );

    return $Value->{Value};
}

=item SearchInputCreate()

create a search input string

    my $Value = $BackendObject->SearchInputCreate(
        Key => 'Item::1::Node::3',
        Item => $ItemRef,
    );

=cut

sub SearchInputCreate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(Key Item)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # hash with values for the input field
    my %FormData;

    if ( $Param{Value} ) {
        $FormData{Value} = $Param{Value};
    }

    # create input field
    my $InputString = $Self->InputCreate(
        %FormData,
        Key    => $Param{Key},
        Item   => $Param{Item},
        Search => 1
    );

    return $InputString;
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
