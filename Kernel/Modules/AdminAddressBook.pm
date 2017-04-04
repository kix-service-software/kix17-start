# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AdminAddressBook;

use strict;
use warnings;

use Kernel::Language qw(Translatable);

use Kernel::System::VariableCheck qw(:all);

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    $Self->{ConfigObject}          = $Kernel::OM->Get('Kernel::Config');
    $Self->{LayoutObject}          = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    $Self->{ParamObject}           = $Kernel::OM->Get('Kernel::System::Web::Request');
    $Self->{AddressBookObject}     = $Kernel::OM->Get('Kernel::System::AddressBook');

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my %GetParam = ();
    $GetParam{Search} = $Self->{ParamObject}->GetParam( Param => 'Search' );

    # ------------------------------------------------------------
    # delete
    # ------------------------------------------------------------
    if ( $Self->{Subaction} eq 'Delete' ) {
        my @SelectedIDs = $Self->{ParamObject}->GetArray( Param => 'ID' );

        if (@SelectedIDs) {
            my $Result = $Self->{AddressBookObject}->DeleteAddress(
                IDs    => \@SelectedIDs,
            );
        }

        $Self->_Overview(
            Search => $GetParam{Search},
        );

        my $Output = $Self->{LayoutObject}->Header();
        $Output .= $Self->{LayoutObject}->NavigationBar();
        
        $Output .= $Self->{LayoutObject}->Output(
            TemplateFile => 'AdminAddressBook',
            Data         => \%Param,
        );
        $Output .= $Self->{LayoutObject}->Footer();
        return $Output;
    }

    # ------------------------------------------------------------
    # empty
    # ------------------------------------------------------------
    elsif ( $Self->{Subaction} eq 'Empty' ) {
        my $Result = $Self->{AddressBookObject}->Empty();

        $Self->_Overview(
            Search => $GetParam{Search},
        );

        my $Output = $Self->{LayoutObject}->Header();
        $Output .= $Self->{LayoutObject}->NavigationBar();
        
        $Output .= $Self->{LayoutObject}->Output(
            TemplateFile => 'AdminAddressBook',
            Data         => \%Param,
        );
        $Output .= $Self->{LayoutObject}->Footer();
        return $Output;
    }

    # ------------------------------------------------------------
    # overview
    # ------------------------------------------------------------
    else {
        $Self->_Overview(
            Search => $GetParam{Search},
        );
        my $Output = $Self->{LayoutObject}->Header();
        $Output .= $Self->{LayoutObject}->NavigationBar();

        $Output .= $Self->{LayoutObject}->Output(
            TemplateFile => 'AdminAddressBook',
            Data         => \%Param,
        );

        $Output .= $Self->{LayoutObject}->Footer();
        return $Output;
    }
}

sub _Overview {
    my ( $Self, %Param ) = @_;

    $Self->{LayoutObject}->Block(
        Name => 'Overview',
        Data => \%Param,
    );

    $Self->{LayoutObject}->Block( 
        Name => 'ActionList',
        Data => \%Param,
    );

    if ($Param{Search}) {
        my $Limit = 400;
        my %List = $Self->{AddressBookObject}->AddressList(
            Search => $Param{Search},
            Limit  => $Limit + 1,
        );
    
        $Self->{LayoutObject}->Block(
            Name => 'OverviewHeader',
            Data => {
                ListSize => scalar(keys %List),
                Limit    => $Limit,
            },
        );
    
        $Self->{LayoutObject}->Block(
            Name => 'OverviewResult',
            Data => \%Param,
        );

        # if there are results to show
        if (%List) {
            for my $ID ( sort { $List{$a} cmp $List{$b} } keys %List ) {

                $Self->{LayoutObject}->Block(
                    Name => 'OverviewResultRow',
                    Data => {
                        ID      => $ID,
                        Email   => $List{$ID},
                        Search  => $Param{Search},
                    },
                );
            }
        }

        # otherwise it displays a no data found message
        else {
            $Self->{LayoutObject}->Block(
                Name => 'NoDataFoundMsg',
                Data => {},
            );
        }
    }

    # if there is nothing to search it shows a message
    else
    {
        $Self->{LayoutObject}->Block(
            Name => 'NoSearchTerms',
            Data => {},
        );
    }
    return 1;
}

1;


=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
