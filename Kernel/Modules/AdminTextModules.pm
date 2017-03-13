# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AdminTextModules;

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

    # create needed objects
    my $ConfigObject      = $Kernel::OM->Get('Kernel::Config');
    my $LayoutObject      = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $QueueObject       = $Kernel::OM->Get('Kernel::System::Queue');
    my $StateObject       = $Kernel::OM->Get('Kernel::System::State');
    my $TextModuleObject  = $Kernel::OM->Get('Kernel::System::TextModule');
    my $TimeObject        = $Kernel::OM->Get('Kernel::System::Time');
    my $TypeObject        = $Kernel::OM->Get('Kernel::System::Type');
    my $ValidObject       = $Kernel::OM->Get('Kernel::System::Valid');
    my $UploadCacheObject = $Kernel::OM->Get('Kernel::System::Web::UploadCache');
    my $ParamObject       = $Kernel::OM->Get('Kernel::System::Web::Request');

    # create form id
    $Self->{FormID} = $UploadCacheObject->FormIDCreate();

    my $DefaultLimit = $ConfigObject->Get('TextModule::LimitShownEntries') || 100;

    # set import/export config options
    my $ImportExportConfig = $ConfigObject->Get('TextModule::ImportExport');

    # get params
    my @Frontends = $ParamObject->GetArray( Param => 'Frontend' );
    my %GetParam = map { $_ => 1 } @Frontends;
    for (
        qw(ID Name Keywords Comment Comment1 Comment2 Subject TextModule
        Language LanguageEdit ValidID FormID Limit Show Download
        XMLUploadDoNotAdd XMLResultFileID XMLResultFileName
        SelectedCategoryID DownloadType UploadType)
        )
    {
        $GetParam{$_} = $ParamObject->GetParam( Param => $_ ) || '';
    }

    my @NewCategoryIDs    = $ParamObject->GetArray( Param => 'AssignedCategoryIDs' );
    my @NewQueueIDs       = $ParamObject->GetArray( Param => 'AssignedQueueIDs' );
    my @NewTicketTypeIDs  = $ParamObject->GetArray( Param => 'AssignedTicketTypeIDs' );
    my @NewTicketStateIDs = $ParamObject->GetArray( Param => 'AssignedTicketStateIDs' );

    $GetParam{XMLUploadDoNotAdd} = 0;
    $GetParam{XMLUploadDoNotAdd} = $ConfigObject->Get('TextModule::XMLUploadDoNotAdd');

    # build valid selection
    my %ValidHash = $ValidObject->ValidList();
    $ValidHash{''} = '-';
    $Param{ValidOption} = $LayoutObject->BuildSelection(
        Data       => \%ValidHash,
        Name       => 'ValidID',
        SelectedID => $Param{ValidID},
        Class      => 'Modernize',
    );

    # build language selection
    my $LanguagesRef = $ConfigObject->Get('DefaultUsedLanguages');
    my %LanguageHash = %{$LanguagesRef};
    $LanguageHash{''} = '-';
    $Param{LanguageOption} = $LayoutObject->BuildSelection(
        Data      => \%LanguageHash,
        Name      => 'Language',
        HTMLQuote => 0,
        Class     => 'Modernize',
    );

    # build category selection
    my %CategoryData = $TextModuleObject->TextModuleCategoryList();
    my $CategorySize = ( scalar keys %CategoryData < 10 ) ? keys %CategoryData : 10;
    $Param{TextModuleCategoryStrg} = $LayoutObject->BuildSelection(
        Data     => \%CategoryData,
        Name     => 'AssignedCategoryIDs',
        Multiple => 1,
        Size     => ( $CategorySize < 3 ) ? 3 : $CategorySize,
        Class    => 'Modernize',
        TreeView => 1,
        Sort     => 'TreeView',
    );

    # build queue selection
    my %QueueData = $QueueObject->QueueList( Valid => 1 );
    my $QueueSize = ( scalar keys %QueueData < 10 ) ? keys %QueueData : 10;
    $Param{QueueTextModuleStrg} = $LayoutObject->BuildSelection(
        Data     => \%QueueData,
        Name     => 'AssignedQueueIDs',
        Multiple => 1,
        Size     => ( $QueueSize < 3 ) ? 3 : $QueueSize,
        Class    => 'Modernize',
        TreeView => 1,
        Sort     => 'TreeView',
    );

    $Param{SelQueuesArray} = 'var arrSelQueues = new Array();';
    $Param{AllQueuesArray} = 'var arrQueues = new Array();';
    my $Index = 0;
    for my $QueueID ( keys %QueueData ) {
        $Param{AllQueuesArray} .= 'arrQueues['
            . $Index
            . '] = "'
            . $QueueID
            . ":::::"
            . $QueueData{$QueueID}
            . '";';
        $Index++;
    }

    $LayoutObject->Block(
        Name => 'QueueList',
        Data => \%Param,
    );

    # build ticket type selection
    my %TicketTypeData = $TypeObject->TypeList( Valid => 1 );
    my $TypeSize = ( scalar keys %TicketTypeData < 10 ) ? keys %TicketTypeData : 10;
    $Param{TicketTypeTextModuleStrg} = $LayoutObject->BuildSelection(
        Data        => \%TicketTypeData,
        Name        => 'AssignedTicketTypeIDs',
        Multiple    => 1,
        Size        => ( $TypeSize < 3 ) ? 3 : $TypeSize,
        Translation => 0,
        Class       => 'Modernize',
    );

    # build ticket type selection
    my %TicketStateData = $StateObject->StateList(
        Valid  => 1,
        UserID => 1,
    );
    my $StateSize = ( scalar keys %TicketStateData < 10 ) ? keys %TicketStateData : 10;
    $Param{TicketStateTextModuleStrg} = $LayoutObject->BuildSelection(
        Data     => \%TicketStateData,
        Name     => 'AssignedTicketStateIDs',
        Multiple => 1,
        Size     => ( $StateSize < 3 ) ? 3 : $StateSize,
        Class    => 'Modernize',
    );

    # prepare initial body
    my $Body = $LayoutObject->Output(
        Template => $Self->{Config}->{Body} || '',
    );

    # make sure body is rich text
    if ( $ConfigObject->Get('Frontend::RichText') ) {
        $Body = $LayoutObject->Ascii2RichText(
            String => $Body,
        );
    }

    $Param{FormID} = $Self->{FormID};

    # build category tree
    my %Categories    = $TextModuleObject->TextModuleCategoryList();
    my %CategoryCount = $TextModuleObject->TextModuleCategoryAssignmentCounts();
    $Param{CategoryTree} = $LayoutObject->TextModuleCategoryTree(
        SelectedCategoryID => $GetParam{SelectedCategoryID},
        Categories         => \%Categories,
        CategoryCount      => \%CategoryCount,
    );

    # ------------------------------------------------------------------------ #
    # change or add text module
    # ------------------------------------------------------------------------ #
    if (
        defined $Self->{Subaction}
        && ( ( $Self->{Subaction} eq 'Change' && $GetParam{ID} ) || $Self->{Subaction} eq 'New' )
        )
    {

        my %TextModuleData = ();

        # output header
        my $Output = $LayoutObject->Header();
        $Output .= $LayoutObject->NavigationBar();

        delete( $ValidHash{''} );
        $Param{ValidOption} = $LayoutObject->BuildSelection(
            Data       => \%ValidHash,
            Name       => 'ValidID',
            SelectedID => 1,
            Class      => 'Validate_Required Modernize',
        );

        if ( $Self->{Subaction} eq 'Change' ) {
            %TextModuleData = $TextModuleObject->TextModuleGet(
                ID => $GetParam{ID}
            );

            $Param{AgentChecked}    = 'checked="checked"' if $TextModuleData{Agent};
            $Param{CustomerChecked} = 'checked="checked"' if $TextModuleData{Customer};
            $Param{PublicChecked}   = 'checked="checked"' if $TextModuleData{Public};

            $Param{ValidOption} = $LayoutObject->BuildSelection(
                Data       => \%ValidHash,
                Name       => 'ValidID',
                SelectedID => $TextModuleData{ValidID},
                Class      => 'Validate_Required Modernize',
            );

            # build category selection
            my $SelectedCategoryDataRef = $TextModuleObject->TextModuleObjectLinkGet(
                ObjectType   => 'TextModuleCategory',
                TextModuleID => $GetParam{ID},
            );
            my @SelectedCategoryIDs = @{$SelectedCategoryDataRef};
            $Param{TextModuleCategoryStrg} = $LayoutObject->BuildSelection(
                Data       => \%CategoryData,
                Name       => 'AssignedCategoryIDs',
                Multiple   => 1,
                Size       => ( $CategorySize < 3 ) ? 3 : $CategorySize,
                SelectedID => \@SelectedCategoryIDs,
                Class      => 'Modernize',
            );

            # build queue selection
            my $SelectedQueueDataRef = $TextModuleObject->TextModuleObjectLinkGet(
                ObjectType   => 'Queue',
                TextModuleID => $GetParam{ID},
            );
            my @SelectedQueueIDs = @{$SelectedQueueDataRef};

            $Param{QueueTextModuleStrg} = $LayoutObject->BuildSelection(
                Data       => \%QueueData,
                Name       => 'AssignedQueueIDs',
                Multiple   => 1,
                Size       => ( $QueueSize < 3 ) ? 3 : $QueueSize,
                SelectedID => \@SelectedQueueIDs,
                Class      => 'Modernize',
            );

            my $QueueIndex = 0;
            for my $QueueID (@SelectedQueueIDs) {
                $Param{SelQueuesArray} .= 'arrSelQueues[' . $QueueIndex . '] = "' . $QueueID . '";';
                $QueueIndex++;
            }

            # build ticket type selection
            my @SelectedTicketTypeIDs;
            if ( $ConfigObject->Get('Ticket::Type') ) {
                my $SelectedTicketTypeDataRef = $TextModuleObject->TextModuleObjectLinkGet(
                    ObjectType   => 'TicketType',
                    TextModuleID => $GetParam{ID},
                );
                @SelectedTicketTypeIDs = @{$SelectedTicketTypeDataRef};
            }

            $Param{TicketTypeTextModuleStrg} = $LayoutObject->BuildSelection(
                Data        => \%TicketTypeData,
                Name        => 'AssignedTicketTypeIDs',
                Multiple    => 1,
                Size        => ( $TypeSize < 3 ) ? 3 : $TypeSize,
                SelectedID  => \@SelectedTicketTypeIDs,
                Disabled    => !$ConfigObject->Get('Ticket::Type'),
                Translation => 0,
                Class       => 'Modernize',
            );

            # build ticket state selection
            my $SelectedTicketStateDataRef = $TextModuleObject->TextModuleObjectLinkGet(
                ObjectType   => 'TicketState',
                TextModuleID => $GetParam{ID},
            );
            my @SelectedTicketStateIDs = @{$SelectedTicketStateDataRef};

            $Param{TicketStateTextModuleStrg} = $LayoutObject->BuildSelection(
                Data       => \%TicketStateData,
                Name       => 'AssignedTicketStateIDs',
                Multiple   => 1,
                Size       => ( $StateSize < 3 ) ? 3 : $StateSize,
                SelectedID => \@SelectedTicketStateIDs,
                Class      => 'Modernize',
            );
        }

        # build Language string
        $Param{LanguageEditOption} = $LayoutObject->BuildSelection(
            Data       => \%LanguageHash,
            Name       => 'LanguageEdit',
            HTMLQuote  => 0,
            SelectedID => $TextModuleData{Language}
                || $GetParam{Language}
                || $Self->{UserLanguage}
                || '',
            Class => 'Modernize',
        );

        # output backlink
        $LayoutObject->Block(
            Name => 'ActionOverview',
            Data => \%Param,
        );

        # output hint
        $LayoutObject->Block(
            Name => 'Hint',
            Data => \%Param,
        );

        $LayoutObject->Block(
            Name => 'Edit',
            Data => {
                %GetParam,
                %Param,
                %TextModuleData,
            },
        );

        # add rich text editor
        if ( $ConfigObject->Get('Frontend::RichText') ) {
            $LayoutObject->Block(
                Name => 'RichText',
                Data => \%Param,
            );
        }

        # add ticket type selection
        if ( $ConfigObject->Get('Ticket::Type') ) {
            $LayoutObject->Block(
                Name => 'EditTicketType',
                Data => {
                    %GetParam,
                    %Param,
                    %TextModuleData,
                },
            );
        }

        # output EditNote
        $LayoutObject->Block(
            Name => 'EditNote',
            Data => \%Param,
        );

        # generate output
        $Output .= $LayoutObject->Output(
            TemplateFile => 'AdminTextModules',
            Data         => \%Param,
        );
        $Output .= $LayoutObject->Footer();
        return $Output;
    }

    # ------------------------------------------------------------------------ #
    # save
    # ------------------------------------------------------------------------ #
    if ( defined $Self->{Subaction} && $Self->{Subaction} eq 'Save' ) {
        my %Error;

        #-----------------------------------------------------------------------
        # output header
        my $Output = $LayoutObject->Header();
        $Output .= $LayoutObject->NavigationBar();

        #-----------------------------------------------------------------------
        # rename Language param...
        $GetParam{Language} = $GetParam{LanguageEdit};

        #-----------------------------------------------------------------------
        # check required attributes...
        for my $Key (qw(Name ValidID)) {
            if ( !$GetParam{$Key} ) {
                $Error{ $Key . 'Invalid' } = 'ServerError';
            }
        }

        #-----------------------------------------------------------------------
        # attempt the update...
        if ( !%Error ) {
            if ( !$GetParam{ID} ) {

                # add text module
                $Param{ID} = $TextModuleObject->TextModuleAdd(
                    %GetParam,
                    UserID => $Self->{UserID}
                );
            }
            else {

                # update text module
                my $UpdateResult = $TextModuleObject->TextModuleUpdate(
                    %GetParam,
                    UserID => $Self->{UserID}
                );
                $Param{ID} = $GetParam{ID};
            }

            # update ticket type links...
            if ( $Param{ID} ) {

                # delete existing links... (only on update)
                if ( $GetParam{ID} ) {
                    $TextModuleObject->TextModuleObjectLinkDelete(
                        TextModuleID => $Param{ID},
                    );
                }

                for my $NewCategoryID (@NewCategoryIDs) {
                    $TextModuleObject->TextModuleObjectLinkCreate(
                        ObjectType   => 'TextModuleCategory',
                        ObjectID     => $NewCategoryID,
                        TextModuleID => $Param{ID},
                        UserID       => $Self->{UserID},
                    );
                }

                # create new links...
                for my $NewQueueID (@NewQueueIDs) {
                    $TextModuleObject->TextModuleObjectLinkCreate(
                        ObjectType   => 'Queue',
                        ObjectID     => $NewQueueID,
                        TextModuleID => $Param{ID},
                        UserID       => $Self->{UserID},
                    );
                }
                for my $NewTicketTypeID (@NewTicketTypeIDs) {
                    $TextModuleObject->TextModuleObjectLinkCreate(
                        ObjectType   => 'TicketType',
                        ObjectID     => $NewTicketTypeID,
                        TextModuleID => $Param{ID},
                        UserID       => $Self->{UserID},
                    );
                }
                for my $NewTicketStateID (@NewTicketStateIDs) {
                    $TextModuleObject->TextModuleObjectLinkCreate(
                        ObjectType   => 'TicketState',
                        ObjectID     => $NewTicketStateID,
                        TextModuleID => $Param{ID},
                        UserID       => $Self->{UserID},
                    );
                }
            }

            return $LayoutObject->Redirect(
                OP => "Action=$Self->{Action}",
            );
        }

        #-----------------------------------------------------------------------
        # some sort of error handling...
        if (%Error) {
            $Param{AgentChecked}    = 'checked="checked"' if $GetParam{Agent};
            $Param{CustomerChecked} = 'checked="checked"' if $GetParam{Customer};
            $Param{PublicChecked}   = 'checked="checked"' if $GetParam{Public};

            $Param{ValidOption} = $LayoutObject->BuildSelection(
                Data       => \%ValidHash,
                Name       => 'ValidID',
                SelectedID => $GetParam{ValidID},
                Class => 'Validate_Required Modernize ' . ( $Error{ValidIDInvalid} || 'Modernize' ),
            );

            $Param{TextModuleCategoryStrg} = $LayoutObject->BuildSelection(
                Data       => \%CategoryData,
                Name       => 'AssignedCategoryIDs',
                Multiple   => 1,
                Size       => ( $CategorySize < 3 ) ? 3 : $CategorySize,
                SelectedID => \@NewCategoryIDs,
                Class      => 'Modernize',
            );

            $Param{QueueTextModuleStrg} = $LayoutObject->BuildSelection(
                Data       => \%QueueData,
                Name       => 'AssignedQueueIDs',
                Multiple   => 1,
                Size       => ( $QueueSize < 3 ) ? 3 : $QueueSize,
                SelectedID => \@NewQueueIDs,
                Class      => 'Modernize',
            );

            my $QueueIndex = 0;
            for my $QueueID (@NewQueueIDs) {
                $Param{SelQueuesArray} .= 'arrSelQueues[' . $QueueIndex . '] = "' . $QueueID . '";';
                $QueueIndex++;
            }

            my $TypeSize = ( scalar keys %TicketTypeData < 10 ) ? keys %TicketTypeData : 10;
            $Param{TicketTypeTextModuleStrg} = $LayoutObject->BuildSelection(
                Data        => \%TicketTypeData,
                Name        => 'AssignedTicketTypeIDs',
                Multiple    => 1,
                Size        => ( $TypeSize < 3 ) ? 3 : $TypeSize,
                SelectedID  => \@NewTicketTypeIDs,
                Disabled    => !$ConfigObject->Get('Ticket::Type'),
                Translation => 0,
                Class       => 'Modernize',
            );

            # build Language string
            $Param{LanguageEditOption} = $LayoutObject->BuildSelection(
                Data       => \%LanguageHash,
                Name       => 'LanguageEdit',
                HTMLQuote  => 0,
                SelectedID => $GetParam{LanguageEdit}
                    || $Self->{UserLanguage}
                    || '',
                Class => 'Modernize',
            );

            # output backlink
            $LayoutObject->Block(
                Name => 'ActionOverview',
                Data => \%Param,
            );

            # output hint
            $LayoutObject->Block(
                Name => 'Hint',
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

            # add rich text editor
            if ( $ConfigObject->Get('Frontend::RichText') ) {
                $LayoutObject->Block(
                    Name => 'RichText',
                    Data => {
                        %GetParam,
                        %Param,
                    },
                );
            }

            # add ticket type selection
            if ( $ConfigObject->Get('Ticket::Type') ) {
                $LayoutObject->Block(
                    Name => 'EditTicketType',
                    Data => {
                        %GetParam,
                        %Param,
                    },
                );
            }

            # generate output
            $Output .= $LayoutObject->Output(
                TemplateFile => 'AdminTextModules',
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
    elsif ( defined $Self->{Subaction} && $Self->{Subaction} eq 'Delete' && $GetParam{ID} ) {
        my $DeleteResult = $TextModuleObject->TextModuleDelete(
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
    elsif ( defined $Self->{Subaction} && $Self->{Subaction} eq 'Upload' && $GetParam{FormID} ) {

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

                    if ( !$InQuote && ( $Char eq ';' || $Char eq "\n" ) && $OldChar eq ';' ) {
                        $PreparedContent .= '""';
                    }
                    elsif (
                        !$InQuote
                        && $Char    ne ';'
                        && $Char    ne '"'
                        && $Char    ne "\n"
                        && $Char    ne "\r"
                        && $OldChar ne '"'
                        )
                    {
                        $PreparedContent .= '"';
                        $InQuote    = 1;
                        $AddedQuote = 1;
                    }
                    elsif (
                        $InQuote
                        && $AddedQuote
                        && ( $Char eq "\n" || $Char eq "\r" || $Char eq ';' )
                        )
                    {
                        $PreparedContent .= '"';
                        $InQuote    = 0;
                        $AddedQuote = 0;
                    }
                    $PreparedContent .= $Char;
                    $OldChar = $Char;
                }

                $PreparedContent =~ s/^;/"";/gm;
                $PreparedContent =~ s/;[^"]\r+$/;""/gms;
                $UploadStuff{Content} = $PreparedContent;
            }

            #start the update process...
            if ( !$Param{UploadMessage} && $UploadStuff{Content} ) {

                %UploadResult = %{
                    $TextModuleObject->TextModulesImport(
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
                    $DownloadFileName =~ s/\..*?$//g;
                    $DownloadFileName .= "_ImportResult_$TimeString.xml";

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
                        = $UploadStuff{Filename} . ' successful loaded.<br /><br />';
                }
            }
        }
        else {
            $Param{UploadMessage} = 'Import failed - No file uploaded/received. <br /><br />';
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
    elsif (
        defined $Self->{Subaction}
        && $Self->{Subaction} eq 'DownloadResult'
        && $GetParam{XMLResultFileID}
        )
    {
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

    elsif ( defined $Self->{Subaction} && $Self->{Subaction} eq 'Download' ) {

        my $Content = $TextModuleObject->TextModulesExport(
            Format    => $GetParam{DownloadType},
            Separator => $ImportExportConfig->{CSVSeparator},
        );
        my $ContentType = 'application/xml';
        my $FileType    = 'xml';

        # if download file as csv
        if ( $GetParam{DownloadType} eq 'CSV' ) {
            $ContentType = 'text/csv; charset=' . $LayoutObject->{UserCharset};
            $FileType    = 'csv';
        }

        my $TimeString = $TimeObject->SystemTime2TimeStamp(
            SystemTime => $TimeObject->SystemTime(),
        );
        $TimeString =~ s/\s/\_/g;
        my $FileName = 'TextModules_' . $TimeString . '.' . $FileType;

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

    my %TextModuleData = $TextModuleObject->TextModuleList(
        CategoryID  => $GetParam{SelectedCategoryID},
        Language    => $GetParam{Language} || '',
        Name        => $GetParam{Name} || '',
        Limit       => $GetParam{Limit},
        Result      => 'HASH',
        AdminSearch => 1
    );

    # output search block
    $LayoutObject->Block(
        Name => 'TextModuleSearch',

        # Data => \%Param,
        Data => { %Param, %GetParam },
    );

    # output category tree
    $LayoutObject->Block(
        Name => 'TextModuleCategoryTree',
        Data => \%Param,
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
    if ( defined $Self->{Subaction} && $Self->{Subaction} ne 'Upload' ) {

        $LayoutObject->Block(
            Name => 'Upload',
            Data => {
                UploadType => $ImportExportConfig->{FileType},
                %Param,
                }
        );
    }
    $Param{Count} = scalar keys %TextModuleData;
    $Param{CountNote} =
        ( $GetParam{Limit} && $Param{Count} == $GetParam{Limit} ) ? '(limited)' : '';

    $Param{SelectedCategoryName} = $Categories{ $GetParam{SelectedCategoryID} }
        || $LayoutObject->{LanguageObject}->Translate('ALL');

    $LayoutObject->Block(
        Name => 'OverviewList',
        Data => \%Param,
    );

    if ( $Param{Count} ) {
        my $Count = 0;
        for my $CurrHashID (
            sort { $TextModuleData{$a}->{Name} cmp $TextModuleData{$b}->{Name} }
            keys %TextModuleData
            )
        {
            $LayoutObject->Block(
                Name => 'OverviewListRow',
                Data => {
                    %{ $TextModuleData{$CurrHashID} },
                    Valid => $ValidHash{ $TextModuleData{$CurrHashID}->{ValidID} }
                    }
            );
            $Count++;
            last if $Count == $DefaultLimit;
        }
    }
    else {
        $LayoutObject->Block( Name => 'OverviewListEmpty' );
    }

    # generate output
    $Output .= $LayoutObject->Output(
        TemplateFile => 'AdminTextModules',
        Data         => \%Param,
    );
    $Output .= $LayoutObject->Footer();

    return $Output;
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
