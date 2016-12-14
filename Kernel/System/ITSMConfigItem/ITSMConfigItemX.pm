# --
# Kernel/System/ITSMConfigItem.pm - additional config item functions
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Torsten(dot)Thau(at)cape(dash)it(dot)de
# * Rene(dot)Boehm(at)cape(dash)it(dot)de
# * Martin(dot)Balzarek(at)cape(dash)it(dot)de
# * Torsten(dot)Thau(at)cape(dash)it(dot)de
# * Stefan(dot)Mehlig(at)cape(dash)it(dot)de
# * Dorothea(dot)Doerffel(at)cape(dash)it(dot)de
# * Ricky(dot)Kaiser(at)cape(dash)it(dot)de
#
# --
# $Id$
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::ITSMConfigItem::ITSMConfigItemX;

use strict;
use warnings;

#-------------------------------------------------------------------------------
# REPLACE ORIGINAL METHODS BY MINOR MODIFICATIONS
#
# The following methods may be used instead of original methods as long as
# (1) this package is registered SysConfig key "ITSMConfigItem::CustomModules"
# (2a) methods are NOT contained in Kernel::System::ITSMConfigItem OR
# (2b) methods are contained in Kernel::System::ITSMConfigItem but call SUPER-class method
#

=item ConfigItemAdd()

add a new config item

    my $ConfigItemID = $ConfigItemObject->ConfigItemAdd(
        Number  => '111',  # (optional)
        ClassID => 123,
        UserID  => 1,
    );

=cut

sub ConfigItemAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(ClassID UserID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # get class list
    my $ClassList = $Kernel::OM->Get('Kernel::System::GeneralCatalog')->ItemList(
        Class => 'ITSM::ConfigItem::Class',
    );

    return if !$ClassList;
    return if ref $ClassList ne 'HASH';

    # check the class id
    if ( !$ClassList->{ $Param{ClassID} } ) {

        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'No valid class id given!',
        );
        return;
    }

    #---------------------------------------------------------------------------
    # KIX4OTRS-capeIT
    # trigger ConfigItemCreate
    my $Result = $Self->PreEventHandler(
        Event => 'ConfigItemCreate',
        Data  => {
            ClassID => $Param{ClassID},
            UserID  => $Param{UserID},
            Version => $Param{Version} || '',
        },
        UserID => $Param{UserID},
    );
    if ( ( ref($Result) eq 'HASH' ) && ( $Result->{Error} ) ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'notice',
            Message  => "Pre-ConfigItemAdd refused CI creation.",
        );
        return $Result;
    }
    elsif ( ref($Result) eq 'HASH' ) {
        for my $ResultKey ( keys %{$Result} ) {
            $Param{$ResultKey} = $Result->{$ResultKey};
        }
    }

    # EO KIX4OTRS-capeIT
    #---------------------------------------------------------------------------

    # create config item number
    if ( $Param{Number} ) {

        # find existing config item number
        my $Exists = $Self->ConfigItemNumberLookup(
            ConfigItemNumber => $Param{Number},
        );

        if ($Exists) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => 'Config item number already exists!',
            );
            return;
        }
    }
    else {

        # create config item number
        $Param{Number} = $Self->ConfigItemNumberCreate(
            Type    => $Kernel::OM->Get('Kernel::Config')->Get('ITSMConfigItem::NumberGenerator'),
            ClassID => $Param{ClassID},
        );
    }

    # insert new config item
    my $Success = $Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL => 'INSERT INTO configitem '
            . '(configitem_number, class_id, create_time, create_by, change_time, change_by) '
            . 'VALUES (?, ?, current_timestamp, ?, current_timestamp, ?)',
        Bind => [ \$Param{Number}, \$Param{ClassID}, \$Param{UserID}, \$Param{UserID} ],
    );

    return if !$Success;

    # find id of new item
    $Kernel::OM->Get('Kernel::System::DB')->Prepare(
        SQL => 'SELECT id FROM configitem WHERE '
            . 'configitem_number = ? AND class_id = ? ORDER BY id DESC',
        Bind  => [ \$Param{Number}, \$Param{ClassID} ],
        Limit => 1,
    );

    # fetch the result
    my $ConfigItemID;
    while ( my @Row = $Kernel::OM->Get('Kernel::System::DB')->FetchrowArray() ) {
        $ConfigItemID = $Row[0];
    }

    # trigger ConfigItemCreate
    $Self->EventHandler(
        Event => 'ConfigItemCreate',
        Data  => {
            ConfigItemID => $ConfigItemID,
            Comment      => $ConfigItemID . '%%' . $Param{Number},
        },
        UserID => $Param{UserID},
    );

    return $ConfigItemID;
}

