# --
# Modified version of the work: Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2019 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AgentCustomerSearch;

use strict;
use warnings;

use Kernel::Language qw(Translatable);

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $JSON = '';

    # get needed objects
    my $ParamObject        = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $EncodeObject       = $Kernel::OM->Get('Kernel::System::Encode');
    my $LayoutObject       = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $CustomerUserObject = $Kernel::OM->Get('Kernel::System::CustomerUser');
    my $ConfigObject       = $Kernel::OM->Get('Kernel::Config');
    my $TicketObject       = $Kernel::OM->Get('Kernel::System::Ticket');
    my $AddressBookObject  = $Kernel::OM->Get('Kernel::System::AddressBook');
    my $UserObject         = $Kernel::OM->Get('Kernel::System::User');

    # get config for frontend
    $Self->{Config} = $ConfigObject->Get("Ticket::Frontend::$Self->{Action}");

    # search customers
    if ( !$Self->{Subaction} ) {

        # get needed params
        my $Search = $ParamObject->GetParam( Param => 'Term' ) || '';
        my $MaxResults = int( $ParamObject->GetParam( Param => 'MaxResults' ) || 20 );
        my $IncludeUnknownTicketCustomers
            = int( $ParamObject->GetParam( Param => 'IncludeUnknownTicketCustomers' ) || 0 );

        # init result hash
        my %CustomerUserList = ();

        # check if unknown users should be included
        if ($IncludeUnknownTicketCustomers) {
            # add customers that are not saved in any backend
            my $UnknownTicketCustomerList = $TicketObject->SearchUnknownTicketCustomers(
                SearchTerm => $Search,
            );
            for my $Key ( keys %{$UnknownTicketCustomerList} ) {
                $CustomerUserList{$Key} = $UnknownTicketCustomerList->{$Key};
            }
        }

        # search address book
        my %AddressList = $AddressBookObject->AddressList(
            Search => '*'.$Search.'*',
        );
        for my $Value ( values %AddressList ) {
            $CustomerUserList{$Value} = $Value;
        }

        # search customer user backends
        my %CustomerUserSearch = $CustomerUserObject->CustomerSearch(
            Search => $Search,
        );
        for my $Key ( keys %CustomerUserSearch ) {
            $CustomerUserList{$Key} = $CustomerUserSearch{$Key};
        }

        # build data
        my @Data;
        CUSTOMERUSERID:
        for my $CustomerUserID ( sort keys %CustomerUserList ) {

            my $CustomerValue = $CustomerUserList{$CustomerUserID};

            # replace new lines with one space (see bug#11133)
            $CustomerValue =~ s/\n/ /gs;
            $CustomerValue =~ s/\r/ /gs;

            if ( !( grep { $_->{CustomerValue} eq $CustomerValue } @Data ) ) {
                push @Data, {
                    CustomerKey   => $CustomerUserID,
                    CustomerValue => $CustomerValue,
                };
            }
            last CUSTOMERUSERID if scalar @Data >= $MaxResults;
        }

        # build JSON output
        $JSON = $LayoutObject->JSONEncode(
            Data => \@Data,
        );
    }

    # get customer info
    elsif ( $Self->{Subaction} eq 'CustomerInfo' ) {

        my $CallingAction = $ParamObject->GetParam( Param => 'CallingAction' ) || '';
        my $TicketID      = $ParamObject->GetParam( Param => 'TicketID' ) || '';
        my %TicketData;
        if ( $TicketID ) {
            %TicketData = $TicketObject->TicketGet(
                TicketID      => $TicketID,
                DynamicFields => 1,
                UserID        => $Self->{UserID} || 1,
            );

            delete $TicketData{CustomerID};
            delete $TicketData{CustomerUserID};
        }

        # get params
        my $CustomerUserID = $ParamObject->GetParam( Param => 'CustomerUserID' ) || '';
        my $CustomerID     = $ParamObject->GetParam( Param => 'CustomerID' )     || $TicketData{CustomerID} || '';

        my $CustomerTableHTMLString        = '';
        my $CustomerDetailsTableHTMLString = '';

        # get customer data
        my %CustomerData = $CustomerUserObject->CustomerUserDataGet(
            User       => $CustomerUserID,
            CustomerID => $CustomerID,
        );

        # get customer id
        if (
            !$CustomerID
            && $CustomerData{UserCustomerID}
        ) {
            $CustomerID = $CustomerData{UserCustomerID};
        }

        # build html for customer info table
        if ( %CustomerData && $ConfigObject->Get('Ticket::Frontend::CustomerInfoCompose') ) {
            $CustomerTableHTMLString = $LayoutObject->AgentCustomerViewTable(
                Data          => {
                    %CustomerData,
                    CustomerID => $CustomerID,
                    AJAX       => 1
                },
                Ticket        => \%TicketData,
                CallingAction => $CallingAction,
                Max           => $ConfigObject->Get('Ticket::Frontend::CustomerInfoComposeMaxSize'),
            );

            $CustomerDetailsTableHTMLString = $LayoutObject->AgentCustomerDetailsViewTable(
                Data          => {
                    %CustomerData,
                    CustomerID => $CustomerID,
                    AJAX       => 1
                },
                Ticket        => \%TicketData,
                CallingAction => $CallingAction,
                Max           => $ConfigObject->Get('Ticket::Frontend::CustomerInfoComposeMaxSize'),
            );
        }

        # build JSON output
        $JSON = $LayoutObject->JSONEncode(
            Data => {
                CustomerID                     => $CustomerID || $CustomerUserID,
                CustomerTableHTMLString        => $CustomerTableHTMLString,
                CustomerDetailsTableHTMLString => $CustomerDetailsTableHTMLString,
            },
        );
    }

    # get customer tickets
    elsif ( $Self->{Subaction} eq 'CustomerTickets' ) {

        # get params
        my $CustomerUserID = $ParamObject->GetParam( Param => 'CustomerUserID' ) || '';
        my $CustomerID     = $ParamObject->GetParam( Param => 'CustomerID' )     || '';

        # get secondary customer ids
        my @CustomerIDs;
        if ($CustomerUserID) {
            @CustomerIDs = $CustomerUserObject->CustomerIDs(
                User => $CustomerUserID,
            );
        }

        # add own customer id
        if ($CustomerID) {
            push @CustomerIDs, $CustomerID;
        }

        my $View    = $ParamObject->GetParam( Param => 'View' )    || '';
        my $SortBy  = $ParamObject->GetParam( Param => 'SortBy' )  || 'Age';
        my $OrderBy = $ParamObject->GetParam( Param => 'OrderBy' ) || 'Down';

        my @ViewableTickets;
        if (@CustomerIDs) {
            @ViewableTickets = $TicketObject->TicketSearch(
                Result        => 'ARRAY',
                Limit         => 250,
                SortBy        => [$SortBy],
                OrderBy       => [$OrderBy],
                CustomerIDRaw => \@CustomerIDs,
                UserID        => $Self->{UserID},
                Permission    => 'ro',
            );
        }

        my $LinkSort = 'Subaction=' . $Self->{Subaction}
            . ';View=' . $LayoutObject->Ascii2Html( Text => $View )
            . ';CustomerUserID=' . $LayoutObject->Ascii2Html( Text => $CustomerUserID )
            . ';CustomerID=' . $LayoutObject->Ascii2Html( Text => $CustomerID )
            . '&';
        my $LinkPage = 'Subaction=' . $Self->{Subaction}
            . ';View=' . $LayoutObject->Ascii2Html( Text => $View )
            . ';SortBy=' . $LayoutObject->Ascii2Html( Text => $SortBy )
            . ';OrderBy=' . $LayoutObject->Ascii2Html( Text => $OrderBy )
            . ';CustomerUserID=' . $LayoutObject->Ascii2Html( Text => $CustomerUserID )
            . ';CustomerID=' . $LayoutObject->Ascii2Html( Text => $CustomerID )
            . '&';
        my $LinkFilter = 'Subaction=' . $Self->{Subaction}
            . ';CustomerUserID=' . $LayoutObject->Ascii2Html( Text => $CustomerUserID )
            . ';CustomerID=' . $LayoutObject->Ascii2Html( Text => $CustomerID )
            . '&';

        my $CustomerTicketsHTMLString = ' ';
        if (@ViewableTickets) {
            $CustomerTicketsHTMLString .= $LayoutObject->TicketListShow(
                TicketIDs  => \@ViewableTickets,
                Total      => scalar @ViewableTickets,
                Env        => $Self,
                View       => $View,
                TitleName  => Translatable('Customer History'),
                LinkPage   => $LinkPage,
                LinkSort   => $LinkSort,
                LinkFilter => $LinkFilter,
                Output     => 'raw',

                OrderBy => $OrderBy,
                SortBy  => $SortBy,
                AJAX    => 1,
            );
        }

        return $LayoutObject->Attachment(
            ContentType => 'text/html; charset=' . $LayoutObject->{Charset},
            Content     => $CustomerTicketsHTMLString || ' ',
            Type        => 'inline',
            NoCache     => 1,
        );
    }

    elsif ($Self->{Subaction} eq 'UserInfo') {

        my $CallingAction       = $ParamObject->GetParam( Param => 'CallingAction' ) || '';
        my $UserID              = $ParamObject->GetParam( Param => 'UserID' )        || '';
        my $UserTableHTMLString = '';

        # get customer data
        my %UserData = $UserObject->GetUserData(
            User => $UserID,
        );

        # build html for user info table
        if ( %UserData && $ConfigObject->Get('Ticket::Frontend::CustomerInfoCompose') ) {

            # build html table
            $LayoutObject->Block(
                Name => 'Customer',
                Data => \%UserData
            );

            my $CustomerInfoString = $UserData{UserFullname}
                . '<br/><br/>'
                . '<b>' . $LayoutObject->{LanguageObject}->Translate('Mail') . ':</b> '
                . $UserData{UserEmail};

            $UserTableHTMLString = $LayoutObject->Output(
                Template => $CustomerInfoString,
                Data     => {},
            );

            while ( $CustomerInfoString =~ /\$UserData\{(.+?)}/ ) {
                my $Tag = $1;
                if ( $UserData{$Tag} ) {
                    $CustomerInfoString =~ s/\$UserData\{$Tag\}/$UserData{$Tag}/;
                }
                else {
                    $CustomerInfoString =~ s/\$UserData\{$Tag\}//;
                }
            }

            $LayoutObject->Block(
                Name => 'CustomerInfoString',
                Data => {
                    %UserData,
                    CustomerInfoString => $CustomerInfoString,
                }
            );

            $UserTableHTMLString = $LayoutObject->Output(
                TemplateFile   => 'AgentCustomerTableView',
                Data           => \%UserData,
                KeepScriptTags => 1,
            );
        }

        # build JSON output
        $JSON = $LayoutObject->JSONEncode(
            Data => {
                UserID              => $UserID,
                UserTableHTMLString => $UserTableHTMLString,
            },
        );
    }

    elsif ( $Self->{Subaction} eq 'ExistsCustomerUser') {

        my $UserID = $ParamObject->GetParam( Param => 'UserID' ) || '';

        my %CustomerUser = $CustomerUserObject->CustomerSearch(
            UserLogin => $UserID,
            Valid     => 1,
        );

        $JSON = $LayoutObject->JSONEncode(
            Data => {
                Customer => \%CustomerUser || ''
            }
        );
    }

    # send JSON response
    return $LayoutObject->Attachment(
        ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
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
