# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::ITSMConfigItem::LayoutCIClassReference;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::Language',
    'Kernel::Output::HTML::Layout',
    'Kernel::System::GeneralCatalog',
    'Kernel::System::ITSMConfigItem',
    'Kernel::System::Log',
    'Kernel::System::Web::Request',
);

=head1 NAME

Kernel::Output::HTML::ITSMConfigItemLayoutCIClassReference - layout backend module

=head1 SYNOPSIS

All layout functions of CIClassReference objects

=over 4

=cut

=item new()

create an object

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $BackendObject = $Kernel::OM->Get('Kernel::Output::HTML::ITSMConfigItemLayoutCIClassReference');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    #allocate new hash for object...
    my $Self = {};
    bless( $Self, $Type );

    $Self->{CIClassReferenceClassID} = 0;

    $Self->{ConfigObject}         = $Kernel::OM->Get('Kernel::Config');
    $Self->{LanguageObject}       = $Kernel::OM->Get('Kernel::Language');
    $Self->{LayoutObject}         = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    $Self->{GeneralCatalogObject} = $Kernel::OM->Get('Kernel::System::GeneralCatalog');
    $Self->{ConfigItemObject}     = $Kernel::OM->Get('Kernel::System::ITSMConfigItem');
    $Self->{LogObject}            = $Kernel::OM->Get('Kernel::System::Log');
    $Self->{ParamObject}          = $Kernel::OM->Get('Kernel::System::Web::Request');

    return $Self;
}

=item OutputStringCreate()

create output string

    my $Value = $BackendObject->OutputStringCreate(
        Value => 11,       # (optional)
    );

=cut

sub OutputStringCreate {
    my ( $Self, %Param ) = @_;

    #transform ascii to html...
    $Param{Value} = $Self->{LayoutObject}->Ascii2Html(
        Text => $Param{Value} || '',
        HTMLResultMode => 1,
    );

    return $Param{Value};
}

=item FormDataGet()

get form data as hash reference

    my $FormDataRef = $BackendObject->FormDataGet(
        Key => 'Item::1::Node::3',
        Item => $ItemRef,
    );

=cut

sub FormDataGet {
    my ( $Self, %Param ) = @_;

    #check needed stuff...
    for my $Argument (qw(Key Item)) {
        if ( !$Param{$Argument} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Need $Argument!"
            );
            return;
        }
    }

    my %FormData;

    #get selected CIClassReference...
    $FormData{Value} = $Self->{ParamObject}->GetParam( Param => $Param{Key} );

    #check search button..
    if ( $Self->{ParamObject}->GetParam( Param => $Param{Key} . '::ButtonSearch' ) ) {
        $Param{Item}->{Form}->{ $Param{Key} }->{Search}
            = $Self->{ParamObject}->GetParam( Param => $Param{Key} . '::Search' );
    }

    #check select button...
    elsif ( $Self->{ParamObject}->GetParam( Param => $Param{Key} . '::ButtonSelect' ) ) {
        $FormData{Value} = $Self->{ParamObject}->GetParam( Param => $Param{Key} . '::Select' );
    }

    #check clear button...
    elsif ( $Self->{ParamObject}->GetParam( Param => $Param{Key} . '::ButtonClear' ) ) {
        $FormData{Value} = '';
    }
    else {

        #reset value if search field is empty...
        if (
            !$Self->{ParamObject}->GetParam( Param => $Param{Key} . '::Search' )
            && defined $FormData{Value}
        ) {
            $FormData{Value} = '';
        }

        #check required option...
        if ( $Param{Item}->{Input}->{Required} && !$FormData{Value} ) {
            $Param{Item}->{Form}->{ $Param{Key} }->{Invalid} = 1;
            $FormData{Invalid} = 1;
        }
    }

    return \%FormData;
}

=item InputCreate()

create a input string

    my $Value = $BackendObject->InputCreate(
        Key => 'Item::1::Node::3',
        Value => 11,       # (optional)
        Item => $ItemRef,
    );

=cut

