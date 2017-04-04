# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::QuickLink;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::Language',
    'Kernel::Output::HTML::Layout',
    'Kernel::System::Encode',
    'Kernel::System::Main',
);

=head1 NAME

Kernel::System::QuickLink

=head1 SYNOPSIS

QuickLink backend

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create a QuickLink object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $QuickLinkObject = $Kernel::OM->Get('Kernel::System::QuickLinkField');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get needed objects
    $Self->{ConfigObject} = $Kernel::OM->Get('Kernel::Config');
    $Self->{EncodeObject} = $Kernel::OM->Get('Kernel::System::Encode');
    $Self->{LayoutObject} = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    $Self->{LogObject}    = $Kernel::OM->Get('Kernel::System::Log');
    $Self->{MainObject}   = $Kernel::OM->Get('Kernel::System::Main');

    # get config
    $Self->{Backends} = $Self->{ConfigObject}->Get('QuickLink::Backend');

    return $Self;
}

=item AddLink()

add the object link

    my $Result = $QuickLinkObject->AddLink(
        SourceObject => 'Ticket',
        SourceKey => 123,
        TargetObject => 'Ticket',
        TargetKey => 123,
        LinkType  => '...',
        LinkDirection => '...',
    );

=cut

sub AddLink {
    my ( $Self, %Param ) = @_;
    my $Result = 0;

    # get needed params
    for (qw(SourceObject SourceKey TargetObject TargetKey LinkType LinkDirection)) {
        if ( !$Param{$_} ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    my ( $Backend, $ID ) = split( '::', $Param{TargetObject} );

    my $BackendObject = $Self->_LoadBackend(
        Backend => $Backend,
    );
    if ($BackendObject) {
        $Result = $BackendObject->AddLink(
            %Param,
        );
    }

    return $Result;
}

=item Search()

Do the search

    my $Result = $QuickLinkObject->Search(
        Term => '...'
        MaxResults =>
        TicketID => 123
    );

=cut

sub Search {
    my ( $Self, %Param ) = @_;
    my @Result;

    # get needed params
    for (qw(Term MaxResults SourceObject SourceKey TargetObject LinkType LinkDirection)) {
        if ( !$Param{$_} ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    # workaround, all auto completion requests get posted by utf8 anyway
    # convert any to 8bit string if application is not running in utf8
    $Param{Term} = $Self->{EncodeObject}->Convert(
        Text => $Param{Term},
        From => 'utf-8',
        To   => $Self->{LayoutObject}->{UserCharset},
    );

    # remove leading and ending spaces
    if ( $Param{Term} ) {

        # remove leading and ending spaces
        $Param{Term} =~ s/^\s+//;
        $Param{Term} =~ s/\s+$//;
    }

    my ( $Backend, $ID ) = split( '::', $Param{TargetObject} );

    my $BackendObject = $Self->_LoadBackend(
        Backend => $Backend,
    );
    if ($BackendObject) {
        @Result = $BackendObject->Search(
            %Param,
        );
    }

    return @Result;
}

=item FilterSelectableObjectsList()

Build the list of selectable objects suitable for BuildSelection

    my @Array = $QuickLinkObject->GetSelectableObjectsList(
        List => ArrayRef
    );

=cut

sub FilterSelectableObjectsList {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(List)) {
        if ( !defined( $Param{$_} ) ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    # add empty selection first
    my @FilteredObjectsList = (
        { Key => '', Value => '-' },    # empty selection
    );

    # filter given list
    if (   defined $Self->{Backends}
        && ref( $Self->{Backends} ) eq 'HASH'
        && keys %{ $Self->{Backends} } )
    {

        foreach my $Item ( @{ $Param{List} } ) {

            # don't use empty entries
            next if $Item->{Key} eq '-';

            # get backend
            my ( $Object, $SubObject ) = split( '::', $Item->{Key} );
            next if !$Self->{Backends}->{$Object} || !$Self->{Backends}->{$Object}->{Module};

            # try to load backend
            my $BackendObject = $Self->_LoadBackend(
                Backend => $Object,
            );

            # check quick link config
            my $TakeIt = 1;
            if ($BackendObject) {
                $TakeIt = $BackendObject->SelectableObjectAccepted(
                    Object    => $Object,
                    SubObject => $SubObject,
                );
            }
            next if !$TakeIt;

            # use it
            push @FilteredObjectsList, $Item;
        }
    }

    # return filtered list
    return @FilteredObjectsList;
}

sub _LoadBackend {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(Backend)) {
        if ( !$Param{$Argument} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "_LoadBackend: Need $Argument!",
            );
            return;
        }
    }

    # check if object is already cached
    return $Self->{Cache}->{LoadBackend}->{ $Param{Backend} }
        if $Self->{Cache}->{LoadBackend}->{ $Param{Backend} };

    my $BackendModule = $Self->{Backends}->{ $Param{Backend} }->{Module};

    # load the backend module
    if ( !$Self->{MainObject}->Require($BackendModule) ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "Can't load QuickLink backend module $BackendModule!"
        );
        return;
    }

    # create new instance
    my $BackendObject = $BackendModule->new(
        %{$Self},
        %Param,
        Config => $Self->{Backends}->{ $Param{Backend} },
    );

    if ( !$BackendObject ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "_LoadBackend: Can't load QuickLink backend module '$BackendModule'!",
        );
        return;
    }

    # cache the object
    $Self->{Cache}->{LoadBackend}->{ $Param{Backend} } = $BackendObject;

    return $BackendObject;
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
