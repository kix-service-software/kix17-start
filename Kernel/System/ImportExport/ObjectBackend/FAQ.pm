# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::ImportExport::ObjectBackend::FAQ;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::HTMLUtils',
    'Kernel::System::Time',
    'Kernel::System::CSV',
    'Kernel::System::User',
    'Kernel::System::Group',
    'Kernel::System::FAQ',
    'Kernel::Config'
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );


    return $Self;

}

sub ObjectAttributesGet {
    my ( $Self, %Param ) = @_;

    # check needed object
    if ( !$Param{UserID} ) {
        $Kernel::OM->Get('Kernel::System::Log')
            ->Log( Priority => 'error', Message => 'Need UserID!' );
        return;
    }
    my $CategoryTreeListRef = $Kernel::OM->Get('Kernel::System::FAQ')->CategoryTreeList(
        Valid  => 0,
        UserID => 1,
    );

    my %CategoryList = %{$CategoryTreeListRef};
    my %StateList    = $Kernel::OM->Get('Kernel::System::FAQ')->StateList( UserID => 1, );
    my %LanguageList = $Kernel::OM->Get('Kernel::System::FAQ')->LanguageList( UserID => 1, );
    my %GroupList    = $Kernel::OM->Get('Kernel::System::Group')->GroupList();
    my %FormatList   = ( "plain" => "PlainText", "html" => "HTML" );

    my $Attributes = [
        {
            Key   => 'DefaultGroupID',
            Name  => 'Default group for new category',
            Input => {
                Type         => 'Selection',
                Data         => \%GroupList,
                Required     => 1,
                Translation  => 0,
                PossibleNone => 0,
            },
        },

        {
            Key   => 'DefaultCategoryID',
            Name  => 'Default Category (if empty/invalid)',
            Input => {
                Type         => 'Selection',
                Data         => \%CategoryList,
                Required     => 0,
                Translation  => 1,
                PossibleNone => 1,
            },
        },
        {
            Key   => 'DefaultLanguageID',
            Name  => 'Default Language (if empty/invalid)',
            Input => {
                Type         => 'Selection',
                Data         => \%LanguageList,
                Required     => 0,
                Translation  => 1,
                PossibleNone => 1,
            },
        },
        {
            Key   => 'DefaultStateID',
            Name  => 'Default State (if empty/invalid)',
            Input => {
                Type         => 'Selection',
                Data         => \%StateList,
                Required     => 0,
                Translation  => 1,
                PossibleNone => 1,
            },
        },
        {
            Key   => 'Format',
            Name  => 'Format',
            Input => {
                Type         => 'Selection',
                Data         => \%FormatList,
                Required     => 1,
                Translation  => 1,
                PossibleNone => 0,
            },
        },
    ];

    return $Attributes;
}

sub MappingObjectAttributesGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(TemplateID UserID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # get object data
    my $ObjectData = $Kernel::OM->Get('Kernel::System::ImportExport')->ObjectDataGet(
        TemplateID => $Param{TemplateID},
        UserID     => $Param{UserID},
    );
    my $ElementList = [
        {
            Key   => 'Number',
            Value => 'Number',
        },
        {
            Key   => 'Title',
            Value => 'Title',
        },
        {
            Key   => 'Category',
            Value => 'Category',
        },

        # Not required yet, because of not implemented part
        # for update existing category in function _CheckCategory
        #        {
        #           Key   => 'CategoryID',
        #            Value => 'CategoryID',
        #        },
        {
            Key   => 'State',
            Value => 'State',
        },
        {
            Key   => 'Approved',
            Value => 'Approved',
        },
        {
            Key   => 'Language',
            Value => 'Language',
        },
        {
            Key   => 'Field1',
            Value => 'Field1',
        },
        {
            Key   => 'Field2',
            Value => 'Field2',
        },
        {
            Key   => 'Field3',
            Value => 'Field3',
        },
        {
            Key   => 'Field4',
            Value => 'Field4',
        },
        {
            Key   => 'Field5',
            Value => 'Field5',
        },
        {
            Key   => 'Field6',
            Value => 'Field6',
        },
        {
            Key   => 'Keywords',
            Value => 'Keywords',
        },
    ];

    my $Attributes = [
        {
            Key   => 'Key',
            Name  => 'Key',
            Input => {
                Type         => 'Selection',
                Data         => $ElementList,
                Required     => 1,
                Translation  => 1,
                PossibleNone => 1,
            },
        },
        {
            Key   => 'Identifier',
            Name  => 'Identifier',
            Input => { Type => 'Checkbox', },
        },
    ];

    return $Attributes;
}

