# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::LinkObject::Document;

use strict;
use warnings;

use Kernel::Output::HTML::Layout;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Log',
    'Kernel::System::Document',
    'Kernel::System::Web::Request',
);

=head1 NAME

Kernel::Output::HTML::LinkObjectDocument - layout backend module

=head1 SYNOPSIS

All layout functions of link object (document)

=over 4

=cut

=item new()

create an object

    $BackendObject = Kernel::Output::HTML::LinkObjectDocument->new(
        UserLanguage => 'en',
        UserID       => 1,
    );

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for my $Needed (qw(UserLanguage UserID)) {
        $Self->{$Needed} = $Param{$Needed} || die "Got no $Needed!";
    }

    # We need our own LayoutObject instance to avoid blockdata collisions
    #   with the main page.
    $Self->{LayoutObject} = Kernel::Output::HTML::Layout->new( %{$Self} );

    # define needed variables
    $Self->{ObjectData} = {
        Object   => 'Document',
        Realname => 'Document',
    };

    return $Self;
}

=item TableCreateComplex()

return an array with the block data

Return

    %BlockData = (
        {
            Object    => 'Document',
            Blockname => 'Document',
            Headline  => [
                {
                    Content => 'Number#',
                    Width   => 130,
                },
                {
                    Content => 'Title',
                },
                {
                    Content => 'Created',
                    Width   => 110,
                },
            ],
            ItemList => [
                [
                    {
                        Type    => 'Link',
                        Key     => $DocumentID,
                        Content => '123123123',
                        Css     => 'style="text-decoration: line-through"',
                    },
                    {
                        Type      => 'Text',
                        Content   => 'The title',
                        MaxLength => 50,
                    },
                    {
                        Type    => 'TimeLong',
                        Content => '2008-01-01 12:12:00',
                    },
                ],
                [
                    {
                        Type    => 'Link',
                        Key     => $DocumentID,
                        Content => '434234',
                    },
                    {
                        Type      => 'Text',
                        Content   => 'The title of document 2',
                        MaxLength => 50,
                    },
                    {
                        Type    => 'TimeLong',
                        Content => '2008-01-01 12:12:00',
                    },
                ],
            ],
        },
    );

    @BlockData = $LinkObject->TableCreateComplex(
        ObjectLinkListWithData => $ObjectLinkListRef,
    );

=cut

sub TableCreateComplex {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{ObjectLinkListWithData} || ref $Param{ObjectLinkListWithData} ne 'HASH' ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need ObjectLinkListWithData!',
        );
        return;
    }

    # convert the list
    my %LinkList;
    for my $LinkType ( sort keys %{ $Param{ObjectLinkListWithData} } ) {

        # extract link type List
        my $LinkTypeList = $Param{ObjectLinkListWithData}->{$LinkType};

        for my $Direction ( sort keys %{$LinkTypeList} ) {

            # extract direction list
            my $DirectionList = $Param{ObjectLinkListWithData}->{$LinkType}->{$Direction};

            for my $DocumentID ( keys %{$DirectionList} ) {
                $LinkList{$DocumentID}->{Data} = $DirectionList->{$DocumentID};
            }
        }
    }

    # get column config
    my $ConfigHash = $Kernel::OM->Get('Kernel::Config')->Get('Document::DefaultColumns');
    my %DisplayedColumns;
    if (
        defined $Param{EnabledColumns}->{Document}
        && scalar @{ $Param{EnabledColumns}->{Document} }
        )
    {
        for my $Column ( @{ $Param{EnabledColumns}->{Document} } ) {
            $DisplayedColumns{$Column} = 1;
        }
    }
    else {
        %DisplayedColumns = %{$ConfigHash};
    }

    # create the item list
    my @ItemList;
    my @HeadLine;

    for my $DocumentID ( sort keys %LinkList ) {

        # extract Document data
        my $Document = $LinkList{$DocumentID}{Data};

        # set css
        my $Css = '';
        my @ItemColumns;
        my @TempLine;

        for my $Key ( sort keys %$Document ) {

            # ignore all columns that are not defined for display
            next if !exists( $DisplayedColumns{$Key} );

            push @ItemColumns, {
                Type => $Document->{LinkURL} ? 'Link' : 'Text',
                Title      => $Document->{$Key},
                Content    => $Document->{$Key},
                Link       => $Document->{LinkURL},
                LinkInfo   => $Document->{LinkInfo},
                ID         => $DocumentID,
                ObjectType => 'Document',
                Key        => $DocumentID,
                Css        => $Css,
            };

            if ( !@HeadLine ) {
                push @TempLine, {
                    Content => $Key
                };
            }
        }

        if ( !@HeadLine ) {
            @HeadLine = @TempLine;
        }

        push @ItemList, \@ItemColumns;
    }

    return if !@ItemList;

    # define the block data
    my %Block = (
        Object    => $Self->{ObjectData}->{Object},
        Blockname => $Self->{ObjectData}->{Realname},
        Headline  => \@HeadLine,
        ItemList  => \@ItemList,
    );

    return ( \%Block );
}

