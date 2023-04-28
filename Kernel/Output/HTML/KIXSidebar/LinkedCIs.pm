# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::KIXSidebar::LinkedCIs;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::Output::HTML::Layout',
    'Kernel::System::GeneralCatalog',
    'Kernel::System::ITSMConfigItem',
);

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
    my $Content;

    # create needed objects
    my $ConfigObject         = $Kernel::OM->Get('Kernel::Config');
    my $LayoutObject         = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $GeneralCatalogObject = $Kernel::OM->Get('Kernel::System::GeneralCatalog');
    my $ConfigItemObject     = $Kernel::OM->Get('Kernel::System::ITSMConfigItem');
    my $ParamObject          = $Kernel::OM->Get('Kernel::System::Web::Request');

    # some special handling for AgentTicketPhone and AgentTicketEmail
    if ( $Param{Action} =~ /^AgentTicket(Phone|Email)$/g && $Param{Subaction} eq 'Created' ) {
        $Self->{TicketID} = '';
        $Param{TicketID}  = '';
    }

    if ( $Param{Action} && $Param{Action} =~ /Customer/ ) {
        $Param{CustomerUserID} = $Self->{UserID} || '';
        $Param{CustomerID}     = $ParamObject->GetParam( Param => 'SelectedCustomerID' ) || '';
    }

    # generate output...
    $Param{LinkConfigItemStrg} = $LayoutObject->KIXSideBarAssignedConfigItemsTable(
        CustomerData   => $Param{CustomerData}   || '',
        CustomerUserID => $Param{CustomerUserID} || $Param{CustomerUser} || '',
        CustomerID     => $Param{CustomerID}     || '',
        CallingAction  => $Param{Data}->{CallingAction} || $Param{CallingAction} || '',
        TicketID       => $Self->{TicketID}             || '',
        UserID         => $Self->{UserID}               || '',
        AJAX           => $Param{Data}->{AJAX}          || 0,
        FormID         => $Param{FormID},
        Frontend       => $Param{Frontend}
    );

    # get class list
    my %Classes;
    if (
        defined $GeneralCatalogObject->ItemList(
            Class => 'ITSM::ConfigItem::Class',
        )
    ) {

        %Classes = reverse %{
            $GeneralCatalogObject->ItemList(
                Class => 'ITSM::ConfigItem::Class',
                )
            };
    }

    if (%Classes) {

        # get defined classes for linked config items
        my @CIClasses
            = keys %{ $ConfigObject->Get('KIXSidebarConfigItemLink::CISearchInClasses') };

        # check if configured class is valid in general catalog
        my %ConfigItemClasses;
        for my $ClassName (@CIClasses) {
            next if ( !defined $Classes{$ClassName} || !$Classes{$ClassName} );
            $ConfigItemClasses{ $Classes{$ClassName} } = $ClassName;
        }
        $ConfigItemClasses{''}
            = ' ' . $LayoutObject->{LanguageObject}->Translate('Select Class');
        $ConfigItemClasses{'-'} = '-';

        # get all selectable classes
        $Param{ConfigItemClassSelectionStrg} = $LayoutObject->BuildSelection(
            Name           => 'ConfigItemClass',
            SelectedID     => 1,
            Data           => \%ConfigItemClasses,
            Translation    => 0,
            DisabledBranch => '-',
            Class => 'Modernize'
        );

        # create filter attribute string
        my %AttributesHash;
        my %XMLDefinitionHash = ();
        for my $Class ( keys %ConfigItemClasses ) {
            next if ( $Class !~ /\d+/g );

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

        # build attributes string for attributes list
        if ( $AttributesHash{Value} ) {
            $Param{AttributesStrg} = $LayoutObject->BuildSelection(
                Data     => $AttributesHash{Value},
                Name     => 'KIXSidebarLinkedCIAttribute',
                Multiple => 0,
                Class => 'Modernize'
            );
        }

        $Param{ValidFilterAttributeTypes}
            = join( ', ', sort keys %{ $Self->{ValidFilterAttributeTypes} } );
    }

    # output result
    $Content = $LayoutObject->Output(
        TemplateFile => 'AgentKIXSidebarLinkedCIs',
        Data         => {
            %Param,
            %{ $Self->{Config} },
            CustomerUserID => $Param{CustomerUserID} || $Param{CustomerUser} || '',
            CustomerID     => $Param{CustomerID},
        },
        KeepScriptTags => $Param{AJAX},
    );

    return $Content;
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
