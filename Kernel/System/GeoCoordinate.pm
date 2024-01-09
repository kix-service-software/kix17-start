# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::GeoCoordinate;

use strict;
use warnings;
use utf8;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Log',
);

=head1 NAME

Kernel::System::Type - type lib

=head1 SYNOPSIS

All type functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $GeoCoordinateObject = $Kernel::OM->Get('Kernel::System::GeoCoordinate');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=item ToDegree()

changes the coordinate format to degrees

    $GeoCoordinateObject->ToDegree(
        Coordinates => +000.000000 +000.000000,
        Result      => Display|Input
    );

Return Display

    my $String = $GeoCoordinateObject->ToDegree(
        Coordinates => +000.000000 +000.000000,
        Result      => Display,
    );

    $String = '+00° 00' 00.000" +000° 00' 00.000"'

Return Input

    my %Hash = $GeoCoordinateObject->ToDegree(
        Coordinates => +000.000000 +000.000000,
        Result      => Input,
    );

    %Hash = (
        Long => {
            MaxLength  => 4,
            Degree     => +00,
            Minute     => 00,
            Second     => 00,
            DecimalSec => 000
        },
        Lat => {
            MaxLength  => 3,
            Degree     => +000,
            Minute     => 00,
            Second     => 00,
            DecimalSec => 000
        }
    );

=cut
sub ToDegree {
    my ($self, %Param) = @_;

    for my $Needed ( qw(Coordinates) ) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    my $Result      = $Param{Result}    || 'Input';
    my $Counter     = 0;
    my @Coordinates = split(' ', $Param{Coordinates});
    my %Result;

    for my $Coord( @Coordinates ) {
        my $Key                     = !$Counter ? 'Lat' : 'Long';
        my ($Operator, $Coordinate) = $Coord =~ /^(\+|-)(.*)/;
        my $Degree                  = int($Coordinate);
        my $TmpMin                  = sprintf( '%f', ($Coordinate - $Degree) * 60);
        my $Minute                  = int($TmpMin);
        my ($Second, $DecimalSec)   = split('\.', sprintf( '%.3f', ($TmpMin - $Minute) * 60));

        if ( !$Operator ) {
            $Operator = '+';
        }

        $Result{$Key} = {
            Degree     => $Operator . (!$Counter ? sprintf('%02d', $Degree) : sprintf('%03d', $Degree)),
            Minute     => sprintf('%02d', $Minute),
            Second     => sprintf('%02d', $Second),
            DecimalSec => sprintf('%03d', $DecimalSec),
            MaxLength  => (!$Counter ? 3 : 4)
        };

        $Counter++;
    }

    if ( $Result eq 'Display' ) {
        my $Value = '';

        for my $Key ( qw(Lat Long) ) {
            $Value .= ' ' if $Value;
            $Value .= $Result{$Key}->{Degree}
                . '° '
                . $Result{$Key}->{Minute}
                . '\' '
                . $Result{$Key}->{Second}
                . '.'
                . $Result{$Key}->{DecimalSec}
                . '"';
        }

        return $Value;
    }

    return %Result;
}

=item ToDecimalDegree()

changes the coordinate format to decimal degrees

    $GeoCoordinateObject->ToDecimalDegree(
        Coordinates  => +000.000000 +000.000000,    # required Coordinates or Values
        Values       => {                           # Values can be only used by output format "Store"
            LongDegree     => +00,
            LongMinute     => 00,
            LongSecond     => 00,
            LongDecimalSec => 000,
            LongDecimalDeg => 000000,
            LatDegree      => +000,
            LatMinute      => 00,
            LatSecond      => 00,
            LatDecimalSec  => 000,
            LatDecimalDeg  => 000000
        }
        Result       => Display|Input|Store,        # default Input
        Format       => Degree|DecimalDegree        # "Format" can be only used by output format "Store"
                                                    # The "Format" is the output format which has the coordinates before being converted.
    );

Return Display

    my $String = $GeoCoordinateObject->ToDecimalDegree(
        Coordinates  => +000.000000 +000.000000,
        Result       => Display,
    );

    $String = '+000.000000 +000.000000'

Return Input

    my %Hash = $GeoCoordinateObject->ToDegree(
        Coordinates  => +000.000000 +000.000000,
        Result       => Input,
    );

    %Hash = (
        Long => {
            Degree     => +000,
            DecimalDeg => 000
        },
        Lat => {
            Degree     => +000,
            DecimalDeg => 000
        }
    );

Return Store with Values

    my %Hash = $GeoCoordinateObject->ToDegree(
        Values       => {
            LongDegree     => +00,
            LongMinute     => 00,
            LongSecond     => 00,
            LongDecimalSec => 000,
            LongDecimalDeg => 000000,
            LatDegree      => +000,
            LatMinute      => 00,
            LatSecond      => 00,
            LatDecimalSec  => 000,
            LatDecimalDeg  => 000000
        }
        Result       => Store,
        Format       => Degree
    );

    %Hash = (
        Long => {
            Degree     => +000,
            DecimalDeg => 000
        },
        Lat => {
            Degree     => +000,
            DecimalDeg => 000
        }
    );