=item ConfigItemDelete()

delete an existing config item

    my $True = $ConfigItemObject->ConfigItemDelete(
        ConfigItemID => 123,
        UserID       => 1,
    );

=cut

sub ConfigItemDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(ConfigItemID UserID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    #---------------------------------------------------------------------------
    # KIX4OTRS-capeIT
    # trigger ConfigItemDelete
    my $Result = $Self->PreEventHandler(
        Event => 'ConfigItemDelete',
        Data  => {
            ConfigItemID => $Param{ConfigItemID},
            Comment      => $Param{ConfigItemID},
            UserID       => $Param{UserID},
        },
        UserID => $Param{UserID},
    );
    if ( ( ref($Result) eq 'HASH' ) && ( $Result->{Error} ) ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'notice',
            Message  => "Pre-ConfigItemDelete refused CI deletion.",
        );
        return $Result;
    }
    elsif ( ref($Result) eq 'HASH' ) {
        for my $ResultKey ( keys %{$Result} ) {
            $Param{$ResultKey} = $Result->{$ResultKey};
        }
    }

    # EO KIX4OTRS-capeIT
    #---------------------------------------------------------------------------

    # delete all links to this config item first, before deleting the versions
    return if !$Kernel::OM->Get('Kernel::System::LinkObject')->LinkDeleteAll(
        Object => 'ITSMConfigItem',
        Key    => $Param{ConfigItemID},
        UserID => $Param{UserID},
    );

    # delete existing versions
    $Self->VersionDelete(
        ConfigItemID => $Param{ConfigItemID},
        UserID       => $Param{UserID},
    );

    # get a list of all attachments
    my @ExistingAttachments = $Self->ConfigItemAttachmentList(
        ConfigItemID => $Param{ConfigItemID},
    );

    # delete all attachments of this config item
    FILENAME:
    for my $Filename (@ExistingAttachments) {

        # delete the attachment
        my $DeletionSuccess = $Self->ConfigItemAttachmentDelete(
            ConfigItemID => $Param{ConfigItemID},
            Filename     => $Filename,
            UserID       => $Param{UserID},
        );

        if ( !$DeletionSuccess ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Unknown problem when deleting attachment $Filename of ConfigItem "
                    . "$Param{ConfigItemID}. Please check the VirtualFS backend for stale "
                    . "files!",
            );
        }
    }

    # trigger ConfigItemDelete event
    # this must be done before deleting the config item from the database,
    # because of a foreign key constraint in the configitem_history table
    $Self->EventHandler(
        Event => 'ConfigItemDelete',
        Data  => {
            ConfigItemID => $Param{ConfigItemID},
            Comment      => $Param{ConfigItemID},
        },
        UserID => $Param{UserID},
    );

    # delete config item
    my $Success = $Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL  => 'DELETE FROM configitem WHERE id = ?',
        Bind => [ \$Param{ConfigItemID} ],
    );

    return $Success;
}

# EO REPLACE ORIGINAL METHODS BY MINOR MODIFICATIONS
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
# KIX4OTRS-capeIT
# Thefollowing methods are meant to ease the handling of the XML-LIKE data hash.
# They do not replace any internal/original methods.

=item GetAttributeValuesByKey()

    Returns values first found, for a given attribute key.
        _GetAttributeValuesByKey (
            KeyName       => 'FQDN',
            XMLData       => $XMLDataRef,
            XMLDefinition => $XMLDefRef,
        );
=cut

sub GetAttributeValuesByKey {
    my ( $Self, %Param ) = @_;
    my @RetArray = qw{};

    # check required params...
    if (
        !$Param{KeyName}
        ||
        ( !$Param{XMLData} ) ||
        ( !$Param{XMLDefinition} ) ||
        ( ref $Param{XMLData} ne 'HASH' ) ||
        ( ref $Param{XMLDefinition} ne 'ARRAY' )
        )
    {
        return \@RetArray;
    }

    ITEM:
    for my $Item ( @{ $Param{XMLDefinition} } ) {

        COUNTER:
        for my $Counter ( 1 .. $Item->{CountMax} ) {

            # no content then stop loop...
            last COUNTER if !defined $Param{XMLData}->{ $Item->{Key} }->[$Counter]->{Content};

            # check if we are looking for this key
            if ( $Item->{Key} eq $Param{KeyName} ) {

                # get the value...
                my $Value = $Self->XMLValueLookup(
                    Item  => $Item,
                    Value => length( $Param{XMLData}->{ $Item->{Key} }->[$Counter]->{Content} )
                    ? $Param{XMLData}->{ $Item->{Key} }->[$Counter]->{Content}
                    : '',
                );

                if ($Value) {
                    push( @RetArray, $Value );
                }
            }
            next COUNTER if !$Item->{Sub};

            #recurse if subsection available...
            my $SubResult = $Self->GetAttributeValuesByKey(
                KeyName       => $Param{KeyName},
                XMLDefinition => $Item->{Sub},
                XMLData       => $Param{XMLData}->{ $Item->{Key} }->[$Counter],
            );

            if ( ref($SubResult) eq 'ARRAY' ) {
                for my $ArrayElem ( @{$SubResult} ) {
                    push( @RetArray, $ArrayElem );
                }
            }
        }
    }

    return \@RetArray;
}

