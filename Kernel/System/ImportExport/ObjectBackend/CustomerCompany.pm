# --
# Kernel/System/ImportExport/ObjectBackend/CustomerCompany.pm
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# import/export backend for CustomerCompany
# written/edited by:
# * Anna(dot)Litvinova(at)cape(dash)it(dot)de
# * Torsten(dot)Thau(at)cape(dash)it(dot)de
# * Stefan(dot)Mehlig(at)cape(dash)it(dot)de
# * Ralf(dot)Boehm(at)cape(dash)it(dot)de
# * Thomas(dot)Lange(at)cape(dash)it(dot)de
# * Frank(dot)Jacquemin(at)cape(dash)it(dot)de
# --
# $Id$
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/gpl-2.0.txt.
# --

package Kernel::System::ImportExport::ObjectBackend::CustomerCompany;

use strict;
use warnings;
use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::System::ImportExport',
    'Kernel::System::CustomerCompany',
    'Kernel::System::Log',
    'Kernel::Config'
);

=head1 NAME

Kernel::System::ImportExport::ObjectBackend::CustomerCompany - import/export backend for CustomerUser

=head1 SYNOPSIS

All functions to import and export CustomerCompany entries

=over 4

=cut

=item new()

create an object

    use Kernel::Config;
    use Kernel::System::DB;
    use Kernel::System::Log;
    use Kernel::System::Main;
    use Kernel::System::ImportExport::ObjectBackend::CustomerCompany;

    my $ConfigObject = Kernel::Config->new();
    my $LogObject = Kernel::System::Log->new(
        ConfigObject => $ConfigObject,
    );
    my $MainObject = Kernel::System::Main->new(
        ConfigObject => $ConfigObject,
        LogObject    => $LogObject,
    );
    my $DBObject = Kernel::System::DB->new(
        ConfigObject => $ConfigObject,
        LogObject    => $LogObject,
        MainObject   => $MainObject,
    );
    my $BackendObject = Kernel::System::ImportExport::ObjectBackend::CustomerCompany->new(
        ConfigObject       => $ConfigObject,
        LogObject          => $LogObject,
        DBObject           => $DBObject,
        MainObject         => $MainObject,
        ImportExportObject => $ImportExportObject,
    );

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # define available separators
    $Self->{AvailableSeparators} = {
        Tabulator => "\t",
        Semicolon => ';',
        Colon     => ':',
        Dot       => '.',
        Comma     => ',',
    };

    return $Self;
}

=item ObjectAttributesGet()

get the object attributes of an object as array/hash reference

    my $Attributes = $ObjectBackend->ObjectAttributesGet(
        UserID => 1,
    );

=cut

sub ObjectAttributesGet {
    my ( $Self, %Param ) = @_;

    # check needed object
    if ( !$Param{UserID} ) {
        $Kernel::OM->Get('Kernel::System::Log')
            ->Log( Priority => 'error', Message => 'Need UserID!' );
        return;
    }

    my %Validlist = $Kernel::OM->Get('Kernel::System::Valid')->ValidList();

    my $Attributes = [
        {
            Key   => 'DefaultValid',
            Name  => 'Default Validity',
            Input => {
                Type         => 'Selection',
                Data         => \%Validlist,
                Required     => 1,
                Translation  => 1,
                PossibleNone => 0,
                ValueDefault => 1,
            },
        },
        {
            Key   => 'CountMax',
            Name  => 'Maximum number of one element',
            Input => {
                Type         => 'Text',
                ValueDefault => '10',
                Required     => 1,
                Regex        => qr{ \A \d+ \z }xms,
                Translation  => 0,
                Size         => 5,
                MaxLength    => 5,
                DataType     => 'IntegerBiggerThanZero',
            },
        },
        {
            Key   => 'EmptyFieldsLeaveTheOldValues',
            Name  => 'Empty fields indicate that the current values are kept',
            Input => {
                Type => 'Checkbox',
            },
        },
                {
            Key   => 'ArrayFormatAs',
            Name  => 'Array convert to',
            Input => {
                Type => 'Selection',
                Data => {
                    String      => 'String',
                    Splitting   => 'Split',
                },
                Translation  => 1,
                PossibleNone => 1,
                ValueDefault => 'String',
            },
        },
        {
            Key   => 'ArraySeparator',
            Name  => 'Array Separator by useing format string',
            Input => {
                Type => 'Selection',
                Data => {
                    Semicolon => 'Semicolon (;)',
                    Colon     => 'Colon (:)',
                    Dot       => 'Dot (.)',
                    Comma     => 'Comma (,)',
                },
                Translation  => 1,
                PossibleNone => 1,
                ValueDefault => 'Comma',
            },
        },
    ];

    return $Attributes;
}

