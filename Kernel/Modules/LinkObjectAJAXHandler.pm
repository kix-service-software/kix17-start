# --
# Copyright (C) 2006-2023 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::LinkObjectAJAXHandler;

use strict;
use warnings;

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

    # get param object
    my $ParamObject  = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $LinkObject   = $Kernel::OM->Get('Kernel::System::LinkObject');

    # get link table view mode
    my $LinkTableViewMode = $ConfigObject->Get('LinkObject::ViewMode');
    my %GetParam;
    my %Filter;

    for ( qw(ItemID Source Target SortBy OrderBy Filter CallingAction ClassID) ) {
        $GetParam{$_} = $ParamObject->GetParam( Param => $_ ) || '';
    }

    if ( $GetParam{Source} eq 'Ticket' ) {
        $Filter{ObjectParameters} = {
            Ticket => {
                IgnoreLinkedTicketStateTypes => 1
            }
        };
    }

    # get linked objects
    my $LinkListWithData = $LinkObject->LinkListWithData(
        Object  => $GetParam{Source},
        Key     => $GetParam{ItemID},
        State   => 'Valid',
        UserID  => $Self->{UserID},
        Object2 => $GetParam{Target},
        %Filter
    );

    for my $LinkObject ( keys %{$LinkListWithData} ) {
        for my $LinkType ( keys %{ $LinkListWithData->{$LinkObject} } ) {
            for my $LinkDirection ( keys %{ $LinkListWithData->{$LinkObject}->{$LinkType} } ) {
                for my $LinkItem (
                    keys %{ $LinkListWithData->{$LinkObject}->{$LinkType}->{$LinkDirection} }
                ) {
                    $LinkListWithData->{$LinkObject}->{$LinkType}->{$LinkDirection}->{$LinkItem}
                        ->{SourceObject} = $GetParam{Source};
                    $LinkListWithData->{$LinkObject}->{$LinkType}->{$LinkDirection}->{$LinkItem}
                        ->{SourceKey} = $GetParam{ItemID};
                }
            }
        }
    }

    if ( $Self->{Subaction} eq 'AJAXFilterUpdate' ) {
        my $Pattern        = $GetParam{Target}. $GetParam{ClassID} . 'ColumnFilter';
        my $ElementChanged = $ParamObject->GetParam( Param => 'ElementChanged' );
        my $Column         = $ElementChanged;

        $Column =~ s{ \A $Pattern }{}gxms;
        my $FilterContent = $LayoutObject->LinkObjectFilterContent(
            LinkListWithData  => $LinkListWithData,
            FilterContentOnly => 1,
            FilterColumn      => $Column,
            ElementChanged    => $ElementChanged,
            Object            => $GetParam{Target},
            Source            => $GetParam{Source},
            OnlyClassID       => $GetParam{ClassID} || ''
        );

        if ( !$FilterContent ) {
            $LayoutObject->FatalError(
                Message => $LayoutObject->{LanguageObject}->Translate(
                    'Can\'t get filter content data of %s!',
                    $Column
                ),
            );
        }

        return $LayoutObject->Attachment(
            ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
            Content     => $FilterContent,
            Type        => 'inline',
            NoCache     => 1,
        );

    }

    %Filter = ();
    if ( $GetParam{Source} eq 'Ticket' ) {
        $Filter{TicketID} = $GetParam{ItemID};
    } else {
        $Filter{LinkConfigItem} = $GetParam{ItemID};
    }

    my $LinkTableStrg = $LayoutObject->LinkObjectTableCreate(
        LinkListWithData => $LinkListWithData,
        ViewMode         => $LinkTableViewMode . 'Delete',
        GetPreferences   => 0,
        Action           => $GetParam{CallingAction},
        Template         => 'LinkObjectAJAXHandler',
        OnlyClassID      => $GetParam{ClassID} || '',
        OrderBy          => $GetParam{OrderBy},
        SortBy           => $GetParam{SortBy},
        %Filter
    );

    return $LayoutObject->Attachment(
        ContentType => 'text/html',
        Charset     => $LayoutObject->{UserCharset},
        Content     => $LinkTableStrg || '',
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