sub InputCreate {
    my ( $Self, %Param ) = @_;

    #check needed stuff...
    for my $Argument (qw(Key Item)) {
        if ( !$Param{$Argument} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Need $Argument!"
            );
            return;
        }
    }

    my $Value = '';
    if ( defined $Param{Value} ) {
        $Value = $Param{Value};
    }
    elsif ( $Param{Item}->{Input}->{ValueDefault} ) {
        $Value = $Param{Item}->{Input}->{ValueDefault};
    }

    # get class list
    my $ClassList = $Self->{GeneralCatalogObject}->ItemList(
        Class => 'ITSM::ConfigItem::Class',
    );

    # check for access rights on the classes
    for my $ClassID ( sort keys %{$ClassList} ) {
        my $HasAccess = $Self->{ConfigItemObject}->Permission(
            Type    => 'ro',
            Scope   => 'Class',
            ClassID => $ClassID,
            UserID  => $Self->{UserID} || 1,
        );

        delete $ClassList->{$ClassID} if !$HasAccess;
    }

    my @ClassIDArray = ();
    if ($Param{Item}->{Input}->{ReferencedCIClassID}) {
        if ($Param{Item}->{Input}->{ReferencedCIClassID} eq 'All') {
            @ClassIDArray = keys %{$ClassList};
        }
        else {
            my @TempClassIDArray = split( /\s*,\s*/, $Param{Item}->{Input}->{ReferencedCIClassID});
            for my $ClassID ( @TempClassIDArray ) {
                if ( $ClassList->{$ClassID} ) {
                    push( @ClassIDArray, $ClassID );
                }
            }
        }
    }
    elsif ($Param{Item}->{Input}->{ReferencedCIClassName}) {
        if ($Param{Item}->{Input}->{ReferencedCIClassName} eq 'All') {
            @ClassIDArray = keys %{$ClassList};
        }
        else {
            my @ClassNameArray = split( /\s*,\s*/, $Param{Item}->{Input}->{ReferencedCIClassName});
            CLASSNAME:
            for my $ClassName ( @ClassNameArray ) {
                if ( !$ClassName ) {
                    @ClassIDArray = ();
                    last CLASSNAME;
                }

                my $ItemDataRef = $Self->{GeneralCatalogObject}->ItemGet(
                    Class => 'ITSM::ConfigItem::Class',
                    Name  => $ClassName,
                );
                if (
                    $ItemDataRef
                    && ref($ItemDataRef) eq 'HASH'
                    && $ItemDataRef->{ItemID}
                    && $ClassList->{$ItemDataRef->{ItemID}}
                ) {
                    push( @ClassIDArray, $ItemDataRef->{ItemID} );
                }
                else {
                    @ClassIDArray = ();
                    last CLASSNAME;
                }
            }
        }
    }
    if ( !@ClassIDArray ) {
        push( @ClassIDArray, '0');
    }

    my $Size         = $Param{Item}->{Input}->{Size} || 50;
    my $Search       = '';
    my $StringOption = '';
    my $StringSelect = '';

    # AutoComplete CIClass
    my $Class = 'W50pc CIClassSearch';

    my $Required = $Param{Required} || '';
    my $Invalid  = $Param{Invalid}  || '';

    if ($Required) {
        $Class .= ' Validate_Required';
    }

    if ($Invalid) {
        $Class .= ' ServerError';
    }

    # CIClassReference search...
    if ( $Param{Item}->{Form}->{ $Param{Key} }->{Search} ) {

        #-----------------------------------------------------------------------
        # search for name....
        my %CISearchList    = ();
        my $CISearchListRef = $Self->{ConfigItemObject}->ConfigItemSearchExtended(
            Name     => '*' . $Param{Item}->{Form}->{ $Param{Key} }->{Search} . '*',
            ClassIDs => \@ClassIDArray,
        );

        for my $SearchResult ( @{$CISearchListRef} ) {
            my $CurrVersionData = $Self->{ConfigItemObject}->VersionGet(
                ConfigItemID => $SearchResult,
                XMLDataGet   => 0,
            );
            if (
                $CurrVersionData
                &&
                ( ref($CurrVersionData) eq 'HASH' ) &&
                $CurrVersionData->{Name} &&
                $CurrVersionData->{Number}
            ) {
                $CISearchList{$SearchResult} = $CurrVersionData->{Name}
                    . " ("
                    . $CurrVersionData->{Number}
                    . ")";
            }
        }

        #-----------------------------------------------------------------------
        # search for number....
        $CISearchListRef = $Self->{ConfigItemObject}->ConfigItemSearchExtended(
            Number   => '*' . $Param{Item}->{Form}->{ $Param{Key} }->{Search} . '*',
            ClassIDs => \@ClassIDArray,
        );

        for my $SearchResult ( @{$CISearchListRef} ) {
            my $CurrVersionData = $Self->{ConfigItemObject}->VersionGet(
                ConfigItemID => $SearchResult,
                XMLDataGet   => 0,
            );
            if (
                $CurrVersionData
                &&
                ( ref($CurrVersionData) eq 'HASH' ) &&
                $CurrVersionData->{Name} &&
                $CurrVersionData->{Number}
            ) {
                $CISearchList{$SearchResult} = $CurrVersionData->{Name}
                    . " ("
                    . $CurrVersionData->{Number}
                    . ")";
            }
        }

        #-----------------------------------------------------------------------
        # build search result presentation....
        if ( %CISearchList && scalar( keys %CISearchList ) > 1 ) {

            #create option list...
            $StringOption = $Self->{LayoutObject}->BuildSelection(
                Name => $Param{Key} . '::Select',
                Data => \%CISearchList,
            );
            $StringOption .= '<br>';

            #create select button...
            $StringSelect = '<input class="button" type="submit" name="'
                . $Param{Key}
                . '::ButtonSelect" '
                . 'value="'
                . $Self->{LanguageObject}->Translate( "Select" )
                . '">&nbsp;';

            #set search...
            $Search = $Param{Item}->{Form}->{ $Param{Key} }->{Search};
        }
        elsif (%CISearchList) {

            $Value = ( keys %CISearchList )[0];
            my $CIVersionDataRef = $Self->{ConfigItemObject}->VersionGet(
                ConfigItemID => $Value,
                XMLDataGet   => 0,
            );
            my $CIName = "";

            if (
                $CIVersionDataRef
                &&
                ( ref($CIVersionDataRef) eq 'HASH' ) &&
                $CIVersionDataRef->{Name} &&
                $CIVersionDataRef->{Number}
            ) {
                $CIName = $CIVersionDataRef->{Name}
                    . " ("
                    . $CIVersionDataRef->{Number}
                    . ")";
            }

            #transform ascii to html...
            $Search = $Self->{LayoutObject}->Ascii2Html(
                Text => $CIName || '',
                HTMLResultMode => 1,
            );
        }

    }

    #create CIClassReference string...
    elsif ($Value) {

        my $CIVersionDataRef = $Self->{ConfigItemObject}->VersionGet(
            ConfigItemID => $Value,
            XMLDataGet   => 0,
        );
        my $CIName = "";

        if (
            $CIVersionDataRef
            &&
            ( ref($CIVersionDataRef) eq 'HASH' ) &&
            $CIVersionDataRef->{Name} &&
            $CIVersionDataRef->{Number}
        ) {
            $CIName = $CIVersionDataRef->{Name}
                . " ("
                . $CIVersionDataRef->{Number}
                . ")";
        }

        #transform ascii to html...
        $Search = $Self->{LayoutObject}->Ascii2Html(
            Text => $CIName || '',
            HTMLResultMode => 1,
        );
    }

    # AutoComplete CIClass
    my $AutoCompleteConfig =
        $Self->{ConfigObject}->Get('ITSMCIAttributeCollection::Frontend::CommonSearchAutoComplete');

    #create string...
    my $String = '';
    if (
        $AutoCompleteConfig
        && ref($AutoCompleteConfig) eq 'HASH'
        && $AutoCompleteConfig->{Active}
    ) {
        my $ItemId = $Param{ItemId} || '';

        $Self->{LayoutObject}->Block(
            Name => 'CIClassSearchAutoComplete',
            Data => {
                minQueryLength      => $AutoCompleteConfig->{MinQueryLength}      || 2,
                queryDelay          => $AutoCompleteConfig->{QueryDelay}          || 0.1,
                maxResultsDisplayed => $AutoCompleteConfig->{MaxResultsDisplayed} || 20,
                dynamicWidth        => $AutoCompleteConfig->{DynamicWidth}        || 1,
            },
        );
        $Self->{LayoutObject}->Block(
            Name => 'CIClassSearchInit',
            Data => {
                ItemID             => $ItemId,
                ClassID            => join(',', @ClassIDArray),
                ActiveAutoComplete => 'true',
            },
        );

        $String = $Self->{LayoutObject}->Output(
            TemplateFile => 'AgentCIClassSearch',
        );
        $String .= '<input type="hidden" name="'
            . $Param{Key}
            . '" value="'
            . $Value
            . '" id="'
            . $ItemId . 'Selected'
            . '"/>'
            . '<input type="text" name="'
            . $Param{Key}
            . '::Search" class="'
            . $Class
            . '" id="'
            . $ItemId
            . '" classid="'
            . join(',', @ClassIDArray)
            . '" SearchClass="CIClassSearch" value="'
            . $Search . '"/>';
    }
    else {
        $String = '<input type="hidden" name="'
            . $Param{Key}
            . '" value="'
            . $Value
            . '">'
            . '<input type="Text" name="'
            . $Param{Key}
            . '::Search" size="'
            . $Size
            . '" value="'
            . $Search . '">' . '<br>'
            . $StringOption
            . $StringSelect
            . '<input class="button" type="submit" name="'
            . $Param{Key}
            . '::ButtonSearch" value="'
            . $Self->{LanguageObject}->Translate( "Search" )
            . '">'
            . '&nbsp;'
            . '<input class="button" type="submit" name="'
            . $Param{Key}
            . '::ButtonClear" value="'
            . $Self->{LanguageObject}->Translate( "Clear" )
            . '">';
    }

    return $String;
}