=item SearchAttributesGet()

get the search object attributes of an object as array/hash reference

    my $AttributeList = $ObjectBackend->SearchAttributesGet(
        TemplateID => 123,
        UserID     => 1,
    );

=cut

sub SearchAttributesGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(TemplateID UserID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    my $AttributeList = [

        #        {
        #            Key   => 'FAQTitle',
        #            Name  => 'Title',
        #            Input => {
        #                Type      => 'Text',
        #                Size      => 80,
        #                MaxLength => 255,
        #            },
        #        },
        {
            Key   => 'Limit',
            Name  => 'Limit',
            Input => {
                Type      => 'Text',
                Size      => 80,
                MaxLength => 80,
            },
        },
    ];

    return $AttributeList;
}

=item ExportDataGet()

get export data as 2D-array-hash reference

    my $ExportData = $ObjectBackend->ExportDataGet(
        TemplateID => 123,
        UserID     => 1,
    );

=cut

sub ExportDataGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(TemplateID UserID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # get object data
    my $ObjectData = $Kernel::OM->Get('Kernel::System::ImportExport')->ObjectDataGet(
        TemplateID => $Param{TemplateID},
        UserID     => $Param{UserID},
    );

    # check object data
    if ( !$ObjectData || ref $ObjectData ne 'HASH' ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "No object data found for the template id $Param{TemplateID}",
        );
        return;
    }

    # get the mapping list
    my $MappingList = $Kernel::OM->Get('Kernel::System::ImportExport')->MappingList(
        TemplateID => $Param{TemplateID},
        UserID     => $Param{UserID},
    );

    # check the mapping list
    if ( !$MappingList || ref $MappingList ne 'ARRAY' || !@{$MappingList} ) {

        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "No valid mapping list found for the template id $Param{TemplateID}",
        );
        return;
    }

    # create the mapping object list
    my @MappingObjectList;
    for my $MappingID ( @{$MappingList} ) {

        # get mapping object data
        my $MappingObjectData =
            $Kernel::OM->Get('Kernel::System::ImportExport')->MappingObjectDataGet(
            MappingID => $MappingID,
            UserID    => $Param{UserID},
            );

        # check mapping object data
        if ( !$MappingObjectData || ref $MappingObjectData ne 'HASH' ) {

            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "No valid mapping list found for the template id $Param{TemplateID}",
            );
            return;
        }

        push( @MappingObjectList, $MappingObjectData );
    }

    # get search data
    my $SearchData = $Kernel::OM->Get('Kernel::System::ImportExport')->SearchDataGet(
        TemplateID => $Param{TemplateID},
        UserID     => $Param{UserID},
    );

    if ( $SearchData && ref($SearchData) ne 'HASH' ) {
        $SearchData = 0;
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message =>
                "FAQ2CustomerUser: search data is not a hash ref - ignoring search limitation.",
        );
    }

    my @FAQList = $Kernel::OM->Get('Kernel::System::FAQ')->FAQSearch(
        Title => $SearchData->{FAQTitle} || '*',
        Limit => $SearchData->{Limit}    || '100000',
        UserID => 1,
    );

    # export data...
    my @ExportData;

    # exported FAQs should be sorted by IDs ascendant, otherwise import problems:
    # If "Number" is configured as identifier, some of just created FAQs
    # will be found as already existent and updated,
    # instead of creating new entries
    for my $FAQID ( sort { $a <=> $b } @FAQList ) {

        my %FAQData = $Kernel::OM->Get('Kernel::System::FAQ')->FAQGet(
            FAQID      => $FAQID,
            UserID     => 1,        # no permission restriction for this export
            ItemFields => 1,
        );

        #-----------------------------------------------------------------------
        # PREPARE DATA...

        $FAQData{Approved} = $FAQData{Approved} ? "yes" : "no";

        my %LanguageList = $Kernel::OM->Get('Kernel::System::FAQ')->LanguageList( UserID => 1, );
        $FAQData{Language} = $LanguageList{ $FAQData{LanguageID} };

        my %StateList = $Kernel::OM->Get('Kernel::System::FAQ')->StateList( UserID => 1, );
        $FAQData{State} = $StateList{ $FAQData{StateID} };

        # build full category name...
        my @NamePartsArray = qw{};
        my $ParentID       = $FAQData{CategoryID};
        while ($ParentID) {
            my %CurrCategoryData = $Kernel::OM->Get('Kernel::System::FAQ')->CategoryGet(
                CategoryID => $ParentID,
                UserID     => 1,
            );
            unshift( @NamePartsArray, $CurrCategoryData{Name} );
            $ParentID = $CurrCategoryData{ParentID};

        }
        $FAQData{Category} = join( "::", @NamePartsArray );

        #-----------------------------------------------------------------------
        # EXPORT DATA...
        my @CurrRow = qw{};
        for my $MappingObject (@MappingObjectList) {
            my $Key = $MappingObject->{Key};

            if ( $Key && $FAQData{$Key} ) {
                if ( $ObjectData->{Format} && $ObjectData->{Format} eq "plain" ) {
                    $FAQData{$Key} =~ s/<xml>.*?<\/xml>//segxmi;
                    $FAQData{$Key} =~ s/<style>.*?<\/style>//segxmi;
                    $FAQData{$Key} =
                        $Kernel::OM->Get('Kernel::System::HTMLUtils')->ToAscii( "String" => $FAQData{$Key} );
                }
                push( @CurrRow, $FAQData{$Key} );
            }
            else {
                push( @CurrRow, '-' );
            }
        }

        push @ExportData, \@CurrRow;

    }

    return \@ExportData;
}

