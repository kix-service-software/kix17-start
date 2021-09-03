# --
# Copyright (C) 2006-2021 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::KIXSidebarLinkedCIsAJAXHandler;

use strict;
use warnings;

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    # define which attribute types are shown in the list of filterable attributes
    $Self->{ValidFilterAttributeTypes} = {
        'Text'     => 1,
        'TextArea' => 1,
        'Integer'  => 1,
    };

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my %GetParam;
    my @SelectedSearchFields;

    # create needed objects
    my $ConfigObject         = $Kernel::OM->Get('Kernel::Config');
    my $LayoutObject         = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ConfigItemObject     = $Kernel::OM->Get('Kernel::System::ITSMConfigItem');
    my $GeneralCatalogObject = $Kernel::OM->Get('Kernel::System::GeneralCatalog');
    my $TicketObject         = $Kernel::OM->Get('Kernel::System::Ticket');
    my $ParamObject          = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $UserObject           = $Kernel::OM->Get('Kernel::System::User');

    # create string for attribute input text field
    if ( $Self->{Subaction} eq 'KIXSidebarAddAttribute' ) {

        # get attribute
        $Param{Name} = $ParamObject->GetParam( Param => 'KIXSidebarLinkedCIAttribute' )
            || '';

        # create input string
        my $InputString
            = '<label for="ArticleTypeFilter">'
            . $LayoutObject->{LanguageObject}->Translate( $Param{Name} )
            . ':</label>'
            . '<div class="Field" id="">'
            . '<input id="' . $Param{Name} . '" type="text" name="' . $Param{Name} . '" value="" />'
            . '<button type="button" class="Remove" value="'
            . $LayoutObject->{LanguageObject}->Translate('Remove')
            . '" title="'
            . $LayoutObject->{LanguageObject}->Translate('Remove Entry')
            . '"><i class="fa fa-minus-square-o"></i>'
            . '</button>'
            . '<div class="Clear"></div>';

        # parse the input string as JSON structure
        $InputString = $LayoutObject->JSONEncode(
            Data => {
                InputString => $InputString,
                }
        );

        # return input string
        return $LayoutObject->Attachment(
            ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
            Content     => $InputString || '',
            Type        => 'inline',
            NoCache     => 1,
        );
    }

    # get attribute filter restrictions
    if ( $Self->{Subaction} eq 'SetFilter' || $Self->{Subaction} eq 'AJAXUpdateSelection' ) {
        @SelectedSearchFields
            = split( /,/, $ParamObject->GetParam( Param => 'SelectedSearchFields' ) );
        for my $Field (@SelectedSearchFields) {
            $GetParam{$Field} = $ParamObject->GetParam( Param => $Field );
        }
    }

    # get needed params
    for my $Needed (qw(CustomerUserID CallingAction FormID ConfigItemClass TicketID)) {
        $Param{$Needed} = $ParamObject->GetParam( Param => $Needed ) || '';
        if ( $Param{CallingAction} && $Param{CallingAction} =~ /Customer/ ) {
            $Param{CustomerUserID} = $Self->{UserID} || '';
        }
    }

    # if no customer user id given on ticket create in agent frontend
    if (
        !$Param{CustomerUserID}
        && ( $Self->{Subaction} eq 'SetFilter' || $Self->{Subaction} eq 'AJAXUpdateSelection' )
    ) {

        my %UserData = $UserObject->GetUserData(
            UserID => $Self->{UserID},
        );
        $Param{CustomerUserID} = $UserData{UserLogin};
    }

    # if no customer user id given, lookup with ticket id
    if (
        !$Param{CustomerUserID}
        && $Param{TicketID}
    ) {
        my %Ticket = $TicketObject->TicketGet(
            TicketID      => $Param{TicketID},
            DynamicFields => 0,
            UserID        => $Self->{UserID},
            Silent        => 0,
        );

        $Param{CustomerUserID} = $Ticket{CustomerUserID};
    }

    # reload attribute selection after removing attributes from filter dialog
    if ( $Self->{Subaction} eq 'AJAXUpdateSelection' ) {

        # get class list
        my %ConfigItemClasses;
        my %Classes = reverse %{
            $GeneralCatalogObject->ItemList(
                Class => 'ITSM::ConfigItem::Class',
                )
            };

        if ( !defined $Param{ConfigItemClass} || !$Param{ConfigItemClass} ) {

            # get defined classes for linked config items
            my @CIClasses
                = keys %{
                $ConfigObject->Get('KIXSidebarConfigItemLink::CISearchInClasses')
                };
            %ConfigItemClasses = reverse map { $_ => $Classes{$_} } @CIClasses;
        }
        else {
            $ConfigItemClasses{ $Param{ConfigItemClass} } = $Classes{ $Param{ConfigItemClass} };
        }

        # create filter attribute string
        my %AttributesHash;
        my %XMLDefinitionHash = ();
        for my $Class ( keys %ConfigItemClasses ) {

            my $XMLDefinition = $ConfigItemObject->DefinitionGet(
                ClassID => $Class,
            );

            # abort, if no definition is defined
            if ( !$XMLDefinition->{DefinitionID} ) {
                return $LayoutObject->ErrorScreen(
                    Message => "No Definition was defined for class $Class!",
                    Comment => 'Please contact the admin.',
                );
            }
            $XMLDefinitionHash{$Class} = $XMLDefinition;

            my @XMLAttributes = (
                {
                    Key   => 'Number',
                    Value => 'Number',
                },
                {
                    Key   => 'Name',
                    Value => 'Name',
                },
                {
                    Key   => 'DeplStateIDs',
                    Value => 'Deployment State',
                },
                {
                    Key   => 'InciStateIDs',
                    Value => 'Incident State',
                },
            );

            # get attributes to include in attributes string
            if ( $XMLDefinition->{Definition} ) {
                $Self->_XMLSearchAttributesGet(
                    XMLDefinition => $XMLDefinition->{DefinitionRef},
                    XMLAttributes => \@XMLAttributes,
                );
            }

            for my $Attribute (@XMLAttributes) {
                if ( defined $AttributesHash{Key}->{ $Attribute->{Key} } ) {
                    $AttributesHash{Key}->{ $Attribute->{Key} }++;
                }
                else {
                    $AttributesHash{Key}->{ $Attribute->{Key} }   = 1;
                    $AttributesHash{Value}->{ $Attribute->{Key} } = $Attribute->{Value};
                }
            }
        }

        # remove attributes activated in filter
        my %Attributes;
        for my $Value ( keys %{ $AttributesHash{Value} } ) {
            next if grep { $_ eq $Value } @SelectedSearchFields;
            $Attributes{$Value} = $AttributesHash{Value}->{$Value};
        }

        # build attributes string for attributes list
        $Param{AttributesStrg} = $LayoutObject->BuildSelection(
            Data     => \%Attributes,
            Name     => 'KIXSidebarLinkedCIAttribute',
            Multiple => 0,
            Class => 'Modernize'
        );

        return $LayoutObject->Attachment(
            ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
            Content     => $Param{AttributesStrg},
            Type        => 'inline',
            NoCache     => 1,
        );
    }

    # generate output
    if (
        $Param{CustomerUserID}
        && $Param{CallingAction}
        && (
            $Param{FormID}
            || $Param{TicketID}
        )
    ) {
        $Param{LinkConfigItemStrg} =
            $LayoutObject->KIXSideBarAssignedConfigItemsTable(
            %GetParam,
            CustomerUserID => $Param{CustomerUserID} || '',
            CallingAction  => $Param{CallingAction}  || '',
            FormID         => $Param{FormID}         || '',
            UserID         => $Self->{UserID}        || '',
            AJAX           => $Param{Data}->{AJAX}   || 0,
            Class          => $Param{ConfigItemClass},
            TicketID       => $Param{TicketID}       || '',
            SelectedSearchFields => \@SelectedSearchFields,
            );
    }

    # return assigned config items
    return $LayoutObject->Attachment(
        ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
        Content     => $Param{LinkConfigItemStrg} || "<br/>",
        Type        => 'inline',
        NoCache     => 1,
    );
}

