# --
# Modified version of the work: Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2022 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::TicketOverview::Small;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);
use Kernel::Language qw(Translatable);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Log',
    'Kernel::Output::HTML::Layout',
    'Kernel::System::CustomerUser',
    'Kernel::System::User',
    'Kernel::System::JSON',
    'Kernel::System::DynamicField',
    'Kernel::System::Ticket::ColumnFilter',
    'Kernel::System::DynamicField::Backend',
    'Kernel::System::Ticket',
    'Kernel::System::Main',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = \%Param;
    bless( $Self, $Type );

    # get UserID param
    $Self->{UserID} = $Param{UserID} || die "Got no UserID!";

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    $Self->{SmallViewColumnHeader} = $ConfigObject->Get('Ticket::Frontend::OverviewSmall')->{ColumnHeader};

    # set pref for columns key
    $Self->{PrefKeyColumns} = 'UserFilterColumnsEnabled' . '-' . $Self->{Action};

    # load backend config
    my $BackendConfigKey = 'Ticket::Frontend::' . $Self->{Action};
    $Self->{Config} = $ConfigObject->Get($BackendConfigKey);

    my %Preferences = $Kernel::OM->Get('Kernel::System::User')->GetPreferences(
        UserID => $Self->{UserID},
    );

    # get JSON object
    my $JSONObject = $Kernel::OM->Get('Kernel::System::JSON');

    # set stored filters if present
    my $StoredFiltersKey = 'UserStoredFilterColumns-' . $Self->{Action};
    if ( $Preferences{$StoredFiltersKey} ) {
        my $StoredFilters = $JSONObject->Decode(
            Data => $Preferences{$StoredFiltersKey},
        );
        $Self->{StoredFilters} = $StoredFilters;
    }

    # get the configured dyanmic fields from the Small Overview setting as a basis
    my %DefaultDynamicFields = %{ $ConfigObject->Get("Ticket::Frontend::OverviewSmall")->{DynamicField} || {} };

    my %DefaultColumns = map { 'DynamicField_' . $_ => $DefaultDynamicFields{$_} } sort keys %DefaultDynamicFields;

    # take general settings (Frontend::Agent) if not defined for the screen
    $Self->{Config}->{DefaultColumns} //= $ConfigObject->Get('DefaultOverviewColumns');

    # check for default settings specific for this screen, should overide the dynamic fields
    %DefaultColumns = ( %DefaultColumns, %{ $Self->{Config}->{DefaultColumns} || {} } );

    # configure columns
    my @ColumnsAvailable = grep { $DefaultColumns{$_} ne '0' } sort keys %DefaultColumns;
    my @ColumnsEnabled
        = grep { $DefaultColumns{$_} eq '2' } sort _DefaultColumnSort keys %DefaultColumns;

    # add article flags
    my $ArticleTabConfig = $ConfigObject->Get('Ticket::Frontend::AgentTicketZoomTabArticle');
    my %ArticleFlagConfig;
    for my $Key (qw(ArticleFlags ArticleFlagIcons ArticleFlagCSS)) {
        $ArticleFlagConfig{$Key} = ();
        next if !defined $ArticleTabConfig->{$Key};
        $ArticleFlagConfig{$Key} = $ArticleTabConfig->{$Key};
    }
    $ArticleFlagConfig{ArticleFlags}->{All} = 'All';
    $Self->{ArticleFlagConfig} = \%ArticleFlagConfig;

    for my $Flag ( keys %{ $ArticleFlagConfig{ArticleFlags} } ) {
        push @ColumnsAvailable, 'MarkedAs::' . $ArticleFlagConfig{ArticleFlags}->{$Flag};
    }

    # get needed objects
    my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # sort available columns depending on selected language
    my %ColumnsAvailableTranslated;
    for my $Column (@ColumnsAvailable) {
        if ( $Column =~ m/^DynamicField_(.*?)$/ ) {
            my $DynamicField = $DynamicFieldObject->DynamicFieldGet( Name => $1 );
            $ColumnsAvailableTranslated{$Column} = $LayoutObject->{LanguageObject}->Translate( $DynamicField->{Label} );
        }
        elsif ( $Column =~ m/^FromTitle/ ) {
            $ColumnsAvailableTranslated{$Column} = $LayoutObject->{LanguageObject}->Translate('From') . ' / ';

            if ( $Self->{SmallViewColumnHeader} eq 'LastCustomerSubject' ) {
                $ColumnsAvailableTranslated{$Column} .= $LayoutObject->{LanguageObject}->Translate('Subject');
                $Self->{Config}->{SortFromTitle}      = 0;
            }
            elsif ( $Self->{SmallViewColumnHeader} eq 'TicketTitle' ) {
                $ColumnsAvailableTranslated{$Column} .= $LayoutObject->{LanguageObject}->Translate('Title');
                $Self->{Config}->{SortFromTitle}      = 1;
            }
        }
        elsif ( $Column =~ m/^MarkedAs::(.*)/ ) {
            $ColumnsAvailableTranslated{$Column} = $LayoutObject->{LanguageObject}->Translate('MarkedAs') . ': '
                                                 . $LayoutObject->{LanguageObject}->Translate($1);
        }
        else {
            $ColumnsAvailableTranslated{$Column} = $LayoutObject->{LanguageObject}->Translate($Column);
        }
    }
    @ColumnsAvailable = sort { $ColumnsAvailableTranslated{$a} cmp $ColumnsAvailableTranslated{$b} }
        keys %ColumnsAvailableTranslated;

    # if preference settings are available, take them
    if ( $Preferences{ $Self->{PrefKeyColumns} } ) {

        my $ColumnsEnabled = $JSONObject->Decode(
            Data => $Preferences{ $Self->{PrefKeyColumns} },
        );

        # remove duplicate columns
        my %UniqueColumns;
        my @ColumnsEnabledAux;

        for my $Column ( @{$ColumnsEnabled} ) {
            if ( !$UniqueColumns{$Column} ) {
                push @ColumnsEnabledAux, $Column;
            }
            $UniqueColumns{$Column} = 1;
        }

        # set filtered column list
        @ColumnsEnabled = @ColumnsEnabledAux;

    }

    # always set TicketNumber
    if ( !grep { $_ eq 'TicketNumber' } @ColumnsEnabled ) {
        unshift @ColumnsEnabled, 'TicketNumber';
    }

    $Self->{ColumnsEnabled}             = \@ColumnsEnabled;
    $Self->{ColumnsAvailable}           = \@ColumnsAvailable;
    $Self->{ColumnsAvailableTranslated} = \%ColumnsAvailableTranslated;

    {

        # loop through all the dynamic fields to get the ones that should be shown
        DYNAMICFIELDNAME:
        for my $DynamicFieldName (@ColumnsEnabled) {

            next DYNAMICFIELDNAME if $DynamicFieldName !~ m{ DynamicField_ }xms;

            # remove dynamic field prefix
            my $FieldName = $DynamicFieldName;
            $FieldName =~ s/DynamicField_//gi;
            $Self->{DynamicFieldFilter}->{$FieldName} = 1;
        }
    }

    # get the dynamic fields for this screen
    $Self->{DynamicField} = $Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldListGet(
        Valid       => 1,
        ObjectType  => ['Ticket'],
        FieldFilter => $Self->{DynamicFieldFilter} || {},
    );

    # hash with all valid sortable columns (taken from TicketSearch)
    # SortBy  => 'Age',   # Created|Owner|Responsible|CustomerID|State|TicketNumber|Queue
    # |Priority|Type|Lock|Title|Service|Changed|SLA|PendingTime|EscalationTime
    # | EscalationUpdateTime|EscalationResponseTime|EscalationSolutionTime
    $Self->{ValidSortableColumns} = {
        'Age'                    => 1,
        'Created'                => 1,
        'Owner'                  => 1,
        'Responsible'            => 1,
        'CustomerID'             => 1,
        'State'                  => 1,
        'TicketNumber'           => 1,
        'Queue'                  => 1,
        'Priority'               => 1,
        'Type'                   => 1,
        'Lock'                   => 1,
        'Title'                  => 1,
        'FromTitle'              => $Self->{Config}->{SortFromTitle},
        'Service'                => 1,
        'Changed'                => 1,
        'SLA'                    => 1,
        'PendingTime'            => 1,
        'EscalationTime'         => 1,
        'EscalationUpdateTime'   => 1,
        'EscalationResponseTime' => 1,
        'EscalationSolutionTime' => 1,
    };

    $Self->{AvailableFilterableColumns} = {
        'Owner'          => 1,
        'Responsible'    => 1,
        'CustomerID'     => 1,
        'CustomerUserID' => 1,
        'State'          => 1,
        'Queue'          => 1,
        'Priority'       => 1,
        'Type'           => 1,
        'Lock'           => 1,
        'Service'        => 1,
        'SLA'            => 1,
    };

    # remove queue from filters on AgentTicketQueue
    if ( $Self->{Action} eq 'AgentTicketQueue' ) {
        delete $Self->{AvailableFilterableColumns}->{Queue};
    }

    # remove service from filters on AgentTicketService
    if ( $Self->{Action} eq 'AgentTicketService' ) {
        delete $Self->{AvailableFilterableColumns}->{Service};
    }

    # remove owner from filters on AgentTicketLockedView
    if ( $Self->{Action} eq 'AgentTicketLockedView' ) {
        delete $Self->{AvailableFilterableColumns}->{Owner};
    }

    # remove responsible from filters on AgentTicketResponsibleView
    if ( $Self->{Action} eq 'AgentTicketResponsibleView' ) {
        delete $Self->{AvailableFilterableColumns}->{Responsible};
    }

    # get dynamic field backend object
    my $BackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');

    # get filterable dynamic fields
    # cycle trough the activated dynamic fields for this screen
    DYNAMICFIELD:
    for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {
        next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

        my $IsFiltrable = $BackendObject->HasBehavior(
            DynamicFieldConfig => $DynamicFieldConfig,
            Behavior           => 'IsFiltrable',
        );

        # if the dynamic field is filterable add it to the AvailableFilterableColumns hash
        if ($IsFiltrable) {
            $Self->{AvailableFilterableColumns}->{ 'DynamicField_' . $DynamicFieldConfig->{Name} } = 1;
        }
    }

    # get sortable dynamic fields
    # cycle trough the activated dynamic fields for this screen
    DYNAMICFIELD:
    for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {
        next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

        my $IsSortable = $BackendObject->HasBehavior(
            DynamicFieldConfig => $DynamicFieldConfig,
            Behavior           => 'IsSortable',
        );

        # if the dynamic field is sortable add it to the ValidSortableColumns hash
        if ($IsSortable) {
            $Self->{ValidSortableColumns}->{ 'DynamicField_' . $DynamicFieldConfig->{Name} } = 1;
        }
    }

    return $Self;
}

