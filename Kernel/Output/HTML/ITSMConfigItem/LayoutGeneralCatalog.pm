# --
# Modified version of the work: Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2022 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::ITSMConfigItem::LayoutGeneralCatalog;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::GeneralCatalog',
    'Kernel::System::Log',
    'Kernel::Output::HTML::Layout',
    'Kernel::System::Web::Request'
);

=head1 NAME

Kernel::Output::HTML::ITSMConfigItem::LayoutGeneralCatalog - layout backend module

=head1 SYNOPSIS

All layout functions of general catalog objects

=over 4

=cut

=item new()

create an object

    $BackendObject = Kernel::Output::HTML::ITSMConfigItem::LayoutGeneralCatalog->new(
        %Param,
    );

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=item OutputStringCreate()

create output string

    my $Value = $BackendObject->OutputStringCreate(
        Value => 11,       # (optional)
        Item => $ItemRef,
    );

=cut

sub OutputStringCreate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Item} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need Item!',
        );
        return;
    }

    $Param{Value} //= '';

    # translate
    if ( $Param{Item}->{Input}->{Translation} ) {
        $Param{Value} = $Kernel::OM->Get('Kernel::Output::HTML::Layout')->{LanguageObject}->Translate( $Param{Value} );
    }

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

    # check needed stuff
    for my $Argument (qw(Key Item)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    my %FormData;

    # get form data
    $FormData{Value} = $Kernel::OM->Get('Kernel::System::Web::Request')->GetParam( Param => $Param{Key} );

    # set invalid param
    if ( $Param{Item}->{Input}->{Required} && !$FormData{Value} ) {
        $FormData{Invalid} = 1;
        $Param{Item}->{Form}->{ $Param{Key} }->{Invalid} = 1;
    }

    return \%FormData;
}

=item InputCreate()

create a input string

    my $Value = $BackendObject->InputCreate(
        Key => 'Item::1::Node::3',
        Value => 11,                # (optional)
        Item => $ItemRef,
    );

=cut

sub InputCreate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(Key Item)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    my $CSSClass = 'Modernize';
    my $Required = $Param{Required};
    my $Invalid  = $Param{Invalid};
    my $ItemId   = $Param{ItemId};

    if ($Required) {
        $CSSClass .= ' Validate_Required';
    }

    if ($Invalid) {
        $CSSClass .= ' ServerError';
    }

    # translation on or off
    my $Translation = 0;
    if ( $Param{Item}->{Input}->{Translation} ) {
        $Translation = 1;
    }

    # get class list
    my $ClassList = $Kernel::OM->Get('Kernel::System::GeneralCatalog')->ItemList(
        Class => $Param{Item}->{Input}->{Class} || '',
    );

    # reverse the class list
    my %ReverseClassList = reverse %{$ClassList};

    my $SelectedID;

    # get the current value
    if ( defined $Param{Value} ) {
        $SelectedID = $Param{Value};
    }

    # get the default id by default value
    else {
        $SelectedID = $ReverseClassList{ $Param{Item}->{Input}->{ValueDefault} || '' } || '';
    }

    # generate string
    my $String = $Kernel::OM->Get('Kernel::Output::HTML::Layout')->BuildSelection(
        Data         => $ClassList,
        Name         => $Param{Key},
        ID           => $ItemId,
        PossibleNone => 1,
        Translation  => $Translation,
        SelectedID   => $SelectedID,
        Class        => $CSSClass,
    );

    return $String;
}

=item SearchFormDataGet()

get search form data

    my $Value = $BackendObject->SearchFormDataGet(
        Key => 'Item::1::Node::3',
    );

=cut

sub SearchFormDataGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(Key Item)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # get form data
    my @FormValues;
    if ( $Param{Value} ) {
        @FormValues = @{ $Param{Value} };
    }
    else {
        @FormValues = $Kernel::OM->Get('Kernel::System::Web::Request')->GetArray( Param => $Param{Key} );
    }

    # get class list
    my $ClassList = $Kernel::OM->Get('Kernel::System::GeneralCatalog')->ItemList(
        Class => $Param{Item}->{Input}->{Class},
    );

    # prepare search values
    my @SearchValues;
    for my $FormValue ( @FormValues ) {
        # process class entries
        ITEM:
        for my $ItemID ( keys( %{ $ClassList } ) ) {
            if ( $ClassList->{ $ItemID } eq $FormValue ) {
                # add id to values
                push( @SearchValues, $ItemID );
                last ITEM;
            }
            elsif ( $ItemID eq $FormValue ) {
                # add id to values
                push( @SearchValues, $ItemID );
                last ITEM;
            }
        }
    }

    return \@SearchValues;
}

=item SearchInputCreate()

create a search input string

    my $Value = $BackendObject->SearchInputCreate(
        Key => 'Item::1::Node::3',
        Item => $ItemRef,
    );

=cut

sub SearchInputCreate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(Key Item)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # get form data
    my @Values;
    my %FormValues;
    if ( $Param{Value} ) {
        %FormValues = map { $_ => 1 } @{ $Param{Value} };
    }
    else {
        my @DataValues = $Kernel::OM->Get('Kernel::System::Web::Request')->GetArray( Param => $Param{Key} );

        if ( scalar( @DataValues ) ) {
            %FormValues = map{ $_ => 1 } @DataValues;
        }
    }

    # translation on or off
    my $Translation = 0;
    if ( $Param{Item}->{Input}->{Translation} ) {
        $Translation = 1;
    }

    # prepare data
    my %Data = ();
    if ( ref( $Param{Item}->{Input}->{Class} ) eq 'ARRAY' ) {
        for my $Class ( @{ $Param{Item}->{Input}->{Class} } ) {
            # get class list
            my $ClassList = $Kernel::OM->Get('Kernel::System::GeneralCatalog')->ItemList(
                Class => $Class,
            );
            # add values to data
            for my $ItemID ( keys( %{ $ClassList } ) ) {
                my $Value = $ClassList->{$ItemID};

                $Data{ $Value } = $Value;

                if (
                    %FormValues
                    && $FormValues{$ItemID}
                ) {
                    push( @Values, $Value );
                }
            }
        }
    }
    else {
        # get class list
        my $ClassList = $Kernel::OM->Get('Kernel::System::GeneralCatalog')->ItemList(
            Class => $Param{Item}->{Input}->{Class} || '',
        );
        # add values to data
        for my $ItemID ( keys( %{ $ClassList } ) ) {
            my $Value = $ClassList->{$ItemID};

            $Data{ $Value } = $Value;

            if (
                %FormValues
                && $FormValues{$ItemID}
            ) {
                push( @Values, $Value );
            }
        }
    }

    # generate string
    my $String = $Kernel::OM->Get('Kernel::Output::HTML::Layout')->BuildSelection(
        Data        => \%Data,
        Name        => $Param{Key},
        Size        => 5,
        Multiple    => 1,
        Translation => $Translation,
        SelectedID  => \@Values,
        Class       => 'Modernize',
    );

    return $String;
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