=item MappingObjectAttributesGet()

get the mapping attributes of an object as array/hash reference

    my $Attributes = $ObjectBackend->MappingObjectAttributesGet(
        TemplateID => 123,
        UserID     => 1,
    );

=cut

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

    my @ElementList = qw{};
    $Self->{CustomerCompanyKey}
        = $Kernel::OM->Get('Kernel::Config')->Get('CustomerCompany')->{CustomerCompanyKey}
        || $Kernel::OM->Get('Kernel::Config')->Get('CustomerCompany')->{Key}
        || die "Need CustomerCompany->CustomerCompanyKey in Kernel/Config.pm!";
    $Self->{CustomerCompanyMap} = $Kernel::OM->Get('Kernel::Config')->Get('CustomerCompany')->{Map}
        || die "Need CustomerCompany->Map in Kernel/Config.pm!";

    for my $CurrAttributeMapping ( @{ $Self->{CustomerCompanyMap} } ) {
        my $CurrAttribute = {
            Key   => $CurrAttributeMapping->[0],
            Value => $CurrAttributeMapping->[0],
        };

        # if ValidID is available - offer Valid instead..
        if ( $CurrAttributeMapping->[0] eq 'ValidID' ) {
            $CurrAttribute = { Key => 'Valid', Value => 'Validity', };
        }

        push( @ElementList, $CurrAttribute );
    }

    my $DynamicFieldObject        = $Kernel::OM->Get('Kernel::System::DynamicField');
    my $DynamicFieldList = $DynamicFieldObject->DynamicFieldListGet(ObjectType => 'CustomerCompany');
    DYNAMICFIELD:
    for my $DynamicFieldConfig ( @{$DynamicFieldList} ) {
            # validate each dynamic field
            next DYNAMICFIELD if !$DynamicFieldConfig;
            next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);
            next DYNAMICFIELD if !$DynamicFieldConfig->{Name};
            
            if( $DynamicFieldConfig->{FieldType} eq 'Multiselect' ){
                for my $Count ( 1 .. $ObjectData->{CountMax}){
                    my $CurrAttribute = {
                        Key   => "DynamicField_".$DynamicFieldConfig->{'Name'}.'::'.$Count,
                        Value => $DynamicFieldConfig->{'Label'}.'::'.$Count,
                    };
                    push( @ElementList, $CurrAttribute );
                }
            }else{
                my $CurrAttribute = {
                    Key   => "DynamicField_".$DynamicFieldConfig->{'Name'},
                    Value => $DynamicFieldConfig->{'Label'},
                };
                push( @ElementList, $CurrAttribute );
            }
    }

    my $Attributes = [
        {
            Key   => 'Key',
            Name  => 'Key',
            Input => {
                Type         => 'Selection',
                Data         => \@ElementList,
                Required     => 1,
                Translation  => 0,
                PossibleNone => 1,
            },
        },

        # It doesn't make sense to configure and set the identifier:
        # CustomerID is used to search for existing enrties anyway!
        # (See sub ImportDataSave)
        #        {
        #            Key   => 'Identifier',
        #            Name  => 'Identifier',
        #            Input => { Type => 'Checkbox', },
        #        },
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

    # get object data
    my $ObjectData = $Kernel::OM->Get('Kernel::System::ImportExport')->ObjectDataGet(
        TemplateID => $Param{TemplateID},
        UserID     => $Param{UserID},
    );

    return;
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

    # list customer companys...
    my %CustomerCompanyList
        = $Kernel::OM->Get('Kernel::System::CustomerCompany')->CustomerCompanyList(
            Valid => 0,
        );
    my @ExportData;

    for my $CurrCompany (%CustomerCompanyList) {

        my %CustomerCompanyData =
            $Kernel::OM->Get('Kernel::System::CustomerCompany')->CustomerCompanyGet( 
                CustomerID => $CurrCompany, 
                # KIXContact - add dynamic fields
                DynamicFields => 1,
                # EO KIXContact - add dynamic fields
            );

        if (%CustomerCompanyData) {
            my @CurrRow;

            # prepare validity...
            if ( $CustomerCompanyData{ValidID} ) {
                $CustomerCompanyData{Valid}
                    = $Kernel::OM->Get('Kernel::System::Valid')->ValidLookup(
                    ValidID => $CustomerCompanyData{ValidID},
                    );
            }

            for my $MappingObject (@MappingObjectList) {
                my @Keys = split('::', $MappingObject->{Key});
                my $CCData = '';
                if ( !$Keys[0] ) {
                    push @CurrRow, '';
                }
                else {
                    if($Keys[0] =~ m/DynamicField_/){
                        if(defined $Keys[1]){
                            # If used array format string
                            if( $ObjectData->{ArrayFormatAs} eq 'String' ){
                                if(ref($CustomerCompanyData{$Keys[0]}) eq 'ARRAY'){
                                    # convert array to string with selected separator
                                    $CCData = join ("$Self->{AvailableSeparators}->{$ObjectData->{ArraySeparator}}", @{$CustomerCompanyData{$Keys[0]}} );
                                }else{
                                    $CCData = $CustomerCompanyData{$Keys[0]};
                                }
                            # if used array format split
                            }elsif ( $ObjectData->{ArrayFormatAs} eq 'Split' ){
                                # splited array to single elements
                                $CCData = $CustomerCompanyData{$Keys[0]}->[($Keys[1]-1)];
                            }
                        }else{
                            $CCData = $CustomerCompanyData{$Keys[0]};
                        }
                        push( @CurrRow, $CCData || '' );
                    }else{
                        push( @CurrRow, $CustomerCompanyData{$Keys[0]} || '' );
                    }
                }
            }
            push @ExportData, \@CurrRow;
        }
    }

    return \@ExportData;
}

