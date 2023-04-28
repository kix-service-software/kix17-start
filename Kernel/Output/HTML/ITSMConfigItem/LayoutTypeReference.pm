# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::ITSMConfigItem::LayoutTypeReference;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::Output::HTML::Layout',
    'Kernel::System::Log',
    'Kernel::System::Type',
    'Kernel::System::Web::Request'
);

=head1 NAME

Kernel::Output::HTML::ITSMConfigItemLayoutTypeReference - layout backend module

=head1 SYNOPSIS

All layout functions of TypeReference objects

=over 4

=cut

=item new()

create an object

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $BackendObject = $Kernel::OM->Get('Kernel::Output::HTML::ITSMConfigItemLayoutTypeReference');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{ConfigObject} = $Kernel::OM->Get('Kernel::Config');
    $Self->{LayoutObject} = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    $Self->{LogObject}    = $Kernel::OM->Get('Kernel::System::Log');
    $Self->{TypeObject}   = $Kernel::OM->Get('Kernel::System::Type');
    $Self->{ParamObject}  = $Kernel::OM->Get('Kernel::System::Web::Request');

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

    if ( $Self->{ConfigObject}->Get('Ticket::TypeTranslation') ) {
        $Param{Value} = $Self->{LayoutObject}->{LanguageObject}->Translate( $Param{Value} );
    }

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

    # check needed stuff
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

    # get selected CustomerCompany
    $FormData{Value} = $Self->{ParamObject}->GetParam( Param => $Param{Key} );

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

    my $ItemId   = $Param{ItemId} || '';
    my $Required = $Param{Required} || '';
    my $Invalid  = $Param{Invalid}  || '';
    my $Class    = 'Modernize';

    if ($Required) {
        $Class .= ' Validate_Required';
    }

    if ($Invalid) {
        $Class .= ' ServerError';
    }

    my %TicketTypes = $Self->{TypeObject}->TypeList(
        Valid => 1,
    );

    my $Selected;
    if ( $Param{Value} ) {
        $Selected = $Param{Value};
    }

    my $TypeSelectionStrg = $Self->{LayoutObject}->BuildSelection(
        Name        => $Param{Key},
        ID          => $ItemId,
        Data        => \%TicketTypes,
        SelectedID  => $Selected,
        Class       => $Class,
        Translation => $Self->{ConfigObject}->Get('Ticket::TypeTranslation'),
    );
    return $TypeSelectionStrg;
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

    if ( ref $Param{Value} eq 'ARRAY' ) {
        return \@{ $Param{Value} };
    }

    #check needed stuff
    if ( !$Param{Key} ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => 'Need Key!'
        );
        return;
    }

    my %FormData;

    # get selected CustomerCompany
    my @Values = $Self->{ParamObject}->GetParam( Param => $Param{Key} );

    return \@Values;
}

=item SearchInputCreate()

create a search input string

    my $Value = $BackendObject->SearchInputCreate(
        Key => 'Item::1::Node::3',
    );

=cut

sub SearchInputCreate {
    my ( $Self, %Param ) = @_;

    my %TicketTypes = $Self->{TypeObject}->TypeList(
        Valid => 1,
    );

    my $TypeSelectionStrg = $Self->{LayoutObject}->BuildSelection(
        Name        => $Param{Key},
        Data        => \%TicketTypes,
        Translation => $Self->{ConfigObject}->Get('Ticket::TypeTranslation'),
    );

    return $TypeSelectionStrg;
}

1;


=head1 VERSION

$Revision$ $Date$

=cut

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