=item ImportDataSave()

import one row of the import data

    my $ConfigItemID = $ObjectBackend->ImportDataSave(
        TemplateID    => 123,
        ImportDataRow => $ArrayRef,
        UserID        => 1,
    );

=cut

sub ImportDataSave {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(TemplateID ImportDataRow UserID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return ( undef, 'Failed' );
        }
    }

    # check import data row
    if ( ref $Param{ImportDataRow} ne 'ARRAY' ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'ImportDataRow must be an array reference',
        );
        return ( undef, 'Failed' );
    }

    # get object data
    my $ObjectData = $Kernel::OM->Get('Kernel::System::ImportExport')->ObjectDataGet(
        TemplateID => $Param{TemplateID},
        UserID     => $Param{UserID},
    );

    # check object data
    if ( !$ObjectData || ref $ObjectData ne 'HASH' ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "No object data found for the template id $Param{TemplateID}",
        );
        return ( undef, 'Failed' );
    }

    # get the mapping list
    my $MappingList = $Kernel::OM->Get('Kernel::System::ImportExport')->MappingList(
        TemplateID => $Param{TemplateID},
        UserID     => $Param{UserID},
    );

    # check the mapping list
    if ( !$MappingList || ref $MappingList ne 'ARRAY' || !@{$MappingList} ) {

        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "No valid mapping list found for the template id $Param{TemplateID}",
        );
        return ( undef, 'Failed' );
    }

    # create the mapping object list
    my @MappingObjectList;
    my %Identifier;
    my $Counter = 0;
    my %NewFAQData;
    my $FAQIdentifierKey = "";

    #--------------------------------------------------------------------------
    #BUILD MAPPING TABLE...
    my $IsHeadline = 1;
    for my $MappingID ( @{$MappingList} ) {

        # get mapping object data
        my $MappingObjectData =
            $Kernel::OM->Get('Kernel::System::ImportExport')->MappingObjectDataGet(
            MappingID => $MappingID,
            UserID    => $Param{UserID},
            );

        # check mapping object data
        if ( !$MappingObjectData || ref $MappingObjectData ne 'HASH' ) {

            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "No valid mapping list found for template id $Param{TemplateID}",
            );
            return ( undef, 'Failed' );
        }

        push( @MappingObjectList, $MappingObjectData );

        if (
            $MappingObjectData->{Identifier}
            && $Identifier{ $MappingObjectData->{Key} }
            )
        {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Can't import this entity. "
                    . "'$MappingObjectData->{Key}' has been used multiple "
                    . "times as identifier (line $Param{Counter}).!",
            );
        }
        elsif ( $MappingObjectData->{Identifier} ) {
            $Identifier{ $MappingObjectData->{Key} } =
                $Param{ImportDataRow}->[$Counter];
            $FAQIdentifierKey = $MappingObjectData->{Key};
        }

        if ( $ObjectData->{Format} && $ObjectData->{Format} eq "plain" ) {
            $NewFAQData{ $MappingObjectData->{Key} } =
                $Kernel::OM->Get('Kernel::System::HTMLUtils')->ToHTML( "String" => $Param{ImportDataRow}->[$Counter] );
        }
        else {
            $NewFAQData{ $MappingObjectData->{Key} } = $Param{ImportDataRow}->[$Counter];
        }

        if ( $MappingObjectData->{Key} ne $Param{ImportDataRow}->[$Counter] ) {
            $IsHeadline = 0;
        }

        $Counter++;
    }

    if ( $IsHeadline && $Param{Counter} == 1 ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "ImportDataSave: line $Param{Counter} contains only "
                . "mapping keys names. It is likely that it is a headline. "
                . "Therefore this line will be skipped."

        );
        return ( 1, "Headline" );
    }

    #--------------------------------------------------------------------------
    # PREPARE DATA...

    # get all FAQ language ids
    my %LanguageList = $Kernel::OM->Get('Kernel::System::FAQ')->LanguageList( UserID => 1, );
    my %ReverseLanguageList = reverse( $Kernel::OM->Get('Kernel::System::FAQ')->LanguageList( UserID => 1, ) );

    # get all state type ids
    my %StateList = $Kernel::OM->Get('Kernel::System::FAQ')->StateList( UserID => 1, );
    my %ReverseStateList = reverse(%StateList);

    my $ItemID     = 0;
    my $ReturnCode = "";                           # Created | Changed | Failed
    my $FAQNumber  = $Param{ImportDataRow}->[0];

    # check approval-state...
    if ( !$Kernel::OM->Get('Kernel::Config')->Get('FAQ::ApprovalRequired') ) {
        $NewFAQData{Approved} = "1";
    }
    elsif ( $NewFAQData{Approved} && ( $NewFAQData{Approved} =~ /\D/ ) ) {
        ( $NewFAQData{Approved} eq 'yes' ) ? $NewFAQData{Approved} = "1" : $NewFAQData{Approved} =
            "0";
    }

    # check language
    if ( $NewFAQData{Language} && !$NewFAQData{LanguageID} ) {
        $NewFAQData{LanguageID} = $ReverseLanguageList{ $NewFAQData{Language} } || '';
    }
    if ( !$NewFAQData{LanguageID} ) {

        # set default language from mapping configuration...
        $NewFAQData{LanguageID} = $ObjectData->{DefaultLanguageID};
    }

    if ( !$NewFAQData{LanguageID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Can't import entity $Param{Counter}: "
                . "No language given or found!",
        );
        return ( undef, 'Failed' );
    }

    # check state
    if ( $NewFAQData{State} && !$NewFAQData{StateID} ) {
        $NewFAQData{StateID} = $ReverseStateList{ $NewFAQData{State} } || '';
    }
    if ( !$NewFAQData{StateID} ) {

        # set default state from mapping configuration...
        $NewFAQData{DefaultStateID} = $ObjectData->{DefaultStateID};
    }

    if ( !$NewFAQData{StateID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Can't import entity $Param{Counter}: "
                . "No state given or found!",
        );
        return ( undef, 'Failed' );
    }

    # check / create category structure...
    my $CategoryID = $Self->_CheckCategory(
        Counter        => $Param{Counter}                  || '',
        CategoryID     => $NewFAQData{CategoryID}          || '',
        Category       => $NewFAQData{Category}            || '',
        DefaultGroupID => $ObjectData->{DefaultCategoryID} || '',
    );

    if ( $NewFAQData{Category} && !$NewFAQData{CategoryID} ) {
        $NewFAQData{CategoryID} = $CategoryID || '';
    }
    elsif ( !$NewFAQData{Category} && !$NewFAQData{CategoryID} ) {

        # set default category from mapping configuration...
        $NewFAQData{CategoryID} = $ObjectData->{DefaultCategoryID};
    }

    if ( !$NewFAQData{CategoryID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Can't import entity $Param{Counter}: "
                . "No category given, created or found!",
        );
        return ( undef, 'Failed' );
    }

    #--------------------------------------------------------------------------
    # DO THE IMPORT...

    # TO DO: up to now some simplification - consider "Number" (and only number)
    # as identificator for existing entry (even though if not explicitly configured)
    # if given it is attempted to find an FAQ item and update it, otherwise a
    # new item is created, leaving a log message that the Number was not known

    # Simplification changed: If NOT explicitly configured,
    # the field "Number" will not be considered as identifier!
    # TO DO: somehow tell the user that only "Number" can be used as indentifier,
    # because other values are not unique

    # if "Number" is given and it is configured to be the indentifier
    # try to find the FAQ with the given number
    my $FAQID = 0;

    if ( $NewFAQData{Number} && $Identifier{Number} ) {
        my @FAQList = $Kernel::OM->Get('Kernel::System::FAQ')->FAQSearch(
            Number => $NewFAQData{Number} || '',
            Limit  => 1,
            UserID => 1,
        );

        # attribute Number should be uniqe, so just take first result into account...
        $FAQID = $FAQList[0] || '';

        #---------------------------------------------------------------------------
        # update existing FAQ entry...
        if ($FAQID) {

            my %FAQData = $Kernel::OM->Get('Kernel::System::FAQ')->FAQGet(
                FAQID      => $FAQID,
                UserID     => 1,
                ItemFields => 1,
            );

            $ItemID = $Kernel::OM->Get('Kernel::System::FAQ')->FAQUpdate(
                ItemID      => $FAQID,
                Title       => $NewFAQData{Title} || $FAQData{Title},
                CategoryID  => $NewFAQData{CategoryID} || $FAQData{CategoryID},
                StateID     => $NewFAQData{StateID} || $FAQData{StateID},
                Number      => $NewFAQData{Number} || $FAQData{Number},
                LanguageID  => $NewFAQData{LanguageID} || $FAQData{LanguageID},
                Field1      => $NewFAQData{Field1} || $FAQData{Field1},
                Field2      => $NewFAQData{Field2} || $FAQData{Field2},
                Field3      => $NewFAQData{Field3} || $FAQData{Field3},
                Field4      => $NewFAQData{Field4} || $FAQData{Field4},
                Field5      => $NewFAQData{Field5} || $FAQData{Field5},
                Field6      => $NewFAQData{Field6} || $FAQData{Keywords},
                Keywords    => $NewFAQData{Keywords} || $FAQData{Keywords},
                Approved    => $NewFAQData{Approved} || $FAQData{Approved},
                ContentType => $NewFAQData{ContentType} || 'text/html',
                UserID      => 1,
            );
            if ($ItemID) {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'notice',
                    Message  => "Updated entity '$FAQID' with data from line "
                        . "$Param{Counter}.",
                );
                $ReturnCode = "Changed";
            }
            else {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message  => "Could not update entity '$FAQID' with data from "
                        . "line $Param{Counter}.!",
                );
            }

        }
        else {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'notice',
                Message  => "FAQ item with number '$NewFAQData{Number}' does not"
                    . " exist. Treating line $Param{Counter} as if no attribute"
                    . " <Number> was given.",

            );
        }
    }

    #---------------------------------------------------------------------------
    # create new FAQ item...
    # if no FAQID was found (or it wasn't searched for)
    if ( !$FAQID ) {
        $ItemID = $Kernel::OM->Get('Kernel::System::FAQ')->FAQAdd(
            Title       => $NewFAQData{Title},
            CategoryID  => $NewFAQData{CategoryID},
            StateID     => $NewFAQData{StateID},
            LanguageID  => $NewFAQData{LanguageID},
            Field1      => $NewFAQData{Field1},
            Field2      => $NewFAQData{Field2},
            Field3      => $NewFAQData{Field3},
            Field4      => $NewFAQData{Field4},
            Field5      => $NewFAQData{Field5},
            Field6      => $NewFAQData{Field6},
            Keywords    => $NewFAQData{Keywords},
            Approved    => $NewFAQData{Approved} || 0,
            ContentType => $NewFAQData{ContentType} || 'text/html',
            UserID      => 1,
        );
        if ($ItemID) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'notice',
                Message  => "Added new FAQ entry with data from line $Param{Counter}.",
            );
            $ReturnCode = "Created";
        }
        else {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Could not add entity for line $Param{Counter}!",
            );
        }
    }

    return ( $ItemID, $ReturnCode );
}