=item TableCreateSimple()

return a hash with the link output data

Return

    %LinkOutputData = (
        Normal::Source => {
            Document => [
                {
                    Type    => 'Link',
                    Content => 'T:55555',
                    Title   => 'Document#555555: The Document title',
                    Css     => 'style="text-decoration: line-through"',
                },
                {
                    Type    => 'Link',
                    Content => 'T:22222',
                    Title   => 'Document#22222: Title of Document 22222',
                },
            ],
        },
        ParentChild::Target => {
            Document => [
                {
                    Type    => 'Link',
                    Content => 'T:77777',
                    Title   => 'Document#77777: Document title',
                },
            ],
        },
    );

    %LinkOutputData = $LinkObject->TableCreateSimple(
        ObjectLinkListWithData => $ObjectLinkListRef,
    );

=cut

sub TableCreateSimple {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{ObjectLinkListWithData} || ref $Param{ObjectLinkListWithData} ne 'HASH' ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need ObjectLinkListWithData!'
        );
        return;
    }

    my %LinkOutputData;
    for my $LinkType ( sort keys %{ $Param{ObjectLinkListWithData} } ) {

        # extract link type List
        my $LinkTypeList = $Param{ObjectLinkListWithData}->{$LinkType};

        for my $Direction ( sort keys %{$LinkTypeList} ) {

            # extract direction list
            my $DirectionList = $Param{ObjectLinkListWithData}->{$LinkType}->{$Direction};

            my @ItemList;
            for my $DocumentID ( sort { $a <=> $b } keys %{$DirectionList} ) {

                # extract Document data
                my $Document = $DirectionList->{$DocumentID};

                # define item data
                my %Item = (
                    Type => $Document->{LinkURL} ? 'Link' : 'Text',
                    Title      => $Document->{Name},
                    Content    => $Document->{Name},
                    Link       => $Document->{LinkURL},
                    LinkInfo   => $Document->{LinkInfo},
                    ID         => $DocumentID,
                    LinkType   => $LinkType,
                    ObjectType => 'Document',
                );

                push @ItemList, \%Item;
            }

            # add item list to link output data
            $LinkOutputData{ $LinkType . '::' . $Direction }->{Document} = \@ItemList;
        }
    }

    return %LinkOutputData;
}

=item ContentStringCreate()

return a output string

    my $String = $LayoutObject->ContentStringCreate(
        ContentData => $HashRef,
    );

=cut

sub ContentStringCreate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{ContentData} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need ContentData!'
        );
        return;
    }

    if (
        ref( $Param{ContentData} ) eq "HASH"
        && $Param{ContentData}->{ObjectType}
        && $Param{ContentData}->{ObjectType} eq 'Document'
        )
    {

        my %CData = %{ $Param{ContentData} };
        my $Css   = '';
        if ( $CData{LinkInfo} && $CData{LinkInfo} eq "NoLink" ) {
            $Css = 'text-decoration: line-through';
        }

        if ( length( $CData{Content} ) > 60 ) {

            # show only first and last 30 chars
            $CData{Content}
                = (
                substr( $CData{Content}, 0, 30 ) . '...'
                    . substr( $CData{Content}, length( $CData{Content} ) - 30 )
                );
        }
        if ( $CData{Link} ) {
            return
                "<a href='"
                . ( $CData{Link} || '' )
                . "' style='$Css'>"
                . ( $CData{Content} ) . "</a>";
        }
        else {
            return "<span style='$Css'>" . ( $CData{Content} || '' ) . "</span>";
        }
    }

    return;
}

=item SelectableObjectList()

return an array hash with selectable objects

Return

    @SelectableObjectList = (
        {
            Key   => 'Document',
            Value => 'Document',
        },
    );

    @SelectableObjectList = $LinkObject->SelectableObjectList(
        Selected => $Identifier,  # (optional)
    );

