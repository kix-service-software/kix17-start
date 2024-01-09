# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Stats::Dynamic::ITSMConfigItemList;

use strict;
use warnings;

use List::Util qw( first );

use Kernel::Language qw(Translatable);

our @ObjectDependencies = (
    'Kernel::System::GeneralCatalog',
    'Kernel::System::ITSMConfigItem',
    'Kernel::System::Time',
    'Kernel::System::Stats',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub GetObjectName {
    my $Self = shift;

    return 'ITSMConfigItemList';
}

sub GetObjectBehaviours {
    my ( $Self, %Param ) = @_;

    my %Behaviours = (
        ProvidesDashboardWidget => 0,
    );

    return %Behaviours;
}

sub GetObjectAttributes {
    my ( $Self, %Param ) = @_;

    my $GeneralCatalogObject = $Kernel::OM->Get('Kernel::System::GeneralCatalog');
    my $ConfigItemObject     = $Kernel::OM->Get('Kernel::System::ITSMConfigItem');
    my $TimeObject           = $Kernel::OM->Get('Kernel::System::Time');

    # get class list
    my $ClassList = $GeneralCatalogObject->ItemList(
        Class => 'ITSM::ConfigItem::Class',
    );

    # get deployment state list
    my $DeplStateList = $GeneralCatalogObject->ItemList(
        Class => 'ITSM::ConfigItem::DeploymentState',
    );

    # get incident state list
    my $InciStateList = $GeneralCatalogObject->ItemList(
        Class => 'ITSM::Core::IncidentState',
    );

    # get current time to fix bug#3830
    my $TimeStamp = $TimeObject->CurrentTimestamp();
    my ($Date)    = split /\s+/, $TimeStamp;
    my $Today     = sprintf "%s 23:59:59", $Date;

    my %ConfigItemAttributes = %{ $Self->_ConfigItemAttributes() };

    my %OrderBy = (
        ClassID => 'Class',
        Number  => 'Number',
        Name    => 'Name',

        DeplStateID => 'Deployment State',
        InciStateID => 'Incident State',

        CreateTime => 'Create Time',
        ChangeTime => 'Change Time',
    );

    my %SortSequence = (
        Up   => Translatable('ascending'),
        Down => Translatable('descending'),
    );

    # create object attribute array
    my @ObjectAttributes = (
        {
            Name             => Translatable('Attributes to be printed'),
            UseAsXvalue      => 1,
            UseAsValueSeries => 0,
            UseAsRestriction => 0,
            Element          => 'ConfigItemAttributes',
            Block            => 'MultiSelectField',
            Translation      => 1,
            Values           => \%ConfigItemAttributes,
            Sort             => 'IndividualKey',
            SortIndividual   => $Self->_SortedAttributes(),
        },
        {
            Name             => Translatable('Order by'),
            UseAsXvalue      => 0,
            UseAsValueSeries => 1,
            UseAsRestriction => 0,
            Element          => 'OrderBy',
            Block            => 'SelectField',
            Translation      => 1,
            Values           => \%OrderBy,
            Sort             => 'IndividualKey',
            SortIndividual   => $Self->_SortedAttributes(),
        },
        {
            Name             => Translatable('Sort sequence'),
            UseAsXvalue      => 0,
            UseAsValueSeries => 1,
            UseAsRestriction => 0,
            Element          => 'SortSequence',
            Block            => 'SelectField',
            Translation      => 1,
            Values           => \%SortSequence,
        },
        {
            Name                => 'Class',
            UseAsXvalue         => 0,
            UseAsValueSeries    => 0,
            UseAsRestriction    => 1,
            Element             => 'ClassIDs',
            Block               => 'MultiSelectField',
            LanguageTranslation => 0,
            Values              => $ClassList,
        },
        {
            Name             => 'Deployment State',
            UseAsXvalue      => 0,
            UseAsValueSeries => 0,
            UseAsRestriction => 1,
            Element          => 'DeplStateIDs',
            Block            => 'MultiSelectField',
            Values           => $DeplStateList,
        },
        {
            Name             => 'Incident State',
            UseAsXvalue      => 0,
            UseAsValueSeries => 0,
            UseAsRestriction => 1,
            Element          => 'InciStateIDs',
            Block            => 'MultiSelectField',
            Values           => $InciStateList,
        },
        {
            Name             => 'Number',
            UseAsXvalue      => 0,
            UseAsValueSeries => 0,
            UseAsRestriction => 1,
            Element          => 'Number',
            Block            => 'InputField',
        },
        {
            Name             => 'Name',
            UseAsXvalue      => 0,
            UseAsValueSeries => 0,
            UseAsRestriction => 1,
            Element          => 'Name',
            Block            => 'InputField',
        },
        {
            Name             => 'Create Time',
            UseAsXvalue      => 0,
            UseAsValueSeries => 0,
            UseAsRestriction => 1,
            Element          => 'CreateTime',
            TimePeriodFormat => 'DateInputFormat',
            Block            => 'Time',
            Values           => {
                TimeStart => 'ConfigItemCreateTimeNewerDate',
                TimeStop  => 'ConfigItemCreateTimeOlderDate',
            },
        },
        {
            Name             => 'Change Time',
            UseAsXvalue      => 0,
            UseAsValueSeries => 0,
            UseAsRestriction => 1,
            Element          => 'ChangeTime',
            TimePeriodFormat => 'DateInputFormat',
            Block            => 'Time',
            TimeStop         => $TimeStamp,
            Values           => {
                TimeStart => 'ConfigItemChangeTimeNewerDate',
                TimeStop  => 'ConfigItemChangeTimeOlderDate',
            },
        },
        {
            Name             => 'Check for empty fields',
            UseAsXvalue      => 0,
            UseAsValueSeries => 0,
            UseAsRestriction => 1,
            Translation      => 1,
            Element          => 'EmptyFields',
            Block            => 'SelectField',
            Values           => {
                Yes => 'Yes',
                No  => 'No',
            },
        },
    );

    # prepare xml stats restrictions# get class list
    my $XMLDefinition = [];
    CLASS:
    for my $ClassID ( keys( %{$ClassList} ) ) {
        # get definiton
        my $XMLDefinitionRef = $ConfigItemObject->DefinitionGet(
            ClassID => $ClassID,
        );
        next CLASS if ( ref( $XMLDefinitionRef->{DefinitionRef} ) ne 'ARRAY' );

        $Self->_XMLAttributeRestrictionDefinition(
            XMLDefinitionRef => $XMLDefinitionRef->{DefinitionRef},
            XMLDefinition    => $XMLDefinition,
        );
    }

    # add config item attributes as restrictions
    $Self->_XMLAttributeAdd(
        ObjectAttributes     => \@ObjectAttributes,
        ConfigItemAttributes => \%ConfigItemAttributes,
        XMLDefinition        => $XMLDefinition,
    );

    return @ObjectAttributes;
}

sub GetStatTablePreview {
    my ( $Self, %Param ) = @_;

    return $Self->GetStatTable(
        %Param,
        Preview => 1,
    );
}

sub GetStatTable {
    my ( $Self, %Param ) = @_;

    my $ConfigItemObject = $Kernel::OM->Get('Kernel::System::ITSMConfigItem');
    my $StatsObject      = $Kernel::OM->Get('Kernel::System::Stats');

    my %SelectedAttributes   = map { $_ => 1 } @{ $Param{XValue}{SelectedValues} };
    my $ConfigItemAttributes = $Self->_ConfigItemAttributes();
    my $SortedAttributesRef  = $Self->_SortedAttributes();
    my $Preview              = $Param{Preview};

    # set default values if no sort or order attribute is given
    my $OrderRef = first { $_->{Element} eq 'OrderBy' } @{ $Param{ValueSeries} };
    my $OrderBy  = $OrderRef ? $OrderRef->{SelectedValues} : ['ConfigItemID'];
    my $SortRef  = first { $_->{Element} eq 'SortSequence' } @{ $Param{ValueSeries} };
    my $Sort     = $SortRef ? $SortRef->{SelectedValues} : ['Down'];

    # prepare search parameter
    my %SearchParameter = ();
    my %SkipParameter   = (
        'EmptyFields' => 1,
    );
    my %StaticParameter = (
        'ClassIDs'                      => 1,
        'DeplStateIDs'                  => 1,
        'InciStateIDs'                  => 1,
        'Number'                        => 1,
        'Name'                          => 1,
        'ConfigItemCreateTimeNewerDate' => 1,
        'ConfigItemCreateTimeOlderDate' => 1,
        'ConfigItemChangeTimeNewerDate' => 1,
        'ConfigItemChangeTimeOlderDate' => 1,
    );
    ELEMENT:
    for my $Element ( keys( %{ $Param{Restrictions} } ) ) {
        # skip certain restrictions
        next ELEMENT if ( $SkipParameter{ $Element } );

        # handle static parameter
        if ( $StaticParameter{ $Element } ) {
            $SearchParameter{ $Element } = $Param{Restrictions}->{ $Element };
        }
        # handle xml parameter
        else {
            # prepare search key
            my $SearchKey = $Element;
            $SearchKey =~ s[ :: ]['}[%]{']xmsg;

            my %SearchHash = (
                '[1]{\'Version\'}[1]{\'' . $SearchKey . '\'}[%]{\'Content\'}' => $Param{Restrictions}->{ $Element },
            );

            # add search values to what
            if ( %SearchHash ) {
                if ( !defined( $SearchParameter{What} ) ) {
                    $SearchParameter{What} = [];
                }
                push( @{ $SearchParameter{What} }, \%SearchHash );
            }
        }
    }

    # don't be irritated of the mixture OrderBy <> Sort and SortBy <> OrderBy
    # the meaning is different as in common handling
    $SearchParameter{OrderBy}          = $OrderBy;
    $SearchParameter{OrderByDirection} = $Sort;

    # start config item extended search
    my $ConfigItemIDs = $ConfigItemObject->ConfigItemSearchExtended(%SearchParameter);

    # generate the configitem list
    my @StatArray;
    for my $ConfigItemID (@{$ConfigItemIDs}) {
        my @ResultRow;
        my $VersionRef = $ConfigItemObject->VersionGet(
            ConfigItemID => $ConfigItemID,
            XMLDataGet   => 1,
        );

        # check for empty fields
        if (
            !$Preview
            && $Param{Restrictions}->{EmptyFields}
            && $Param{Restrictions}->{EmptyFields} eq 'Yes'
        ) {
            my $EmptyFieldFound = $Self->_CheckEmptyFields(
                XMLData       => $VersionRef->{XMLData}->[1]->{Version}->[1],
                XMLDefinition => $VersionRef->{XMLDefinition},
            );

            next if ( !$EmptyFieldFound );
        }

        my $ConfigItemRef = $ConfigItemObject->ConfigItemGet(
            ConfigItemID => $ConfigItemID,
        );

        ATTRIBUTE:
        for my $Attribute ( @{$SortedAttributesRef} ) {
            next ATTRIBUTE if (
                !$ConfigItemAttributes->{$Attribute}
                || !$SelectedAttributes{$Attribute}
            );

            my $AttValue = '';
            if ( $ConfigItemRef->{$Attribute} ) {
                $AttValue = $ConfigItemRef->{$Attribute};
            }
            if ( $VersionRef->{$Attribute} ) {
                $AttValue = $VersionRef->{$Attribute};
            }
            else {
                my $XMLAttValue = $ConfigItemObject->GetAttributeValuesByKey(
                    KeyName       => $Attribute,
                    XMLData       => $VersionRef->{XMLData}->[1]->{Version}->[1],
                    XMLDefinition => $VersionRef->{XMLDefinition},
                );
                if (
                    ref($XMLAttValue) eq 'ARRAY'
                    && scalar( @{$XMLAttValue} )
                ) {
                    $AttValue = join(', ', @{ $XMLAttValue } );
                }
            }

            # add the given TimeZone for time values
            if (
                $Param{TimeZone}
                && $AttValue
                && $AttValue =~ /(\d{4})-(\d{2})-(\d{2})\s(\d{2}):(\d{2}):(\d{2})/
            ) {
                $AttValue = $StatsObject->_AddTimeZone(
                    TimeStamp => $AttValue,
                    TimeZone  => $Param{TimeZone},
                );
                $AttValue .= " ($Param{TimeZone})";
            }
            push @ResultRow, $AttValue;
        }
        push @StatArray, \@ResultRow;
    }

    return @StatArray;
}

sub GetHeaderLine {
    my ( $Self, %Param ) = @_;

    my %SelectedAttributes   = map { $_ => 1 } @{ $Param{XValue}{SelectedValues} };
    my $ConfigItemAttributes = $Self->_ConfigItemAttributes();
    my $SortedAttributesRef  = $Self->_SortedAttributes();
    my @HeaderLine;

    # get language object
    my $LanguageObject = $Kernel::OM->Get('Kernel::Language');

    ATTRIBUTE:
    for my $Attribute ( @{$SortedAttributesRef} ) {
        next ATTRIBUTE if (
            !$ConfigItemAttributes->{$Attribute}
            || !$SelectedAttributes{$Attribute}
        );
        push @HeaderLine, $LanguageObject->Translate( $ConfigItemAttributes->{$Attribute} );
    }
    return \@HeaderLine;
}

sub ExportWrapper {
    my ( $Self, %Param ) = @_;

    return \%Param;
}

sub ImportWrapper {
    my ( $Self, %Param ) = @_;

    return \%Param;
}

sub _ConfigItemAttributes {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $GeneralCatalogObject = $Kernel::OM->Get('Kernel::System::GeneralCatalog');
    my $ConfigItemObject     = $Kernel::OM->Get('Kernel::System::ITSMConfigItem');

    # get class list
    my $ClassList = $GeneralCatalogObject->ItemList(
        Class => 'ITSM::ConfigItem::Class',
    );

    my %ConfigItemAttributes = (
        Class  => 'Class',
        Number => 'Number',
        Name   => 'Name',

        CurDeplState => 'Deployment State',
        CurInciState => 'Incident State',

        CurDeplStateType => 'Deployment State Type',
        CurInciStateType => 'Incident State Type',

        CreateTime => 'Create Time',
        ChangeTime => 'Change Time',
    );

    my %AttributeHash = ();
    CLASS:
    for my $ClassID ( keys( %{ $ClassList } ) ) {
        my $XMLDefinition = $ConfigItemObject->DefinitionGet(
            ClassID => $ClassID,
        );
        next CLASS if ( !$XMLDefinition->{Definition} );

        my @XMLAttributes = ();

        $Self->_XMLAttributesGet(
            XMLDefinition => $XMLDefinition->{DefinitionRef},
            XMLAttributes => \@XMLAttributes,
        );

        for my $Attribute (@XMLAttributes) {
            if ( !defined( $AttributeHash{Key}->{ $Attribute->{Key} } ) ) {
                $AttributeHash{Key}->{ $Attribute->{Key} }   = 1;
                $AttributeHash{Type}->{ $Attribute->{Key} }  = $Attribute->{Type};
                $AttributeHash{Value}->{ $Attribute->{Key} } = $Attribute->{Value};
            }
            elsif( $AttributeHash{Key}->{ $Attribute->{Key} } ) {
                if (
                    !$AttributeHash{Type}->{ $Attribute->{Key} }
                    || $AttributeHash{Type}->{ $Attribute->{Key} } eq $Attribute->{Type}
                ) {
                    $AttributeHash{Key}->{ $Attribute->{Key} } += 1;
                }
                else {
                    $AttributeHash{Key}->{ $Attribute->{Key} } = 0;
                }
            }
        }
    }

    for my $Attribute ( keys( %{ $AttributeHash{Key} } ) ) {
        if ( $AttributeHash{Key}->{ $Attribute } == keys( %{ $ClassList } ) ) {
            $ConfigItemAttributes{ $Attribute } = $AttributeHash{Value}->{ $Attribute };
        }
    }

    return \%ConfigItemAttributes;
}

sub _XMLAttributeRestrictionDefinition {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    return if ref $Param{XMLDefinition} ne 'ARRAY';
    return if ref $Param{XMLDefinitionRef} ne 'ARRAY';

    ITEM:
    for my $Item ( @{ $Param{XMLDefinitionRef} } ) {
        my $CurrDefItem;
        if ( ref( $Param{XMLDefinition} ) eq 'ARRAY' ) {
            DEFITEM:
            for my $DefItem ( @{ $Param{XMLDefinition} } ) {
                if (
                    $Item->{Key} eq $DefItem->{Key}
                    && $Item->{Input}->{Type} eq $DefItem->{Input}->{Type}
                ) {
                    $CurrDefItem = $DefItem;
                    if ( $DefItem->{Input}->{Type} eq 'GeneralCatalog' ) {
                        if ( ref( $DefItem->{Input}->{Class} ) eq 'ARRAY' ) {
                            push( @{ $DefItem->{Input}->{Class} }, $Item->{Input}->{Class} );
                        }
                        else {
                            $DefItem->{Input}->{Class} = [
                                $DefItem->{Input}->{Class},
                                $Item->{Input}->{Class}
                            ];
                        }
                    }
                    last DEFITEM;
                }
            }
        }
        if ( !defined( $CurrDefItem ) ) {
            my %TempItem = %{ $Item };
            delete( $TempItem{Sub} );
            $CurrDefItem = \%TempItem;
            push( @{ $Param{XMLDefinition} }, $CurrDefItem );
        }

        next ITEM if !$Item->{Sub};

        if ( !defined( $CurrDefItem->{Sub} ) ) {
            $CurrDefItem->{Sub} = [];
        }

        # start recursion, if "Sub" was found
        $Self->_XMLAttributeRestrictionDefinition(
            XMLDefinitionRef => $Item->{Sub},
            XMLDefinition    => $CurrDefItem->{Sub},
        );
    }

    return 1;
}

sub _SortedAttributes {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $GeneralCatalogObject = $Kernel::OM->Get('Kernel::System::GeneralCatalog');
    my $ConfigItemObject     = $Kernel::OM->Get('Kernel::System::ITSMConfigItem');

    # get class list
    my $ClassList = $GeneralCatalogObject->ItemList(
        Class => 'ITSM::ConfigItem::Class',
    );

    my @SortedAttributes = qw(
        Class
        Number
        Name
        CurDeplState
        CurDeplStateType
        CurInciState
        CurInciStateType
        CreateTime
        ChangeTime
    );

    my %AttributeCounter = ();
    CLASS:
    for my $ClassID ( keys( %{ $ClassList } ) ) {
        my $XMLDefinition = $ConfigItemObject->DefinitionGet(
            ClassID => $ClassID,
        );
        next CLASS if ( !$XMLDefinition->{Definition} );

        my @XMLAttributes = ();

        $Self->_XMLAttributesGet(
            XMLDefinition => $XMLDefinition->{DefinitionRef},
            XMLAttributes => \@XMLAttributes,
        );

        for my $Attribute (@XMLAttributes) {
            if ( $AttributeCounter{ $Attribute->{Key} } ) {
                $AttributeCounter{ $Attribute->{Key} } += 1;
            }
            else {
                $AttributeCounter{ $Attribute->{Key} } = 1;
            }
        }
    }

    for my $Attribute ( sort( keys( %AttributeCounter ) ) ) {
        if ( $AttributeCounter{ $Attribute } == keys( %{ $ClassList } ) ) {
            push( @SortedAttributes, $Attribute );
        }
    }

    return \@SortedAttributes;
}

sub _CheckEmptyFields {
    my ( $Self, %Param ) = @_;

    # check required params...
    if (
        !$Param{XMLDefinition}
        || ref $Param{XMLDefinition} ne 'ARRAY'
    ) {
        return;
    }

    ITEM:
    for my $Item ( @{ $Param{XMLDefinition} } ) {

        COUNTER:
        for my $Counter ( 1 .. $Item->{CountMax} ) {

            # no content then stop loop...
            return 1 if (
                !defined $Param{XMLData}
                || !defined $Param{XMLData}->{ $Item->{Key} }
                || !defined $Param{XMLData}->{ $Item->{Key} }->[$Counter]
                || !defined $Param{XMLData}->{ $Item->{Key} }->[$Counter]->{Content}
            );

            next COUNTER if !$Item->{Sub};

            #recurse if subsection available...
            my $SubResult = $Self->_CheckEmptryFields(
                XMLDefinition => $Item->{Sub},
                XMLData       => $Param{XMLData}->{ $Item->{Key} }->[$Counter],
            );

            if ( $SubResult ) {
                return 1;
            }
        }
    }

    return 0;
}

sub _XMLAttributesGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    return if !$Param{XMLDefinition};
    return if ref $Param{XMLDefinition} ne 'ARRAY';
    return if ref $Param{XMLAttributes} ne 'ARRAY';

    ITEM:
    for my $Item ( @{ $Param{XMLDefinition} } ) {

        # set prefix
        my $InputKey = $Item->{Key};
        my $Name     = $Item->{Name};
        my $Type     = $Item->{Input}->{Type};

        # store attribute, if marked as searchable
        push @{ $Param{XMLAttributes} }, {
            Key   => $InputKey,
            Value => $Name,
            Type  => $Type,
        };

        next ITEM if !$Item->{Sub};

        # start recursion, if "Sub" was found
        $Self->_XMLAttributesGet(
            XMLDefinition => $Item->{Sub},
            XMLAttributes => $Param{XMLAttributes},
        );
    }

    return 1;
}