sub _CheckCategory {
    my ( $Self, %Param ) = @_;
    my %Result   = ();
    my $ParentID = '0';

    # get group id for faq group
    my $DefaultFAQGroupID = $Param{DefaultGroupID};
    if ( !$DefaultFAQGroupID ) {
        $DefaultFAQGroupID = $Kernel::OM->Get('Kernel::System::Group')->GroupLookup(
            Group => 'faq',
        );
    }

    my @CategoryNamePartsArray = split( "::", $Param{Category} );

    my $CategoryHashRef = $Kernel::OM->Get('Kernel::System::FAQ')->CategoryList(
        UserID => 1,
    );

    # NOTE: $CategoryHash{<ParentID>}->{<ChildID>}->{Name}

    # find / create category (no ID, but full name given)...
    if ( !$Param{CategoryID} && $Param{Category} ) {
        for my $CurrNamePart (@CategoryNamePartsArray) {
            my $CurrSiblingsRef    = $CategoryHashRef->{$ParentID};
            my %ReverseSiblingList = ();
            if ( $CurrSiblingsRef && ref($CurrSiblingsRef) eq 'HASH' ) {

                # following works because the name's supposed to be unique in a category level...
                %ReverseSiblingList = reverse( %{$CurrSiblingsRef} );
            }

            # category for this level found...
            if ( $ReverseSiblingList{$CurrNamePart} ) {
                $ParentID = $ReverseSiblingList{$CurrNamePart};
            }

            # create category in this level...
            else {
                my $NewCategoryID = $Kernel::OM->Get('Kernel::System::FAQ')->CategoryAdd(
                    Name     => $CurrNamePart,
                    ParentID => $ParentID || '0',
                    Comment  => 'automatically created by FAQ-Import',
                    ValidID  => 1,
                    UserID   => 1,
                );
                $Kernel::OM->Get('Kernel::System::FAQ')->SetCategoryGroup(
                    CategoryID => $NewCategoryID,
                    GroupIDs   => [$DefaultFAQGroupID],
                    UserID     => 1,
                );
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'notice',
                    Message  => "New category '$CurrNamePart' (parent $ParentID)"
                        . " created from line $Param{Counter}.!",
                );

                # remember the new category...
                $CategoryHashRef->{$ParentID}->{$NewCategoryID} = $CurrNamePart;
                $ParentID = $NewCategoryID;
            }

        }
    }

    # update existing category (ID and full name given)...
    elsif ( $Param{CategoryID} && $Param{Category} ) {

        # TO DO: update a given category ID
        # IT SHOULD NOT BE IMPLEMENTED RIGHT NOW
        # BECAUSE OF FAR_REACHING CONSEQUENCES
        #
    }
    return $ParentID;
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