=cut

sub SelectableObjectList {
    my ( $Self, %Param ) = @_;

    my $Selected;
    if ( $Param{Selected} && $Param{Selected} eq $Self->{ObjectData}->{Object} ) {
        $Selected = 1;
    }

    # object select list
    my @ObjectSelectList = (
        {
            Key      => $Self->{ObjectData}->{Object},
            Value    => $Self->{ObjectData}->{Realname},
            Selected => $Selected,
        },
    );

    return @ObjectSelectList;
}

=item SearchOptionList()

return an array hash with search options

Return

    @SearchOptionList = (
        {
            Key       => 'DocumentNumber',
            Name      => 'Document#',
            InputStrg => $FormString,
            FormData  => '1234',
        },
        {
            Key       => 'Title',
            Name      => 'Title',
            InputStrg => $FormString,
            FormData  => 'BlaBla',
        },
    );

    @SearchOptionList = $LinkObject->SearchOptionList(
        SubObject => 'Bla',  # (optional)
    );

=cut

sub SearchOptionList {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $DocumentObject = $Kernel::OM->Get('Kernel::System::Document');

    # search option list
    my @SearchOptionList = (
        {
            Key        => 'DocumentSource',
            Name       => 'Source',
            Type       => 'List',
            Class      => 'Validate_Required Modernize',
            ClassLabel => 'Mandatory',
        },
        {
            Key        => 'DocumentName',
            Name       => 'Document Name',
            Type       => 'Text',
            Class      => 'Validate_Required Modernize',
            ClassLabel => 'Mandatory',
        },
        {
            Key        => 'IgnoreCase',
            Name       => 'Ignore Case',
            Type       => 'List',
            Class      => 'Modernize',
            Class      => 'Validate_Required Modernize',
        },
        {
            Key        => 'Limit',
            Name       => 'Limit',
            Type       => 'List',
            Class      => 'Modernize',
            PossibleNone => 1,
        },
    );

    # add formkey
    for my $Row (@SearchOptionList) {
        $Row->{FormKey} = 'SEARCH::' . $Row->{Key};
    }

    # add form data and input string
    ROW:
    for my $Row (@SearchOptionList) {

        # prepare text input fields
        if ( $Row->{Type} eq 'Text' ) {

            # get form data
            $Row->{FormData} = $Kernel::OM->Get('Kernel::System::Web::Request')->GetParam( Param => $Row->{FormKey} );

            # parse the input text block
            $Self->{LayoutObject}->Block(
                Name => 'InputText',
                Data => {
                    Key   => $Row->{FormKey},
                    Value => $Row->{FormData} || '',
                    Class => $Row->{Class} || '',
                },
            );

            # add the input string
            $Row->{InputStrg} = $Self->{LayoutObject}->Output(
                TemplateFile => 'LinkObject',
            );

            next ROW;
        }

        # prepare list boxes
        elsif ( $Row->{Type} eq 'List' ) {

            # get form data
            my @FormData = $Kernel::OM->Get('Kernel::System::Web::Request')->GetArray( Param => $Row->{FormKey} );
            $Row->{FormData} = \@FormData;

            my %ListData;
            if ( $Row->{Key} eq 'DocumentSource' ) {

                # get source list
                %ListData =
                    $DocumentObject->DocumentSourcesList( UserID => $Self->{UserID} );

                if ( !%ListData ) {
                    %ListData = ( '' => '-' );
                }
            }
            elsif ( $Row->{Key} eq 'IgnoreCase' ) {

                # get case options
                %ListData = (
                    0 => 'No',
                    1 => 'Yes',
                );
                $Row->{FormData} = 0;
            }
            elsif ( $Row->{Key} eq 'Limit' ) {

                # get limit options
                %ListData = (
                    10   => ' 10',
                    25   => ' 25',
                    50   => ' 50',
                    100  => '100',
                    150  => '150',
                    200  => '200',
                );
            }

            # add the input string
            $Row->{InputStrg} = $Self->{LayoutObject}->BuildSelection(
                Data       => \%ListData,
                Name       => $Row->{FormKey},
                SelectedID => $Row->{FormData},
                Size       => 3,
                Multiple   => $Row->{Multiple} || 0,
                Class      => $Row->{Class} || '',
                PossibleNone => $Row->{PossibleNone} || 0,
            );

            next ROW;
        }
    }

    return @SearchOptionList;
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