=item SearchFormDataGet()

get search form data

    my $Value = $BackendObject->SearchFormDataGet(
        Key => 'Item::1::Node::3',
        Item => $ItemRef,
    );

=cut

sub SearchFormDataGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(Key Item)) {
        if ( !$Param{$Argument} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    if (
        $Param{Item}->{Input}->{SearchInputType}
        && $Param{Item}->{Input}->{SearchInputType} eq 'Pattern'
    ) {

        my @Values = qw{};
        if ( ref($Param{Value}) eq 'ARRAY' ) {
            @Values = @{ $Param{Value} };
        } else {
            # get class list
            my $ClassList = $Self->{GeneralCatalogObject}->ItemList(
                Class => 'ITSM::ConfigItem::Class',
            );

            # check for access rights on the classes
            for my $ClassID ( sort keys %{$ClassList} ) {
                my $HasAccess = $Self->{ConfigItemObject}->Permission(
                    Type    => 'ro',
                    Scope   => 'Class',
                    ClassID => $ClassID,
                    UserID  => $Self->{UserID} || 1,
                );

                delete $ClassList->{$ClassID} if !$HasAccess;
            }

            my @ClassIDArray = ();
            if ($Param{Item}->{Input}->{ReferencedCIClassID}) {
                if ($Param{Item}->{Input}->{ReferencedCIClassID} eq 'All') {
                    @ClassIDArray = keys %{$ClassList};
                }
                else {
                    my @TempClassIDArray = split( /\s*,\s*/, $Param{Item}->{Input}->{ReferencedCIClassID});
                    for my $ClassID ( @TempClassIDArray ) {
                        if ( $ClassList->{$ClassID} ) {
                            push( @ClassIDArray, $ClassID );
                        }
                    }
                }
            }
            elsif ($Param{Item}->{Input}->{ReferencedCIClassName}) {
                if ($Param{Item}->{Input}->{ReferencedCIClassName} eq 'All') {
                    @ClassIDArray = keys %{$ClassList};
                }
                else {
                    my @ClassNameArray = split( /\s*,\s*/, $Param{Item}->{Input}->{ReferencedCIClassName});
                    CLASSNAME:
                    for my $ClassName ( @ClassNameArray ) {
                        if ( !$ClassName ) {
                            @ClassIDArray = ();
                            last CLASSNAME;
                        }

                        my $ItemDataRef = $Self->{GeneralCatalogObject}->ItemGet(
                            Class => 'ITSM::ConfigItem::Class',
                            Name  => $ClassName,
                        );
                        if (
                            $ItemDataRef
                            && ref($ItemDataRef) eq 'HASH'
                            && $ItemDataRef->{ItemID}
                            && $ClassList->{$ItemDataRef->{ItemID}}
                        ) {
                            push( @ClassIDArray, $ItemDataRef->{ItemID} );
                        }
                        else {
                            @ClassIDArray = ();
                            last CLASSNAME;
                        }
                    }
                }
            }
            if ( !@ClassIDArray ) {
                push( @ClassIDArray, '0');
            }

            my $SearchValue = $Self->{ParamObject}->GetParam( Param => $Param{Key} ) || '';

            my @SearchValueParts = split('\|\|', $SearchValue);

            SEARCHVALUEPART:
            for my $CurrSearchValuePart (@SearchValueParts) {
                next SEARCHVALUEPART if (!$CurrSearchValuePart);

                # check pattern for id
                if ($CurrSearchValuePart =~ m/^\[ID\]([0-9]+)$/i) {
                    push(@Values, $1);

                    next SEARCHVALUEPART;
                }

                if ($CurrSearchValuePart =~ m/^\[Number\]([0-9*]+)$/i) {
                    my $CISearchListRef = $Self->{ConfigItemObject}->ConfigItemSearchExtended(
                        Number   => $1,
                        ClassIDs => \@ClassIDArray,
                    );
                    for my $SearchResult ( @{$CISearchListRef} ) {
                        push(@Values, $SearchResult);
                    }

                    next SEARCHVALUEPART;
                }

                my $CISearchListRef = $Self->{ConfigItemObject}->ConfigItemSearchExtended(
                    Name     => $CurrSearchValuePart,
                    ClassIDs => \@ClassIDArray,
                );
                for my $SearchResult ( @{$CISearchListRef} ) {
                    push(@Values, $SearchResult);
                }
            }
        }

        return \@Values;
    } else {

        # get form data
        my $Value;
        if ( $Param{Value} ) {
            $Value = $Param{Value};
        }
        else {
            $Value = $Self->{ParamObject}->GetParam( Param => $Param{Key} ) || '';
        }

        return $Value;
    }
}

=item SearchInputCreate()

create a search input string

    my $Value = $BackendObject->SearchInputCreate(
        Key => 'Item::1::Node::3',
    );

=cut

sub SearchInputCreate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(Key Item)) {
        if ( !$Param{$Argument} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    my $InputString = '';

    if (
        $Param{Item}->{Input}->{SearchInputType}
        && $Param{Item}->{Input}->{SearchInputType} eq 'Pattern'
    ) {
        my $Value = '';
        if (ref($Param{Value}) eq 'ARRAY') {
            for my $TempValue (@{$Param{Value}}) {
                if ($Value) {
                    $Value .= "||";
                }
                if ($TempValue =~ m/^[0-9]+$/) {
                    $Value .= "[ID]" . $TempValue;
                } else {
                    $Value .= $TempValue;
                }
            }
        }
        $InputString = "<input type=\"Text\" name=\"$Param{Key}\" size=\"30\" value=\"$Value\">";
    } else {
        # hash with values for the input field
        my %FormData;

        if ( $Param{Value} ) {
            $FormData{Value} = $Param{Value};
        }

        # create input field
        $InputString = $Self->InputCreate(
            %FormData,
            Key    => $Param{Key},
            Item   => $Param{Item},
            ItemId => $Param{Key},
        );
    }

    return $InputString;
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
