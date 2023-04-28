# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::SaveAsDraftAJAXHandler;

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

    # create needed objects
    my $EncodeObject      = $Kernel::OM->Get('Kernel::System::Encode');
    my $UploadCacheObject = $Kernel::OM->Get('Kernel::System::Web::UploadCache');
    my $ConfigObject      = $Kernel::OM->Get('Kernel::Config');
    my $LayoutObject      = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ParamObject       = $Kernel::OM->Get('Kernel::System::Web::Request');

    my $CallingAction = $ParamObject->GetParam( Param => 'CallingAction' );
    $Self->{Config} = $ConfigObject->Get("Ticket::SaveAsDraftAJAXHandler");

    # get params
    my %GetParam;
    for my $Key ( @{ $Self->{Config}->{Attributes} } ) {
        $GetParam{$Key} = $ParamObject->GetParam( Param => $Key );
    }

    my $NewFormID = $ParamObject->GetParam( Param => 'FormID' ) || 0;
    my $TicketID  = $ParamObject->GetParam( Param => 'TicketID' ) || 0;

    # the hardcoded unix timestamp 2147483646 is necessary for UploadCache FS backend
    my $FormID
        = '2147483646.SaveAsDraftAJAXHandler.'
        . $CallingAction . '.'
        . $Self->{UserID} . '.'
        . $TicketID;
    my $JSON = '1';

    # cleanup cache
    if ( $Self->{Subaction} ne 'GetFormContent' ) {
        $UploadCacheObject->FormIDRemove( FormID => $FormID );
    }

    if ( $Self->{Subaction} eq 'SaveFormContent' ) {

        # add attachment
        for my $Key ( keys %GetParam ) {

            # save file only if content given
            if ( defined $GetParam{$Key} && $GetParam{$Key} ) {
                my $FileID = $UploadCacheObject->FormIDAddFile(
                    FormID      => $FormID,
                    Filename    => $Key,
                    Content     => $GetParam{$Key},
                    ContentType => 'text/xml',
                );
            }
        }
    }
    elsif ( $Self->{Subaction} eq 'GetFormContent' ) {
        my @ContentItems = $UploadCacheObject->FormIDGetAllFilesData(
            FormID => $FormID,
        );

        my @Result;
        for my $Item (@ContentItems) {
            $EncodeObject->EncodeInput( \$Item->{Content} );

            # check if we have a new FormID for inline images of the draft
            if ( $NewFormID ) {
                while( $Item->{Content} =~ m/Action=PictureUpload;FormID=(\d+\.\d+\.\d+);ContentID=(inline\d+\.\d+\.\d+\.\d+\.\d+@)/ ) {
                    # get data of inline image
                    my $OldFormID = $1;
                    my $ContentID = $2;

                    # get data from upload cache
                    my @Data = $UploadCacheObject->FormIDGetAllFilesData(
                        FormID => $OldFormID,
                    );

                    # process files
                    FILE:
                    for my $FileEntry ( @Data ) {
                        # check for matching ContentID
                        if (
                            $FileEntry->{ContentID}
                            && $FileEntry->{ContentID} =~ m/^$ContentID/
                        ) {
                            # add file to new FormID
                            $UploadCacheObject->FormIDAddFile(
                                %{ $FileEntry },
                                FormID => $NewFormID,
                            );

                            # mark occurrences
                            $Item->{Content} =~ s/(Action=PictureUpload;FormID=)\d+\.\d+\.\d+(;ContentID=$ContentID)/$1NEW$2/g;

                            # stop processing
                            last FILE;
                        }
                    }

                    # remove remaining entries
                    $Item->{Content} =~ s/<.+?Action=PictureUpload;FormID=\d+\.\d+\.\d+;ContentID=$ContentID.+?>//g;
                }

                # replace occurences with new FormID
                if ( $Item->{Content} =~ m/Action=PictureUpload;FormID=NEW;ContentID=inline\d+\.\d+\.\d+\.\d+\.\d+@/ ) {
                    $Item->{Content} =~ s/(Action=PictureUpload;FormID=)NEW(;ContentID=inline\d+\.\d+\.\d+\.\d+\.\d+@)/$1$NewFormID$2/g
                }
            }

            push @Result, { Label => $Item->{Filename}, Value => $Item->{Content} };
        }

        $JSON = $LayoutObject->JSONEncode(
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