=item GetAttributeContentsByKey()

    Returns contents first found, for a given attribute key.
        GetAttributeContentsByKey (
            KeyName       => 'FQDN',
            XMLData       => $XMLDataRef,
            XMLDefinition => $XMLDefRef,
        );
=cut

sub GetAttributeContentsByKey {
    my ( $Self, %Param ) = @_;
    my @RetArray = qw{};

    # check required params...
    if (
        !$Param{KeyName}
        ||
        ( !$Param{XMLData} ) ||
        ( !$Param{XMLDefinition} ) ||
        ( ref $Param{XMLData} ne 'HASH' ) ||
        ( ref $Param{XMLDefinition} ne 'ARRAY' )
        )
    {
        return \@RetArray;
    }

    ITEM:
    for my $Item ( @{ $Param{XMLDefinition} } ) {

        COUNTER:
        for my $Counter ( 1 .. $Item->{CountMax} ) {

            # no content then stop loop...
            last COUNTER if !defined $Param{XMLData}->{ $Item->{Key} }->[$Counter]->{Content};

            # get the value...
            my $Content
                = length( $Param{XMLData}->{ $Item->{Key} }->[$Counter]->{Content} )
                ? $Param{XMLData}->{ $Item->{Key} }->[$Counter]->{Content}
                : '';

            if ( ( $Item->{Key} eq $Param{KeyName} ) && $Content ) {
                push( @RetArray, $Content );
            }

            next COUNTER if !$Item->{Sub};

            #recurse if subsection available...
            my $SubResult = $Self->GetAttributeContentsByKey(
                KeyName       => $Param{KeyName},
                XMLDefinition => $Item->{Sub},
                XMLData       => $Param{XMLData}->{ $Item->{Key} }->[$Counter],
            );

            if ( ref($SubResult) eq 'ARRAY' ) {
                for my $ArrayElem ( @{$SubResult} ) {
                    push( @RetArray, $ArrayElem );
                }
            }
        }
    }

    return \@RetArray;
}

=item GetAttributeDataByType()

    Returns a hashref with names and attribute values from the
    XML-DataHash for a specified data type.

    $ConfigItemObject->GetAttributeDataByType(
        XMLData       => $XMLData,
        XMLDefinition => $XMLDefinition,
        AttributeType => $AttributeType,
    );

=cut

sub GetAttributeDataByType {
    my ( $Self, %Param ) = @_;

    my @Keys = ();
    my %Result;

    #get all keys for specified input type...
    @Keys = @{
        $Self->GetKeyNamesByType(
            XMLDefinition => $Param{XMLDefinition},
            AttributeType => $Param{AttributeType}
            )
        };

    if ( $Param{Content} ) {
        for my $CurrKey (@Keys) {
            my $CurrContent = $Self->GetAttributeContentsByKey(
                KeyName       => $CurrKey,
                XMLData       => $Param{XMLData},
                XMLDefinition => $Param{XMLDefinition},
            );
            $Result{$CurrKey} = $CurrContent;
        }
    }
    else {
        for my $CurrKey (@Keys) {
            my $CurrVal = $Self->GetAttributeValuesByKey(
                KeyName       => $CurrKey,
                XMLData       => $Param{XMLData},
                XMLDefinition => $Param{XMLDefinition},
            );
            $Result{$CurrKey} = $CurrVal;
        }
    }

    return \%Result;

}

=item GetKeyNamesByType()

    Returns an array of keynames which are of a specified data type.

    $ConfigItemObject->GetKeyNamesByType(
        XMLDefinition => $XMLDefinition,
        AttributeType => $AttributeType,
    );

=cut

