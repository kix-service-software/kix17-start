# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::CustomerDashboard::CustomerServices;

use strict;
use warnings;

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    # get needed objects
    my $LayoutObject       = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # get user preferences
    $Self->{PrefKey}     = 'UserCustomerDashboardPref' . $Self->{Name} . '-Shown';
    $Self->{TableHeight} = $LayoutObject->{ $Self->{PrefKey} }
        || $Self->{Config}->{TableHeight};

    return $Self;
}

sub Preferences {
    my ( $Self, %Param ) = @_;

    my @Params = (
        {
            Desc  => 'Max. table height',
            Name  => $Self->{PrefKey},
            Block => 'Option',
            Data  => {
                '050' => '50',
                '075' => '75',
                100   => '100',
                125   => '125',
                150   => '150',
                175   => '175',
                200   => '200',
                250   => '250',
                300   => '300',
                400   => '400',
                500   => '500',
            },
            SelectedID => $Self->{TableHeight},
        },
    );

    return @Params;
}

sub Config {
    my ( $Self, %Param ) = @_;

    return (
        %{ $Self->{Config} },
    );
}

sub Run {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $LayoutObject       = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ConfigObject       = $Kernel::OM->Get('Kernel::Config');
    my $CustomerUserObject = $Kernel::OM->Get('Kernel::System::CustomerUser');
    my $ServiceObject      = $Kernel::OM->Get('Kernel::System::Service');

    my $Content = '';
    my %AssignedServices;

    if ( $ConfigObject->Get('Ticket::Service') ) {

        # get assigned services
        if ( defined $Param{CustomerID} && $Param{CustomerID} ) {

            my $CustomerIDs = {
                $CustomerUserObject->CustomerSearch(
                    CustomerID => $Param{CustomerID}
                )
            };

            if ( ref $CustomerIDs eq 'HASH' && $CustomerIDs ) {
                for my $ID ( keys %{$CustomerIDs} ) {
                    my %AssignedServicesTmp = $ServiceObject->CustomerUserServiceMemberList(
                        CustomerUserLogin => $ID,
                        Result            => 'HASH',
                        DefaultServices   => 1,
                    );

                    for my $Service ( keys %AssignedServicesTmp ) {
                        next if $AssignedServices{$Service};
                        $AssignedServices{$Service} = $AssignedServicesTmp{$Service};
                    }
                }
            }
        }
        elsif ( defined $Param{CustomerUserLogin} && $Param{CustomerUserLogin} ) {
            my %AssignedServicesTmp = $ServiceObject->CustomerUserServiceMemberList(
                CustomerUserLogin => $Param{CustomerUserLogin},
                Result            => 'HASH',
                DefaultServices   => 1,
            );

            for my $Service ( keys %AssignedServicesTmp ) {
                next if $AssignedServices{$Service};
                $AssignedServices{$Service} = $AssignedServicesTmp{$Service};
            }
        }

        # create output
        $LayoutObject->Block(
            Name => 'ServiceList',
        );

        if (%AssignedServices) {
            for my $CurrentService ( sort { $a cmp $b } values %AssignedServices ) {
                if ( $ConfigObject->Get('Ticket::ServiceTranslation') ) {
                    my @Services = split(/::/, $CurrentService);
                    for my $ServiceName ( @Services ) {
                        $ServiceName = $LayoutObject->{LanguageObject}->Translate($ServiceName);
                    }
                    $CurrentService = join('::', @Services);
                }

                $CurrentService =~ s/::/ => /g;
                $LayoutObject->Block(
                    Name => 'ServiceItem',
                    Data => {
                        Name => $CurrentService,
                    },
                );
            }
        }
        else {
            $LayoutObject->Block(
                Name => 'NoServices',
            );
        }

        $Content = $LayoutObject->Output(
            TemplateFile => 'AgentCustomerDashboardCustomerServices',
            Data         => {
                %{ $Self->{Config} },
                TableHeight => $Self->{TableHeight},
            },
            KeepScriptTags => $Param{AJAX},
        );
    }

    # return content
    return $Content;
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
