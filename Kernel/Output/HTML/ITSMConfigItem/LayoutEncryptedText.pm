# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::ITSMConfigItem::LayoutEncryptedText;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::Language',
    'Kernel::Output::HTML::Layout',
    'Kernel::System::Log',
    'Kernel::System::Web::Request'
);

=head1 NAME

Kernel::Output::HTML::ITSMConfigItemLayoutEncryptedText - layout backend module

=head1 SYNOPSIS

All layout functions of EncryptedText objects

=over 4

=cut

=item new()

create an object

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $BackendObject = $Kernel::OM->Get('Kernel::Output::HTML::ITSMConfigItemLayoutEncryptedText');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{ConfigObject}   = $Kernel::OM->Get('Kernel::Config');
    $Self->{LanguageObject} = $Kernel::OM->Get('Kernel::Language');
    $Self->{LayoutObject}   = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    $Self->{LogObject}      = $Kernel::OM->Get('Kernel::System::Log');
    $Self->{ParamObject}    = $Kernel::OM->Get('Kernel::System::Web::Request');

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
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => 'Need Item!',
        );
        return;
    }

    if ( !defined $Param{Value} ) {
        $Param{Value} = '';
    }

    my $GroupsRef = $Param{Item}->{Group};
    my @Groups    = ();
    if ( $GroupsRef && ref $GroupsRef eq 'HASH' ) {
        @Groups = keys %{$GroupsRef};
    }

    my $Access = 0;
    for my $Group (@Groups) {

        next
            if (
            !$Self->{LayoutObject}->{"UserIsGroup[$Group]"}
            || $Self->{LayoutObject}->{"UserIsGroup[$Group]"} ne 'Yes'
            );

        $Access = 1;
        last;
    }

    if ($Access) {
        $Param{Value} = $Self->_Decrypt( $Param{Value} );
    }
    else {
        while ( $Param{Value} =~ /[a-zA-Z0-9_]/ ) {
            $Param{Value} =~ s/[a-zA-Z0-9_]/*/;
        }
    }

    # translate
    if ( $Param{Item}->{Input}->{Translation} ) {
        $Param{Value} =
            $Self->{LanguageObject}->Translate( $Param{Value} );
    }

    my $LinkFeature    = 1;
    my $HTMLResultMode = 1;

    # do not transform links in print view
    if ( $Param{Print} ) {
        $LinkFeature = 0;

        # do not convert whitespace and newlines in PDF mode
        if ( $Self->{ConfigObject}->Get('PDF') ) {
            $HTMLResultMode = 0;
        }
    }

    # transform ascii to html
    $Param{Value} = $Self->{LayoutObject}->Ascii2Html(
        Text           => $Param{Value},
        HTMLResultMode => $HTMLResultMode,
        LinkFeature    => $LinkFeature,
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
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    my %FormData;

    # get form data
    $FormData{Value} = $Self->{ParamObject}->GetParam( Param => $Param{Key} );

    my $GroupsRef = $Param{Item}->{Group};
    my @Groups    = ();
    if ( $GroupsRef && ref $GroupsRef eq 'HASH' ) {
        @Groups = keys %{$GroupsRef};
    }

    my $Access = 0;
    for my $Group (@Groups) {

        next
            if (
            !$Self->{LayoutObject}->{"UserIsGroup[$Group]"}
            || $Self->{LayoutObject}->{"UserIsGroup[$Group]"} ne 'Yes'
            );

        $Access = 1;
        last;
    }
    if ( $Access && defined( $FormData{Value} ) ) {

        # do encryption
        $FormData{Value} = $Self->_Encrypt( $FormData{Value} );
    }

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
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    my $Value = $Param{Value};
    if ( !defined $Param{Value} ) {
        $Value = $Param{Item}->{Input}->{ValueDefault} || '';
    }

    my $Class    = '';
    my $Size     = 'W50pc';
    my $Required = $Param{Required};
    my $Invalid  = $Param{Invalid};
    my $ItemId   = $Param{ItemId};

    if ($Required) {
        $Class .= ' Validate_Required';
    }

    if ($Invalid) {
        $Class .= ' ServerError';
    }
    $Class .= ' ' . $Size;
    my $String = "<input type=\"text\" name=\"$Param{Key}\" class=\"$Class\" ";

    if ($ItemId) {
        $String .= "id=\"$ItemId\" ";
    }

    my $GroupsRef = $Param{Item}->{Group};
    my @Groups    = ();
    if ( $GroupsRef && ref $GroupsRef eq 'HASH' ) {
        @Groups = keys %{$GroupsRef};
    }

    my $Access = 0;
    for my $Group (@Groups) {

        next
            if (
            !$Self->{LayoutObject}->{"UserIsGroup[$Group]"}
            || $Self->{LayoutObject}->{"UserIsGroup[$Group]"} ne 'Yes'
            );

        $Access = 1;
        last;
    }

    # check if value can be edited and if so decrypt value
    if ( !$Access ) {
        $String .= "readonly=\"readonly\" ";
    }
    else {
        $Value = $Self->_Decrypt($Value);

        # add maximum length only if "access edit" otherwise value will be
        # truncated and cause input required message
        if ( $Param{Item}->{Input}->{MaxLength} ) {
            $String .= "maxlength=\"$Param{Item}->{Input}->{MaxLength}\" ";
        }
    }

    $Value = $Self->{LayoutObject}->Ascii2Html( Text => $Value || '' );

    $String .= "value=\"$Value\" ";
    $String .= '/> ';

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
    if ( !$Param{Key} ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => 'Need Key!',
        );
        return;
    }

    # get form data
    my $Value;
    if ( $Param{Value} ) {
        $Value = $Param{Value};
    }
    else {
        $Value = $Self->{ParamObject}->GetParam( Param => $Param{Key} );
    }
    return $Value;
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
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    my $Value = $Self->SearchFormDataGet(%Param);
    if ( !defined $Value ) {
        $Value = '';
    }

    my $String =
        qq{<input type="text" name="$Param{Key}" value="$Value" class="W50pc" >};

    return $String;
}

sub _Decrypt {
    my ( $Self, $Pw ) = @_;

    return $Pw if !$Pw;

    my $Length = length($Pw) * 4;
    $Pw = pack "h$Length", $Pw;
    $Pw = unpack "B$Length", $Pw;
    $Pw =~ s/1/A/g;
    $Pw =~ s/0/1/g;
    $Pw =~ s/A/0/g;
    $Pw = pack "B$Length", $Pw;

    return $Pw;
}

sub _Encrypt {
    my ( $Self, $Pw ) = @_;

    return $Pw if !$Pw;

    my $Length = length($Pw) * 8;
    chomp $Pw;

    # get bit code
    my $T = unpack( "B$Length", $Pw );

    # crypt bit code
    $T =~ s/1/A/g;
    $T =~ s/0/1/g;
    $T =~ s/A/0/g;

    # get ascii code
    $T = pack( "B$Length", $T );

    # get hex code
    my $H = unpack( "h$Length", $T );

    return $H;
}

1;


=head1 VERSION

$Revision$ $Date$

=cut


=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