sub GetKeyNamesByType {
    my ( $Self, %Param ) = @_;

    my @Keys = ();
    my %Result;

    if ( defined( $Param{XMLDefinition} ) ) {

        for my $AttrDef ( @{ $Param{XMLDefinition} } ) {
            if ( $AttrDef->{Input}->{Type} eq $Param{AttributeType} ) {
                push( @Keys, $AttrDef->{Key} )
            }

            next if !$AttrDef->{Sub};

            my @SubResult = @{
                $Self->GetKeyNamesByType(
                    AttributeType => $Param{AttributeType},
                    XMLDefinition => $AttrDef->{Sub},
                    )
                };

            @Keys = ( @Keys, @SubResult );
        }

    }

    return \@Keys;
}

=item _GetKeyNamesByType()

    Sames as GetKeyNamesByType - returns an array of keynames which are of a
    specified data type. => use GetKeyNamesByType instead !
    !!! DEPRECATED - ONLY FOR COMPATIBILITY - WILL BE REMOVED !!!

    $ConfigItemObject->_GetKeyNamesByType(
        XMLDefinition => $XMLDefinition,
        AttributeType => $AttributeType,
    );

=cut

sub _GetKeyNamesByType {
    my ( $Self, %Param ) = @_;

    my @Keys = ();
    my %Result;

    if ( defined( $Param{XMLDefinition} ) ) {

        for my $AttrDef ( @{ $Param{XMLDefinition} } ) {
            if ( $AttrDef->{Input}->{Type} eq $Param{AttributeType} ) {
                push( @Keys, $AttrDef->{Key} )
            }

            next if !$AttrDef->{Sub};

            my @SubResult = @{
                $Self->_GetKeyNamesByType(
                    AttributeType => $Param{AttributeType},
                    XMLDefinition => $AttrDef->{Sub},
                    )
                };

            @Keys = ( @Keys, @SubResult );
        }

    }

    return \@Keys;
}

=item GetAttributeDefByTagKey()

Returns chosen CI attribute definition, for a given tag key.
    my %AttrDef = $ConfigItemObject->GetAttributeDefByTagKey (
        TagKey        => "[1]{'Version'}[1]{'Model'}[1]",
        XMLData       => $XMLDataRef,
        XMLDefinition => $XMLDefRef,
    );

returns

    Input => {
        Type
        Class
        Required
        Translation
        Size
        MaxLength
    }
    Key
    Name
    Searchable
    CountMin
    CountMax
    CountDefault

=cut

sub GetAttributeDefByTagKey {
    my ( $Self, %Param ) = @_;

    # check required params...
    return
        if (
        !$Param{XMLData}       || ref( $Param{XMLData} )       ne 'HASH' ||
        !$Param{XMLDefinition} || ref( $Param{XMLDefinition} ) ne 'ARRAY' ||
        !$Param{TagKey}
        );

    ITEM:
    for my $Item ( @{ $Param{XMLDefinition} } ) {
        next ITEM if ( !$Param{XMLData}->{ $Item->{Key} } );

        COUNTER:
        for my $Counter ( 1 .. $Item->{CountMax} ) {
            if ( $Param{XMLData}->{ $Item->{Key} }->[$Counter]->{TagKey} eq $Param{TagKey} ) {
                return %{$Item};
            }

            next COUNTER if !$Item->{Sub};

            # recurse if subsection available...
            my $SubResult = $Self->GetAttributeDefByTagKey(
                TagKey        => $Param{TagKey},
                XMLDefinition => $Item->{Sub},
                XMLData       => $Param{XMLData}->{ $Item->{Key} }->[$Counter],
            );

            if ( $SubResult && ref($SubResult) eq 'HASH' ) {
                return %{$SubResult};
            }
        }
    }

    return ();
}

=item VersionDataUpdate()

    Returns a the current version data in the most current definition format
    (usually this is done in the frontend). The version data might be structured
    in a previous definition.

    $NewVersionXMLData = $ConfigItemObject->VersionDataUpdate(
        XMLDefinition => $NewDefinitionRef->{DefinitionRef},
        XMLData       => $CurrentVersionRef->{XMLData}->[1]->{Version}->[1],
    );

=cut

