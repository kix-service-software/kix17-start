# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::KIXSidebarFAQ;

use strict;
use warnings;

use utf8;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::FAQ',
    'Kernel::System::LinkObject',
    'Kernel::System::Valid',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    $Self->{ConfigObject} = $Kernel::OM->Get('Kernel::Config');
    $Self->{FAQObject}    = $Kernel::OM->Get('Kernel::System::FAQ');
    $Self->{LinkObject}   = $Kernel::OM->Get('Kernel::System::LinkObject');

    return $Self;
}

sub KIXSidebarFAQSearch {
    my ( $Self, %Param ) = @_;

    my $StateTypeList = $Self->{FAQObject}->StateTypeList(
        UserID => 1,
    );
    my %StateTypes;
    my @StateTypeArray = split( /,/, $Param{SearchStateTypes} || '' );
    for my $StateType (@StateTypeArray) {
        for my $StateTypeID ( keys %{$StateTypeList} ) {
            if ( $StateTypeList->{$StateTypeID} =~ m/^$StateType/i ) {
                $StateTypes{$StateTypeID} = $StateTypeList->{$StateTypeID};
            }
        }
    }

    # get interface state list
    my $CustomerInterfaceStates = $Self->{FAQObject}->StateTypeList(
        Types  => $Self->{ConfigObject}->Get('FAQ::Customer::StateTypes'),
        UserID => 1,
    );

    # get the valid ids
    my @ValidIDs = $Kernel::OM->Get('Kernel::System::Valid')->ValidIDsGet();
    my %ValidIDLookup = map { $_ => 1 } @ValidIDs;

    my %Result;

    if ( $Param{TicketID} && $Param{LinkMode} ) {
        my %LinkKeyList = $Self->{LinkObject}->LinkKeyList(
            Object1 => 'Ticket',
            Key1    => $Param{TicketID},
            Object2 => 'FAQ',
            State   => $Param{LinkMode},
            UserID  => 1,
        );

        for my $ID ( keys %LinkKeyList ) {
            my %FAQ = $Self->{FAQObject}->FAQGet(
                ItemID => $ID,
                UserID => 1,
            );
            if ( %FAQ && $FAQ{StateTypeID} && $StateTypes{ $FAQ{StateTypeID} } ) {
                if ( $Param{Interface} eq 'internal' ) {
                    # check user permission
                    my $Permission = $Self->{FAQObject}->CheckCategoryUserPermission(
                        UserID     => $Param{UserID},
                        CategoryID => $FAQ{CategoryID},
                    );

                    # skip entry
                    next if (
                        !$Permission
                        || !$ValidIDLookup{ $FAQ{ValidID} }
                    );
                }
                elsif ( $Param{Interface} eq 'external' ) {
                    # check user permission
                    my $Permission = $Self->{FAQObject}->CheckCategoryCustomerPermission(
                        CustomerUser => $Param{UserLogin},
                        CategoryID   => $FAQ{CategoryID},
                        UserID       => 1,
                    );

                    # skip entry
                    next if (
                        !$Permission
                        || !$FAQ{Approved}
                        || !$ValidIDLookup{ $FAQ{ValidID} }
                        || !$CustomerInterfaceStates->{ $FAQ{StateTypeID} }
                    );
                }

                $Result{$ID}->{'Title'} = $FAQ{Title};
                $Result{$ID}->{'Link'}  = 1;

                # Check if limit is reached
                return \%Result if ( $Param{Limit} && ( scalar keys %Result ) == $Param{Limit} );
            }
        }
    }

    # clean up SearchString
    $Param{SearchString} =~ s/([!*%&|])/\\$1/g;
    $Param{SearchString} =~ s/\s+/ /g;
    $Param{SearchString} =~ s/(^\s+|\s+$)//g;

    if ( $Param{SearchString} ) {

        if ( $Param{MatchAll} ) {
            $Param{SearchString} =~ s/\s/&&/g;
        }
        else {
            $Param{SearchString} =~ s/\s/||/g;
        }

        my %Search = ();
        $Param{SearchMode} = $Param{SearchMode} || '';
        if ( $Param{SearchMode} =~ m/^keyword$/i ) {
            $Search{Keyword} = $Param{SearchString};
        }
        elsif ( $Param{SearchMode} =~ m/^title$/i ) {
            $Search{Title} = $Param{SearchString};
        }
        else {
            $Search{What} = $Param{SearchString};
        }

        my @IDs = $Self->{FAQObject}->FAQSearch(
            %Search,
            States    => \%StateTypes,
            Interface => {
                Name => $Param{Interface},
            },
            UserID => 1,
        );

        for my $ID (@IDs) {

            # Skip entries added by LinkKeyList
            next if ( $Result{$ID} );

            my %FAQ = $Self->{FAQObject}->FAQGet(
                ItemID => $ID,
                UserID => 1,
            );
            if (%FAQ) {
                if ( $Param{Interface} eq 'internal' ) {
                    # check user permission
                    my $Permission = $Self->{FAQObject}->CheckCategoryUserPermission(
                        UserID     => $Param{UserID},
                        CategoryID => $FAQ{CategoryID},
                    );

                    # skip entry
                    next if (
                        !$Permission
                        || !$ValidIDLookup{ $FAQ{ValidID} }
                    );
                }
                elsif ( $Param{Interface} eq 'external' ) {
                    # check user permission
                    my $Permission = $Self->{FAQObject}->CheckCategoryCustomerPermission(
                        CustomerUser => $Param{UserLogin},
                        CategoryID   => $FAQ{CategoryID},
                        UserID       => 1,
                    );

                    # skip entry
                    next if (
                        !$Permission
                        || !$FAQ{Approved}
                        || !$ValidIDLookup{ $FAQ{ValidID} }
                        || !$CustomerInterfaceStates->{ $FAQ{StateTypeID} }
                    );
                }

                $Result{$ID}->{'Title'} = $FAQ{Title};
                $Result{$ID}->{'Link'}  = 0;

                # Check if limit is reached
                return \%Result if ( $Param{Limit} && ( scalar keys %Result ) == $Param{Limit} );
            }
        }
    }

    return \%Result;
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
