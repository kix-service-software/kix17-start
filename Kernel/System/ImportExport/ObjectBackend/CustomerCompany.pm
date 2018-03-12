# --
# Modified version of the work: Copyright (C) 2006-2018 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2018 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::ImportExport::ObjectBackend::CustomerCompany;

use strict;
use warnings;
use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::CustomerCompany',
    'Kernel::System::ImportExport',
    'Kernel::System::Log',
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

    my %CSList    = $Kernel::OM->Get('Kernel::System::CustomerCompany')->CustomerCompanySourceList( ReadOnly => 0 );
    my %Validlist = $Kernel::OM->Get('Kernel::System::Valid')->ValidList();

    my $Attributes = [
        {
            Key   => 'CustomerCompanyBackend',
            Name  => 'Customer Company Backend',
            Input => {
                Type         => 'Selection',
                Data         => \%CSList,
                Required     => 1,
                Translation  => 0,
                PossibleNone => 0,
            },
        },
        {
            Key   => 'ForceImportInConfiguredCustomerCompanyBackend',
            Name  => 'Force import in configured customer company backend',
            Input => {
                Type => 'Selection',
                Data => {
                    '0' => 'No',
                    '1' => 'Yes',
                },
                Required     => 0,
                Translation  => 1,
                PossibleNone => 0,
                ValueDefault => 0,
            },
        },
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
            Key   => 'EmptyFieldsLeaveTheOldValues',
            Name  => 'Empty fields indicate that the current values are kept',
            Input => {
                Type => 'Checkbox',
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
    my @Map = @{ $Kernel::OM->Get('Kernel::Config')->{ $ObjectData->{CustomerCompanyBackend} }->{'Map'} };

    for my $CurrAttributeMapping (@Map) {
        my $CurrAttribute = {
            Key   => $CurrAttributeMapping->[0],
            Value => $CurrAttributeMapping->[0],
        };

        # if ValidID is available - offer Valid instead..
        if ( $CurrAttributeMapping->[0] eq 'ValidID' ) {
            $CurrAttribute = {
                Key   => 'ValidID',
                Value => 'ValidID (not used in import anymore, use Validity instead)',
            };
            push( @ElementList, $CurrAttribute );

            $CurrAttribute = { Key => 'Valid', Value => 'Validity', };
        }

        push( @ElementList, $CurrAttribute );

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
    my %CustomerCompanyList = $Kernel::OM->Get('Kernel::System::CustomerCompany')->CustomerCompanyList(
            Valid => 0,
        );
    my @ExportData;

    for my $CurrCompany (%CustomerCompanyList) {

        my %CustomerCompanyData = $Kernel::OM->Get('Kernel::System::CustomerCompany')->CustomerCompanyGet(
            CustomerID => $CurrCompany
        );

        if (
            $CustomerCompanyData{Source}
            && ( $CustomerCompanyData{Source} eq $ObjectData->{CustomerCompanyBackend} )
        ) {
            my @CurrRow;

            # prepare validity...
            if ( $CustomerCompanyData{ValidID} ) {
                $CustomerCompanyData{Valid} = $Kernel::OM->Get('Kernel::System::Valid')->ValidLookup(
                    ValidID => $CustomerCompanyData{ValidID},
                );
            }

            for my $MappingObject (@MappingObjectList) {
                my $Key = $MappingObject->{Key};
                if ( !$Key ) {
                    push @CurrRow, '';
                }
                else {
                    push( @CurrRow, $CustomerCompanyData{$Key} || '' );
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
    #    my @MappingObjectList;
    #    my %Identifier;
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
            $NewCustomerCompanyData{ $MappingObjectData->{Key} } =
                $Param{ImportDataRow}->[$Counter];
        }
        else {
            # Sanitize country if it isn't found in OTRS to increase the chance it will
            # Note that standardizing against the ISO 3166-1 list might be a better approach...
            my $CountryList = $Kernel::OM->Get('Kernel::System::ReferenceData')->CountryList();
            if ( exists $CountryList->{ $Param{ImportDataRow}->[$Counter] } ) {
                $NewCustomerCompanyData{ $MappingObjectData->{Key} } = $Param{ImportDataRow}->[$Counter];
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


        # WORKAROUND - for FEFF-character in _some_ texts (remove it)...
        if ( $NewCustomerCompanyData{ $MappingObjectData->{Key} } ) {
            $NewCustomerCompanyData{ $MappingObjectData->{Key} } =~ s/(\x{feff})//g;
        }
        #EO WORKAROUND

        $Counter++;

    }

    #--------------------------------------------------------------------------
    #DO THE IMPORT...

    #(0) lookup company entry
    my %CustomerCompanyData = ();

    my $CustomerCompanyKey;
    my $CustomerCompanyBackend = $Kernel::OM->Get('Kernel::Config')->Get($ObjectData->{CustomerCompanyBackend});
    if ( $CustomerCompanyBackend && $CustomerCompanyBackend->{CustomerCompanyKey} && $CustomerCompanyBackend->{Map} ) {
        for my $Entry ( @{ $CustomerCompanyBackend->{Map} } ) {
            next if ( $Entry->[1] ne $CustomerCompanyBackend->{CustomerCompanyKey} );

            $CustomerCompanyKey = $Entry->[0];
            last;
        }
        if ( !$CustomerCompanyKey ) {
            $CustomerCompanyKey = "CustomerID";
        }
    }

    if ( $NewCustomerCompanyData{$CustomerCompanyKey} ) {
        %CustomerCompanyData = $Kernel::OM->Get('Kernel::System::CustomerCompany')->CustomerCompanyGet(
            CustomerID => $NewCustomerCompanyData{$CustomerCompanyKey}
        );
    }

    my $NewCompany = 1;
    if (%CustomerCompanyData) {
        $NewCompany = 0;
    }

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

    #---------------------------------------------------------------------------
    # (2) overwrite existing values with new values...
    for my $Key ( keys(%NewCustomerCompanyData) ) {
        if( $ObjectData->{EmptyFieldsLeaveTheOldValues}
            && $NewCustomerCompanyData{$Key}
        ) {
            $CustomerCompanyData{$Key} = $NewCustomerCompanyData{$Key};

        } elsif ( !$ObjectData->{EmptyFieldsLeaveTheOldValues} ) {
            $CustomerCompanyData{$Key} = $NewCustomerCompanyData{$Key};
        }
    }

    #(3) if company DOES NOT exist => create in specified backend
    my $Result     = 0;
    my $ReturnCode = "";    # Created | Changed | Failed

    if ($NewCompany) {
        $Result = $Kernel::OM->Get('Kernel::System::CustomerCompany')->CustomerCompanyAdd(
            %CustomerCompanyData,
            Source => $ObjectData->{CustomerCompanyBackend},
            UserID => $Param{UserID},
        );

        if ( !$Result ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "ImportDataSave: adding CustomerCompany ("
                    . "CustomerCompany "
                    . $CustomerCompanyData{$CustomerCompanyKey}
                    . ") failed (line $Param{Counter}).",
            );
        }
        else {
            $ReturnCode = "Created";
        }
    }

    #(4) if company DOES exist => check backend and update...
    else {
        $CustomerCompanyData{ID} = $NewCustomerCompanyData{$CustomerCompanyKey};

        if (
            $CustomerCompanyData{Source}
            && $CustomerCompanyData{Source} eq $ObjectData->{CustomerCompanyBackend}
            )
        {
            $Result = $Kernel::OM->Get('Kernel::System::CustomerCompany')->CustomerCompanyUpdate(
                %CustomerCompanyData,
                Source => $ObjectData->{CustomerCompanyBackend},
                UserID => $Param{UserID},
            );

            if ( !$Result ) {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message  => "ImportDataSave: updating CustomerCompany "
                        . $CustomerCompanyData{ID}
                        . " failed (line $Param{Counter}).",
                );
            }
            else {
                $ReturnCode = "Changed";
            }
        }
        elsif ( $ObjectData->{ForceImportInConfiguredCustomerCompanyBackend} ) {

            # NOTE: this is a somewhat dirty hack to force the import of the
            # customer company data in the backend which is assigned in the current
            # mapping. Actually a customer company data set can not be added under the
            # same key (CustomerID).

            my %BackendRef = ();
            my $ResultNote = "";

            # find backend and backup customer company data backend refs...
            while (
                $CustomerCompanyData{Source}
                && $CustomerCompanyData{Source} ne $ObjectData->{CustomerCompanyBackend}
                )
            {
                $BackendRef{ $CustomerCompanyData{Source} } =
                    $Kernel::OM->Get('Kernel::System::CustomerCompany')->{ $CustomerCompanyData{Source} };
                delete( $Kernel::OM->Get('Kernel::System::CustomerCompany')->{ $CustomerCompanyData{Source} } );

                %CustomerCompanyData = $Kernel::OM->Get('Kernel::System::CustomerCompany')->CustomerCompanyGet(
                    CustomerID => $NewCustomerCompanyData{$CustomerCompanyKey}
                );
            }

            # overwrite existing values with new values...
            for my $Key ( keys(%NewCustomerCompanyData) ) {
                $CustomerCompanyData{$Key} = $NewCustomerCompanyData{$Key};
            }

            # update existing entry...
            if (
                $CustomerCompanyData{Source}
                && $CustomerCompanyData{Source} eq $ObjectData->{CustomerCompanyBackend}
                )
            {
                $CustomerCompanyData{ID} = $NewCustomerCompanyData{$CustomerCompanyKey};
                $Result = $Kernel::OM->Get('Kernel::System::CustomerCompany')->CustomerCompanyUpdate(
                    %CustomerCompanyData,
                    Source => $ObjectData->{CustomerCompanyBackend},
                    UserID => $Param{UserID},
                );
                $ResultNote = "update";
                $ReturnCode = "Changed";
            }

            # create new entry...
            else {
                $Result = $Kernel::OM->Get('Kernel::System::CustomerCompany')->CustomerCompanyAdd(
                    %CustomerCompanyData,
                    Source => $ObjectData->{CustomerCompanyBackend},
                    UserID => $Param{UserID},
                );
                $ResultNote = "add";
                $ReturnCode = "Created";
            }

            # check for errors...
            if ( !$Result ) {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message  => "ImportDataSave: forcing CustomerCompany "
                        . $CustomerCompanyData{ID}
                        . " in "
                        . $ObjectData->{CustomerCompanyBackend}
                        . " ($ResultNote) "
                        . " failed (line $Param{Counter}).",
                );
                $ReturnCode = "";
            }

            # restore customer company data backend refs...
            for my $CurrKey ( keys(%BackendRef) ) {
                $Kernel::OM->Get('Kernel::System::CustomerCompany')->{$CurrKey} = $BackendRef{$CurrKey};
            }

        }
        else {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'notice',
                Message  => "ImportDataSave: updating CustomerCompany "
                    . $CustomerCompanyData{ID}
                    . " failed - CustomerCompany exists in other backend.",

            );
        }
    }

    #
    #--------------------------------------------------------------------------

    return ( $Result, $ReturnCode );
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