sub ActionRow {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # check if bulk feature is enabled
    my $BulkFeature = 0;
    if ( $Param{Bulk} && $ConfigObject->Get('Ticket::Frontend::BulkFeature') ) {
        my @Groups;
        if ( $ConfigObject->Get('Ticket::Frontend::BulkFeatureGroup') ) {
            @Groups = @{ $ConfigObject->Get('Ticket::Frontend::BulkFeatureGroup') };
        }
        if ( !@Groups ) {
            $BulkFeature = 1;
        }
        else {
            GROUP:
            for my $Group (@Groups) {
                next GROUP if !$LayoutObject->{"UserIsGroup[$Group]"};
                if ( $LayoutObject->{"UserIsGroup[$Group]"} eq 'Yes' ) {
                    $BulkFeature = 1;
                    last GROUP;
                }
            }
        }
    }

    $LayoutObject->Block(
        Name => 'DocumentActionRow',
        Data => \%Param,
    );

    if ($BulkFeature) {
        $LayoutObject->Block(
            Name => 'DocumentActionRowBulk',
            Data => {
                %Param,
                Name => Translatable('Bulk'),
            },
        );
    }

    # check if there was a column filter and no results, and print a link to back
    if ( scalar @{ $Param{TicketIDs} } == 0 && $Param{LastColumnFilter} ) {
        $LayoutObject->Block(
            Name => 'DocumentActionRowLastColumnFilter',
            Data => {
                %Param,
            },
        );
    }

    # add translations for the allocation lists for regular columns
    my %Column  = map { $_ => 1 } @{ $Self->{ColumnsAvailable} };
    my $Columns = \%Column;
    if ( $Columns && IsHashRefWithData($Columns) ) {

        COLUMN:
        for my $Column ( sort keys %{$Columns} ) {

            # dynamic fields will be translated in the next block
            next COLUMN if $Column =~ m{ \A DynamicField_ }xms;

            my $TranslatedWord = $Column;
            if ( $Column eq 'EscalationTime' ) {
                $TranslatedWord = Translatable('Service Time');
            }
            elsif ( $Column eq 'EscalationResponseTime' ) {
                $TranslatedWord = Translatable('First Response Time');
            }
            elsif ( $Column eq 'EscalationSolutionTime' ) {
                $TranslatedWord = Translatable('Solution Time');
            }
            elsif ( $Column eq 'EscalationUpdateTime' ) {
                $TranslatedWord = Translatable('Update Time');
            }
            elsif ( $Column eq 'PendingTime' ) {
                $TranslatedWord = Translatable('Pending till');
            }
            elsif ( $Column eq 'CustomerCompanyName' ) {
                $TranslatedWord = Translatable('Customer Company Name');
            }
            elsif ( $Column eq 'CustomerUserID' ) {
                $TranslatedWord = Translatable('Customer User ID');
            }

            my $TranslateString;
            if ( $Column =~ m/^MarkedAs::(.*)$/ ) {
                $TranslateString = $LayoutObject->{LanguageObject}->Translate('MarkedAs') . ': '
                                 . $LayoutObject->{LanguageObject}->Translate($1);
            }
            else {
                $TranslateString = $LayoutObject->{LanguageObject}->Translate($TranslatedWord);
            }

            $LayoutObject->Block(
                Name => 'ColumnTranslation',
                Data => {
                    ColumnName      => $Column,
                    TranslateString => $TranslateString,
                },
            );
            $LayoutObject->Block(
                Name => 'ColumnTranslationSeparator',
            );
        }
    }

    # add translations for the allocation lists for dynamic field columns
    my $ColumnsDynamicField = $Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldListGet(
        Valid      => 0,
        ObjectType => ['Ticket'],
    );

    if ( $ColumnsDynamicField && IsArrayRefWithData($ColumnsDynamicField) ) {

        my $Counter = 0;

        DYNAMICFIELD:
        for my $DynamicField ( sort @{$ColumnsDynamicField} ) {

            next DYNAMICFIELD if !$DynamicField;

            $Counter++;

            $LayoutObject->Block(
                Name => 'ColumnTranslation',
                Data => {
                    ColumnName      => 'DynamicField_' . $DynamicField->{Name},
                    TranslateString => $LayoutObject->{LanguageObject}->Translate( $DynamicField->{Label} ) . " (DF)",
                },
            );

            if ( $Counter < scalar @{$ColumnsDynamicField} ) {
                $LayoutObject->Block(
                    Name => 'ColumnTranslationSeparator',
                );
            }
        }
    }

    my $Output = $LayoutObject->Output(
        TemplateFile => 'AgentTicketOverviewSmall',
        Data         => \%Param,
    );

    return $Output;
}

sub SortOrderBar {
    my ( $Self, %Param ) = @_;

    return '';
}