=item ImportDataSave()

import one row of the import data

    my $ConfigItemID = $ObjectBackend->ImportDataSave(
        TemplateID    => 123,
        ImportDataRow => $ArrayReConfigf,
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
    #    my @MappingObjectList;
    #    my %Identifier;
    #    my $CustomerCompanyKey     = "";

    my $Counter                = 0;
    my %NewCustomerCompanyData = qw{};

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

        #        push( @MappingObjectList, $MappingObjectData );

        # TO DO: It doesn't make sense to configure and set the identifier:
        # CustomerID is used to search for existing enrties anyway!
        #
        #  See lines 529-530:
        #  my %CustomerCompanyData = $Self->{CustomerCompanyObject}
        #        ->CustomerCompanyGet( CustomerID => $NewCustomerCompanyData{CustomerID} );

        #        if (
        #            $MappingObjectData->{Identifier}
        #            && $Identifier{ $MappingObjectData->{Key} }
        #            )
        #        {
        #            $Self->{LogObject}->Log(
        #                Priority => 'error',
        #                Message  => "Can't import this entity. "
        #                    . "'$MappingObjectData->{Key}' has been used multiple "
        #                    . "times as identifier (line $Param{Counter}).!",
        #            );
        #        }
        #        elsif ( $MappingObjectData->{Identifier} ) {
        #            $Identifier{ $MappingObjectData->{Key} } =
        #                $Param{ImportDataRow}->[$Counter];
        #            $CustomerCompanyKey = $MappingObjectData->{Key};
        #        }

        if ( $MappingObjectData->{Key} ne "CustomerCompanyCountry" ) {
            my @Keys = split('::',$MappingObjectData->{Key});

            # Check if key dynamic field
            if($Keys[0] =~ m/DynamicField_/){
                if(defined $Keys[1]){

                    # if used convert array to string
                    if( $ObjectData->{ArrayFormatAs} eq 'String' ){
                        my @StringToArray = split ("$Self->{AvailableSeparators}->{$ObjectData->{ArraySeparator}}", $Param{ImportDataRow}->[$Counter] );

                        # Check is Array defined
                        if( @StringToArray ){
                            if( ref($NewCustomerCompanyData{ $Keys[0] }) eq 'ARRAY'){

                                # Check exists element in main array
                                ITEM:
                                for my $Item ( @StringToArray ){
                                    next ITEM if grep { $_ eq $Item; } @{ $NewCustomerCompanyData{ $Keys[0] } };
                                    push( @{ $NewCustomerCompanyData{ $Keys[0] } }, $Item);
                                }
                            }else{
                                push( @{ $NewCustomerCompanyData{ $Keys[0] } }, @StringToArray);
                            }
                        }else{
                            if( ref($NewCustomerCompanyData{ $Keys[0] }) ne 'ARRAY'){
                                if( !$ObjectData->{EmptyFieldsLeaveTheOldValues} ) {
                                    $NewCustomerCompanyData{ $Keys[0] } = '';
                                }
                            }
                        }

                    # if used convert array to single elements
                    }elsif ( $ObjectData->{ArrayFormatAs} eq 'Split' ){
                        if($Param{ImportDataRow}->[$Counter]){
                            push( @{ $NewCustomerCompanyData{ $Keys[0] } }, $Param{ImportDataRow}->[$Counter]);
                        }else{
                            # if checked ignore empty value
                            if( !$ObjectData->{EmptyFieldsLeaveTheOldValues}
                                && !$NewCustomerCompanyData{ $Keys[0] } )
                            {
                                $NewCustomerCompanyData{ $Keys[0] } = '';
                            }
                        }
                    }
                }else{
                    # if checked ignore empty value
                    if( !$ObjectData->{EmptyFieldsLeaveTheOldValues}
                        || IsStringWithData($Param{ImportDataRow}->[$Counter]))
                    {
                        $NewCustomerCompanyData{ $MappingObjectData->{Key} } =
                            $Param{ImportDataRow}->[$Counter];
                    }
                }
            }else{
                # if checked ignore empty value
                if( !$ObjectData->{EmptyFieldsLeaveTheOldValues}
                    || IsStringWithData($Param{ImportDataRow}->[$Counter]))
                {
                    $NewCustomerCompanyData{ $MappingObjectData->{Key} } =
                        $Param{ImportDataRow}->[$Counter];
                }
            }
        }
        else {
            # Sanitize country if it isn't found in OTRS to increase the chance it will
            # Note that standardizing against the ISO 3166-1 list might be a better approach...
            my $CountryList = $Kernel::OM->Get('Kernel::System::ReferenceData')->CountryList();
            if ( exists $CountryList->{ $Param{ImportDataRow}->[$Counter] } ) {
                $NewCustomerCompanyData{ $MappingObjectData->{Key} }
                    = $Param{ImportDataRow}->[$Counter];
            }
            else {
                $NewCustomerCompanyData{ $MappingObjectData->{Key} } =
                    join( '', map { ucfirst lc } split /(\s+)/, $Param{ImportDataRow}->[$Counter] );
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'notice',
                    Message  => "Country '$Param{ImportDataRow}->[$Counter]' "
                        . "not found - save as '$NewCustomerCompanyData{ $MappingObjectData->{Key} }'.",
                );
            }
        }
        $Counter++;

    }

    #--------------------------------------------------------------------------
    #DO THE IMPORT...

    #(1) Preprocess data...

    # lookup Valid-ID...
    if ( !$NewCustomerCompanyData{ValidID} && $NewCustomerCompanyData{Valid} ) {
        $NewCustomerCompanyData{ValidID} = $Kernel::OM->Get('Kernel::System::Valid')->ValidLookup(
            Valid => $NewCustomerCompanyData{Valid}
        );
    }
    if ( !$NewCustomerCompanyData{ValidID} ) {
        $NewCustomerCompanyData{ValidID} = $ObjectData->{DefaultValid} || 1;
    }

    #(1) lookup company entry...
    my %CustomerCompanyData = $Kernel::OM->Get('Kernel::System::CustomerCompany')
        ->CustomerCompanyGet( CustomerID => $NewCustomerCompanyData{CustomerID} );

    my $NewCompany = 1;
    if (%CustomerCompanyData) {
        $NewCompany = 0;
    }

    for my $Key ( keys(%NewCustomerCompanyData) ) {
        next if ( !$NewCustomerCompanyData{$Key} );
        $CustomerCompanyData{$Key} = $NewCustomerCompanyData{$Key};
    }

    #(2) if company DOES NOT exist => create new entry...
    my $Result     = 0;
    my $ReturnCode = "";    # Created | Changed | Failed

    if ($NewCompany) {
        $Result = $Kernel::OM->Get('Kernel::System::CustomerCompany')->CustomerCompanyAdd(
            %CustomerCompanyData,
            UserID => $Param{UserID},
        );

        if ( !$Result ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "ImportDataSave: adding CustomerCompany ("
                    . "CustomerID "
                    . $CustomerCompanyData{CustomerID}
                    . ") failed (line $Param{Counter}).",
            );
        }
        else {
            $ReturnCode = "Created";
        }
    }

    #(3) if company DOES exist => check update...
    else {
        $Result = $Kernel::OM->Get('Kernel::System::CustomerCompany')->CustomerCompanyUpdate(
            %CustomerCompanyData,
            UserID => $Param{UserID},
        );

        if ( !$Result ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "ImportDataSave: updating CustomerCompany ("
                    . "CustomerID "
                    . $CustomerCompanyData{CustomerID}
                    . ") failed (line $Param{Counter}).",
            );
        }
        else {
            $ReturnCode = "Changed";
        }
    }

    #
    #--------------------------------------------------------------------------

    return ( $Result, $ReturnCode );
}

1;
