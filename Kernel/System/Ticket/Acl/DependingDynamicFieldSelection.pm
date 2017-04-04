# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::Acl::DependingDynamicFieldSelection;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Cache',
    'Kernel::System::DependingDynamicField',
    'Kernel::System::DynamicField',
    'Kernel::System::DynamicField::Backend',
    'Kernel::System::Log',
    'Kernel::System::Ticket',
);

use JSON::XS;
use Digest::MD5 qw(md5_hex);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # create required objects
    $Self->{CacheObject}               = Kernel::System::Cache->new( %{$Self} );
    $Self->{ConfigObject}              = $Kernel::OM->Get('Kernel::Config');
    $Self->{DynamicFieldObject}        = $Kernel::OM->Get('Kernel::System::DynamicField');
    $Self->{DynamicFieldBackendObject} = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');
    $Self->{DependingDynamicFieldObject}
        = $Kernel::OM->Get('Kernel::System::DependingDynamicField');
    $Self->{LogObject}    = $Kernel::OM->Get('Kernel::System::Log');
    $Self->{TicketObject} = $Kernel::OM->Get('Kernel::System::Ticket');

    $Self->{CacheType} = 'DependingDynamicFieldACL';

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ReturnSubType ReturnType)) {
        if ( !defined( $Param{$_} ) ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    return
        if (
        defined $Param{Action}
        && ( $Param{Action} eq 'AgentTicketSearch' || $Param{Action} eq 'CustomerTicketSearch' )
        );

    my %PossibleValues;
    my $AvailableDynamicFields;

    if ( $Param{ReturnSubType} =~ m/^DynamicField_(.*)$/ ) {

        # get data of given dynamic field - used to get DynamicFieldID
        my $DynamicFieldName = $1;
        my $DynamicFieldData
            = $Self->{DynamicFieldObject}->DynamicFieldGet( Name => $DynamicFieldName );
        my $DynamicFieldID = $DynamicFieldData->{ID};

        # get config
        if ( $Param{Action} ) {

            # only get DFs configure for this action
            $Self->{Config}       = $Self->{ConfigObject}->Get("Ticket::Frontend::$Param{Action}");
            $Self->{DynamicField} = $Self->{DynamicFieldObject}->DynamicFieldListGet(
                Valid       => 1,
                ObjectType  => [ 'Ticket', 'Article' ],
                FieldFilter => $Self->{Config}->{DynamicField} || {},
            );
        }
        else {

            # get all DFs (i.e. AgentTicketProcess, CustomerTicketProcess, ...)
            $Self->{DynamicField} = $Self->{DynamicFieldObject}->DynamicFieldListGet(
                Valid => 1,
                ObjectType => [ 'Ticket', 'Article' ],
            );
        }

        # get ticket data if ID given
        my %Ticket;
        if ( $Param{TicketID} ) {
            %Ticket = $Self->{TicketObject}->TicketGet(
                TicketID      => $Param{TicketID},
                DynamicFields => 1,
            );
        }

        # get sorted list of possible depending dynamic fields
        my @DynamicFieldList;
        my %DefaultDynamicField;
        my %SelectedValues;    # DynamicField_name = Key1;

        # get selected values from ticket hash
        for my $Field ( @{ $Self->{DynamicField} } ) {
            next
                if (
                defined $Field->{Config}->{DisplayFieldType}
                && $Field->{Config}->{DisplayFieldType} eq 'Multiselect'
                );
            next
                if (
                !defined $Field->{Config}->{DisplayFieldType}
                && $Field->{FieldType} !~ /^Dropdown/
                );

            push @DynamicFieldList, $Field->{ID};
            if ( $Param{TicketID} && ref \%Ticket eq 'HASH' ) {
                $DefaultDynamicField{ 'DynamicField_' . $Field->{Name} } =
                    $Ticket{ 'DynamicField_' . $Field->{Name} };
            }
        }

        # if no selected dynamic fields given, use values from ticket hash
        $Param{DynamicFieldList} = \@DynamicFieldList;    # [1,2,5,6...]
        if ( !defined $Param{DynamicField} || !%{ $Param{DynamicField} } ) {
            %SelectedValues = %DefaultDynamicField
        }
        else {
            %SelectedValues = %{ $Param{DynamicField} };
            for my $Field ( keys %DefaultDynamicField ) {
                if ( !defined $SelectedValues{$Field} ) {
                    $SelectedValues{$Field} = $DefaultDynamicField{$Field};
                }
            }
        }

        # get dependencies
        my $Count = 0;
        while (
            $Count < scalar @{ $Param{DynamicFieldList} }
            )
        {

            # get branches of given dynamic field, e.g. (1 -> 3 -> 2) = [2,3,1]
            my @DependencyList
                = @{
                $Self->{DependingDynamicFieldObject}
                    ->DependencyList(
                    DynamicFieldID => $Param{DynamicFieldList}->[$Count],
                    ValidID        => 1
                    )
                };

            # look up DynamicFieldID in DependencyList
            if ( grep {/$DynamicFieldID/} @DependencyList ) {
                $DynamicFieldData
                    = $Self->{DynamicFieldObject}
                    ->DynamicFieldGet( ID => $Param{DynamicFieldList}->[$Count] );
                $DynamicFieldName = $DynamicFieldData->{Name};

                # if found set Count to max
                $Count = scalar @{ $Param{DynamicFieldList} };
            }
            $Count++;
        }

        # dynamic field found in dependency list
        if ( $DynamicFieldData && ref $DynamicFieldData eq 'HASH' )
        {
            my $DynamicFieldID = $DynamicFieldData->{ID};

            # get config
            if ( $Param{Action} ) {

                # only get DFs configure for this action
                my $Config = $Self->{ConfigObject}->Get("Ticket::Frontend::$Param{Action}");
                $AvailableDynamicFields = $Self->{DynamicFieldObject}->DynamicFieldListGet(
                    Valid       => 1,
                    ObjectType  => [ 'Ticket', 'Article' ],
                    FieldFilter => $Config->{DynamicField} || {},
                );
            }
            else {

                # get all DFs
                $AvailableDynamicFields = $Self->{DynamicFieldObject}->DynamicFieldListGet(
                    Valid => 1,
                    ObjectType => [ 'Ticket', 'Article' ],
                );
            }

            # get possible depending dynamic fields for current action
            my @UsedDynamicFields;
            for my $Hash ( @{$AvailableDynamicFields} ) {
                if (
                    $Hash->{FieldType} =~ /^Dropdown/
                    || (
                        defined $Hash->{Config}->{DisplayFieldType}
                        && $Hash->{Config}->{DisplayFieldType} ne 'Multiselect'
                    )
                    )
                {
                    push @UsedDynamicFields, $Hash->{ID};
                }
            }

            # get possible values depending on given depending field
            if ( grep {$DynamicFieldID} @UsedDynamicFields ) {
                %PossibleValues = (
                    %PossibleValues,
                    %{
                        $Self->_GetChild(
                            ParentID         => 0,
                            SelectedValues   => \%SelectedValues,
                            DynamicFieldName => $DynamicFieldName,
                            NextEmpty        => 0,
                            PossibleValues   => \%PossibleValues,
                            )
                        }
                );
            }
        }
    }

    # create PossibleNOT
    my %PossibleNotValues;
    for my $DynamicField ( keys %PossibleValues ) {

        # get name
        $DynamicField =~ /^DynamicField_(.*)/;
        my $DynamicFieldName = $1;

        # get all possible values
        my $AllPossibleValues;
        for my $AvailableFieldHash ( @{$AvailableDynamicFields} ) {
            next if $AvailableFieldHash->{Name} ne $DynamicFieldName;
            $AllPossibleValues = $Self->{DynamicFieldBackendObject}->PossibleValuesGet(
                DynamicFieldConfig    => $AvailableFieldHash,
                GetAutocompleteValues => 1
            );
            last;
        }

        # add values to possible not hash (keys added, new handling of acl-data)
        for my $Value ( keys %{$AllPossibleValues} ) {

            # mask speacial chars with backslash
            my $SpecialCharacters = '\\' . join '\\', keys %{ $Self->_SpecialCharactersGet() };
            $AllPossibleValues->{$Value} =~ s{(?<!\\)([$SpecialCharacters])}{\\$1}smxg;
            next if grep {/^$AllPossibleValues->{$Value}$/} @{ $PossibleValues{$DynamicField} };
            push @{ $PossibleNotValues{$DynamicField} }, $Value;
        }
    }

    # build ACL
    $Param{Acl}->{'990_DependingDynamicFieldSelection'} = {
        PossibleNot => {
            Ticket => {
                %PossibleNotValues
            },
        },
        StopAfterMatch => 1,
    };

    return 1;
}

sub _GetChild {
    my ( $Self, %Param ) = @_;

    my $CheckSum;

    # check cache
    if ( !$Param{ParentID} && $Self->{CacheObject} ) {
        $CheckSum = md5_hex( encode_json( \%Param ) );
        my $Hash = $Self->{CacheObject}->Get(
            Type => $Self->{CacheType},
            Key  => "GetChild::$CheckSum",
        );
        return $Hash if defined $Hash;
    }

    my $PossibleValues = $Param{PossibleValues};
    my %ResultHash;

    # get dynamic field data to get ID
    my $DynamicFieldID;

    if ( $Param{DynamicFieldName} ) {
        my $DynamicFieldData
            = $Self->{DynamicFieldObject}->DynamicFieldGet(
            Name => $Param{DynamicFieldName}
            );
        $DynamicFieldID = $DynamicFieldData->{ID};
    }

    # get all dynamic fields depending on given dynamic field id
    my $DependingFields
        = $Self->{DependingDynamicFieldObject}->DependingDynamicFieldListGet(
        ParentID       => $Param{ParentID},
        DynamicFieldID => $DynamicFieldID || '',
        ValidID        => 1
        );

    # get child values
    if ( scalar @{$DependingFields} ) {

        my %DynamicFieldData;
        my %TmpResultHash;
        my %CountHash;

        # for each child hash
        for my $Field ( @{$DependingFields} ) {

            if ( !defined $CountHash{ 'DynamicField_' . $Field->{Name} } ) {
                $CountHash{ 'DynamicField_' . $Field->{Name} } = 0;
            }

            # first insert empty values
            if ( !$CountHash{ 'DynamicField_' . $Field->{Name} } ) {

                my @EmptyArray;

                # get dynamic field data (used for possible values / object type)
                $DynamicFieldData{ 'DynamicField_' . $Field->{Name} }
                    = $Self->{DynamicFieldObject}->DynamicFieldGet(
                    Name => $Field->{Name}
                    );

                # add empty array
                $TmpResultHash{ 'DynamicField_' . $Field->{Name} } = \@EmptyArray;

                # add '-' value if 'possible none' active
                if (
                    !$Param{NextEmpty}
                    && $DynamicFieldData{ 'DynamicField_' . $Field->{Name} }->{Config}
                    ->{PossibleNone}
                    )
                {
                    push @{ $TmpResultHash{ 'DynamicField_' . $Field->{Name} } }, '-';
                }

                $CountHash{ 'DynamicField_' . $Field->{Name} }++;
            }

            # if next node not empty add possible values
            if ( !$Param{NextEmpty} ) {
                my $Values = $Self->{DynamicFieldBackendObject}->PossibleValuesGet(
                    DynamicFieldConfig    => $DynamicFieldData{ 'DynamicField_' . $Field->{Name} },
                    GetAutocompleteValues => 1
                );
                push @{ $TmpResultHash{ 'DynamicField_' . $Field->{Name} } },
                    $Values->{ $Field->{Value} } || '';
            }

        }

        # if there are more depending fields - check each child node of given dynamic field
        my %ChildHash;
        for my $Field ( @{$DependingFields} ) {

            my %TmpChildHash = %ChildHash;

            # check if item is selected
            if (
                defined $Param{SelectedValues}->{ 'DynamicField_' . $Field->{Name} }
                && $Param{SelectedValues}->{ 'DynamicField_' . $Field->{Name} } eq
                $Field->{Value}
                && !$Param{NextEmpty}
                )
            {
                %ChildHash =
                    %{
                    $Self->_GetChild(
                        ParentID       => $Field->{ID},
                        SelectedValues => $Param{SelectedValues},
                        NextEmpty      => 0,
                        PossibleValues => $PossibleValues,
                        )
                    };
            }
            else {
                %ChildHash =
                    %{
                    $Self->_GetChild(
                        ParentID       => $Field->{ID},
                        SelectedValues => $Param{SelectedValues},
                        NextEmpty      => 1,
                        PossibleValues => $PossibleValues,
                        )
                    };
            }

            # merge child hashes
            for my $HashItem ( keys %TmpChildHash ) {
                if (
                    !defined $ChildHash{$HashItem}
                    || ref $ChildHash{$HashItem} ne 'ARRAY'
                    || !scalar @{ $ChildHash{$HashItem} }
                    )
                {
                    $ChildHash{$HashItem} = $TmpChildHash{$HashItem};
                }
            }
        }

        # merge result hashes
        %ResultHash = %ChildHash;
        for my $HashItem ( keys %TmpResultHash ) {
            if (
                !defined $ResultHash{$HashItem}
                || ref $ResultHash{$HashItem} ne 'ARRAY'
                || !scalar @{ $ResultHash{$HashItem} }
                )
            {
                $ResultHash{$HashItem} = $TmpResultHash{$HashItem};
            }
        }
    }

    # cache request
    if ( !$Param{ParentID} && $Self->{CacheObject} ) {
        $Self->{CacheObject}->Set(
            Type  => $Self->{CacheType},
            Key   => "GetChild::$CheckSum",
            Value => \%ResultHash,
            TTL   => 5 * 60,
        );
    }

    return \%ResultHash;
}

sub _SpecialCharactersGet {
    my ( $Self, %Param ) = @_;

    my %SpecialCharacter = (
        '(' => 1,
        ')' => 1,
        '&' => 1,
        '|' => 1,
        '+' => 1,
        '*' => 1,
    );

    return \%SpecialCharacter;
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