sub VersionDataUpdate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    return if !$Param{XMLData};
    return if ref $Param{XMLData} ne 'HASH';
    return if !$Param{XMLDefinition};
    return if ref $Param{XMLDefinition} ne 'ARRAY';

    my $FormData = {};

    ITEM:
    for my $Item ( @{ $Param{XMLDefinition} } ) {
        my $CounterInsert = 1;

        COUNTER:
        for my $Counter ( 1 .. $Item->{CountMax} ) {

            # create inputkey and addkey
            my $InputKey = $Item->{Key} . '::' . $Counter;
            if ( $Param{Prefix} ) {
                $InputKey = $Param{Prefix} . '::' . $InputKey;
            }

            #get content...
            my $Content = $Param{XMLData}->{ $Item->{Key} }->[$Counter]->{Content} || '';
            next COUNTER if !$Content;

            # start recursion, if "Sub" was found
            if ( $Item->{Sub} ) {
                my $SubFormData = $Self->VersionDataUpdate(
                    XMLDefinition => $Item->{Sub},
                    XMLData       => $Param{XMLData}->{ $Item->{Key} }->[1],
                    Prefix        => $InputKey,
                );
                $FormData->{ $Item->{Key} }->[$CounterInsert] = $SubFormData;
            }

            $FormData->{ $Item->{Key} }->[$CounterInsert]->{Content} = $Content;
            $CounterInsert++;

        }
    }

    return $FormData;
}

=item SetAttributeContentsByKey()

    Sets the content of the specified keyname in the XML data hash.

    $ConfigItemObject->SetAttributeContentsByKey(
        KeyName       => 'Location',
        NewContent    => $RetireCILocationID,
        XMLData       => $NewVersionData,
        XMLDefinition => $UsedVersion,
    );

=cut

sub SetAttributeContentsByKey {
    my ( $Self, %Param ) = @_;

    # check required params...
    if (
        !$Param{KeyName}
        ||
        !length( $Param{NewContent} ) ||
        ( !$Param{XMLData} ) ||
        ( !$Param{XMLDefinition} ) ||
        ( ref $Param{XMLData} ne 'HASH' ) ||
        ( ref $Param{XMLDefinition} ne 'ARRAY' )
        )
    {
        return 0;
    }

    ITEM:
    for my $Item ( @{ $Param{XMLDefinition} } ) {

        COUNTER:
        for my $Counter ( 1 .. $Item->{CountMax} ) {

            # get the value...
            if ( $Item->{Key} eq $Param{KeyName} ) {
                $Param{XMLData}->{ $Item->{Key} }->[$Counter]->{Content} = $Param{NewContent};
            }

            # no content then stop loop...
            last COUNTER if !defined $Param{XMLData}->{ $Item->{Key} }->[$Counter]->{Content};

            next COUNTER if !$Item->{Sub};

            #recurse if subsection available...
            my $SubResult = $Self->SetAttributeContentsByKey(
                KeyName       => $Param{KeyName},
                NewContent    => $Param{NewContent},
                XMLDefinition => $Item->{Sub},
                XMLData       => $Param{XMLData}->{ $Item->{Key} }->[$Counter],
            );

        }
    }

    return 0;
}

=item VersionCount()

    Returns the number of versions for a given config item.

    $ConfigItemObject->VersionCount(
        ConfigItemID => 123,
    );

=cut

sub VersionCount {
    my ( $Self, %Param ) = @_;
    my $Result = 0;

    return if ( !$Param{ConfigItemID} );

    my $VersionList = $Self->VersionList(
        ConfigItemID => $Param{ConfigItemID},
    );
    return if ( !$VersionList || ref($VersionList) ne 'ARRAY' );

    $Result = ( scalar( @{$VersionList} ) || 0 );

    return $Result;
}

=item CountLinkedObjects()

Returns the number of objects linked with a given ticket.

    my $Result = $ConfigItemObject->CountLinkedObjects(
        ConfigItemID => 123,
        UserID => 1
    );

=cut

sub CountLinkedObjects {
    my ( $Self, %Param ) = @_;
    my $Result = 0;

    return if ( !$Param{ConfigItemID} );

    my $LinkObject = $Self->{LinkObject} || undef;

    if ( !$LinkObject ) {
        $LinkObject = $Kernel::OM->Get('Kernel::System::LinkObject');
    }

    return '' if !$LinkObject;

    my %PossibleObjectsList = $LinkObject->PossibleObjectsList(
        Object => 'ITSMConfigItem',
        UserID => $Param{UserID} || 1,
    );
    for my $CurrObject ( keys(%PossibleObjectsList) ) {
        my %LinkList = $LinkObject->LinkKeyList(
            Object1 => 'ITSMConfigItem',
            Key1    => $Param{ConfigItemID},
            Object2 => $CurrObject,
            State   => 'Valid',
            UserID  => 1,
        );

        $Result = $Result + ( scalar( keys(%LinkList) ) || 0 );
    }

    return $Result;
}

# EO KIX4OTRS-capeIT
#-------------------------------------------------------------------------------

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the OTRS project (http://otrs.org/).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see http://www.gnu.org/licenses/agpl.txt.

=cut

=head1 VERSION

$Revision$ $Date$

=cut
