# --
# Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AdminTextModuleCategories;

use strict;
use warnings;

use File::Temp qw( tempfile tempdir );
use File::Basename;

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
    my %GetParam;

    # create needed objects
    my $ConfigObject      = $Kernel::OM->Get('Kernel::Config');
    my $LayoutObject      = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $TextModuleObject  = $Kernel::OM->Get('Kernel::System::TextModule');
    my $TimeObject        = $Kernel::OM->Get('Kernel::System::Time');
    my $UploadCacheObject = $Kernel::OM->Get('Kernel::System::Web::UploadCache');
    my $ParamObject       = $Kernel::OM->Get('Kernel::System::Web::Request');

    # create form id
    $Self->{FormID} = $UploadCacheObject->FormIDCreate();

    my $DefaultLimit = $ConfigObject->Get('TextModuleCategory::LimitShownEntries') || 100;

    # set import/export config options
    my $ImportExportConfig = $ConfigObject->Get('TextModuleCategory::ImportExport');

    # get params
    for (
        qw(SelectedCategoryID ID Name ParentCategory FormID Limit Show Download DownloadType UploadType
        XMLUploadDoNotAdd XMLResultFileID XMLResultFileName)
    ) {
        $GetParam{$_} = $ParamObject->GetParam( Param => $_ ) || '';
    }

    if ( !$GetParam{ID} ) {
        $GetParam{ID} = $GetParam{SelectedCategoryID};    # fallback
    }

    $GetParam{XMLUploadDoNotAdd} = 0;
    $GetParam{XMLUploadDoNotAdd}
        = $ConfigObject->Get('TextModuleCategory::XMLUploadDoNotAdd');

    $Param{FormID} = $Self->{FormID};

    my %Categories = $TextModuleObject->TextModuleCategoryList();

    # build ParentCategory list
    my %ParentCategories;
    my $SelectedCategory = '';
    if ( $GetParam{ID} ) {
        $SelectedCategory = $Categories{ $GetParam{ID} };
        delete $Categories{ $GetParam{ID} };
    }
    foreach my $CategoryID ( keys %Categories ) {
        if ( $Categories{$CategoryID} =~ /^$SelectedCategory\:\:/g ) {
            next;
        }
        $ParentCategories{ $Categories{$CategoryID} } = $Categories{$CategoryID};
    }
    $Param{ParentCategoryStrg} = $LayoutObject->BuildSelection(
        Data         => \%ParentCategories,
        Name         => 'ParentCategory',
        SelectedID   => $GetParam{ParentCategory},
        PossibleNone => 1,
        Class        => 'Modernize',
    );

    # ------------------------------------------------------------------------ #
    # change or add text module category
    # ------------------------------------------------------------------------ #
    if ( ( $Self->{Subaction} eq 'Change' && $GetParam{ID} ) || $Self->{Subaction} eq 'New' ) {

        my %TextModuleCategoryData = ();

        # output header
        my $Output = $LayoutObject->Header();
        $Output .= $LayoutObject->NavigationBar();

        if ( $Self->{Subaction} eq 'Change' ) {
            %TextModuleCategoryData = $TextModuleObject->TextModuleCategoryGet(
                ID => $GetParam{ID}
            );
            my @NameSplit = split( /::/, $TextModuleCategoryData{Name} );
            $TextModuleCategoryData{Name} = pop @NameSplit;
            $GetParam{ParentCategory} = join( ' :: ', @NameSplit );
        }

        # output backlink
        $LayoutObject->Block(
            Name => 'ActionOverview',
            Data => \%Param,
        );

        $Param{ParentCategoryStrg} = $LayoutObject->BuildSelection(
            Data         => \%ParentCategories,
            Name         => 'ParentCategory',
            SelectedID   => $GetParam{ParentCategory},
            PossibleNone => 1,
            Class        => 'Modernize',
        );

        $LayoutObject->Block(
            Name => 'Edit',
            Data => {
                %GetParam,
                %Param,
                %TextModuleCategoryData,
            },
        );

        # generate output
        $Output .= $LayoutObject->Output(
            TemplateFile => 'AdminTextModuleCategories',
            Data         => \%Param,
        );
        $Output .= $LayoutObject->Footer();
        return $Output;
    }

    # ------------------------------------------------------------------------ #
    # save
    # ------------------------------------------------------------------------ #
    if ( $Self->{Subaction} eq 'Save' ) {
        my %Error;

        # output header
        my $Output = $LayoutObject->Header();
        $Output .= $LayoutObject->NavigationBar();

        # check required attributes...
        for my $Key (qw(Name)) {
            if ( !$GetParam{$Key} ) {
                $Error{ $Key . 'Invalid' } = 'ServerError';
            }
        }

        # attempt the update...
        if ( !%Error ) {
            $GetParam{Name}
                = $GetParam{ParentCategory}
                ? $GetParam{ParentCategory} . '::' . $GetParam{Name}
                : $GetParam{Name};

            if ( !$GetParam{ID} ) {
                $Param{ID} = $TextModuleObject->TextModuleCategoryAdd(
                    %GetParam,
                    UserID => $Self->{UserID}
                );
            }
            else {
                my $UpdateResult = $TextModuleObject->TextModuleCategoryUpdate(
                    %GetParam,
                    UserID => $Self->{UserID}
                );
                $Param{ID} = $GetParam{ID};
            }

            return $LayoutObject->Redirect(
                OP => "Action=$Self->{Action}",
            );
        }

        # some sort of error handling...
        if (%Error) {

            # output backlink
            $LayoutObject->Block(
                Name => 'ActionOverview',
                Data => \%Param,
            );

            # output edit
            $LayoutObject->Block(
                Name => 'Edit',
                Data => {
                    %GetParam,
                    %Error,
                    %Param,
                },
            );

            # generate output
            $Output .= $LayoutObject->Output(
                TemplateFile => 'AdminTextModuleCategories',
                Data         => \%Param,
            );
            $Output .= $LayoutObject->Footer();

            return $Output;

        }

        return $LayoutObject->Redirect(
            OP => "Action=$Self->{Action};Subaction=Overview;ID=$Param{ID}"
        );
    }

    # ------------------------------------------------------------------------ #
    # delete
    # ------------------------------------------------------------------------ #
    elsif ( $Self->{Subaction} eq 'Delete' && $GetParam{ID} ) {
        my $DeleteResult = $TextModuleObject->TextModuleCategoryDelete(
            ID => $GetParam{ID}
        );
        if ($DeleteResult) {
            return $LayoutObject->Redirect(
                OP => "Action=$Self->{Action}"
            );
        }
        else {
            return $LayoutObject->ErrorScreen();
        }
    }

    # ------------------------------------------------------------------------ #
    # upload
    # ------------------------------------------------------------------------ #
    elsif ( $Self->{Subaction} eq 'Upload' && $GetParam{FormID} ) {

        # init result...
        my %UploadResult = ();
        $Param{CountUploaded}     = 0;
        $Param{CountUpdateFailed} = 0;
        $Param{CountUpdated}      = 0;
        $Param{CountInsertFailed} = 0;
        $Param{CountAdded}        = 0;

        # get uploaded data...
        my %UploadStuff = $ParamObject->GetUploadAll(
            Param  => 'file_upload',
            Source => 'string',
        );

        my @FileList = $UploadCacheObject->FormIDGetAllFilesMeta(
            FormID => $Param{FormID},
        );

        if (%UploadStuff) {
            my $UploadFileName = $UploadStuff{Filename};

            # if file was uploaded as csv
            if ( $GetParam{UploadType} eq 'CSV' ) {
                my $Content = $UploadStuff{Content};

                my @ContentChars = split( //, $Content );
                my $InQuote      = 0;
                my $AddedQuote   = 0;
                my $PreparedContent;
                my $OldChar = '';
                foreach my $Char (@ContentChars) {
                    if ( $Char eq '"' && !$InQuote ) {
                        $InQuote = 1;
                    }
                    elsif ( $Char eq '"' && $InQuote ) {
                        $InQuote = 0;
                    }

                    if (
                        !$InQuote && (
                            $Char eq ';' || $Char eq "\n"
                        )
                        && $OldChar eq ';'
                    ) {
                        $PreparedContent .= '""';
                    }
                    elsif (
                        !$InQuote
                        && $Char    ne ';'
                        && $Char    ne '"'
                        && $Char    ne " \n "
                        && $Char    ne " \r "
                        && $OldChar ne '"'
                    ) {
                        $PreparedContent .= '"';
                        $InQuote    = 1;
                        $AddedQuote = 1;
                    }
                    elsif (
                        $InQuote
                        && $AddedQuote
                        && ( $Char eq " \n " || $Char eq " \r " || $Char eq ';' )
                    ) {
                        $PreparedContent .= '"';
                        $InQuote    = 0;
                        $AddedQuote = 0;
                    }
                    $PreparedContent .= $Char;
                    $OldChar = $Char;
                }

                $PreparedContent =~ s/^;/"";/gm;
                $PreparedContent =~ s/;[^"]\r+$/;""/gm;
                $PreparedContent =~ s/;[^"]$/;""/gm;

                $UploadStuff{Content} = $PreparedContent;
            }

            #start the update process...
            if ( !$Param{UploadMessage} && $UploadStuff{Content} ) {

                %UploadResult = %{
                    $TextModuleObject->TextModuleCategoriesImport(
                        Format       => $GetParam{UploadType},
                        Content      => $UploadStuff{Content},
                        CSVSeparator => $ImportExportConfig->{CSVSeparator},
                        DoNotAdd     => $GetParam{XMLUploadDoNotAdd},
                        UserID       => $Self->{UserID},
                        )
                    };

                if ( $UploadResult{XMLResultString} ) {
                    my $DownloadFileName = $UploadFileName;
                    my $TimeString       = $TimeObject->SystemTime2TimeStamp(
                        SystemTime => $TimeObject->SystemTime(),
                    );
                    $TimeString       =~ s/\s/\_/g;
                    $DownloadFileName =~ s/\.(.*)$/_ImportResult_$TimeString\.xml/g;

                    my $FileID = $UploadCacheObject->FormIDAddFile(
                        FormID      => $Param{FormID},
                        Filename    => $DownloadFileName,
                        Content     => $UploadResult{XMLResultString},
                        ContentType => 'text/xml',

                    );
                    $Param{XMLResultFileID}   = $FileID;
                    $Param{XMLResultFileName} = $DownloadFileName;
                    $Param{XMLResultFileSize} = length( $UploadStuff{Content} );
                }
                if ( !$UploadResult{UploadMessage} ) {
                    $UploadResult{UploadMessage}
                        = $UploadStuff{Filename} . ' '
                        . $LayoutObject->{LanguageObject}->Translate('successful loaded.');
                }
            }
        }
        else {
            $Param{UploadMessage} = $LayoutObject->{LanguageObject}
                ->Translate('Import failed - No file uploaded/received.');
        }

        # output upload
        $LayoutObject->Block(
            Name => 'Upload',
            Data => {
                UploadType => $ImportExportConfig->{FileType},
                %Param,
                }
        );

        # output overview list
        $LayoutObject->Block(
            Name => 'UploadResult',
            Data => { %GetParam, %Param, %UploadResult },
        );
    }

    # ------------------------------------------------------------ #
    # DownloadResult
    # ------------------------------------------------------------ #
    elsif ( $Self->{Subaction} eq 'DownloadResult' && $GetParam{XMLResultFileID} ) {
        my @Data = $UploadCacheObject->FormIDGetAllFilesData(
            FormID => $GetParam{FormID},
        );
        for my $Entry (@Data) {
            if ( $Entry->{FileID} eq $GetParam{XMLResultFileID} ) {
                return $LayoutObject->Attachment(
                    Type        => 'attachment',
                    Filename    => $Entry->{Filename},
                    ContentType => $Entry->{ContentType},
                    Content     => $Entry->{Content},
                    NoCache     => 1,
                );
            }
        }
    }

    # ------------------------------------------------------------ #
    # download
    # ------------------------------------------------------------ #

    elsif ( $Self->{Subaction} eq 'Download' ) {
        my $Content = $TextModuleObject->TextModuleCategoriesExport(
            Format    => $GetParam{DownloadType},
            Separator => $ImportExportConfig->{CSVSeparator},
        );
        my $ContentType = 'application/xml';
        my $FileType    = 'xml';

        # if download file as csv
        if ( $GetParam{DownloadType} eq 'CSV' ) {
            $ContentType = 'text/csv;charset = ' . $LayoutObject->{UserCharset};
            $FileType    = 'csv';
        }

        my $TimeString = $TimeObject->SystemTime2TimeStamp(
            SystemTime => $TimeObject->SystemTime(),
        );
        $TimeString =~ s/\s/\_/g;
        my $FileName = 'TextModuleCategories_' . $TimeString . '.' . $FileType;

        return $LayoutObject->Attachment(
            Type        => 'attachment',
            Filename    => $FileName,
            ContentType => $ContentType,
            Content     => $Content,
            NoCache     => 1,
        );
    }

    # ------------------------------------------------------------ #
    # overview
    # ------------------------------------------------------------ #

    # output header
    my $Output = $LayoutObject->Header();
    $Output .= $LayoutObject->NavigationBar();

    my $CategoryName = '';
    if ( $GetParam{Name} ) {
        $CategoryName = '*' . $GetParam{Name} . '*';
    }
    my %TextModuleCategoryData = $TextModuleObject->TextModuleCategoryList(
        Name  => $CategoryName,
        Limit => $GetParam{Limit},
    );

    # output search block
    $LayoutObject->Block(
        Name => 'TextModuleCategorySearch',
        Data => { %Param, %GetParam },
    );

    # output add
    $LayoutObject->Block(
        Name => 'ActionAdd',
        Data => \%Param,
    );

    # output download
    $LayoutObject->Block(
        Name => 'Download',
        Data => {
            DownloadType => $ImportExportConfig->{FileType},
            %Param,
            }
    );

    # output upload
    if ( $Self->{Subaction} ne 'Upload' ) {

        $LayoutObject->Block(
            Name => 'Upload',
            Data => {
                UploadType => $ImportExportConfig->{FileType},
                %Param,
                }
        );
    }

    $Param{Count} = scalar keys %TextModuleCategoryData;
    $Param{CountNote} =
        ( $GetParam{Limit} && $Param{Count} == $GetParam{Limit} ) ? '(limited)' : '';

    $LayoutObject->Block(
        Name => 'OverviewList',
        Data => \%Param,
    );

    # build category tree
    $Param{CategoryTree} = $LayoutObject->TextModuleCategoryTree(
        SelectedCategoryID   => $GetParam{SelectedCategoryID},
        Categories           => \%TextModuleCategoryData,
        CategoryDeletionLink => 1,
        NoVirtualCategories  => 1,
        NoContentCounters    => 1,
        Limit                => $DefaultLimit,
    );

    # generate output
    $Output .= $LayoutObject->Output(
        TemplateFile => 'AdminTextModuleCategories',
        Data         => \%Param,
    );
    $Output .= $LayoutObject->Footer();

    return $Output;
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