sub _XMLSearchAttributesGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    return if !$Param{XMLDefinition};
    return if ref $Param{XMLDefinition} ne 'ARRAY';
    return if ref $Param{XMLAttributes} ne 'ARRAY';

    $Param{Level} ||= 0;
    ITEM:
    for my $Item ( @{ $Param{XMLDefinition} } ) {

        # check valid type
        next if !$Self->{ValidFilterAttributeTypes}->{ $Item->{Input}->{Type} };

        # set prefix
        my $InputKey = $Item->{Key};
        my $Name     = $Item->{Name};
        if ( $Param{Prefix} ) {
            $InputKey = $Param{Prefix} . '::' . $InputKey;
            $Name     = $Param{PrefixName} . '::' . $Name;
        }

        # store attribute, if marked as searchable
        if ( $Item->{Searchable} ) {
            push @{ $Param{XMLAttributes} }, {
                Key   => $InputKey,
                Value => $Name,
            };
        }

        next ITEM if !$Item->{Sub};

        # start recursion, if "Sub" was found
        $Self->_XMLSearchAttributesGet(
            XMLDefinition => $Item->{Sub},
            XMLAttributes => $Param{XMLAttributes},
            Level         => $Param{Level} + 1,
            Prefix        => $InputKey,
            PrefixName    => $Name,
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