sub _XMLAttributeAdd {
    my ( $Self, %Param ) = @_;

    return if !$Param{ObjectAttributes};
    return if !$Param{ConfigItemAttributes};
    return if !$Param{XMLDefinition};
    return if ref $Param{XMLDefinition} ne 'ARRAY';

    ITEM:
    for my $Item ( @{ $Param{XMLDefinition} } ) {

        next ITEM if !$Item->{Searchable} && !$Item->{Sub};

        # create key and name
        my $Key  = $Item->{Key};
        my $Name = $Item->{Name};

        # add attribute
        my $Attribute = $Kernel::OM->Get('Kernel::System::ITSMConfigItem')->XMLStatsAttributeCreate(
            Key  => $Key,
            Item => $Item,
            Name => $Name,
        );

        next ITEM if !$Attribute;
        next ITEM if ref $Attribute ne 'ARRAY';
        next ITEM if !scalar @{$Attribute};

        # disable x and y axis for attribute
        for my $Entry ( @{ $Attribute } ) {
            $Entry->{UseAsXvalue}      = 0;
            $Entry->{UseAsValueSeries} = 0;
        }

        # add attributes to object array
        if ( $Param{ConfigItemAttributes}->{ $Key } ) {
            push @{ $Param{ObjectAttributes} }, @{$Attribute};
        }

        next ITEM if !$Item->{Sub};

        # start recursion, if "Sub" was found
        $Self->_XMLAttributeAdd(
            ObjectAttributes     => $Param{ObjectAttributes},
            ConfigItemAttributes => $Param{ConfigItemAttributes},
            XMLDefinition        => $Item->{Sub},
        );
    }

    return 1;
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
