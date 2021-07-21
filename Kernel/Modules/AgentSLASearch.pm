# --
# Copyright (C) 2006-2021 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AgentSLASearch;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::Output::HTML::Layout',
    'Kernel::System::Package',
    'Kernel::System::Service',
    'Kernel::System::SLA',
    'Kernel::System::Web::Request'
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    $Self->{ConfigObject}  = $Kernel::OM->Get('Kernel::Config');
    $Self->{LayoutObject}  = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    $Self->{PackageObject} = $Kernel::OM->Get('Kernel::System::Package');
    $Self->{ServiceObject} = $Kernel::OM->Get('Kernel::System::Service');
    $Self->{SLAObject}     = $Kernel::OM->Get('Kernel::System::SLA');
    $Self->{ParamObject}   = $Kernel::OM->Get('Kernel::System::Web::Request');

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $JSON = '';

    # get needed params
    my $Search              = $Self->{ParamObject}->GetParam( Param => 'Term' )                || '';
    my $ServiceData         = $Self->{ParamObject}->GetParam( Param => 'ServiceData' )         || '';
    my $CustomerLoginData   = $Self->{ParamObject}->GetParam( Param => 'CustomerLoginData' )   || '';
    my $CustomerCompanyData = $Self->{ParamObject}->GetParam( Param => 'CustomerCompanyData' ) || '';

    # check if KIXServiceCatalog is installed
    my $KIXProInstalled = $Self->{PackageObject}->PackageIsInstalled(
        Name   => 'KIXPro',
    );

    # get all valid SLAs
    my %AllValidSLAs = $Self->{SLAObject}->SLAList(
        Valid  => 1,
        UserID => $Self->{UserID},
    );
    my %SLAs = %AllValidSLAs;

    # if KIX Professional is not installed
    if (!$KIXProInstalled) {
        # no slas if restricted to service but no service given
        if ( !$ServiceData ) {
            %SLAs = ();
        }
        else {
            # if ServiceData is given -> get SLAs that are configured for ALL given services
            if ( $ServiceData ne 'NONE' ) {
                my @Services = split( ';', $ServiceData );
                if (@Services) {
                    for my $ServiceID (@Services) {
                        my %SLAsForService = $Self->{SLAObject}->SLAList(
                            Valid     => 1,
                            ServiceID => $ServiceID,
                            UserID    => $Self->{UserID},
                        );

                        # delete SLA from result if it is not configured for one of Services
                        for my $SLA ( keys %SLAs ) {
                            delete $SLAs{$SLA} if !$SLAsForService{$SLA};
                        }
                    }
                }
                else {
                    %SLAs = ();
                }
            }

            # if CustomerLoginData is given -> get SLAs that are configured for ALL CustomerUser's Services
            if ( $CustomerLoginData && $CustomerLoginData ne 'NONE' ) {
                my @CustomerUsers = split( ';', $CustomerLoginData );
                if (@CustomerUsers) {
                    for my $CustomerUserLogin (@CustomerUsers) {
                        my %SLAsForCustomerUser = ();

                        # get Services for CustomerUser
                        my %Services = $Self->{ServiceObject}->CustomerUserServiceMemberList(
                            CustomerUserLogin => $CustomerUserLogin,
                            Result            => 'HASH',
                            DefaultServices   => 0,
                        );

                        # get SLAs for each Service (SLAs for CUstomerUser)
                        for my $ServiceID ( keys %Services ) {
                            my %SLAsForService = $Self->{SLAObject}->SLAList(
                                Valid             => 1,
                                ServiceID         => $ServiceID,
                                UserID            => $Self->{UserID},
                            );
                            %SLAsForCustomerUser = ( %SLAsForCustomerUser, %SLAsForService );
                        }

                        # delete SLA from result if it is not configured for one of CustomerUsers
                        for my $SLA ( keys %SLAs ) {
                            delete $SLAs{$SLA} if !$SLAsForCustomerUser{$SLA};
                        }
                    }
                }
                else {
                    %SLAs = ();
                }
            }

            # get SLAs for DEFAULT-Services
            my %SLAsForDefaultServices = ();
            my %DefaultServices = $Self->{ServiceObject}->CustomerUserServiceMemberList(
                CustomerUserLogin => '<DEFAULT>',
                Result            => 'HASH',
                DefaultServices   => 0,
            );
            for my $ServiceID ( keys %DefaultServices ) {
                my %SLAsForService = $Self->{SLAObject}->SLAList(
                    Valid     => 1,
                    ServiceID => $ServiceID,
                    UserID    => $Self->{UserID},
                );
                %SLAsForDefaultServices = ( %SLAsForDefaultServices, %SLAsForService );
            }
            %SLAs = ( %SLAs, %SLAsForDefaultServices );
        }
    }
    # if KIX Professional is installed
    else {
        # no slas if restricted to service but no service given
        if ( !$ServiceData ) {
            %SLAs = ();
        }
        else {
            # prepare relevant services
            my %ServiceHash = ();
            if ( $ServiceData ne 'NONE' ) {
                my @Services = split( ';', $ServiceData );
                if (@Services) {
                    for my $ServiceID (@Services) {
                        $ServiceHash{$ServiceID} = 1;
                    }
                }
            }

            # if CustomerLoginData is given -> get relevant
            if ( $CustomerLoginData && $CustomerLoginData ne 'NONE' ) {
                my @CustomerUsers = split( ';', $CustomerLoginData );
                if (@CustomerUsers) {
                    for my $CustomerUserLogin (@CustomerUsers) {
                        my %SLAsForCustomerUser = ();

                        my %Services;
                        if (!%ServiceHash) {
                            # get Services for CustomerUser
                            %Services = $Self->{ServiceObject}->CustomerUserServiceMemberList(
                                CustomerUserLogin => $CustomerUserLogin,
                                Result            => 'HASH',
                                DefaultServices   => 0,
                            );
                        }
                        else {
                            %Services = %ServiceHash;
                        }

                        # get SLAs for each Service (SLAs for CUstomerUser)
                        for my $ServiceID ( keys %Services ) {
                            my %SLAsForService = $Self->{SLAObject}->SLAList(
                                Valid             => 1,
                                ServiceID         => $ServiceID,
                                CustomerUserLogin => $CustomerUserLogin,
                                UserID            => $Self->{UserID},
                            );
                            %SLAsForCustomerUser = ( %SLAsForCustomerUser, %SLAsForService );
                        }

                        # delete SLA from result if it is not configured for one of CustomerUsers
                        for my $SLA ( keys %SLAs ) {
                            delete $SLAs{$SLA} if !$SLAsForCustomerUser{$SLA};
                        }
                    }
                }
                else {
                    %SLAs = ();
                }
            }
            # if CustomerCompanyData is given -> get relevant SLAs
            elsif ( $CustomerCompanyData && $CustomerCompanyData ne 'NONE' ) {
                my @CustomerCompanyList = split( ';', $CustomerCompanyData );
                if (@CustomerCompanyList) {
                    for my $CustomerCompany (@CustomerCompanyList) {

                        # get CustomerServiceSLA entries that have this CustomerID
                        my @CustomerServiceSLAs = $Self->{ServiceObject}->CustomerServiceMemberSearch(
                            CustomerID => $CustomerCompany,
                            Result     => 'HASH',
                        );

                        # get SLAs for this CustomerCompany (CustomerID)
                        my %SLAsForCustomerCompany = ();
                        for my $CatalogEntry (@CustomerServiceSLAs) {
                            next if ( ref($CatalogEntry) ne 'HASH' );
                            next if ( %ServiceHash && !$ServiceHash{$CatalogEntry->{ServiceID}} );
                            if ( $CatalogEntry->{SLAID} ) {
                                $SLAsForCustomerCompany{ $CatalogEntry->{SLAID} } = 1;
                            }
                        }

                        # delete SLA from result if it is not configured for one of CustomerIDs
                        for my $SLA ( keys %SLAs ) {
                            delete $SLAs{$SLA} if !$SLAsForCustomerCompany{$SLA};
                        }
                    }
                }
                else {
                    %SLAs = ();
                }
            }
            # get SLA only by Service
            elsif ( $ServiceData ne 'NONE' ) {
                for my $ServiceID ( keys( %ServiceHash ) ) {
                    my %SLAsForService = $Self->{SLAObject}->SLAList(
                        Valid     => 1,
                        ServiceID => $ServiceID,
                        UserID    => $Self->{UserID},
                    );

                    # delete SLA from result if it is not configured for one of Services
                    for my $SLA ( keys %SLAs ) {
                        delete $SLAs{$SLA} if !$SLAsForService{$SLA};
                    }
                }
            }

            my %SLAsForDefaultServices = ();
            my @CustomerServiceSLAs = $Self->{ServiceObject}->CustomerServiceMemberSearch(
                CustomerID => 'DEFAULT',
                Result     => 'HASH',
            );
            for my $CatalogEntry (@CustomerServiceSLAs) {
                next if ( ref($CatalogEntry) ne 'HASH' );
                next if ( %ServiceHash && !$ServiceHash{$CatalogEntry->{ServiceID}} );
                if ( $CatalogEntry->{SLAID} ) {
                    $SLAsForDefaultServices{ $CatalogEntry->{SLAID} } = $AllValidSLAs{ $CatalogEntry->{SLAID} };
                }
            }
            %SLAs = ( %SLAs, %SLAsForDefaultServices );
        }
    }

    $Search =~ s/\_/\./g;
    $Search =~ s/\%/\.\*/g;
    $Search =~ s/\*/\.\*/g;

    # build data
    my @Data;
    for my $SLAID ( keys %SLAs ) {
        my $SLAName = $SLAs{$SLAID};
        if ( $Self->{ConfigObject}->Get('Ticket::SLATranslation') ) {
            $SLAName = $Self->{LayoutObject}->{LanguageObject}->Translate( $SLAName );
        }

        if ( $SLAName =~ /$Search/i ) {
            push @Data, {
                SLAKey   => $SLAID,
                SLAValue => $SLAName,
            };
        }
    }

    @Data = sort{ $a->{SLAValue} cmp $b->{SLAValue} } ( @Data );

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

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
