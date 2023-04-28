# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2023 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::FAQOverview::Small;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::Output::HTML::Layout',
    'Kernel::System::DynamicField',
    'Kernel::System::DynamicField::Backend',
    'Kernel::System::FAQ',
    'Kernel::System::Log',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    # get UserID param
    $Self->{UserID} = $Param{UserID} || die "Got no UserID!";

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(PageShown StartHit)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    # need FAQIDs
    if ( !$Param{FAQIDs} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need the FAQIDs!',
        );
        return;
    }

    # get needed objects
    my $ConfigObject       = $Kernel::OM->Get('Kernel::Config');
    my $LayoutObject       = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');
    my $BackendObject      = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');
    my $FAQObject          = $Kernel::OM->Get('Kernel::System::FAQ');
    my $HTMLUtilsObject    = $Kernel::OM->Get('Kernel::System::HTMLUtils');

    # get isolated layout object for link safety checks
    my $HTMLLinkLayoutObject = $Kernel::OM->GetNew('Kernel::Output::HTML::Layout');

    # store the FAQIDs
    my @IDs;
    if ( $Param{FAQIDs} && ref $Param{FAQIDs} eq 'ARRAY' ) {
        @IDs = @{ $Param{FAQIDs} };
    }

    my $MultiLanguage = $ConfigObject->Get('FAQ::MultiLanguage');

    # get dynamic field config for frontend module
    my $DynamicFieldFilter = $ConfigObject->Get("FAQ::Frontend::OverviewSmall")->{DynamicField};

    # get the dynamic fields for this screen
    my $DynamicField = $DynamicFieldObject->DynamicFieldListGet(
        Valid       => 1,
        ObjectType  => ['FAQ'],
        FieldFilter => $DynamicFieldFilter || {},
    );

    my @ShowColumns;

    if (@IDs) {
        # check ShowColumns parameter
        if ( $Param{ShowColumns} && ref $Param{ShowColumns} eq 'ARRAY' ) {
            @ShowColumns = @{ $Param{ShowColumns} };
        }

        # get dynamic field backend object

        # build column header blocks
        if (@ShowColumns) {

            # call main block
            $LayoutObject->Block( Name => 'RecordForm' );

            COLUMN:
            for my $Column (@ShowColumns) {

                next COLUMN if ( $Column eq 'Language' && !$MultiLanguage );

                # create needed variables
                my $CSS = 'OverviewHeader';
                my $OrderBy;

                # remove ID if necessary
                if ( $Param{SortBy} ) {
                    $Param{SortBy} = $Param{SortBy} eq 'PriorityID'
                        ? 'Priority'
                        : $Param{SortBy} eq 'CategoryID' ? 'Category'
                        : $Param{SortBy} eq 'LanguageID' ? 'Language'
                        : $Param{SortBy} eq 'StateID'    ? 'State'
                        : $Param{SortBy} eq 'FAQID'      ? 'Number'
                        :                                  $Param{SortBy};
                }

                # set the correct Set CSS class and order by link
                if ( $Param{SortBy} && ( $Param{SortBy} eq $Column ) ) {
                    if ( $Param{OrderBy} && ( $Param{OrderBy} eq 'Up' ) ) {
                        $OrderBy = 'Down';
                        $CSS .= ' SortDescendingLarge';
                    }
                    else {
                        $OrderBy = 'Up';
                        $CSS .= ' SortAscendingLarge';
                    }
                }
                else {
                    $OrderBy = 'Up';
                }

                $LayoutObject->Block(
                    Name => 'Record' . $Column . 'Header',
                    Data => {
                        %Param,
                        CSS     => $CSS,
                        OrderBy => $OrderBy,
                    },
                );
            }

            # Dynamic fields
            # cycle trough the activated Dynamic Fields for this screen
            DYNAMICFIELD:
            for my $DynamicFieldConfig ( @{$DynamicField} ) {
                next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

                my $Label = $DynamicFieldConfig->{Label};

                # get field sortable condition
                my $IsSortable = $BackendObject->HasBehavior(
                    DynamicFieldConfig => $DynamicFieldConfig,
                    Behavior           => 'IsSortable',
                );

                if ($IsSortable) {
                    my $CSS = '';
                    my $OrderBy;
                    if (
                        $Param{SortBy}
                        && ( $Param{SortBy} eq ( 'DynamicField_' . $DynamicFieldConfig->{Name} ) )
                    ) {
                        if ( $Param{OrderBy} && ( $Param{OrderBy} eq 'Up' ) ) {
                            $OrderBy = 'Down';
                            $CSS .= ' SortDescending';
                        }
                        else {
                            $OrderBy = 'Up';
                            $CSS .= ' SortAscending';
                        }
                    }

                    $LayoutObject->Block(
                        Name => 'RecordDynamicFieldHeader',
                        Data => {
                            %Param,
                            CSS => $CSS,
                        },
                    );

                    $LayoutObject->Block(
                        Name => 'RecordDynamicFieldHeaderSortable',
                        Data => {
                            %Param,
                            OrderBy          => $OrderBy,
                            Label            => $Label,
                            DynamicFieldName => $DynamicFieldConfig->{Name},
                        },
                    );

                    # example of dynamic fields order customization
                    $LayoutObject->Block(
                        Name => 'RecordDynamicField_' . $DynamicFieldConfig->{Name} . 'Header',
                        Data => {
                            %Param,
                            CSS => $CSS,
                        },
                    );

                    $LayoutObject->Block(
                        Name => 'RecordDynamicField_'
                            . $DynamicFieldConfig->{Name}
                            . 'HeaderSortable',
                        Data => {
                            %Param,
                            OrderBy          => $OrderBy,
                            Label            => $Label,
                            DynamicFieldName => $DynamicFieldConfig->{Name},
                        },
                    );
                }
                else {

                    $LayoutObject->Block(
                        Name => 'RecordDynamicFieldHeader',
                        Data => {
                            %Param,
                        },
                    );

                    $LayoutObject->Block(
                        Name => 'RecordDynamicFieldHeaderNotSortable',
                        Data => {
                            %Param,
                            Label => $Label,
                        },
                    );

                    # example of dynamic fields order customization
                    $LayoutObject->Block(
                        Name => 'RecordDynamicField_' . $DynamicFieldConfig->{Name} . 'Header',
                        Data => {
                            %Param,
                        },
                    );

                    $LayoutObject->Block(
                        Name => 'RecordDynamicField_'
                            . $DynamicFieldConfig->{Name}
                            . 'HeaderNotSortable',
                        Data => {
                            %Param,
                            Label => $Label,
                        },
                    );
                }
            }
        }

        my $Counter = 0;

        ID:
        for my $ID (@IDs) {
            $Counter++;
            if (
                $Counter >= $Param{StartHit}
                && $Counter < ( $Param{PageShown} + $Param{StartHit} )
            ) {

                # to store all data
                my %Data;

                # get FAQ data
                my %FAQ = $FAQObject->FAQGet(
                    ItemID     => $ID,
                    ItemFields => 0,
                    UserID     => $Self->{UserID},
                );

                $FAQ{CleanTitle} = $FAQObject->FAQArticleTitleClean(
                    Title => $FAQ{Title},
                    Size  => $Param{TitleSize},
                );

                next ID if !%FAQ;

                # add FAQ data
                %Data = ( %Data, %FAQ );

                # build record block
                $LayoutObject->Block(
                    Name => 'Record',
                    Data => {
                        %Param,
                        %Data,
                    },
                );

                # build column record blocks
                if (@ShowColumns) {
                    COLUMN:
                    for my $Column (@ShowColumns) {

                        # do not show language column if FAQ does not support multiple languages
                        next COLUMN if ( $Column eq 'Language' && !$MultiLanguage );

                        $LayoutObject->Block(
                            Name => 'Record' . $Column,
                            Data => {
                                %Param,
                                %Data,
                            },
                        );

                        # do not display columns as links in the customer frontend
                        next COLUMN if $Param{Frontend} eq 'Customer';

                        # show links if available
                        $LayoutObject->Block(
                            Name => 'Record' . $Column . 'LinkStart',
                            Data => {
                                %Param,
                                %Data,
                            },
                        );
                        $LayoutObject->Block(
                            Name => 'Record' . $Column . 'LinkEnd',
                            Data => {
                                %Param,
                                %Data,
                            },
                        );
                    }
                }

                # Dynamic fields
                # cycle trough the activated Dynamic Fields for this screen
                DYNAMICFIELD:
                for my $DynamicFieldConfig ( @{$DynamicField} ) {
                    next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

                    # get field value
                    my $Value = $BackendObject->ValueGet(
                        DynamicFieldConfig => $DynamicFieldConfig,
                        ObjectID           => $ID,
                    );

                    my $ValueStrg = $BackendObject->DisplayValueRender(
                        DynamicFieldConfig => $DynamicFieldConfig,
                        Value              => $Value,
                        ValueMaxChars      => 20,
                        LayoutObject       => $LayoutObject,
                    );

                    $LayoutObject->Block(
                        Name => 'RecordDynamicField',
                        Data => {
                            Value => $ValueStrg->{Value},
                            Title => $ValueStrg->{Title},
                        },
                    );

                    my $HTMLLink;
                    if ( $ValueStrg->{Link} ) {
                        $HTMLLink = $HTMLLinkLayoutObject->Output(
                            Template => '<a href="[% Data.Link %]" class="DynamicFieldLink">[% Data.Value %]</a>',
                            Data     => {
                                Value                       => $ValueStrg->{Value},
                                Title                       => $ValueStrg->{Title},
                                Link                        => $ValueStrg->{Link},
                                $DynamicFieldConfig->{Name} => $ValueStrg->{Title},
                            },
                        );
                        my %Safe = $HTMLUtilsObject->Safety(
                            String       => $HTMLLink,
                            NoApplet     => 1,
                            NoObject     => 1,
                            NoEmbed      => 1,
                            NoSVG        => 1,
                            NoImg        => 1,
                            NoIntSrcLoad => 0,
                            NoExtSrcLoad => 1,
                            NoJavaScript => 1,
                        );
                        if ( $Safe{Replace} ) {
                            $HTMLLink = $Safe{String};
                        }

                        $LayoutObject->Block(
                            Name => 'RecordDynamicFieldLink',
                            Data => {
                                Value                       => $ValueStrg->{Value},
                                Title                       => $ValueStrg->{Title},
                                Link                        => $ValueStrg->{Link},
                                $DynamicFieldConfig->{Name} => $ValueStrg->{Title},
                                HTMLLink                    => $HTMLLink,
                            },
                        );
                    }
                    else {
                        $LayoutObject->Block(
                            Name => 'RecordDynamicFieldPlain',
                            Data => {
                                Value => $ValueStrg->{Value},
                                Title => $ValueStrg->{Title},
                            },
                        );
                    }

                    # example of dynamic fields order customization
                    $LayoutObject->Block(
                        Name => 'RecordDynamicField_' . $DynamicFieldConfig->{Name},
                        Data => {
                            Value => $ValueStrg->{Value},
                            Title => $ValueStrg->{Title},
                        },
                    );

                    if ( $ValueStrg->{Link} ) {
                        $LayoutObject->Block(
                            Name => 'RecordDynamicField_' . $DynamicFieldConfig->{Name} . '_Link',
                            Data => {
                                Value                       => $ValueStrg->{Value},
                                Title                       => $ValueStrg->{Title},
                                Link                        => $ValueStrg->{Link},
                                $DynamicFieldConfig->{Name} => $ValueStrg->{Title},
                                HTMLLink                    => $HTMLLink,
                            },
                        );
                    }
                    else {
                        $LayoutObject->Block(
                            Name => 'RecordDynamicField_' . $DynamicFieldConfig->{Name} . '_Plain',
                            Data => {
                                Value => $ValueStrg->{Value},
                                Title => $ValueStrg->{Title},
                            },
                        );
                    }
                }
            }
        }
    }
    else {
        $LayoutObject->Block( Name => 'NoFAQFound' );
    }

    # use template
    my $Output = $LayoutObject->Output(
        TemplateFile => 'AgentFAQOverviewSmall',
        Data         => {
            %Param,
            Type        => $Self->{ViewType},
            ColumnCount => scalar @ShowColumns,
        },
    );

    return $Output;
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
