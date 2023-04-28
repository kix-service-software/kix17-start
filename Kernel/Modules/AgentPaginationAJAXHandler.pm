# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AgentPaginationAJAXHandler;

use strict;
use warnings;

our $ObjectManagerDisabled = 1;

use Data::Dumper;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # create needed objects
    my $ConfigObject        = $Kernel::OM->Get('Kernel::Config');
    my $EncodeObject        = $Kernel::OM->Get('Kernel::System::Encode');
    my $LayoutObject        = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ParamObject         = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $UploadCacheObject   = $Kernel::OM->Get('Kernel::System::Web::UploadCache');
    my $JSONObject          = $Kernel::OM->Get('Kernel::System::JSON');

    for my $Needed ( qw(Subaction CallAction FormID) ) {
        $Param{$Needed} = $ParamObject->GetParam( Param => $Needed ) || '';
        if ( !$Param{$Needed} ) {
            return $LayoutObject->ErrorScreen( Message => "Need $Needed!", );
        }
    }

    if( $Self->{Subaction} ne 'DeleteFormContent' ) {
        $Param{ItemIDs} = $ParamObject->GetParam( Param => 'ItemIDs' ) || '';
        if ( !$Param{ItemIDs} ) {
            return $LayoutObject->ErrorScreen( Message => "Need ItemIDs!", );
        }
    }

    my $FormID
        = $Param{FormID} . '.'
        . $Param{CallAction} . '.'
        . $Self->{UserID};
    my $JSON        = '1';
    my $StrgIDs     = '';
    my $FileName    = '';

    if ( $Param{Subaction} eq 'UploadContentIDs' ) {
        my @ContentItems = $UploadCacheObject->FormIDGetAllFilesData(
            FormID => $FormID,
        );

        if ( scalar @ContentItems ) {
            $UploadCacheObject->FormIDRemove( FormID => $FormID );
        }

        # save file only if content given
        my $FileID = $UploadCacheObject->FormIDAddFile(
            FormID      => $FormID,
            Filename    => 'ItemIDs',
            Content     => $Param{ItemIDs},
            ContentType => 'text/xml',
        );

        $JSON = $JSONObject->Encode(
            Data => {
                FileID => $FileID,
            },
        );

    } elsif ( $Param{Subaction} eq 'LoadContentIDs' ) {
        my @ContentItems = $UploadCacheObject->FormIDGetAllFilesData(
            FormID => $FormID,
        );

        my @Result;
        for my $Item (@ContentItems) {
            $Item->{Content} = $EncodeObject->Convert(
                Text => $Item->{Content},
                From => 'utf-8',
                To   => 'iso-8859-1',
            );
            push @Result, { Value => $Item->{Content} };
        }

        $JSON = $JSONObject->Encode(
            Data => \@Result,
        );
    }

    elsif ( $Self->{Subaction} eq 'DeleteFormContent' ) {
        $JSON = $UploadCacheObject->FormIDRemove( FormID => $FormID ) || '0';
    }

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