sub Run {
    my ( $Self, %Param ) = @_;

    # If $Param{EnableColumnFilters} is not sent, we want to disable all filters
    #   for the current screen. We localize the setting for this sub and change it
    #   after that, if needed. The original value will be restored after this function.
    local $Self->{AvailableFilterableColumns} = $Self->{AvailableFilterableColumns};
    if ( !$Param{EnableColumnFilters} ) {
        $Self->{AvailableFilterableColumns} = {};    # disable all column filters
    }

    # check needed stuff
    for (qw(OriginalTicketIDs TicketIDs PageShown StartHit)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # get needed objects
    my $ConfigObject       = $Kernel::OM->Get('Kernel::Config');
    my $LayoutObject       = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $CustomerUserObject = $Kernel::OM->Get('Kernel::System::CustomerUser');
    my $BackendObject      = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');
    my $HTMLUtilsObject    = $Kernel::OM->Get('Kernel::System::HTMLUtils');
    my $TicketObject       = $Kernel::OM->Get('Kernel::System::Ticket');
    my $TimeObject         = $Kernel::OM->Get('Kernel::System::Time');
    my $UserObject         = $Kernel::OM->Get('Kernel::System::User');

    # get isolated layout object for link safety checks
    my $HTMLLinkLayoutObject = $Kernel::OM->GetNew('Kernel::Output::HTML::Layout');

    # get needed un-/selected tickets for bulk feature
    my @SelectedItems     = @{ $Param{SelectedItems} };
    my %SelectedItemsHash = map( { $_ => 1 } @SelectedItems );
    my @UnselectedItems   = @{ $Param{UnselectedItems} };

    # check if bulk feature is enabled
    my $BulkFeature = 0;
    if ( $Param{Bulk} && $ConfigObject->Get('Ticket::Frontend::BulkFeature') ) {
        my @Groups;
        if ( $ConfigObject->Get('Ticket::Frontend::BulkFeatureGroup') ) {
            @Groups = @{ $ConfigObject->Get('Ticket::Frontend::BulkFeatureGroup') };
        }
        if ( !@Groups ) {
            $BulkFeature = 1;
        }
        else {
            GROUP:
            for my $Group (@Groups) {
                next GROUP if !$LayoutObject->{"UserIsGroup[$Group]"};
                if ( $LayoutObject->{"UserIsGroup[$Group]"} eq 'Yes' ) {
                    $BulkFeature = 1;
                    last GROUP;
                }
            }
        }
    }

    my $Counter = 0;
    my @ArticleBox;
    for my $TicketID ( @{ $Param{TicketIDs} } ) {
        $Counter++;
        if ( $Counter >= $Param{StartHit} && $Counter < ( $Param{PageShown} + $Param{StartHit} ) ) {
            # get last customer article
            my %Article = $TicketObject->ArticleLastCustomerArticle(
                TicketID      => $TicketID,
                Extended      => 1,
                DynamicFields => 0,
            );

            # get ticket data
            my %Ticket = $TicketObject->TicketGet(
                TicketID      => $TicketID,
                Extended      => 1,
                DynamicFields => 0,
            );

            # Fallback for tickets without articles: get at least basic ticket data
            if ( !%Article ) {
                %Article = %Ticket;
                if ( !$Article{Title} ) {
                    $Article{Title} = $LayoutObject->{LanguageObject}->Translate(
                        'This ticket has no title or subject'
                    );
                }
                $Article{Subject} = $Article{Title};
            }

            # show ticket create time in small view
            $Article{Created} = $Ticket{Created};

            # prepare a "long" version of the subject to show in the title attribute. We don't take
            # the whole string (which could be VERY long) to avoid polluting the DOM and having too
            # much data to be transferred on large ticket lists
            $Article{SubjectLong} = $TicketObject->TicketSubjectClean(
                TicketNumber => $Article{TicketNumber},
                Subject      => $Article{Subject} || '',
                Size         => 500,
            );

            # get class for ticket highlight
            $Article{HighlightClass} = $LayoutObject->GetTicketHighlight(
                View   => 'Small',
                Ticket => \%Article
            );

            # prepare subject
            $Article{Subject} = $TicketObject->TicketSubjectClean(
                TicketNumber => $Article{TicketNumber},
                Subject      => $Article{Subject} || '',
            );

            # create human age
            $Article{Age} = $LayoutObject->CustomerAge(
                Age   => $Article{Age},
                Space => ' ',
            );

            my $PreMenuCount = 0;

            # run ticket pre menu modules
            my @ActionItems;
            if ( IsHashRefWithData($ConfigObject->Get('Ticket::Frontend::PreMenuModule')) ) {

                # get ACL restrictions
                my %PossibleActions;

                # get all registered Actions
                if ( ref $ConfigObject->Get('Frontend::Module') eq 'HASH' ) {

                    my %Actions = %{ $ConfigObject->Get('Frontend::Module') };

                    # only use those Actions that stats with AgentTicket
                    %PossibleActions = map { ++$PreMenuCount => $_ }
                        grep { substr( $_, 0, length 'AgentTicket' ) eq 'AgentTicket' }
                        sort keys %Actions;
                }

                my $ACL = $TicketObject->TicketAcl(
                    Data          => \%PossibleActions,
                    Action        => $Self->{Action},
                    TicketID      => $Article{TicketID},
                    ReturnType    => 'Action',
                    ReturnSubType => '-',
                    UserID        => $Self->{UserID},
                );
                my %AclAction = %PossibleActions;
                if ($ACL) {
                    %AclAction = $TicketObject->TicketAclActionData();
                }

                my %Menus = %{ $ConfigObject->Get('Ticket::Frontend::PreMenuModule') };
                MENU:
                for my $Menu ( sort keys %Menus ) {

                    # load module
                    if ( !$Kernel::OM->Get('Kernel::System::Main')->Require( $Menus{$Menu}->{Module} ) ) {
                        return $LayoutObject->FatalError();
                    }
                    my $Object = $Menus{$Menu}->{Module}->new(
                        %{$Self},
                        TicketID => $Article{TicketID},
                    );

                    # run module
                    my $Item = $Object->Run(
                        %Param,
                        Ticket => \%Article,
                        ACL    => \%AclAction,
                        Config => $Menus{$Menu},
                    );
                    next MENU if !$Item;
                    next MENU if ref $Item ne 'HASH';

                    # add session id if needed
                    if ( !$LayoutObject->{SessionIDCookie} && $Item->{Link} ) {
                        $Item->{Link}
                            .= ';'
                            . $LayoutObject->{SessionName} . '='
                            . $LayoutObject->{SessionID};
                    }

                    # create id
                    $Item->{ID} = $Item->{Name};
                    $Item->{ID} =~ s/(\s|&|;)//ig;

                    my $Output;
                    if ( $Item->{Block} ) {
                        $LayoutObject->Block(
                            Name => $Item->{Block},
                            Data => $Item,
                        );
                        $Output = $LayoutObject->Output(
                            TemplateFile => 'AgentTicketOverviewSmall',
                            Data         => $Item,
                        );
                    }
                    else {
                        $Output = '<li id="'
                            . $Item->{ID}
                            . '"><a href="#" title="'
                            . $LayoutObject->{LanguageObject}->Translate( $Item->{Description} )
                            . '">'
                            . $LayoutObject->{LanguageObject}->Translate( $Item->{Name} )
                            . '</a></li>';
                    }

                    $Output =~ s/\n+//g;
                    $Output =~ s/\s+/ /g;
                    $Output =~ s/<\!--.+?-->//g;

                    # check if the browser sends the session id cookie
                    # if not, add the session id to the url
                    my $SessionID = '';
                    if ( $Self->{SessionID} && !$Self->{SessionIDCookie} ) {
                        $SessionID = ';' . $Self->{SessionName} . '=' . $Self->{SessionID};
                    }

                    push @ActionItems, {
                        HTML        => $Output,
                        ID          => $Item->{ID},
                        Link        => $LayoutObject->{Baselink} . $Item->{Link} . $SessionID,
                        Target      => $Item->{Target},
                        PopupType   => $Item->{PopupType},
                        Description => $Item->{Description},
                    };
                    $Article{ActionItems} = \@ActionItems;
                }
            }

            # get all article flags of ticket
            my %ArticleFlagHash = ();
            my %ArticleFlags = $TicketObject->ArticleFlagsOfTicketGet(
                TicketID => $TicketID,
                UserID   => $Self->{UserID},
            );

            for my $ArticleID (keys %ArticleFlags) {
                my @TempArray = ();
                for my $Flag ( keys %{$ArticleFlags{$ArticleID}} ) {
                    next if $Flag eq 'Seen';
                    push @TempArray, $Flag;
                }
                $ArticleFlagHash{$ArticleID} = \@TempArray;
            }

            $Article{FlagHash} = \%ArticleFlagHash;

            push @ArticleBox, \%Article;
        }
    }

    # check if sysconfig is a hash reference
    if ( IsArrayRefWithData( $Self->{ColumnsEnabled} ) ) {

        # check if column is really filterable
        COLUMNNAME:
        for my $ColumnName ( @{ $Self->{ColumnsEnabled} } ) {
            next COLUMNNAME if !grep { $_ eq $ColumnName } @{ $Self->{ColumnsEnabled} };
            next COLUMNNAME if !$Self->{AvailableFilterableColumns}->{$ColumnName};
            $Self->{ValidFilterableColumns}->{$ColumnName} = 1;
        }
    }

    my $ColumnValues = $Self->_GetColumnValues(
        OriginalTicketIDs => $Param{OriginalTicketIDs},
    );

    $LayoutObject->Block(
        Name => 'DocumentContent',
        Data => \%Param,
    );

    # array to save the column names to do the query
    my @Col = @{ $Self->{ColumnsEnabled} };

    # define special ticket columns
    my %SpecialColumns = (
        TicketNumber        => 1,
        Owner               => 1,
        Responsible         => 1,
        CustomerID          => 1,
        FromTitle           => 1,
        LastCustomerSubject => 1,
        ArticleFlagAll      => 1,
    );

    for my $Flag ( keys %{ $Self->{ArticleFlagConfig}->{ArticleFlags} } ) {
        $SpecialColumns{ 'MarkedAs::' . $Self->{ArticleFlagConfig}->{ArticleFlags}->{$Flag} } = 1
    }

    my $TicketData = scalar @ArticleBox;
    if ($TicketData) {

        $LayoutObject->Block( Name => 'OverviewTable' );
        $LayoutObject->Block( Name => 'TableHeader' );

        if ($BulkFeature) {
            my $ItemALLChecked = '';
            my $SelectedAll      = '';

            if ( !scalar( @UnselectedItems ) ) {
                $ItemALLChecked = ' checked="checked"';
            }

            if ( $Param{AllHits} > $Param{PageShown} ) {
                $SelectedAll = 'SelectAllItemsPages';
            }

            $LayoutObject->Block(
                Name => 'GeneralOverviewHeader',
            );
            $LayoutObject->Block(
                Name => 'BulkNavBar',
                Data => {
                    %Param,
                    ItemALLChecked  => $ItemALLChecked,
                    SelectedAll     => $SelectedAll
                }
            );
        }

        # meta items
        my @TicketMetaItems = $LayoutObject->TicketMetaItemsCount();
        for my $Item (@TicketMetaItems) {

            $LayoutObject->Block(
                Name => 'GeneralOverviewHeader',
            );

            my $CSS = '';
            my $OrderBy;
            my $Title = $Item;

            if ( $Param{SortBy} && ( $Param{SortBy} eq $Item ) ) {
                if ( $Param{OrderBy} && ( $Param{OrderBy} eq 'Up' ) ) {
                    $OrderBy = 'Down';
                    $CSS .= ' SortAscendingLarge';
                }
                else {
                    $OrderBy = 'Up';
                    $CSS .= ' SortDescendingLarge';
                }

                # set title description
                my $TitleDesc
                    = $OrderBy eq 'Down' ? Translatable('sorted descending') : Translatable('sorted ascending');
                $TitleDesc = $LayoutObject->{LanguageObject}->Translate($TitleDesc);
                $Title .= ', ' . $TitleDesc;
            }

            $LayoutObject->Block(
                Name => 'OverviewNavBarPageFlag',
                Data => {
                    CSS   => $CSS,
                    Title => $Title,
                },
            );

            if ( $Item eq 'New Article' ) {
                $LayoutObject->Block(
                    Name => 'OverviewNavBarPageFlagEmpty',
                    Data => {
                        Name => $Item,
                        }
                );
            }
            else {
                $LayoutObject->Block(
                    Name => 'OverviewNavBarPageFlagLink',
                    Data => {
                        %Param,
                        Name    => $Item,
                        CSS     => $CSS,
                        OrderBy => $OrderBy,
                        Title   => $Title,
                    },
                );
            }

        }

        my $CSS = '';
        my $OrderBy;

        # show special ticket columns, if needed
        COLUMN:
        for my $Column (@Col) {

            $LayoutObject->Block(
                Name => 'GeneralOverviewHeader',
            );

            $CSS = $Column;
            my $Title = $LayoutObject->{LanguageObject}->Translate($Column);

            # output overall block so TicketNumber as well as other columns can be ordered
            $LayoutObject->Block(
                Name => 'OverviewNavBarPageTicketHeader',
                Data => {},
            );

            if ( $SpecialColumns{$Column} ) {

                if ( $Param{SortBy} && ( $Param{SortBy} eq $Column ) ) {
                    if ( $Param{OrderBy} && ( $Param{OrderBy} eq 'Up' ) ) {
                        $OrderBy = 'Down';
                        $CSS .= ' SortAscendingLarge';
                    }
                    else {
                        $OrderBy = 'Up';
                        $CSS .= ' SortDescendingLarge';
                    }

                    # add title description
                    my $TitleDesc
                        = $OrderBy eq 'Down' ? Translatable('sorted ascending') : Translatable('sorted descending');
                    $TitleDesc = $LayoutObject->{LanguageObject}->Translate($TitleDesc);
                    $Title .= ', ' . $TitleDesc;
                }

                # translate the column name to write it in the current language
                my $TranslatedWord = $Self->{ColumnsAvailableTranslated}->{$Column};

                if ( $Column =~ /^MarkedAs::(.*)$/ ) {
                    $TranslatedWord = $LayoutObject->{LanguageObject}->Translate($1);
                }

                my $FilterTitle     = $TranslatedWord;
                my $FilterTitleDesc = Translatable('filter not active');
                if (
                    $Self->{StoredFilters} &&
                    (
                        $Self->{StoredFilters}->{$Column} ||
                        $Self->{StoredFilters}->{ $Column . 'IDs' }
                    )
                ) {
                    $CSS .= ' FilterActive';
                    $FilterTitleDesc = Translatable('filter active');
                }
                $FilterTitleDesc = $LayoutObject->{LanguageObject}->Translate($FilterTitleDesc);
                $FilterTitle .= ', ' . $FilterTitleDesc;

                $LayoutObject->Block(
                    Name =>
                        $Column eq 'TicketNumber'
                    ? 'OverviewNavBarPageTicketNumber'
                    : 'OverviewNavBarPageColumn',
                    Data => {
                        %Param,
                        OrderBy              => $OrderBy,
                        ColumnName           => $Column || '',
                        CSS                  => $CSS || '',
                        ColumnNameTranslated => $TranslatedWord || $Column,
                        Title                => $Title,
                    },
                );

                # verify if column is filterable and sortable
                if (
                    $Self->{ValidFilterableColumns}->{$Column}
                    && $Self->{ValidSortableColumns}->{$Column}
                ) {
                    my $Css;
                    if ( $Column eq 'CustomerID' || $Column eq 'Owner' || $Column eq 'Responsible' ) {
                        $Css .= ' Hidden';
                    }

                    # variable to save the filter's html code
                    my $ColumnFilterHTML = $Self->_InitialColumnFilter(
                        ColumnName    => $Column,
                        Label         => $Column,
                        ColumnValues  => $ColumnValues->{$Column},
                        SelectedValue => $Param{GetColumnFilter}->{$Column} || '',
                        Css           => $Css,
                    );

                    $LayoutObject->Block(
                        Name => 'OverviewNavBarPageColumnFilterLink',
                        Data => {
                            %Param,
                            ColumnName           => $Column,
                            CSS                  => $CSS,
                            ColumnNameTranslated => $TranslatedWord || $Column,
                            ColumnFilterStrg     => $ColumnFilterHTML,
                            OrderBy              => $OrderBy,
                            Title                => $Title,
                            FilterTitle          => $FilterTitle,
                        },
                    );

                    if ( $Column eq 'CustomerID' ) {

                        $LayoutObject->Block(
                            Name =>
                                'ContentLargeTicketGenericHeaderColumnFilterLinkCustomerIDSearch',
                            Data => {
                                minQueryLength      => 2,
                                queryDelay          => 100,
                                maxResultsDisplayed => 20,
                            },
                        );
                    }
                    elsif ( $Column eq 'Owner' || $Column eq 'Responsible' ) {

                        $LayoutObject->Block(
                            Name => 'ContentLargeTicketGenericHeaderColumnFilterLinkUserSearch',
                            Data => {
                                minQueryLength      => 2,
                                queryDelay          => 100,
                                maxResultsDisplayed => 20,
                            },
                        );
                    }

                }

                # verify if column is filterable and sortable
                elsif ( $Self->{ValidFilterableColumns}->{$Column} ) {

                    # variable to save the filter's HTML code
                    my $ColumnFilterHTML = $Self->_InitialColumnFilter(
                        ColumnName    => $Column,
                        Label         => $Column,
                        ColumnValues  => $ColumnValues->{$Column},
                        SelectedValue => $Param{GetColumnFilter}->{$Column} || '',
                    );

                    $LayoutObject->Block(
                        Name => 'OverviewNavBarPageColumnFilter',
                        Data => {
                            %Param,
                            ColumnName           => $Column,
                            CSS                  => $CSS,
                            ColumnNameTranslated => $TranslatedWord || $Column,
                            ColumnFilterStrg     => $ColumnFilterHTML,
                            OrderBy              => $OrderBy,
                            Title                => $Title,
                            FilterTitle          => $FilterTitle,
                        },
                    );
                }

                # verify if column is sortable
                elsif ( $Self->{ValidSortableColumns}->{$Column} ) {
                    $LayoutObject->Block(
                        Name => 'OverviewNavBarPageColumnLink',
                        Data => {
                            %Param,
                            ColumnName           => $Column,
                            CSS                  => $CSS,
                            ColumnNameTranslated => $TranslatedWord || $Column,
                            OrderBy              => $OrderBy,
                            Title                => $Title,
                        },
                    );
                }
                else {
                    $LayoutObject->Block(
                        Name => 'OverviewNavBarPageColumnEmpty',
                        Data => {
                            %Param,
                            ColumnName           => $Column,
                            CSS                  => $CSS,
                            ColumnNameTranslated => $TranslatedWord || $Column,
                            Title                => $Title,
                        },
                    );
                }
                next COLUMN;
            }
            elsif ( $Column !~ m{\A DynamicField_}xms ) {

                if ( $Param{SortBy} && ( $Param{SortBy} eq $Column ) ) {
                    if ( $Param{OrderBy} && ( $Param{OrderBy} eq 'Up' ) ) {
                        $OrderBy = 'Down';
                        $CSS .= ' SortAscendingLarge';
                    }
                    else {
                        $OrderBy = 'Up';
                        $CSS .= ' SortDescendingLarge';
                    }

                    # add title description
                    my $TitleDesc
                        = $OrderBy eq 'Down' ? Translatable('sorted ascending') : Translatable('sorted descending');
                    $TitleDesc = $LayoutObject->{LanguageObject}->Translate($TitleDesc);
                    $Title .= ', ' . $TitleDesc;
                }

                # translate the column name to write it in the current language
                my $TranslatedWord;
                if ( $Column eq 'EscalationTime' ) {
                    $TranslatedWord = $LayoutObject->{LanguageObject}->Translate('Service Time');
                }
                elsif ( $Column eq 'EscalationResponseTime' ) {
                    $TranslatedWord = $LayoutObject->{LanguageObject}->Translate('First Response Time');
                }
                elsif ( $Column eq 'EscalationSolutionTime' ) {
                    $TranslatedWord = $LayoutObject->{LanguageObject}->Translate('Solution Time');
                }
                elsif ( $Column eq 'EscalationUpdateTime' ) {
                    $TranslatedWord = $LayoutObject->{LanguageObject}->Translate('Update Time');
                }
                elsif ( $Column eq 'PendingTime' ) {
                    $TranslatedWord = $LayoutObject->{LanguageObject}->Translate('Pending till');
                }
                elsif ( $Column eq 'CustomerCompanyName' ) {
                    $TranslatedWord = $LayoutObject->{LanguageObject}->Translate('Customer Company Name');
                }
                elsif ( $Column eq 'CustomerUserID' ) {
                    $TranslatedWord = $LayoutObject->{LanguageObject}->Translate('Customer User ID');
                }
                else {
                    $TranslatedWord = $LayoutObject->{LanguageObject}->Translate($Column);
                }

                my $FilterTitle     = $TranslatedWord;
                my $FilterTitleDesc = Translatable('filter not active');
                if ( $Self->{StoredFilters} && $Self->{StoredFilters}->{ $Column . 'IDs' } ) {
                    $CSS .= ' FilterActive';
                    $FilterTitleDesc = Translatable('filter active');
                }
                $FilterTitleDesc = $LayoutObject->{LanguageObject}->Translate($FilterTitleDesc);
                $FilterTitle .= ', ' . $FilterTitleDesc;

                $LayoutObject->Block(
                    Name => 'OverviewNavBarPageColumn',
                    Data => {
                        %Param,
                        ColumnName           => $Column,
                        CSS                  => $CSS,
                        ColumnNameTranslated => $TranslatedWord || $Column,
                    },
                );

                # verify if column is filterable and sortable
                if (
                    $Self->{ValidFilterableColumns}->{$Column}
                    && $Self->{ValidSortableColumns}->{$Column}
                ) {

                    # variable to save the filter's HTML code
                    my $ColumnFilterHTML = $Self->_InitialColumnFilter(
                        ColumnName    => $Column,
                        Label         => $Column,
                        ColumnValues  => $ColumnValues->{$Column},
                        SelectedValue => $Param{GetColumnFilter}->{$Column} || '',
                    );

                    $LayoutObject->Block(
                        Name => 'OverviewNavBarPageColumnFilterLink',
                        Data => {
                            %Param,
                            ColumnName           => $Column,
                            CSS                  => $CSS,
                            ColumnNameTranslated => $TranslatedWord || $Column,
                            ColumnFilterStrg     => $ColumnFilterHTML,
                            OrderBy              => $OrderBy,
                            Title                => $Title,
                            FilterTitle          => $FilterTitle,
                        },
                    );
                }

                # verify if column is just filterable
                elsif ( $Self->{ValidFilterableColumns}->{$Column} ) {

                    my $Css;
                    if ( $Column eq 'CustomerUserID' ) {
                        $Css = 'Hidden';
                    }

                    # variable to save the filter's HTML code
                    my $ColumnFilterHTML = $Self->_InitialColumnFilter(
                        ColumnName    => $Column,
                        Label         => $Column,
                        ColumnValues  => $ColumnValues->{$Column},
                        SelectedValue => $Param{GetColumnFilter}->{$Column} || '',
                        Css           => $Css,
                    );
                    $LayoutObject->Block(
                        Name => 'OverviewNavBarPageColumnFilter',
                        Data => {
                            %Param,
                            ColumnName           => $Column,
                            CSS                  => $CSS,
                            ColumnNameTranslated => $TranslatedWord || $Column,
                            ColumnFilterStrg     => $ColumnFilterHTML,
                            OrderBy              => $OrderBy,
                            Title                => $Title,
                            FilterTitle          => $FilterTitle,
                        },
                    );
                    if ( $Column eq 'CustomerUserID' ) {

                        $LayoutObject->Block(
                            Name =>
                                'ContentLargeTicketGenericHeaderColumnFilterLinkCustomerUserSearch',
                            Data => {
                                minQueryLength      => 2,
                                queryDelay          => 100,
                                maxResultsDisplayed => 20,
                            },
                        );
                    }
                }

                # verify if column is sortable
                elsif ( $Self->{ValidSortableColumns}->{$Column} ) {
                    $LayoutObject->Block(
                        Name => 'OverviewNavBarPageColumnLink',
                        Data => {
                            %Param,
                            ColumnName           => $Column,
                            CSS                  => $CSS,
                            ColumnNameTranslated => $TranslatedWord || $Column,
                            OrderBy              => $OrderBy,
                            Title                => $Title,
                        },
                    );
                }
                else {
                    $LayoutObject->Block(
                        Name => 'OverviewNavBarPageColumnEmpty',
                        Data => {
                            %Param,
                            ColumnName           => $Column,
                            CSS                  => $CSS,
                            ColumnNameTranslated => $TranslatedWord || $Column,
                            Title                => $Title,
                        },
                    );
                }
            }

            # show the DFs
            else {

                my $DynamicFieldConfig;
                my $DFColumn = $Column;
                $DFColumn =~ s/DynamicField_//g;
                DYNAMICFIELD:
                for my $DFConfig ( @{ $Self->{DynamicField} } ) {
                    next DYNAMICFIELD if !IsHashRefWithData($DFConfig);
                    next DYNAMICFIELD if $DFConfig->{Name} ne $DFColumn;

                    $DynamicFieldConfig = $DFConfig;
                    last DYNAMICFIELD;
                }
                next COLUMN if !IsHashRefWithData($DynamicFieldConfig);

                my $Label = $LayoutObject->{LanguageObject}->Translate( $DynamicFieldConfig->{Label} );
                $Title = $Label;
                my $FilterTitle = $Label;

                # get field sortable condition
                my $IsSortable = $BackendObject->HasBehavior(
                    DynamicFieldConfig => $DynamicFieldConfig,
                    Behavior           => 'IsSortable',
                );

                if ($IsSortable) {
                    my $DynamicFieldCSS = 'DynamicField_' . $DynamicFieldConfig->{Name};
                    my $DynamicFieldOrderBy;
                    if (
                        $Param{SortBy}
                        && ( $Param{SortBy} eq ( 'DynamicField_' . $DynamicFieldConfig->{Name} ) )
                    ) {
                        if ( $Param{OrderBy} && ( $Param{OrderBy} eq 'Up' ) ) {
                            $DynamicFieldOrderBy = 'Down';
                            $DynamicFieldCSS .= ' SortAscendingLarge';
                        }
                        else {
                            $DynamicFieldOrderBy = 'Up';
                            $DynamicFieldCSS .= ' SortDescendingLarge';
                        }

                        # add title description
                        my $TitleDesc
                            = $DynamicFieldOrderBy eq 'Down' ? Translatable('sorted ascending') : Translatable('sorted descending');
                        $TitleDesc = $LayoutObject->{LanguageObject}->Translate($TitleDesc);
                        $Title .= ', ' . $TitleDesc;
                    }

                    my $FilterTitleDesc = Translatable('filter not active');
                    if ( $Self->{StoredFilters} && $Self->{StoredFilters}->{$Column} ) {
                        $DynamicFieldCSS .= ' FilterActive';
                        $FilterTitleDesc = Translatable('filter active');
                    }
                    $FilterTitleDesc = $LayoutObject->{LanguageObject}->Translate($FilterTitleDesc);
                    $FilterTitle .= ', ' . $FilterTitleDesc;

                    $LayoutObject->Block(
                        Name => 'OverviewNavBarPageDynamicField',
                        Data => {
                            %Param,
                            CSS => $DynamicFieldCSS,
                        },
                    );

                    my $DynamicFieldName = 'DynamicField_' . $DynamicFieldConfig->{Name};

                    if ( $Self->{ValidFilterableColumns}->{$DynamicFieldName} ) {

                        # variable to save the filter's HTML code
                        my $ColumnFilterHTML = $Self->_InitialColumnFilter(
                            ColumnName    => $DynamicFieldName,
                            Label         => $Label,
                            ColumnValues  => $ColumnValues->{$DynamicFieldName},
                            SelectedValue => $Param{GetColumnFilter}->{$DynamicFieldName} || '',
                        );

                        $LayoutObject->Block(
                            Name => 'OverviewNavBarPageDynamicFieldFiltrableSortable',
                            Data => {
                                %Param,
                                Label            => $Label,
                                DynamicFieldName => $DynamicFieldConfig->{Name},
                                ColumnFilterStrg => $ColumnFilterHTML,
                                OrderBy          => $DynamicFieldOrderBy,
                                Title            => $Title,
                                FilterTitle      => $FilterTitle,
                            },
                        );
                    }

                    else {
                        $LayoutObject->Block(
                            Name => 'OverviewNavBarPageDynamicFieldSortable',
                            Data => {
                                %Param,
                                OrderBy          => $DynamicFieldOrderBy,
                                Label            => $Label,
                                DynamicFieldName => $DynamicFieldConfig->{Name},
                                Title            => $Title,
                            },
                        );
                    }

                    # example of dynamic fields order customization
                    $LayoutObject->Block(
                        Name => 'OverviewNavBarPageDynamicField_' . $DynamicFieldConfig->{Name},
                        Data => {
                            %Param,
                            CSS => $DynamicFieldCSS,
                        },
                    );

                    if ( $Self->{ValidFilterableColumns}->{$DynamicFieldName} ) {

                        # variable to save the filter's HTML code
                        my $ColumnFilterHTML = $Self->_InitialColumnFilter(
                            ColumnName    => $DynamicFieldName,
                            Label         => $Label,
                            ColumnValues  => $ColumnValues->{$DynamicFieldName},
                            SelectedValue => $Param{GetColumnFilter}->{$DynamicFieldName} || '',
                        );

                        $LayoutObject->Block(
                            Name => 'OverviewNavBarPageDynamicField'
                                . $DynamicFieldConfig->{Name}
                                . '_FiltrableSortable',
                            Data => {
                                %Param,
                                Label            => $Label,
                                DynamicFieldName => $DynamicFieldConfig->{Name},
                                ColumnFilterStrg => $ColumnFilterHTML,
                                OrderBy          => $DynamicFieldOrderBy,
                                Title            => $Title,
                            },
                        );
                    }
                    else {
                        $LayoutObject->Block(
                            Name => 'OverviewNavBarPageDynamicField_'
                                . $DynamicFieldConfig->{Name}
                                . '_Sortable',
                            Data => {
                                %Param,
                                OrderBy          => $DynamicFieldOrderBy,
                                Label            => $Label,
                                DynamicFieldName => $DynamicFieldConfig->{Name},
                                Title            => $Title,
                            },
                        );
                    }
                }
                else {

                    my $DynamicFieldName = 'DynamicField_' . $DynamicFieldConfig->{Name};
                    my $DynamicFieldCSS  = $DynamicFieldName;

                    $LayoutObject->Block(
                        Name => 'OverviewNavBarPageDynamicField',
                        Data => {
                            %Param,
                            CSS => $DynamicFieldCSS,
                        },
                    );

                    if ( $Self->{ValidFilterableColumns}->{$DynamicFieldName} ) {

                        # variable to save the filter's HTML code
                        my $ColumnFilterHTML = $Self->_InitialColumnFilter(
                            ColumnName    => $DynamicFieldName,
                            Label         => $Label,
                            ColumnValues  => $ColumnValues->{$DynamicFieldName},
                            SelectedValue => $Param{GetColumnFilter}->{$DynamicFieldName} || '',
                        );

                        $LayoutObject->Block(
                            Name => 'OverviewNavBarPageDynamicFieldFiltrableNotSortable',
                            Data => {
                                %Param,
                                Label            => $Label,
                                DynamicFieldName => $DynamicFieldConfig->{Name},
                                ColumnFilterStrg => $ColumnFilterHTML,
                                Title            => $Title,
                                FilterTitle      => $FilterTitle,
                            },
                        );
                    }
                    else {
                        $LayoutObject->Block(
                            Name => 'OverviewNavBarPageDynamicFieldNotSortable',
                            Data => {
                                %Param,
                                Label => $Label,
                                Title => $Title,
                            },
                        );
                    }

                    # example of dynamic fields order customization
                    $LayoutObject->Block(
                        Name => 'OverviewNavBarPageDynamicField_' . $DynamicFieldConfig->{Name},
                        Data => {
                            %Param,
                        },
                    );

                    if ( $Self->{ValidFilterableColumns}->{$DynamicFieldName} ) {

                        # variable to save the filter's HTML code
                        my $ColumnFilterHTML = $Self->_InitialColumnFilter(
                            ColumnName    => $DynamicFieldName,
                            Label         => $Label,
                            ColumnValues  => $ColumnValues->{$DynamicFieldName},
                            SelectedValue => $Param{GetColumnFilter}->{$DynamicFieldName} || '',
                        );

                        $LayoutObject->Block(
                            Name => 'OverviewNavBarPageDynamicField_'
                                . $DynamicFieldConfig->{Name}
                                . '_FiltrableNotSortable',
                            Data => {
                                %Param,
                                Label            => $Label,
                                DynamicFieldName => $DynamicFieldConfig->{Name},
                                ColumnFilterStrg => $ColumnFilterHTML,
                                Title            => $Title,
                            },
                        );
                    }
                    else {
                        $LayoutObject->Block(
                            Name => 'OverviewNavBarPageDynamicField_'
                                . $DynamicFieldConfig->{Name}
                                . '_NotSortable',
                            Data => {
                                %Param,
                                Label => $Label,
                                Title => $Title,
                            },
                        );
                    }
                }

            }

        }

        $LayoutObject->Block( Name => 'TableBody' );

    }
    else {
        $LayoutObject->Block( Name => 'NoTicketFound' );
    }

    my $BulkActivate = 0;
    for my $ArticleRef (@ArticleBox) {

        # get last customer article
        my %Article = %{$ArticleRef};

        # get ticket escalation preferences
        my $TicketEscalation = $TicketObject->TicketEscalationCheck(
            TicketID => $Article{TicketID},
            UserID   => $Self->{UserID},
        );
        my $TicketEscalationDisabled = $TicketObject->TicketEscalationDisabledCheck(
            TicketID => $Article{TicketID},
            UserID   => $Self->{UserID},
        );

        # escalation human times
        if (
            $TicketEscalation->{'FirstResponse'}
            || $TicketEscalation->{'Update'}
            || $TicketEscalation->{'Solution'}
        ) {
            if ($TicketEscalationDisabled) {
                $Article{EscalationTimeHuman}       = $LayoutObject->{LanguageObject}->Translate('suspended');
                $Article{EscalationTimeWorkingTime} = $LayoutObject->{LanguageObject}->Translate('suspended');
            }
            else {
                $Article{EscalationTimeHuman} = $LayoutObject->CustomerAgeInHours(
                    Age   => $Article{EscalationTime},
                    Space => ' ',
                );
                $Article{EscalationTimeWorkingTime} = $LayoutObject->CustomerAgeInHours(
                    Age   => $Article{EscalationTimeWorkingTime},
                    Space => ' ',
                );
            }
        }

        # customer info
        my %CustomerInfo;
        if ( $Param{Config}->{CustomerInfo} ) {
            if ( $Article{CustomerUserID} ) {
                $Article{CustomerName} = $CustomerUserObject->CustomerName(
                    UserLogin => $Article{CustomerUserID},
                );

                %CustomerInfo = $CustomerUserObject->CustomerUserDataGet(
                    User       => $Article{CustomerUserID},
                    CustomerID => $Article{CustomerID},
                );

                INFOKEY:
                for my $InfoKey ( sort keys %CustomerInfo ) {
                    next INFOKEY if $InfoKey =~ m{\ACustomer}xms;

                    $CustomerInfo{ 'Customer' . $InfoKey } = $CustomerInfo{$InfoKey};
                }
            }
        }

        # user info
        my %UserInfo = $UserObject->GetUserData(
            UserID => $Article{OwnerID},
        );

        # Responsible info.
        my %ResponsibleInfo = $UserObject->GetUserData(
            UserID => $Article{ResponsibleID},
        );
        $UserInfo{ResponsibleInfo} = \%ResponsibleInfo;

        $LayoutObject->Block(
            Name => 'Record',
            Data => { %Article, %UserInfo },
        );

        # check if bulk feature is enabled
        if ($BulkFeature) {
            my $ItemChecked = '';

            if ( $SelectedItemsHash{ $Article{TicketID} } ) {
                $ItemChecked = ' checked="checked"';
            }

            $LayoutObject->Block(
                Name => 'GeneralOverviewRow',
            );
            $LayoutObject->Block(
                Name => 'Bulk',
                Data => {
                    ItemChecked => $ItemChecked,
                    %Article,
                    %UserInfo,
                },
            );

            if (
                !$BulkActivate
                && $ItemChecked
            ) {
                $BulkActivate = 1;
                $LayoutObject->Block(
                    Name => 'BulkActivate',
                );
            }
        }

        # show ticket flags
        my @TicketMetaItems = $LayoutObject->TicketMetaItems(
            Ticket => \%Article,
        );
        for my $Item (@TicketMetaItems) {
            $LayoutObject->Block(
                Name => 'GeneralOverviewRow',
            );
            $LayoutObject->Block(
                Name => 'ContentLargeTicketGenericRowMeta',
                Data => $Item,
            );
            if ($Item) {
                $LayoutObject->Block(
                    Name => 'ContentLargeTicketGenericRowMetaImage',
                    Data => $Item,
                );
            }
        }

        # save column content
        my $DataValue;
        my $DynamicFieldDisplayLimit = $ConfigObject->Get('Frontend::OverrideDynamicFieldDisplayLimits') || 20;

        # show all needed columns
        TICKETCOLUMN:
        for my $TicketColumn (@Col) {
            $LayoutObject->Block(
                Name => 'GeneralOverviewRow',
            );
            if ( $TicketColumn !~ m{\A DynamicField_}xms ) {
                $LayoutObject->Block(
                    Name => 'RecordTicketData',
                    Data => {},
                );

                if ( $SpecialColumns{$TicketColumn} ) {
                    if ( $TicketColumn eq 'FromTitle' ) {

                        # check if last customer subject or ticket title should be shown
                        if ( $Self->{SmallViewColumnHeader} eq 'LastCustomerSubject' ) {
                            $LayoutObject->Block(
                                Name => 'RecordFromLastCustomerSubject',
                                Data => { %Article, %UserInfo },
                            );
                        }
                        elsif ( $Self->{SmallViewColumnHeader} eq 'TicketTitle' ) {
                            $LayoutObject->Block(
                                Name => 'RecordFromTicketTitle',
                                Data => { %Article, %UserInfo },
                            );
                        }
                    }

                    elsif ( $TicketColumn =~ m/^MarkedAs::(.*)/ ) {

                        $LayoutObject->Block(
                            Name => 'RecordMarkedAs',
                            Data => { %Article, %UserInfo },
                        );

                        for my $ArticleItem ( keys %{ $Article{FlagHash} } ) {

                            for my $Flag ( @{ $Article{FlagHash}->{$ArticleItem} } ) {
                                next
                                    if (
                                    $1 ne 'All'
                                    && $1 ne $Self->{ArticleFlagConfig}->{ArticleFlags}->{$Flag}
                                    );

                                my %FlagHash = $TicketObject->ArticleFlagDataGet(
                                    ArticleID      => $ArticleItem,
                                    ArticleFlagKey => $Flag,
                                    UserID         => $Self->{UserID},
                                );

                                $LayoutObject->Block(
                                    Name => 'RecordMarkedAsFlag',
                                    Data => {
                                        Icon =>
                                            $Self->{ArticleFlagConfig}->{ArticleFlagIcons}->{$Flag},
                                        Title => $LayoutObject->{LanguageObject}->Translate(
                                            $Self->{ArticleFlagConfig}->{ArticleFlags}->{$Flag}
                                        ),
                                        FlagSubject => $FlagHash{Subject},
                                        Tooltip     => $FlagHash{Note},
                                        CSS => $Self->{ArticleFlagConfig}->{ArticleFlagCSS}->{$Flag}
                                            || '',
                                    },
                                );
                            }
                        }
                    }
                    else {
                        $LayoutObject->Block(
                            Name => 'Record' . $TicketColumn,
                            Data => { %Article, %UserInfo },
                        );
                    }
                    next TICKETCOLUMN;
                }

                if ( $TicketColumn eq 'CreatedBy' ) {

                    my %TicketCreatedByInfo = $UserObject->GetUserData(
                        UserID => $Article{CreatedBy},
                    );

                    $LayoutObject->Block(
                        Name => 'RecordTicketCreatedBy',
                        Data => \%TicketCreatedByInfo,
                    );
                    next TICKETCOLUMN;
                }

                # escalation column
                my %EscalationData;
                if ( $TicketColumn eq 'EscalationTime' ) {

                    if (
                        $TicketEscalationDisabled
                        && (
                            $TicketEscalation->{'FirstResponse'}
                            || $TicketEscalation->{'Update'}
                            || $TicketEscalation->{'Solution'}
                        )
                    ) {
                        $LayoutObject->Block(
                            Name => "RecordTicketColumnTranslatable",
                            Data => {
                                GenericValue => 'suspended',
                                Class        => '',
                            },
                        );
                        next TICKETCOLUMN;
                    }
                    elsif (
                        $TicketEscalation->{'FirstResponse'}
                        || $TicketEscalation->{'Update'}
                        || $TicketEscalation->{'Solution'}
                    ) {
                        $EscalationData{EscalationTime}            = $Article{EscalationTime}            || 0;
                        $EscalationData{EscalationDestinationDate} = $Article{EscalationDestinationDate} || 0;

                        $EscalationData{EscalationTimeHuman} = $LayoutObject->CustomerAgeInHours(
                            Age   => $EscalationData{EscalationTime},
                            Space => ' ',
                        );
                        $EscalationData{EscalationTimeWorkingTime} = $LayoutObject->CustomerAgeInHours(
                            Age   => $EscalationData{EscalationTimeWorkingTime},
                            Space => ' ',
                        );
                        if (
                            defined $Article{EscalationTime}
                            && $Article{EscalationTime} < 60 * 60 * 1
                        ) {
                            $EscalationData{EscalationClass} = 'Warning';
                        }
                        $LayoutObject->Block(
                            Name => 'RecordEscalationTime',
                            Data => {%EscalationData},
                        );
                        next TICKETCOLUMN;
                    }
                    else {
                        $LayoutObject->Block(
                            Name => "RecordTicketColumnTranslatable",
                            Data => {
                                GenericValue => 'none',
                                Class        => '',
                            },
                        );
                        next TICKETCOLUMN;
                    }
                }

                my $BlockType = '';
                my $CSSClass  = '';
                if ( $TicketColumn eq 'EscalationSolutionTime' ) {
                    if (
                        $TicketEscalationDisabled
                        && $TicketEscalation->{'Solution'}
                    ) {
                        $BlockType = 'Translatable';
                        $DataValue = 'suspended';
                    }
                    elsif ( $TicketEscalation->{'Solution'} ) {
                        $BlockType = 'Escalation';
                        $DataValue = $LayoutObject->CustomerAgeInHours(
                            Age => $Article{SolutionTime} || 0,
                            Space => ' ',
                        );
                        if ( defined $Article{SolutionTime} && $Article{SolutionTime} < 60 * 60 * 1 ) {
                            $CSSClass = 'Warning';
                        }
                    }
                    else {
                        $BlockType = 'Translatable';
                        $DataValue = 'none';
                    }
                }
                elsif ( $TicketColumn eq 'EscalationResponseTime' ) {
                    if (
                        $TicketEscalationDisabled
                        && $TicketEscalation->{'FirstResponse'}
                    ) {
                        $BlockType = 'Translatable';
                        $DataValue = 'suspended';
                    }
                    elsif ( $TicketEscalation->{'FirstResponse'} ) {
                        $BlockType = 'Escalation';
                        $DataValue = $LayoutObject->CustomerAgeInHours(
                            Age => $Article{FirstResponseTime} || 0,
                            Space => ' ',
                        );
                        if (
                            defined $Article{FirstResponseTime}
                            && $Article{FirstResponseTime} < 60 * 60 * 1
                        ) {
                            $CSSClass = 'Warning';
                        }
                    }
                    else {
                        $BlockType = 'Translatable';
                        $DataValue = 'none';
                    }
                }
                elsif ( $TicketColumn eq 'EscalationUpdateTime' ) {
                    if (
                        $TicketEscalationDisabled
                        && $TicketEscalation->{'Update'}
                    ) {
                        $BlockType = 'Translatable';
                        $DataValue = 'suspended';
                    }
                    elsif ( $TicketEscalation->{'Update'} ) {
                        $BlockType = 'Escalation';
                        $DataValue = $LayoutObject->CustomerAgeInHours(
                            Age => $Article{UpdateTime} || 0,
                            Space => ' ',
                        );
                        if ( defined $Article{UpdateTime} && $Article{UpdateTime} < 60 * 60 * 1 ) {
                            $CSSClass = 'Warning';
                        }
                    }
                    else {
                        $BlockType = 'Translatable';
                        $DataValue = 'none';
                    }
                }
                elsif ( $TicketColumn eq 'PendingTime' ) {
                    $BlockType = 'Escalation';

                    my %UserPreferences    = $UserObject->GetPreferences( UserID => $Self->{UserID} );
                    my $DisplayPendingTime = $UserPreferences{UserDisplayPendingTime} || '';

                    if ( $DisplayPendingTime && $DisplayPendingTime eq 'RemainingTime' ) {
                        $DataValue = $LayoutObject->CustomerAge(
                            Age   => $Article{'UntilTime'},
                            Space => ' '
                        );
                    }
                    elsif ( defined $Article{UntilTime} && $Article{UntilTime} ) {
                        $DataValue = $TimeObject->SystemTime2TimeStamp(
                            SystemTime => $Article{RealTillTimeNotUsed},
                        );
                        $DataValue = $LayoutObject->{LanguageObject}->FormatTimeString( $DataValue, 'DateFormat' );
                    }
                    else {
                        $DataValue = '';
                    }

                    if ( defined $Article{UntilTime} && $Article{UntilTime} < -1 ) {
                        $CSSClass = 'Warning';
                    }
                }
                elsif (
                    $TicketColumn eq 'State'
                    || $TicketColumn eq 'Lock'
                    || $TicketColumn eq 'Priority'
                    || (
                        $TicketColumn eq 'Type'
                        && $ConfigObject->Get('Ticket::TypeTranslation')
                    )
                    || (
                        $TicketColumn eq 'Service'
                        && $ConfigObject->Get('Ticket::ServiceTranslation')
                    )
                    || (
                        $TicketColumn eq 'SLA'
                        && $ConfigObject->Get('Ticket::SLATranslation')
                    )
                ) {
                    $BlockType = 'Translatable';
                    $DataValue = $Article{$TicketColumn} || $UserInfo{$TicketColumn};
                }
                elsif ( $TicketColumn eq 'Created' || $TicketColumn eq 'Changed' ) {
                    $BlockType = 'Time';
                    $DataValue = $Article{$TicketColumn} || $UserInfo{$TicketColumn};
                }
                else {
                    $DataValue = $Article{$TicketColumn}
                        || $UserInfo{$TicketColumn}
                        || $CustomerInfo{$TicketColumn};
                }

                $LayoutObject->Block(
                    Name => "RecordTicketColumn$BlockType",
                    Data => {
                        GenericValue => $DataValue || '',
                        Class        => $CSSClass  || '',
                    },
                );
            }

            # dynamic fields
            else {

                # cycle trough the activated dynamic fields for this screen

                my $DynamicFieldConfig;
                my $DFColumn = $TicketColumn;
                $DFColumn =~ s/DynamicField_//g;
                DYNAMICFIELD:
                for my $DFConfig ( @{ $Self->{DynamicField} } ) {
                    next DYNAMICFIELD if !IsHashRefWithData($DFConfig);
                    next DYNAMICFIELD if $DFConfig->{Name} ne $DFColumn;

                    $DynamicFieldConfig = $DFConfig;
                    last DYNAMICFIELD;
                }
                next TICKETCOLUMN if !IsHashRefWithData($DynamicFieldConfig);

                # get field value
                my $Value = $BackendObject->ValueGet(
                    DynamicFieldConfig => $DynamicFieldConfig,
                    ObjectID           => $Article{TicketID},
                );

                my $ValueStrg = $BackendObject->DisplayValueRender(
                    DynamicFieldConfig => $DynamicFieldConfig,
                    Value              => $Value,
                    ValueMaxChars      => $DynamicFieldDisplayLimit,
                    LayoutObject       => $LayoutObject,
                );

                $LayoutObject->Block(
                    Name => 'RecordDynamicField',
                    Data => {
                        Value => $ValueStrg->{Value},
                        Title => $ValueStrg->{Title},
                    },
                );

                if ( $ValueStrg->{Link} ) {
                    my $HTMLLink = $HTMLLinkLayoutObject->Output(
                        Template => '<a href="[% Data.Link | Interpolate %]" target="_blank" class="DynamicFieldLink">[% Data.Value %]</a>',
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

        # add action items as js
        if ( $Article{ActionItems} ) {

            $LayoutObject->Block(
                Name => 'DocumentReadyActionRowAdd',
                Data => {
                    TicketID => $Article{TicketID},
                    Data     => $Article{ActionItems},
                },
            );
        }
    }

    # init for table control
    $LayoutObject->Block(
        Name => 'DocumentReadyStart',
        Data => \%Param,
    );

    # set column filter form, to correctly fill the column filters is necessary to pass each
    #    overview some information in the AJAX call, for example the fixed Filters or NavBarFilters
    #    and also other values like the Queue in AgentTicketQueue, otherwise the filters will be
    #    filled with default restrictions, resulting in more options than the ones that the
    #    available tickets should provide, see Bug#9902
    if ( IsHashRefWithData( $Param{ColumnFilterForm} ) ) {
        $LayoutObject->Block(
            Name => 'DocumentColumnFilterForm',
            Data => {},
        );
        for my $Element ( sort keys %{ $Param{ColumnFilterForm} } ) {
            $LayoutObject->Block(
                Name => 'DocumentColumnFilterFormElement',
                Data => {
                    ElementName  => $Element,
                    ElementValue => $Param{ColumnFilterForm}->{$Element},
                },
            );
        }
    }

    # use template
    my $Output = $LayoutObject->Output(
        TemplateFile => 'AgentTicketOverviewSmall',
        Data         => {
            %Param,
            Type => $Self->{ViewType},
        },
    );

    return $Output;
}

sub _GetColumnValues {
    my ( $Self, %Param ) = @_;

    return if !IsStringWithData( $Param{HeaderColumn} );

    my $HeaderColumn = $Param{HeaderColumn};
    my %ColumnFilterValues;
    my $TicketIDs;

    if ( IsArrayRefWithData( $Param{OriginalTicketIDs} ) ) {
        $TicketIDs = $Param{OriginalTicketIDs};
    }

    if ( $HeaderColumn !~ m/^DynamicField_/ ) {
        my $FunctionName = $HeaderColumn . 'FilterValuesGet';
        if ( $HeaderColumn eq 'CustomerID' ) {
            $FunctionName = 'CustomerFilterValuesGet';
        }
        $ColumnFilterValues{$HeaderColumn} = $Kernel::OM->Get('Kernel::System::Ticket::ColumnFilter')->$FunctionName(
            TicketIDs    => $TicketIDs,
            HeaderColumn => $HeaderColumn,
            UserID       => $Self->{UserID},
        );
    }
    else {
        DYNAMICFIELD:
        for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {
            next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);
            my $FieldName = 'DynamicField_' . $DynamicFieldConfig->{Name};
            next DYNAMICFIELD if $FieldName ne $HeaderColumn;

            # get dynamic field backend object
            my $BackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');
            my $IsFiltrable               = $BackendObject->HasBehavior(
                DynamicFieldConfig => $DynamicFieldConfig,
                Behavior           => 'IsFiltrable',
            );
            next DYNAMICFIELD if !$IsFiltrable;
            $Self->{ValidFilterableColumns}->{$HeaderColumn} = $IsFiltrable;
            if ( IsArrayRefWithData($TicketIDs) ) {

                # get the historical values for the field
                $ColumnFilterValues{$HeaderColumn} = $BackendObject->ColumnFilterValuesGet(
                    DynamicFieldConfig => $DynamicFieldConfig,
                    LayoutObject       => $Kernel::OM->Get('Kernel::Output::HTML::Layout'),
                    TicketIDs          => $TicketIDs,
                );
            }
            else {

                # get PossibleValues
                $ColumnFilterValues{$HeaderColumn} = $BackendObject->PossibleValuesGet(
                    DynamicFieldConfig => $DynamicFieldConfig,
                );
            }
            last DYNAMICFIELD;
        }
    }

    return \%ColumnFilterValues;
}

sub _InitialColumnFilter {
    my ( $Self, %Param ) = @_;

    return if !$Param{ColumnName};
    return if !$Self->{ValidFilterableColumns}->{ $Param{ColumnName} };

    # get layout object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    my $Label = $Param{Label} || $Param{ColumnName};
    $Label = $LayoutObject->{LanguageObject}->Translate($Label);

    # set fixed values
    my $Data = [
        {
            Key   => '',
            Value => uc $Label,
        },
    ];

    # define if column filter values should be translatable
    my $TranslationOption = 0;

    if (
        $Param{ColumnName} eq 'State'
        || $Param{ColumnName} eq 'Lock'
        || $Param{ColumnName} eq 'Priority'
        || (
            $Param{ColumnName} eq 'Type'
            && $ConfigObject->Get('Ticket::TypeTranslation')
        )
        || (
            $Param{ColumnName} eq 'Service'
            && $ConfigObject->Get('Ticket::ServiceTranslation')
        )
        || (
            $Param{ColumnName} eq 'SLA'
            && $ConfigObject->Get('Ticket::SLATranslation')
        )
    ) {
        $TranslationOption = 1;
    }

    my $Class = 'ColumnFilter';
    if ( $Param{Css} ) {
        $Class .= ' ' . $Param{Css};
    }

    # build select HTML
    my $ColumnFilterHTML = $LayoutObject->BuildSelection(
        Name        => 'ColumnFilter' . $Param{ColumnName},
        Data        => $Data,
        Class       => $Class,
        Translation => $TranslationOption,
        SelectedID  => '',
    );
    return $ColumnFilterHTML;
}

sub FilterContent {
    my ( $Self, %Param ) = @_;

    return if !$Param{HeaderColumn};

    my $HeaderColumn = $Param{HeaderColumn};

    # get column values for to build the filters later
    my $ColumnValues = $Self->_GetColumnValues(
        OriginalTicketIDs => $Param{OriginalTicketIDs},
        HeaderColumn      => $HeaderColumn,
    );

    my $SelectedValue  = '';
    my $SelectedColumn = $HeaderColumn;
    if ( $HeaderColumn eq 'CustomerUserID' ) {
        $SelectedColumn = 'CustomerUserLogin';
    }
    if ( $HeaderColumn eq 'CustomerID' ) {
        $SelectedColumn = 'CustomerID';
    }
    elsif ( $HeaderColumn !~ m{ \A DynamicField_ }xms ) {
        $SelectedColumn .= 'IDs';
    }

    my $LabelColumn = $HeaderColumn;
    if ( $LabelColumn =~ m{ \A DynamicField_ }xms ) {

        my $DynamicFieldConfig;
        $LabelColumn =~ s{\A DynamicField_ }{}xms;

        DYNAMICFIELD:
        for my $DFConfig ( @{ $Self->{DynamicField} } ) {
            next DYNAMICFIELD if !IsHashRefWithData($DFConfig);
            next DYNAMICFIELD if $DFConfig->{Name} ne $LabelColumn;

            $DynamicFieldConfig = $DFConfig;
            last DYNAMICFIELD;
        }
        if ( IsHashRefWithData($DynamicFieldConfig) ) {
            $LabelColumn = $DynamicFieldConfig->{Label};
        }
    }

    if ( $SelectedColumn && $Self->{StoredFilters}->{$SelectedColumn} ) {

        if ( IsArrayRefWithData( $Self->{StoredFilters}->{$SelectedColumn} ) ) {
            $SelectedValue = $Self->{StoredFilters}->{$SelectedColumn}->[0];
        }
        elsif ( IsHashRefWithData( $Self->{StoredFilters}->{$SelectedColumn} ) ) {
            $SelectedValue = $Self->{StoredFilters}->{$SelectedColumn}->{Equals};
        }
    }

    # variable to save the filter's HTML code
    my $ColumnFilterJSON = $Self->_ColumnFilterJSON(
        ColumnName    => $HeaderColumn,
        Label         => $LabelColumn,
        ColumnValues  => $ColumnValues->{$HeaderColumn},
        SelectedValue => $SelectedValue,
    );

    return $ColumnFilterJSON;
}

=over

=item _ColumnFilterJSON()

    creates a JSON select filter for column header

    my $ColumnFilterJSON = $TicketOverviewSmallObject->_ColumnFilterJSON(
        ColumnName => 'Queue',
        Label      => 'Queue',
        ColumnValues => {
            1 => 'PostMaster',
            2 => 'Junk',
        },
        SelectedValue '1',
    );

=cut

sub _ColumnFilterJSON {
    my ( $Self, %Param ) = @_;

    if (
        !$Self->{AvailableFilterableColumns}->{ $Param{ColumnName} } &&
        !$Self->{AvailableFilterableColumns}->{ $Param{ColumnName} . 'IDs' }
    ) {
        return;
    }

    # get layout object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    my $Label = $Param{Label};
    $Label =~ s{ \A DynamicField_ }{}gxms;
    $Label = $LayoutObject->{LanguageObject}->Translate($Label);

    # set fixed values
    my $Data = [
        {
            Key   => 'DeleteFilter',
            Value => uc $Label,
        },
        {
            Key      => '-',
            Value    => '-',
            Disabled => 1,
        },
    ];

    if ( $Param{ColumnValues} && ref $Param{ColumnValues} eq 'HASH' ) {

        my %Values = %{ $Param{ColumnValues} };

        # set possible values
        for my $ValueKey ( sort { lc $Values{$a} cmp lc $Values{$b} } keys %Values ) {
            push @{$Data}, {
                Key   => $ValueKey,
                Value => $Values{$ValueKey}
            };
        }
    }

    # define if column filter values should be translatable
    my $TranslationOption = 0;

    if (
        $Param{ColumnName} eq 'State'
        || $Param{ColumnName} eq 'Lock'
        || $Param{ColumnName} eq 'Priority'
        || (
            $Param{ColumnName} eq 'Type'
            && $ConfigObject->Get('Ticket::TypeTranslation')
        )
        || (
            $Param{ColumnName} eq 'Service'
            && $ConfigObject->Get('Ticket::ServiceTranslation')
        )
        || (
            $Param{ColumnName} eq 'SLA'
            && $ConfigObject->Get('Ticket::SLATranslation')
        )
    ) {
        $TranslationOption = 1;
    }

    # build select HTML
    my $JSON = $LayoutObject->BuildSelectionJSON(
        [
            {
                Name         => 'ColumnFilter' . $Param{ColumnName},
                Data         => $Data,
                Class        => 'ColumnFilter',
                Sort         => 'AlphanumericKey',
                TreeView     => 1,
                SelectedID   => $Param{SelectedValue},
                Translation  => $TranslationOption,
                AutoComplete => 'off',
            },
        ],
    );

    return $JSON;
}

sub _DefaultColumnSort {

    my %DefaultColumns = (
        TicketNumber           => 100,
        Age                    => 110,
        Changed                => 111,
        PendingTime            => 112,
        EscalationTime         => 113,
        EscalationSolutionTime => 114,
        EscalationResponseTime => 115,
        EscalationUpdateTime   => 116,
        FromTitle              => 120,
        From                   => 121,
        LastCustomerSubject    => 122,
        Title                  => 123,
        State                  => 130,
        Lock                   => 140,
        Queue                  => 150,
        Owner                  => 160,
        Responsible            => 161,
        CustomerID             => 170,
        CustomerName           => 171,
        CustomerUserID         => 172,
        Type                   => 180,
        Service                => 191,
        SLA                    => 192,
        Priority               => 193,
    );

    # dynamic fields can not be on the DefaultColumns sorting hash
    # when comparing 2 dynamic fields sorting must be alphabetical
    if ( !$DefaultColumns{$a} && !$DefaultColumns{$b} ) {
        return $a cmp $b;
    }

    # when a dynamic field is compared to a ticket attribute it must be higher
    elsif ( !$DefaultColumns{$a} ) {
        return 1;
    }

    # when a ticket attribute is compared to a dynamic field it must be lower
    elsif ( !$DefaultColumns{$b} ) {
        return -1;
    }

    # otherwise do a numerical comparison with the ticket attributes
    return $DefaultColumns{$a} <=> $DefaultColumns{$b};
}

1;

=back

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
