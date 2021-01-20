# --
# Copyright (C) 2006-2021 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::HeaderMeta::OpenSearch;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::Output::HTML::Layout',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # check job configuration
    if (
        !$Param{Config}
        || !$Param{Config}->{Frontend}
        || $Param{Config}->{Frontend} !~ m/(?:Agent|Customer|Public)/
    ) {
        return;
    }

    # get configured open search
    my $OpenSearchRef = $ConfigObject->Get('OpenSearch');
    # check config
    if (
        ref( $OpenSearchRef ) eq 'HASH'
        && ref ( $OpenSearchRef->{Identifier} ) eq 'ARRAY'
        && ref ( $OpenSearchRef->{Frontend} ) eq 'HASH'
        && ref ( $OpenSearchRef->{ShortName} ) eq 'HASH'
        && ref ( $OpenSearchRef->{Description} ) eq 'HASH'
        && ref ( $OpenSearchRef->{SearchUrl} ) eq 'HASH'
    ) {
        # process identifier
        IDENTIFIER:
        for my $Identifier ( @{ $OpenSearchRef->{Identifier} } ) {
            # check frontend
            next IDENTIFIER if (
                !$OpenSearchRef->{Frontend}->{ $Identifier }
                || $OpenSearchRef->{Frontend}->{ $Identifier } ne $Param{Config}->{Frontend}
            );
            # check mandatory data
            for my $Attribute ( qw(ShortName Description SearchUrl) ) {
                next IDENTIFIER if ( !$OpenSearchRef->{ $Attribute }->{ $Identifier } );
            }

            # prepare ShortName
            my $ShortName = $LayoutObject->Output(
                Template => $OpenSearchRef->{ShortName}->{ $Identifier },
                Data     => {},
            );

            # add meta link for OpenSearch
            $LayoutObject->Block(
                Name => 'MetaLink',
                Data => {
                    Rel   => 'search',
                    Type  => 'application/opensearchdescription+xml',
                    Title => $ShortName,
                    Href  => 'public.pl?Action=PublicOpenSearch;Identifier=' . $Identifier,
                },
            );
        }
    }

    return 1;
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
