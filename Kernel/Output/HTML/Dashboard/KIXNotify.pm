# --
# based upon DashboardProductNotify.pm
# original Copyright (C) 2001-2015 OTRS AG, http://otrs.com/
# KIX4OTRS-Extensions Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Martin(dot)Balzarek(at)cape(dash)it(dot)de
# * Dorothea(dot)Doerffel(at)cape(dash)it(dot)de
#
# --
# $Id$
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::Dashboard::KIXNotify;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    # get needed parameters
    for my $Needed (qw(Config Name UserID)) {
        die "Got no $Needed!" if ( !$Self->{$Needed} );
    }

    return $Self;
}

sub Preferences {
    my ( $Self, %Param ) = @_;

    return;
}

sub Config {
    my ( $Self, %Param ) = @_;

    return (
        %{ $Self->{Config} },
    );
}

sub Run {
    my ( $Self, %Param ) = @_;

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # get layout object
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # KIX4OTRS-capeIT
    # Cloud content removed
    # EO KIX4OTRS-capeIT

    # check cache
    # KIX4OTRS-capeIT
    # my $CacheKey = "CloudService::" . $CloudService . "::Operation::" . $Operation . "::Language::"
    #    . $LayoutObject->{UserLanguage} . "::Product::" . $Product . "::Version::$Version";
    my $CacheKey
        = $Self->{Config}->{URL} . '-' . $LayoutObject->{UserLanguage} . '-capeIT-Modules';

    # EO KIX4OTRS-capeIT

    # get cache object
    my $CacheObject = $Kernel::OM->Get('Kernel::System::Cache');

    my $Content = $Kernel::OM->Get('Kernel::System::Cache')->Get(

        # KIX4OTRS-capeIT
        # Type => 'DashboardProductNotify',
        Type => 'DashboardKIXNotify',

        # EO KIX4OTRS-capeIT
        Key => $CacheKey,
    );

    # KIX4OTRS-capeIT
    # load c.a.p.e. IT modules information
    my %KIXVersions = ();
    for my $Package ( $Kernel::OM->Get('Kernel::System::Package')->RepositoryList() ) {
        next if $Package->{Vendor}->{Content} ne 'c.a.p.e. IT GmbH';
        $KIXVersions{ $Package->{Name}->{Content} } = $Package->{Version}->{Content};
    }

    # EO KIX4OTRS-capeIT

    # get content
    my %Response = $Kernel::OM->Get('Kernel::System::WebUserAgent')->Request(
        URL => $Self->{Config}->{URL}
    );

    # set error message as content if xml file get not downloaded
    if ( $Response{Status} !~ /200/ ) {
        $Content = "Can't connect to: " . $Self->{Config}->{URL} . " ($Response{Status})";
    }
    else {

        # generate content based on xml file
        my $XMLObject = Kernel::System::XML->new( %{$Self} );
        my @Data = $XMLObject->XMLParse2XMLHash( String => ${ $Response{Content} } );

        # set error message if unable to parse xml file
        if ( !@Data ) {
            $Content = "Can't parse xml of: " . $Self->{Config}->{URL};
        }
        else {

            # remember if content got shown
            my $ContentFound = 0;

            for my $Item ( keys %{ $Data[1]->{capeIT_modules}->[1] } ) {

                # show messages
                if ( $Item eq 'Message' ) {

                    # remember if content got shown
                    $ContentFound = 1;
                    $LayoutObject->Block(
                        Name => 'ContentKIXMessage',
                        Data => {
                            Message => $Data[1]->{capeIT_modules}->[1]->{$Item}->[1]->{Content},
                        },
                    );
                }
                elsif ( $Item eq 'Release' ) {

                    RELEASE:
                    for my $Record ( @{ $Data[1]->{capeIT_modules}->[1]->{$Item} } ) {

                        next RELEASE if !$Record;
                        next RELEASE if !defined $KIXVersions{ $Record->{Name}->[1]->{Content} };

                        # check if release is newer then the installed one
                        next if !$Self->_CheckVersion(
                            Version1 => $KIXVersions{ $Record->{Name}->[1]->{Content} },
                            Version2 => $Record->{Version}->[1]->{Content},
                        );

                        # remember if content got shown
                        $ContentFound = 1;
                        $LayoutObject->Block(
                            Name => 'ContentKIXRelease',
                            Data => {
                                Name    => $Record->{Name}->[1]->{Content},
                                Version => $Record->{Version}->[1]->{Content},
                                Link    => $Record->{Link}->[1]->{Content},
                            },
                        );
                    }
                }
            }

            # check if content got shown, if true, render block
            if ($ContentFound) {
                $Content = $LayoutObject->Output(
                    TemplateFile => 'AgentDashboardKIXNotify',
                    Data         => {
                        %{ $Self->{Config} },
                    },
                );
            }

            # check if we need to set CacheTTL based on xml file
            my $CacheTTL = $Data[1]->{otrs_product}->[1]->{CacheTTL};
            if ( $CacheTTL && $CacheTTL->[1]->{Content} ) {
                $Self->{Config}->{CacheTTLLocal} = $CacheTTL->[1]->{Content};
            }
        }
    }

    # cache result
    if ( $Self->{Config}->{CacheTTLLocal} ) {
        $CacheObject->Set(
            Type  => 'DashboardKIXNotify',
            Key   => $CacheKey,
            Value => $Content || '',
            TTL   => $Self->{Config}->{CacheTTLLocal} * 60,
        );
    }

    # return content
    return $Content;
}

sub _CheckVersion {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(Version1 Version2)) {
        if ( !defined $Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "$Needed not defined!",
            );

            return;
        }
    }
    for my $Type (qw(Version1 Version2)) {
        $Param{$Type} =~ s/\s/\./g;
        $Param{$Type} =~ s/[A-z]/0/g;

        my @Parts = split /\./, $Param{$Type};
        $Param{$Type} = 0;
        for ( 0 .. 4 ) {
            if ( IsNumber( $Parts[$_] ) ) {
                $Param{$Type} .= sprintf( "%04d", $Parts[$_] );
            }
            else {
                $Param{$Type} .= '0000';
            }
        }
        $Param{$Type} = int( $Param{$Type} );
    }

    return 1 if ( $Param{Version2} > $Param{Version1} );

    return;
}

1;
