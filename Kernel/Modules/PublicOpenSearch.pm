# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::PublicOpenSearch;

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

    # get needed objects
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ParamObject  = $Kernel::OM->Get('Kernel::System::Web::Request');

    # get Identifier
    my $Identifier = $ParamObject->GetParam( Param => 'Identifier' );

    # get configured open search
    my $OpenSearchRef = $ConfigObject->Get('OpenSearch');

    # check config
    if (
        !$Identifier
        || ref( $OpenSearchRef ) ne 'HASH'
        || ref ( $OpenSearchRef->{Identifier} ) ne 'ARRAY'
        || ref ( $OpenSearchRef->{Frontend} ) ne 'HASH'
        || ref ( $OpenSearchRef->{ShortName} ) ne 'HASH'
        || ref ( $OpenSearchRef->{Description} ) ne 'HASH'
        || ref ( $OpenSearchRef->{SearchUrl} ) ne 'HASH'
        || !$OpenSearchRef->{Frontend}->{ $Identifier }
        || !$OpenSearchRef->{ShortName}->{ $Identifier }
        || !$OpenSearchRef->{Description}->{ $Identifier }
        || !$OpenSearchRef->{SearchUrl}->{ $Identifier }
    ) {
        return $LayoutObject->CustomerNoPermission(
            WithHeader => 'no',
        );
    }

    # check Identifier
    my $IdentifierFound = 0;
    CHECKIDENTIFIER:
    for my $CheckIdentifier ( @{ $OpenSearchRef->{Identifier} } ) {
        if ( $CheckIdentifier eq $Identifier ) {
            $IdentifierFound = 1;
            last CHECKIDENTIFIER;
        }
    }
    if ( !$IdentifierFound ) {
        return $LayoutObject->CustomerNoPermission(
            WithHeader => 'no',
        );
    }

    # generate output
    my $Output = $LayoutObject->Output(
        TemplateFile => 'PublicOpenSearch',
        Data         => {
            Identifier  => $Identifier,
            ShortName   => $OpenSearchRef->{ShortName}->{ $Identifier },
            Description => $OpenSearchRef->{Description}->{ $Identifier },
            SearchUrl   => $OpenSearchRef->{SearchUrl}->{ $Identifier },
            LongName    => $OpenSearchRef->{LongName}->{ $Identifier } || '',
            Tags        => $OpenSearchRef->{Tags}->{ $Identifier } || '',
        },
    );

    # return attachment
    return $LayoutObject->Attachment(
        Filename    => $Identifier . '.xml',
        ContentType => 'application/opensearchdescription+xml',
        Content     => $Output,
        Type        => 'inline',
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
