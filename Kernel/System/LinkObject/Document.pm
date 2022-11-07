# --
# Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::LinkObject::Document;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::Document',
    'Kernel::System::Log',
);

=head1 NAME

Kernel::System::LinkObject::Document

=head1 SYNOPSIS

Ticket backend for the Document link object.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $LinkObjectDocumentObject = $Kernel::OM->Get('Kernel::System::LinkObject::Document');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # create needed objects
    $Self->{DocumentObject} = $Kernel::OM->Get('Kernel::System::Document');
    $Self->{LogObject}      = $Kernel::OM->Get('Kernel::System::Log');

    return $Self;
}

=item LinkListWithData()

fill up the link list with data

    $Success = $LinkObjectBackend->LinkListWithData(
        LinkList => $HashRef,
        UserID   => 1,
    );

=cut

sub LinkListWithData {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(LinkList UserID)) {
        if ( !$Param{$Argument} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # check link list
    if ( ref $Param{LinkList} ne 'HASH' ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => 'LinkList must be a hash reference!',
        );
        return;
    }

    for my $LinkType ( keys %{ $Param{LinkList} } ) {

        for my $Direction ( keys %{ $Param{LinkList}->{$LinkType} } ) {

            FILEID:
            for my $FileID ( keys %{ $Param{LinkList}->{$LinkType}->{$Direction} } ) {

                # get document data
                next FILEID if $FileID !~ /^.+:.+$/;

                # get link
                my %DocumentData = $Self->{DocumentObject}->DocumentMetaGet(
                    DocumentID => $FileID,
                    UserID     => $Param{UserID},
                );

                if (%DocumentData) {

                    # add file data
                    my %LinkData = $Self->{DocumentObject}->DocumentLinkGet(
                        DocumentID => $FileID,
                        UserID     => $Param{UserID},
                    );
                    $DocumentData{LinkURL}                                 = $LinkData{URL};
                    $DocumentData{LinkInfo}                                = $LinkData{LinkInfo};
                    $Param{LinkList}->{$LinkType}->{$Direction}->{$FileID} = \%DocumentData;
                }
                else {
                    delete $Param{LinkList}->{$LinkType}->{$Direction}->{$FileID};
                }
            }
        }
    }

    return 1;
}

=item ObjectDescriptionGet()

return a hash of object descriptions

Return
    %Description = (
        Normal => "DocumentName",
        Long   => "DocumentSimple Data",
    );

    %Description = $LinkObject->ObjectDescriptionGet(
        Key     => 123,
        Mode    => 'Temporary',  # (optional)
        UserID  => 1,
    );

=cut

sub ObjectDescriptionGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(Object Key UserID)) {
        if ( !$Param{$Argument} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # create description
    my %Description = (
        Normal => 'Document',
        Long   => 'Document',
    );

    return %Description if $Param{Mode} && $Param{Mode} eq 'Temporary';

    return if $Param{Key} !~ /^(?:.+):(?:.+)$/;

    # get description
    my %Document = $Self->{DocumentObject}->DocumentMetaGet( DocumentID => $Param{Key} );

    # create description
    $Description{Normal} = $Document{Name};
    my $LongDescription;
    foreach my $Key ( keys %Document ) {
        $LongDescription .= $Document{$Key} . ", ";
    }
    $Description{Long} = $LongDescription;

    return %Description;
}

=item ObjectSearch()

return a hash list of the search results

Return
    $SearchList = {
        NOTLINKED => {
            Source => {
                12  => $DataOfItem12,
                212 => $DataOfItem212,
                332 => $DataOfItem332,
            },
        },
    };

    $SearchList = $LinkObjectBackend->ObjectSearch(
        SubObject    => 'Bla',     # (optional)
        SearchParams => $HashRef,  # (optional)
        UserID       => 1,
    );

=cut

sub ObjectSearch {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{UserID} ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => 'Need UserID!',
        );
        return;
    }

    my @SearchList = $Self->{DocumentObject}->DocumentNameSearch(
        Source     => $Param{SearchParams}->{DocumentSource}->[0],
        FileName   => $Param{SearchParams}->{DocumentName},
        IgnoreCase => $Param{SearchParams}->{IgnoreCase}->[0],
        Limit      => $Param{SearchParams}->{Limit}->[0] || 10000,
        UserID     => $Param{UserID},
    );

    my %FoundFiles;

    for my $ID (@SearchList) {
        my %FileData = $Self->{DocumentObject}->DocumentMetaGet( DocumentID => $ID );

        $FoundFiles{NOTLINKED}->{Source}->{$ID} = {%FileData};
    }

    return \%FoundFiles;
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