=cut
sub ToDecimalDegree {
    my ($self, %Param) = @_;

    if (
        !$Param{Coordinates}
        && !$Param{Values}
    ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Need Coordinates or Values (as hash ref)!"
        );
        return;
    }

    if (
        !$Param{Coordinates}
        && $Param{Values}
        && ref $Param{Values} ne 'HASH'
    ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Parameter "Values" is not a hash ref!'
        );
        return;
    }

    my $Result  = $Param{Result} || 'Input';
    my $Format  = $Param{Format} || '';
    my $Output  = '';
    my %Result;

    if ( $Result eq 'Store' ) {
        if ( !$Param{Format} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need Format!"
            );
            return;
        }

        if ( $Param{Values} ) {
            my $Values = $Param{Values};
            for my $Key ( qw(Lat Long) ) {
                my $Value = '';
                if ( $Format eq 'Degree' ) {
                    my ($Operator, $Degree) = $Values->{$Key . 'Degree'} =~ /^(\+|-)(.*)/;
                    my $Second              = sprintf( '%.3f', $Values->{$Key . 'Second'} . '.' . $Values->{$Key . 'DecimalSec'});
                    my $Minute              = int($Values->{$Key . 'Minute'});
                    $Degree                 = int($Degree);

                    if ( !$Operator ) {
                        $Operator = '+';
                    }

                    if ( $Key eq 'Lat' ) {
                        $Value = $Operator . sprintf(
                            '%010.7f',
                            (($Second/60)+$Minute)/60+$Degree
                        );
                    }
                    else {
                        $Value = $Operator . sprintf(
                            '%011.7f',
                            (($Second/60)+$Minute)/60+$Degree
                        );
                    }
                }

                elsif ( $Format eq 'DecimalDegree' ) {
                    my ($Operator, $Degree) = $Values->{$Key . 'Degree'} =~ /^(\+|-)(.*)/;
                    my $DecimalDeg          = $Values->{$Key . 'DecimalDeg'};
                    $Degree                 = int($Degree);

                    if ( !$Operator ) {
                        $Operator = '+';
                    }

                    if ( $Key eq 'Lat' ) {
                        $Value = $Operator . sprintf(
                            '%09.6f',
                            $Degree . '.' . $DecimalDeg
                        );
                    }
                    else {
                        $Value = $Operator . sprintf(
                            '%010.6f',
                            $Degree . '.' . $DecimalDeg
                        );
                    }

                }

                $Output .= ' ' if $Output;
                $Output .= $Value;
            }
        }

        elsif ( $Param{Coordinates} ) {
            if ( $Format eq 'Degree' ) {
                $Param{Coordinates} =~ s/(°|\')\s+/$1/g;

                my $Counter     = 0;
                my @Coordinates = split(' ', $Param{Coordinates});
                for my $Coord ( @Coordinates ) {
                    my $Key                     = !$Counter ? 'Lat' : 'Long';
                    my ($Operator, $Coordinate) = $Coord =~ /^(\+|-)(.*)/;
                    $Coordinate =~ s/(°|\')/ /g;
                    $Coordinate =~ s/\"//g;

                    if ( !$Operator ) {
                        $Operator = '+';
                    }

                    my ($Degree, $Minute, $Second) = split(' ', $Coordinate);

                    my $Value;
                    if ( $Key eq 'Lat' ) {
                        $Value = sprintf(
                            '%010.7f',
                            (($Second/60)+$Minute)/60+$Degree
                        );
                    }
                    else {
                        $Value = sprintf(
                            '%011.7f',
                            (($Second/60)+$Minute)/60+$Degree
                        );
                    }

                    $Output .= ' ' if $Output;
                    $Output .= $Operator . $Value;

                    $Counter++;
                }
            }
            elsif ( $Format eq 'DecimalDegree' ) {
                $Output = $Param{Coordinates};
            }
        }

        return $Output;
    }

    elsif ( $Result eq 'Display' ) {
        return $Param{Coordinates};
    }

    my $Counter      = 0;
    my @Coordinates  = split(' ', $Param{Coordinates});
    for my $Coord( @Coordinates ) {
        my $Key                     = !$Counter ? 'Lat' : 'Long';
        my ($Operator, $Coordinate) = $Coord =~ /^(\+|-)(.*)/;
        my ($Degree, $DecimalDeg)   = split('\.', $Coordinate);

        if ( !$Operator ) {
            $Operator = '+';
        }

        if ( $Key eq 'Lat' ) {
            $Result{$Key} = {
                Degree     => $Operator . sprintf('%02d', $Degree),
                DecimalDeg => sprintf('%06d', $DecimalDeg),
                MaxLength  => 3
            };
        }
        else {
            $Result{$Key} = {
                Degree     => $Operator . sprintf('%03d', $Degree),
                DecimalDeg => sprintf('%06d', $DecimalDeg),
                MaxLength  => 4
            };
        }

        $Counter++;
    }

    return %Result;
}

sub ValueLookup {
    my ($Self, %Param) = @_;

    my $DegPattern = '^[+-]?\d{1,2}\°(?:|\s)\d{1,2}\'(?:|\s)\d{1,2}\.\d{1,3}\"\s[-+]?\d{1,3}\°(?:|\s)\d{1,2}\'(?:|\s)\d{1,2}\.\d{1,3}\"$';
    my $DecPattern = '^[+-]?\d{1,2}\.\d+\s[-+]?\d{1,3}\.\d+$';

    if (
        $Param{Coordinates} =~ /$DegPattern/g
    ) {
        return $Self->ToDecimalDegree(
            %Param,
            Format => 'Degree',
            Result => 'Store'
        );
    }

    elsif (
        $Param{Coordinates} =~ /$DecPattern/g
    ) {
        return $Param{Coordinates};
    }

    else {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'The used format is not supported!'
        );
    }

    return '';
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
