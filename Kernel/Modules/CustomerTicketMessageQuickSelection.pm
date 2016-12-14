# --
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Torsten(dot)Thau(at)cape(dash)it(dot)de
# * Martin(dot)Balzarek(at)cape(dash)it(dot)de
# * Dorothea(dot)Doerffel(at)cape(dash)it(dot)de
# * Rene(dot)Boehm(at)cape(dash)it(dot)de
# --
# $Id$
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --
package Kernel::Modules::CustomerTicketMessageQuickSelection;

use strict;
use warnings;

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    # create needed objects
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $ParamObject  = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # all static variables
    $Self->{ViewableSenderTypes} = $ConfigObject->Get('Ticket::ViewableSenderTypes')
        || $LayoutObject->FatalError(
        Message => 'No Config entry "Ticket::ViewableSenderTypes"!'
        );

    # get params
    $Self->{Filter} = $ParamObject->GetParam( Param => 'Filter' ) || 'Open';
    $Self->{SortBy} = $ParamObject->GetParam( Param => 'SortBy' ) || 'Age';
    $Self->{Order}  = $ParamObject->GetParam( Param => 'Order' )  || 'Down';
    $Self->{StartHit} = int( $ParamObject->GetParam( Param => 'StartHit' ) || 1 );
    $Self->{PageShown} = $Self->{UserShowTickets} || 1;
    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # create needed objects
    my $ConfigObject  = $Kernel::OM->Get('Kernel::Config');
    my $ParamObject   = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $LayoutObject  = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $SessionObject = $Kernel::OM->Get('Kernel::System::AuthSession');
    my $TicketObject  = $Kernel::OM->Get('Kernel::System::Ticket');

    # remember last mask...
    $SessionObject->UpdateSessionID(
        SessionID => $Self->{SessionID},
        Key       => 'LastScreenView',
        Value     => $Self->{RequestedURL},
    );
    $SessionObject->UpdateSessionID(
        SessionID => $Self->{SessionID},
        Key       => 'LastScreenOverview',
        Value     => $Self->{RequestedURL},
    );

    # get QuickTicketConfig for UserRestrictions from SysConfig
    my $QuickTicketConfig = $ConfigObject->Get('Ticket::QuickTicketByDefaultSet::Customer');

    # get QuickTicketConfig data from database
    my @Templates = $TicketObject->TicketTemplateList(
        Result   => 'Name',
        Frontend => 'Customer',
        UserID   => $Self->{UserID},
    );

    my %TemplateHash;
    for my $CurrTemplateKey ( sort(@Templates) ) {
        my $UseTemplate = 1;

        # check restrictions for $CurrTemplateKey...
        if (
            $QuickTicketConfig->{UserAttributeRestriction}
            && ref $QuickTicketConfig->{UserAttributeRestriction} eq 'HASH'
            )
        {

            for my $UserAttributeKey ( keys %{ $QuickTicketConfig->{UserAttributeRestriction} } ) {
                next if ( $UserAttributeKey !~ /^($CurrTemplateKey)\:\:(.*)/ );
                my $RestrictionKey = $UserAttributeKey;
                my $UserAttribute  = $2;
                if (
                    !$Self->{$UserAttribute}
                    || $Self->{$UserAttribute}
                    =~ /$QuickTicketConfig->{UserAttributeRestriction}->{$RestrictionKey}/
                    )
                {
                    $UseTemplate = 0;
                    last;
                }
            }
        }

        # display template selection...
        if ($UseTemplate) {
            my %TemplateData = $TicketObject->TicketTemplateGet(
                Name => $CurrTemplateKey,
            );

            $LayoutObject->Block(
                Name => 'TemplateRow',
                Data => {
                    DefaultSet   => $TemplateData{Name},
                    DefaultSetID => $TemplateData{ID},
                    Title        => $CurrTemplateKey,
                    Description  => $TemplateData{Description},
                },
            );
        }
    }

    # create & return output
    my $Refresh = '';
    if ( $Self->{UserRefreshTime} ) {
        $Refresh = 60 * $Self->{UserRefreshTime};
    }
    my $Output = $LayoutObject->CustomerHeader(
        Title   => $Self->{Subaction},
        Refresh => $Refresh,
    );
    $Output .= $LayoutObject->CustomerNavigationBar();
    $Output .= $LayoutObject->Output(
        TemplateFile => 'CustomerTicketMessageQuickSelection',
        Data         => \%Param,
    );
    $Output .= $LayoutObject->CustomerFooter();

    # return page
    return $Output;
}
1;
