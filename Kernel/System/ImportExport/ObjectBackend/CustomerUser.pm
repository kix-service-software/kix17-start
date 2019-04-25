# --
# Modified version of the work: Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2019 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::ImportExport::ObjectBackend::CustomerUser;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::ImportExport',
    'Kernel::System::CustomerUser',
    'Kernel::System::Log',
    'Kernel::Config'
);

=head1 NAME

Kernel::System::ImportExport::ObjectBackend::CustomerUser - import/export backend for CustomerUser

=head1 SYNOPSIS

All functions to import and export CustomerUser entries

=over 4

=cut

=item new()

create an object

    use Kernel::Config;
    use Kernel::System::DB;
    use Kernel::System::Log;
    use Kernel::System::Main;
    use Kernel::System::ImportExport::ObjectBackend::CustomerUser;

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
    my $BackendObject = Kernel::System::ImportExport::ObjectBackend::CustomerUser->new(
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

    my %CSList    = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerSourceList();
    my %Validlist = $Kernel::OM->Get('Kernel::System::Valid')->ValidList();

    my $Attributes = [
        {
            Key   => 'CustomerBackend',
            Name  => 'Customer Backend',
            Input => {
                Type         => 'Selection',
                Data         => \%CSList,
                Required     => 1,
                Translation  => 0,
                PossibleNone => 0,
            },
        },
        {
            Key   => 'ForceImportInConfiguredCustomerBackend',
            Name  => 'Force import in configured customer backend',
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
            Key   => 'DefaultUserCustomerID',
            Name  => 'Default Customer ID',
            Input => {
                Type         => 'Text',
                Required     => 0,
                Size         => 50,
                MaxLength    => 250,
                ValueDefault => '',
            },
        },
        {
            Key   => 'EnableMailDomainCustomerIDMapping',
            Name  => 'Maildomain-CustomerID Mapping (see SysConfig)',
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
            Key   => 'DefaultUserEmail',
            Name  => 'Default Email',
            Input => {
                Type         => 'Text',
                Required     => 0,
                Size         => 50,
                MaxLength    => 250,
                ValueDefault => '',
            },
        },
        {
            Key   => 'ResetPassword',
            Name  => 'Reset password if updated',
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
            Key   => 'ResetPasswordSuffix',
            Name  => 'Password-Suffix (new password = login + suffix)',
            Input => {
                Type         => 'Text',
                Required     => 0,
                Size         => 50,
                MaxLength    => 50,
                ValueDefault => '',
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
    my @Map =
        @{ $Kernel::OM->Get('Kernel::Config')->{ $ObjectData->{CustomerBackend} }->{'Map'} };

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

        # if UserPassword is available - add note to mapping..
        if ( $CurrAttributeMapping->[0] eq 'UserPassword' ) {
            $CurrAttribute = {
                Key => 'UserPassword',
                Value =>
                    'UserPassword (not filled in export, relevant only for import of new entries)',
            };
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
        # CustomerKey of Backend is used to search for existing enrties anyway!
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

    # search the customer users...
    my %CustomerUserList = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerSearch(
        Search => '*',
        Valid  => 0,
    );

    my @ExportData;

    for my $CurrUser (%CustomerUserList) {

        my %CustomerUserData = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerUserDataGet(
            User => $CurrUser,
        );

        # prepare validity...
        if ( $CustomerUserData{ValidID} ) {
            $CustomerUserData{Valid} = $Kernel::OM->Get('Kernel::System::Valid')->ValidLookup(
                ValidID => $CustomerUserData{ValidID},
            );
        }

        # prepare password...
        if ( $CustomerUserData{UserPassword} ) {
            $CustomerUserData{UserPassword} = '-';
        }

        if (
            $CustomerUserData{Source}
            && ( $CustomerUserData{Source} eq $ObjectData->{CustomerBackend} )
        ) {
            my @CurrRow;
            for my $MappingObject (@MappingObjectList) {
                my $Key = $MappingObject->{Key};
                if ( !$Key ) {
                    push @CurrRow, '';
                }
                else {
                    push( @CurrRow, $CustomerUserData{$Key} || '' );
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
    my $Counter             = 0;
    my %NewCustomerUserData = qw{};

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

        # It doesn't make sense to configure and set the identifier:
        # CustomerKey of Backend is used to search for existing enrties anyway!
        #
        #  See lines 638-639:
        #       if ( !$CustomerUserKey || $CustomerUserKey ne 'UserLogin' ) {
        #           $CustomerUserKey = "UserLogin";
        #       }

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
        #            $CustomerUserKey = $MappingObjectData->{Key};
        #        }

        if ( $MappingObjectData->{Key} ne "UserCountry" ) {
            $NewCustomerUserData{ $MappingObjectData->{Key} } = 
            $Param{ImportDataRow}->[$Counter];
        } 
        else {
            # Sanitize country if it isn't found in OTRS to increase the chance it will
            # Note that standardizing against the ISO 3166-1 list might be a better approach...
            my $CountryList = $Kernel::OM->Get('Kernel::System::ReferenceData')->CountryList();
            if ( exists $CountryList->{$Param{ImportDataRow}->[$Counter]} ) {
                $NewCustomerUserData{ $MappingObjectData->{Key} } = $Param{ImportDataRow}->[$Counter];
            }
            else {
                $NewCustomerUserData{ $MappingObjectData->{Key} } =
                    join ('', map { ucfirst lc } split /(\s+)/, $Param{ImportDataRow}->[$Counter]);
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'notice',
                    Message  => "Country '$Param{ImportDataRow}->[$Counter]' "
                        . "not found - save as '$NewCustomerUserData{ $MappingObjectData->{Key} }'.",
                );
            }
        }


        # WORKAROUND - for FEFF-character in _some_ texts (remove it)...
        if ( $NewCustomerUserData{ $MappingObjectData->{Key} } ) {
            $NewCustomerUserData{ $MappingObjectData->{Key} } =~ s/(\x{feff})//g;
        }
        #EO WORKAROUND

        $Counter++;

    }

    #--------------------------------------------------------------------------
    #DO THE IMPORT...

    # (0) search user
    my %CustomerUserData = ();

    my $CustomerUserKey;
    my $CustomerBackend = $Kernel::OM->Get('Kernel::Config')->Get($ObjectData->{CustomerBackend} || $ObjectData->{CustomerUserBackend});
    if ( $CustomerBackend && $CustomerBackend->{CustomerKey} && $CustomerBackend->{Map} ) {
        for my $Entry ( @{ $CustomerBackend->{Map} } ) {
            next if ( $Entry->[1] ne $CustomerBackend->{CustomerKey} );

            $CustomerUserKey = $Entry->[0];
            last;
        }
        if ( !$CustomerUserKey ) {
            $CustomerUserKey = "UserLogin";
        }
    }

    if ( $NewCustomerUserData{$CustomerUserKey} ) {
        %CustomerUserData = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerUserDataGet(
            User => $NewCustomerUserData{$CustomerUserKey}
        );
    }

    my $NewUser = 1;
    if (%CustomerUserData) {
        $NewUser = 0;
    }

    #---------------------------------------------------------------------------
    # (1) Preprocess data...
    my $DefaultCustomerID = $Kernel::OM->Get('Kernel::Config')->Get(
        'CustomerUserImport::DefaultCustomerID'
    ) || 'DefaultCustomerID';
    my $DefaultEmailAddress = $Kernel::OM->Get('Kernel::Config')->Get(
        'CustomerUserImport::DefaultEmailAddress'
    ) || 'dummy@localhost';
    my $EmailDomainCustomerIDMapping = $Kernel::OM->Get('Kernel::Config')->Get(
        'CustomerUserImport::EMailDomainCustomerIDMapping'
    );

    # lookup Valid-ID...
    if ( !$NewCustomerUserData{ValidID} && $NewCustomerUserData{Valid} ) {
        $NewCustomerUserData{ValidID} = $Kernel::OM->Get('Kernel::System::Valid')->ValidLookup(
            Valid => $NewCustomerUserData{Valid}
        );
    }
    if ( !$NewCustomerUserData{ValidID} ) {
        $NewCustomerUserData{ValidID} = $ObjectData->{DefaultValid} || 1;
    }

    #UserEmail-Domain 2 CustomerID Mapping...
    if ( $ObjectData->{EnableMailDomainCustomerIDMapping} ) {

        # get company mapping from email address
        if ( $NewCustomerUserData{UserEmail} ) {

            for my $Key ( keys( %{$EmailDomainCustomerIDMapping} ) ) {
                $EmailDomainCustomerIDMapping->{ lc($Key) } = $EmailDomainCustomerIDMapping->{$Key};
            }

            my ( $LocalPart, $DomainPart ) = split( '@', $NewCustomerUserData{UserEmail} );
            $DomainPart = lc($DomainPart);

            if ( $EmailDomainCustomerIDMapping->{$DomainPart} ) {
                $NewCustomerUserData{UserCustomerID} =
                    $EmailDomainCustomerIDMapping->{$DomainPart};
            }
            elsif (
                $EmailDomainCustomerIDMapping->{$DomainPart}
                && $EmailDomainCustomerIDMapping->{ANYTHINGELSE}
            ) {
                $NewCustomerUserData{UserCustomerID} =
                    $EmailDomainCustomerIDMapping->{ANYTHINGELSE};
            }
        }
    }

    # default UserCustomerID...
    if ( !$NewCustomerUserData{UserCustomerID} ) {
        $NewCustomerUserData{UserCustomerID} = $CustomerUserData{UserCustomerID}
            || $ObjectData->{DefaultUserCustomerID}
            || $DefaultCustomerID;
    }

    # default UserEmail...
    if ( !$NewCustomerUserData{UserEmail} ) {
        $NewCustomerUserData{UserEmail} = $CustomerUserData{UserEmail}
            || $ObjectData->{DefaultUserEmail}
            || $DefaultEmailAddress;
    }

    # reset UserPassword...
    if (
        ( $NewUser || $ObjectData->{ResetPassword} )
        && (
            ( $NewCustomerUserData{UserPassword} && $NewCustomerUserData{UserPassword} eq '-' )
            || ( !$NewCustomerUserData{UserPassword} )
        )
    ) {
        $NewCustomerUserData{UserPassword} = $NewCustomerUserData{$CustomerUserKey}
            . ( $ObjectData->{ResetPasswordSuffix} || '' );
    }
    elsif ( !$NewUser && !$ObjectData->{ResetPassword} ) {
        delete $NewCustomerUserData{UserPassword};
        delete $CustomerUserData{UserPassword};
    }

    #---------------------------------------------------------------------------
    # (2) overwrite existing values with new values...
    for my $Key ( keys(%NewCustomerUserData) ) {
        $CustomerUserData{$Key} = $NewCustomerUserData{$Key};
    }

    #---------------------------------------------------------------------------
    # (3) if user DOES NOT exists => create in specified backend
    # update user
    my $Result     = 0;
    my $ReturnCode = "";    # Created | Changed | Failed
    if ($NewUser) {

        # set defaults
        delete $CustomerUserData{ID};
        $Result = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerUserAdd(
            %CustomerUserData,
            Source => $ObjectData->{CustomerBackend} || $ObjectData->{CustomerUserBackend},
            UserID => $Param{UserID},
        );

        if ( !$Result ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "ImportDataSave: adding CustomerUser ("
                    . "CustomerEmail "
                    . $CustomerUserData{UserEmail}
                    . ") failed (line $Param{Counter}).",
            );
        }
        else {
            $ReturnCode = "Created";
        }

    }

    #---------------------------------------------------------------------------
    #(3) if user DOES exists => check backend and update...
    else {
        $CustomerUserData{ID} = $NewCustomerUserData{$CustomerUserKey};

        if (
            $CustomerUserData{Source}
            && $CustomerUserData{Source} eq $ObjectData->{CustomerBackend}
        ) {
            $Result = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerUserUpdate(
                Source => $ObjectData->{CustomerBackend},
                %CustomerUserData,
                UserID => $Param{UserID},
            );

            if ( !$Result ) {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message  => "ImportDataSave: updating CustomerUser ("
                        . "CustomerEmail "
                        . $CustomerUserData{UserEmail}
                        . ") failed (line $Param{Counter}).",
                );
            }
            else {
                $ReturnCode = "Changed";
            }
        }
        elsif ( $ObjectData->{ForceImportInConfiguredCustomerBackend} ) {

            # NOTE: this is a somewhat dirty hack to force the import of the
            # customer user data in the backend which is assigned in the current
            # mapping. Actually a customer data set can not be added under the
            # same key (UserLogin).

            my %BackendRef = ();
            my $ResultNote = "";

            # find backend and backup customer user data backend refs...
            while (
                $CustomerUserData{Source}
                && $CustomerUserData{Source} ne $ObjectData->{CustomerBackend}
            ) {
                $BackendRef{ $CustomerUserData{Source} } =
                    $Kernel::OM->Get('Kernel::System::CustomerUser')->{ $CustomerUserData{Source} };
                delete( $Kernel::OM->Get('Kernel::System::CustomerUser')->{ $CustomerUserData{Source} } );

                %CustomerUserData = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerUserDataGet(
                    User => $NewCustomerUserData{$CustomerUserKey}
                );
            }

            # overwrite existing values with new values...
            for my $Key ( keys(%NewCustomerUserData) ) {
                $CustomerUserData{$Key} = $NewCustomerUserData{$Key};
            }

            # update existing entry...
            if (
                $CustomerUserData{Source}
                && $CustomerUserData{Source} eq $ObjectData->{CustomerBackend}
            ) {
                $CustomerUserData{ID} = $NewCustomerUserData{$CustomerUserKey};
                $Result = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerUserUpdate(
                    %CustomerUserData,
                    Source => $ObjectData->{CustomerBackend},
                    UserID => $Param{UserID},
                );
                $ResultNote = "update";
                $ReturnCode = "Changed";
            }

            # create new entry...
            else {
                $Result = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerUserAdd(
                    %CustomerUserData,
                    Source => $ObjectData->{CustomerBackend},
                    UserID => $Param{UserID},
                );
                $ResultNote = "add";
                $ReturnCode = "Created";
            }

            # check for errors...
            if ( !$Result ) {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message  => "ImportDataSave: forcing CustomerUser ("
                        . "CustomerEmail "
                        . $CustomerUserData{UserEmail}
                        . ") in "
                        . $ObjectData->{CustomerBackend}
                        . " ($ResultNote) "
                        . " failed (line $Param{Counter}).",
                );
                $ReturnCode = "";
            }

            # restore customer user data backend refs...
            for my $CurrKey ( keys(%BackendRef) ) {
                $Kernel::OM->Get('Kernel::System::CustomerUser')->{$CurrKey} = $BackendRef{$CurrKey};
            }

        }
        else {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'notice',
                Message  => "ImportDataSave: updating CustomerUser ("
                    . "CustomerEmail "
                    . $CustomerUserData{UserEmail}
                    . ") failed - CustomerUser exists in other backend.",

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
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
