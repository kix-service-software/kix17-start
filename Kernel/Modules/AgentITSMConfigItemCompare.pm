# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AgentITSMConfigItemCompare;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::GeneralCatalog',
    'Kernel::System::ITSMConfigItem',
    'Kernel::System::LinkObject',
    'Kernel::System::User',
);

## no critic qw(BuiltinFunctions::ProhibitStringyEval)

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    # create needed objects
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # get config of frontend module
    $Self->{Config} = $ConfigObject->Get("ITSMConfigItem::Frontend::AgentITSMConfigItemCompare");
    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # create needed objects
    my $ConfigItemObject     = $Kernel::OM->Get('Kernel::System::ITSMConfigItem');
    my $GeneralCatalogObject = $Kernel::OM->Get('Kernel::System::GeneralCatalog');
    my $LinkObject           = $Kernel::OM->Get('Kernel::System::LinkObject');
    my $UserObject           = $Kernel::OM->Get('Kernel::System::User');
    my $ParamObject          = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $LayoutObject         = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # get params
    my $ConfigItemID = $ParamObject->GetParam( Param => 'ConfigItemID' ) || 0;
    my $LeftItem     = $ParamObject->GetParam( Param => 'LeftItem' )     || 0;
    my $RightItem    = $ParamObject->GetParam( Param => 'RightItem' )    || 0;

    # check needed stuff
    if ( !$ConfigItemID ) {

        # error page
        return $LayoutObject->ErrorScreen(
            Message => 'Can\'t compare, no ConfigItemID is given!',
            Comment => 'Please contact the admin.',
        );
    }

    if ( $Self->{Subaction} eq 'Compare' && ( !$LeftItem || !$RightItem ) ) {

        # error page
        return $LayoutObject->ErrorScreen(
            Message => 'Can\'t compare, need two VersionIDs!',
            Comment => 'Please contact the admin.',
        );
    }

    # check for access rights
    my $HasAccess = $ConfigItemObject->Permission(
        Scope  => 'Item',
        ItemID => $ConfigItemID,
        UserID => $Self->{UserID},
        Type   => $Self->{Config}->{Permission},
    );

    if ( !$HasAccess ) {

        # error page
        return $LayoutObject->ErrorScreen(
            Message => 'Can\'t compare screen, no access rights given!',
            Comment => 'Please contact the admin.',
        );
    }

    # get all information about the config item
    my $ConfigItem = $ConfigItemObject->ConfigItemGet(
        ConfigItemID => $ConfigItemID,
    );
    if ( !$ConfigItem->{ConfigItemID} ) {
        return $LayoutObject->ErrorScreen(
            Message => "ConfigItemID $ConfigItemID not found in database!",
            Comment => 'Please contact the admin.',
        );
    }

    # get version list
    my $VersionList = $ConfigItemObject->VersionZoomList(
        ConfigItemID => $ConfigItemID,
    );
    if ( !$VersionList->[0]->{VersionID} ) {
        return $LayoutObject->ErrorScreen(
            Message => "No Version found for ConfigItemID $ConfigItemID!",
            Comment => 'Please contact the admin.',
        );
    }

    # build version tree view
    $LayoutObject->Block(
        Name => 'ConfigItemData',
        Data => {
            %{$ConfigItem},
            }
    );

    # build header
    $LayoutObject->Block(
        Name => 'Header',
        Data => {
            %{$ConfigItem},
            Name => $VersionList->[-1]->{Name},
            }
    );

    # build legend
    $LayoutObject->Block(
        Name => 'CompareLegend',
        Data => {
            css_changed => $Self->{Config}->{CSSHighlight}->{changed},
            css_added   => $Self->{Config}->{CSSHighlight}->{added},
            css_removed => $Self->{Config}->{CSSHighlight}->{removed}
        },
    );

    my $Counter = 1;
    my @VersionArray;
    my $SelectedLeft;
    my $SelectedRight;

    # output version tree
    for my $VersionHash ( @{$VersionList} ) {

        # get user info
        my %UserInfo = $UserObject->GetUserData(
            UserID => $VersionHash->{CreateBy},
            Cached => 1
        );

        # save the current version for use in compare view
        $VersionArray[ $VersionHash->{VersionID} ] = $Counter;

        if ( $LeftItem == $VersionHash->{VersionID} ) {
            $SelectedLeft = 'checked="checked"';
        }
        else {
            $SelectedLeft = '';
        }

        if ( $RightItem == $VersionHash->{VersionID} ) {
            $SelectedRight = 'checked="checked"';
        }
        else {
            $SelectedRight = '';
        }

        # build left item table row
        $LayoutObject->Block(
            Name => 'TreeItemLeft',
            Data => {
                %UserInfo,
                %{$ConfigItem},
                %{$VersionHash},
                Count        => $Counter,
                SelectedLeft => $SelectedLeft,
            },
        );

        # build right item table row
        $LayoutObject->Block(
            Name => 'TreeItemRight',
            Data => {
                %UserInfo,
                %{$ConfigItem},
                %{$VersionHash},
                Count         => $Counter,
                SelectedRight => $SelectedRight,
            },
        );

        # displayed version counter
        $Counter++;
    }

    #----------------------------------------------------------------------#
    # Compare                                                              #
    #----------------------------------------------------------------------#

    if ( $Self->{Subaction} || $Self->{Subaction} eq 'Compare' ) {

        # build compare header
        $LayoutObject->Block(
            Name => 'ConfigItemCompare',
            Data => {
                Version1 => $VersionArray[$LeftItem],
                Version2 => $VersionArray[$RightItem],
                %{$ConfigItem},
            },
        );

        # get data
        my %Version;
        for my $Part (qw(Left Right)) {
            my $Item        = '$' . $Part . 'Item';
            my $VersionHash = $ConfigItemObject->VersionGet(
                VersionID => eval($Item),
            );
            $Version{$Part} = $VersionHash;
        }

        # compare Name, DeplState, InciState
        for my $Key (qw(Name DeplState InciState)) {
            my $css = '';
            if ( $Version{Left}->{$Key} ne $Version{Right}->{$Key} ) {
                $css = $Self->{Config}->{CSSHighlight}->{changed};
            }
            for my $Part (qw(Left Right)) {

                # build row left
                $LayoutObject->Block(
                    Name => 'CompareItem' . $Part,
                    Data => {
                        Name        => $Key,
                        Value       => $Version{$Part}->{$Key},
                        Css         => $css,
                        Indentation => 1,
                    },
                );
            }
        }

        # compare XMLData
        # compare left with right
        $Param{Hash} = $Self->_GetChanges(
            VersionHash     => $Version{Left}->{XMLData},
            LastVersionHash => $Version{Right}->{XMLData},
        );

        # compare right with left (makes a difference)
        $Param{ReverseHash} = $Self->_GetChanges(
            VersionHash     => $Version{Right}->{XMLData},
            LastVersionHash => $Version{Left}->{XMLData},
        );

        # swaped attributes may behave like changed attributes - remove them
        if ( $Self->{Config}->{CompareBehaviour} ) {
            $Self->_RemoveUnusedChanges(
                Hash            => $Param{Hash},
                ReverseHash     => $Param{ReverseHash},
                VersionHash     => $Version{Left}->{XMLData},
                LastVersionHash => $Version{Right}->{XMLData},
            );
        }

        # merge the two diff-hashes to one hash with css attributes
        my $ChangesHash = $Self->_GetAllChanges(
            DiffChanges        => $Param{Hash},
            DiffChangesReverse => $Param{ReverseHash}
        );

        # create Output
        $Self->_XMLOutput(
            XMLData       => $Version{Left}->{XMLData}->[1]->{Version}->[1],
            XMLDataOther  => $Version{Right}->{XMLData}->[1]->{Version}->[1],
            XMLDefinition => $Version{Left}->{XMLDefinition},
            LayoutBlock   => 'CompareItemLeft',
            Changes       => $ChangesHash,
            Part          => 'Left',
            OtherPart     => 'Right'
        );

        $Self->_XMLOutput(
            XMLData       => $Version{Right}->{XMLData}->[1]->{Version}->[1],
            XMLDataOther  => $Version{Left}->{XMLData}->[1]->{Version}->[1],
            XMLDefinition => $Version{Right}->{XMLDefinition},
            LayoutBlock   => 'CompareItemRight',
            Changes       => $ChangesHash,
            Part          => 'Right',
            OtherPart     => 'Left'
        );
    }

    # build page
    my $Output = $LayoutObject->Header(
        Value => $VersionList->[-1]->{Number} . ' ' . $VersionList->[-1]->{Name},
        Type  => 'Small'
    );
    $Output .= $LayoutObject->Output(
        TemplateFile => 'AgentITSMConfigItemCompare',
    );
    $Output .= $LayoutObject->Footer( Type => 'Small' );
    return $Output;
}

=item _RemoveUnusedChanges

removes unused changes from swaped items

    my $Success = $Self->_RemoveUnusedChanges(
            Hash            => $DiffChanges,
            ReverseHash     => $DiffChangesReverse,
            VersionHash     => $VersionHashRef,
            LastVersionHash => $VersionHashRef
    );

=cut

sub _RemoveUnusedChanges {
    my ( $Self, %Param ) = @_;

    my $Hash            = $Param{Hash};
    my $ReverseHash     = $Param{ReverseHash};
    my $VersionHash     = $Param{VersionHash};
    my $LastVersionHash = $Param{LastVersionHash};

    my %ChangesHash;

    # Key = Version/Software/....
    for my $Key ( keys %{$Hash} ) {
        if ( defined $ReverseHash->{$Key} && $ReverseHash->{$Key} ) {

            # check if same item exists in reverse hash ( Item = 1,2,3,... )
            ITEM:
            for my $Item ( keys %{ $Hash->{$Key} } ) {

                # Value = <Value of parent attribute>
                for my $Value ( keys %{ $Hash->{$Key}->{$Item} } ) {

                    # search in reverse hash
                    for my $ReverseItem ( keys %{ $ReverseHash->{$Key} } ) {

                        # do not remove real changes, only remove if item moved
                        next if $ReverseItem eq $Item;

                        # remove
                        if (
                            $Hash->{$Key}->{$Item}->{$Value}->{new} eq
                            $ReverseHash->{$Key}->{$ReverseItem}->{$Value}->{new}
                        ) {

                            # check if there are changed sub attributes
                            $Self->_CheckSubAttributes(
                                VersionHash      => $Param{VersionHash},
                                LastVersionHash  => $Param{LastVersionHash},
                                Hash             => $Param{Hash},
                                ReverseHash      => $Param{ReverseHash},
                                Key              => $Key,
                                LastIndex        => $Item,
                                LastReverseIndex => $ReverseItem

                            );
                            delete $Param{Hash}->{$Key}->{$Item};
                            delete $Param{ReverseHash}->{$Key}->{$ReverseItem};
                            next ITEM;
                        }
                    }
                }
            }
        }
    }
    return 1;
}

=item _CheckSubAttributes

checks wether sub attributes of items to be removed were changed

    my $Success = $Self->_CheckSubAttributes(
        VersionHash     => $Param{VersionHash},
        LastVersionHash => $Param{LastVersionHash},
        Hash            => $Param{Hash},
        ReverseHash     => $Param{ReverseHash},
        Key             => $Key,
        LastIndex       => $Item,
        LastReverseIndex => $ReverseItem
    );

=cut

sub _CheckSubAttributes {
    my ( $Self, %Param ) = @_;

    my $Hash            = $Param{Hash};
    my $ReverseHash     = $Param{ReverseHash};
    my $VersionHash     = $Param{VersionHash};
    my $LastVersionHash = $Param{LastVersionHash};

    my $Key              = $Param{Key};
    my $LastIndex        = $Param{LastIndex};
    my $LastReverseIndex = $Param{LastReverseIndex};

    # get information for creating the version SubHash
    my @KeyArray = split( /\//, $Key );
    my $VersionSubHash;
    my $VersionSubLastHash;

    my $XMLDefinitionPath     = '$VersionSubHash     = $VersionHash->[1]->';
    my $XMLDefinitionLastPath = '$VersionSubLastHash = $LastVersionHash->[1]->';
    my $ChangesHashKey        = '';
    my $ChangesReverseHashKey = '';

    my $Number;
    my $LastIndexHash        = $LastIndex;
    my $LastReverseIndexHash = $LastReverseIndex;
    for ( my $i = 0; $i < ( scalar @KeyArray ) - 1; $i++ ) {
        $Number = 1;
        $KeyArray[$i] =~ m/(.*?)(\d)/;
        if ( defined $2 && $2 ne '' ) {
            $Number = $2;
        }
        $XMLDefinitionPath     .= '{' . $KeyArray[$i] . '}->[' . $Number . ']->';
        $XMLDefinitionLastPath .= '{' . $KeyArray[$i] . '}->[' . $Number . ']->';
        if ( $Number == 1 ) {
            $Number = '';
        }
        $ChangesHashKey        .= $KeyArray[$i] . $Number . "/";
        $ChangesReverseHashKey .= $KeyArray[$i] . $Number . "/";
    }
    $XMLDefinitionPath     .= '{' . $KeyArray[-1] . '}->[' . $LastIndex . '];';
    $XMLDefinitionLastPath .= '{' . $KeyArray[-1] . '}->[' . $LastReverseIndex . '];';
    $LastIndexHash        = '' if $LastIndex == 1;
    $LastReverseIndexHash = '' if $LastReverseIndex == 1;
    $ChangesHashKey        .= $KeyArray[-1] . $LastIndexHash;
    $ChangesReverseHashKey .= $KeyArray[-1] . $LastReverseIndexHash;

    # create version sub hash
    eval({$XMLDefinitionPath});
    eval({$XMLDefinitionLastPath});

    # get changes of sub hash for all items except TagKey and Content
    for my $HashKey ( keys %{$VersionSubHash} ) {
        next if ( $HashKey eq 'Content' || $HashKey eq 'TagKey' );

        # remove sub-attributes from hash / reverse hash before adding possible changes
        $ChangesHashKey        .= '/' . $HashKey;
        $ChangesReverseHashKey .= '/' . $HashKey;

        for my $HashItem ( keys %{$Hash} ) {
            next if $HashItem !~ m/^$ChangesHashKey/;

            if ( $Param{Hash}->{$HashItem} ) {
                delete( $Param{Hash}->{$HashItem} );
            }
        }

        for my $HashItem ( keys %{$ReverseHash} ) {
            next if $HashItem !~ m/^$ChangesReverseHashKey/;

            if ( $Param{ReverseHash}->{$HashItem} ) {
                delete( $Param{ReverseHash}->{$HashItem} );
            }
        }

        # get changes
        my $Differences = $Self->_GetChanges(
            VersionHash          => $VersionSubHash->{$HashKey},
            LastVersionHash      => $VersionSubLastHash->{$HashKey},
            AttributeDisplayPath => $HashKey,
        );

        # if there are changes include them in Hash / ReverseHash
        for my $DisplayPath ( keys %{$Differences} ) {
            my $NewDisplayPath = $Key . $LastIndex . "/" . $DisplayPath;
            if ( !defined $Param{Hash}->{$NewDisplayPath} ) {
                $Param{ReverseHash}->{$NewDisplayPath} = $Differences->{$DisplayPath};
                $Param{Hash}->{$NewDisplayPath}        = $Differences->{$DisplayPath};
            }
        }
    }
    return 1;
}

=item _GetAllChanges

merges two diff hashes

    my $Changes = $Self->_GetAllChanges(
        DiffChanges         => $DiffChangesRef          # required (normal diff hash)
        DiffChangesReverse  => $DiffChangesReverse      # required (reverse diff hash)
    );

=cut

sub _GetAllChanges {
    my ( $Self, %Param ) = @_;

    my $DiffChanges        = $Param{DiffChanges};
    my $DiffChangesReverse = $Param{DiffChangesReverse};
    my %ChangesHash;

    # sort hash - keys with less /
    my $MaxIndex = 0;
    for my $Key ( keys %{$DiffChanges} ) {
        my @KeyArray = split( /\//, $Key );
        next if ( $MaxIndex > scalar @KeyArray );
        $MaxIndex = scalar @KeyArray;
    }

    # sort hash - keys with less /
    my $MaxIndexReverse = 0;
    for my $Key ( keys %{$DiffChangesReverse} ) {
        my @KeyArray = split( /\//, $Key );
        next if ( $MaxIndexReverse > scalar @KeyArray );
        $MaxIndexReverse = scalar @KeyArray;
    }

    # create hash of both diff hashes
    $Param{ResultHash} = {};

    my $Index = 2;
    while ( $Index <= $MaxIndex ) {
        for my $Key ( keys %{$DiffChanges} ) {
            my @KeyArray = split( /\//, $Key );
            next if ( $Index != scalar @KeyArray );
            $Self->_GetChangesHash(
                Key                    => $Key,
                DifferencesHash        => $DiffChanges,
                DifferencesHashReverse => $DiffChangesReverse,
                ResultHash             => $Param{ResultHash},
                Type                   => 'normal'
            );
        }
        $Index++;
    }

    $Index = 2;
    while ( $Index <= $MaxIndexReverse ) {
        for my $Key ( keys %{$DiffChangesReverse} ) {
            my @KeyArray = split( /\//, $Key );
            next if ( $Index != scalar @KeyArray );
            $Self->_GetChangesHash(
                Key                    => $Key,
                DifferencesHash        => $DiffChangesReverse,
                DifferencesHashReverse => $DiffChanges,
                ResultHash             => $Param{ResultHash},
                Type                   => 'reverse'
            );
        }
        $Index++;
    }

    return $Param{ResultHash};

}

=item _GetChangesHash

returns the merged hash in $Param{ResultHash}

    my $Success = $Self->_GetAllChanges(
        DiffChanges         => $DiffChangesRef          # required (normal diff hash)
        DiffChangesReverse  => $DiffChangesReverse      # required (reverse diff hash)
        Key                 => $Key,                    # required (e.g. Version/Software/Type...)
        ResultHash          => $Param{ResultHash},      # required
        Type                => 'normal / reverse'       # required
    );

=cut

sub _GetChangesHash {
    my ( $Self, %Param ) = @_;

    # create string for ResultHash
    my $ResultString = '$Param{ResultHash}->{$Side}->';

    # get Keys
    my @KeyArray = split( /\//, $Param{Key} );
    for ( my $i = 1; $i < ( scalar @KeyArray ) - 1; $i++ ) {
        $KeyArray[$i] =~ m/(.*?)_(\d)?/;
        if ( !defined $2 ) {
            $KeyArray[$i] = $KeyArray[$i] . '_1';
        }
        $ResultString .= '{' . $KeyArray[$i] . '}->{sub}->';
    }

    # set right or left depending on hash (normal or reverse)
    my $Type = $Param{Type};
    my $FirstSide;
    my $SecondSide;
    if ( $Type eq 'normal' ) {
        $FirstSide  = 'Left';
        $SecondSide = 'Right';
    }
    else {
        $FirstSide  = 'Right';
        $SecondSide = 'Left';
    }

    # create hash with all changes from both diff hashes
    for my $Number ( keys %{ $Param{DifferencesHash}->{ $Param{Key} } } ) {
        for my $Item ( keys %{ $Param{DifferencesHash}->{ $Param{Key} }->{$Number} } ) {
            my $Side;
            my $String;

            # changed or removed/added on swap
            if (
                defined $Param{DifferencesHash}->{ $Param{Key} }->{$Number}->{$Item}->{new}
                && defined $Param{DifferencesHash}->{ $Param{Key} }->{$Number}->{$Item}->{old}
            ) {

                # changed
                if (
                    defined $Param{DifferencesHashReverse}->{ $Param{Key} }->{$Number}->{$Item}
                    ->{old}
                    && (
                        $Param{DifferencesHash}->{ $Param{Key} }->{$Number}->{$Item}->{new} eq
                        $Param{DifferencesHashReverse}->{ $Param{Key} }->{$Number}->{$Item}->{old}
                    )
                ) {
                    $Side = $FirstSide;
                    $String =
                        $ResultString . '{'
                        . $KeyArray[-1] . "_"
                        . $Number
                        . '}->{Content} = "changed";';
                    eval($String);
                    $Side = $SecondSide;
                    $String =
                        $ResultString . '{'
                        . $KeyArray[-1] . "_"
                        . $Number
                        . '}->{Content} = "changed";';
                    eval($String);
                }

                # swap add
                elsif (
                    !defined $Param{DifferencesHashReverse}->{ $Param{Key} }->{$Number}->{$Item}
                    ->{new}
                    && $Type eq 'normal'
                ) {
                    $Side = $FirstSide;
                    $String =
                        $ResultString . '{'
                        . $KeyArray[-1] . "_"
                        . $Number
                        . '}->{Content} = "removed";';
                    eval($String);
                }

                # swap remove
                elsif (
                    !defined $Param{DifferencesHashReverse}->{ $Param{Key} }->{$Number}->{$Item}
                    ->{new}
                    && $Type eq 'reverse'
                ) {
                    $Side = $FirstSide;
                    $String =
                        $ResultString . '{'
                        . $KeyArray[-1] . "_"
                        . $Number
                        . '}->{Content} = "added";';
                    eval($String);
                }

                # swap change
                else {
                    $Side = $FirstSide;
                    $String =
                        $ResultString . '{'
                        . $KeyArray[-1] . "_"
                        . $Number
                        . '}->{Content} = "changed";';
                    eval($String);
                    $Side = $SecondSide;
                    $String =
                        $ResultString . '{'
                        . $KeyArray[-1] . "_"
                        . $Number
                        . '}->{Content} = "changed";';
                    eval($String);
                }
            }

            # remove
            elsif (
                defined $Param{DifferencesHash}->{ $Param{Key} }->{$Number}->{$Item}->{new}
                && !defined $Param{DifferencesHash}->{ $Param{Key} }->{$Number}->{$Item}->{old}
                && $Type eq 'normal'
            ) {
                $Side = $FirstSide;
                $String =
                    $ResultString . '{'
                    . $KeyArray[-1] . "_"
                    . $Number
                    . '}->{Content} = "removed";';
                eval($String);
            }

            # add
            elsif (
                defined $Param{DifferencesHash}->{ $Param{Key} }->{$Number}->{$Item}->{new}
                && !defined $Param{DifferencesHash}->{ $Param{Key} }->{$Number}->{$Item}->{old}
                && $Type eq 'reverse'
            ) {
                $Side = $FirstSide;
                $String
                    = $ResultString . '{'
                    . $KeyArray[-1] . "_"
                    . $Number
                    . '}->{Content} = "added";';
                eval($String);
            }
        }
    }
    return 1;
}

=item _GetChanges

recursive method to detect and return a hashref containing the changes

    my $Changes = $Self->_GetChanges(
        VersionHash     => $XMLVersionRef   # required
        LastVersionHash => $XMLVersionRef   # required
    );

=cut

sub _GetChanges {
    my ( $Self, %Param ) = @_;

    # init some parameters need in recursive calls
    foreach my $Key (qw(AttributePath AttributeDisplayPath)) {
        if ( !exists( $Param{$Key} ) || !defined( $Param{$Key} ) ) {
            $Param{$Key} = '';
        }
    }

    $Param{Counter} = 1;

    if ( !exists( $Param{Changes} ) || !defined( $Param{Changes} ) ) {
        $Param{Changes} = {};
    }

    # first level
    my $HashCounter = 0;
    foreach my $Hash ( @{ $Param{VersionHash} } ) {
        next if !$Hash || !keys %{$Hash};
        $HashCounter++;
        my $LastContent;
        my $EvalCommand =
            '$LastContent = $Param{LastVersionHash}'
            . $Param{AttributePath}
            . "->[$HashCounter]->{Content}";
        eval($EvalCommand);

        # check content
        if ( !defined $LastContent && defined $Hash->{Content} ) {

            # new
            if ( !$Param{HashContent} ) { $Param{HashContent} = '-' }
            $Param{Changes}->{ $Param{AttributeDisplayPath} }->{ $Param{Counter} }
                ->{ $Param{HashContent} }->{new} = $Hash->{Content};
        }
        elsif ( !defined $Hash->{Content} && defined $LastContent ) {

            # old
            if ( !$Param{HashContent} ) { $Param{HashContent} = '-' }
            $Param{Changes}->{ $Param{AttributeDisplayPath} }->{ $Param{Counter} }
                ->{ $Param{HashContent} }->{old} = $Hash->{Content};
        }
        elsif (
            defined $LastContent
            && defined $Hash->{Content}
            && $Hash->{Content} ne $LastContent
        ) {
            if ( !$Param{HashContent} ) { $Param{HashContent} = '-' }

            # new
            $Param{Changes}->{ $Param{AttributeDisplayPath} }->{ $Param{Counter} }
                ->{ $Param{HashContent} }->{new} = $Hash->{Content}
                unless (
                ( $Hash->{Content} && $LastContent )
                && $Hash->{Content} eq $LastContent
                );

            # old
            $Param{Changes}->{ $Param{AttributeDisplayPath} }->{ $Param{Counter} }
                ->{ $Param{HashContent} }->{old} = $LastContent
                unless (
                ( $Hash->{Content} && $LastContent )
                && $Hash->{Content} eq $LastContent
                );
        }

        foreach my $Key ( keys %{$Hash} ) {
            if ( ref( $Hash->{$Key} ) eq 'ARRAY' ) {
                my $Value = $Self->_GetChanges(
                    %Param,
                    VersionHash          => $Hash->{$Key},
                    LastVersionHash      => $Param{LastVersionHash},
                    AttributePath        => $Param{AttributePath} . "->[$HashCounter]->{'$Key'}",
                    HashContent          => $Hash->{Content},
                    AttributeDisplayPath => $Param{AttributeDisplayPath}
                        . ( $HashCounter > 1 ? "_" . $HashCounter : '' )
                        . ( $Param{AttributeDisplayPath} ? '/' : '' )
                        . $Key,
                );
            }
        }
        $Param{Counter}++;
    }
    return $Param{Changes};
}

sub _XMLOutput {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    return if !$Param{XMLData};
    return if !$Param{XMLDataOther};
    return if ref $Param{XMLData} ne 'HASH';
    return if ref $Param{XMLDataOther} ne 'HASH';

    return if !$Param{XMLDefinition};
    return if ref $Param{XMLDefinition} ne 'ARRAY';

    return if !$Param{LayoutBlock};
    return if !$Param{Changes};
    return if !$Param{Part};
    return if !$Param{OtherPart};

    # create needed objects
    my $ConfigItemObject = $Kernel::OM->Get('Kernel::System::ITSMConfigItem');
    my $LayoutObject     = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    $Param{Level} ||= 0;

    for my $Item ( @{ $Param{XMLDefinition} } ) {

        COUNTER:
        for my $Counter ( 1 .. $Item->{CountMax} ) {

            # set css highlight
            last COUNTER if !defined $Param{XMLData}->{ $Item->{Key} }->[$Counter]->{Content};

            # get value
            my $Value = $ConfigItemObject->XMLValueLookup(
                Item  => $Item,
                Value => $Param{XMLData}->{ $Item->{Key} }->[$Counter]->{Content},
            );

            # get value
            my $OtherValue = $ConfigItemObject->XMLValueLookup(
                Item  => $Item,
                Value => $Param{XMLDataOther}->{ $Item->{Key} }->[$Counter]->{Content},
            );

            $Value = $LayoutObject->ITSMConfigItemOutputStringCreate(
                Value => $Value,
                Item  => $Item,
            );

            # get css based on changes
            my $css = '';
            if (
                defined $Param{Changes}->{ $Param{Part} }->{ $Item->{Key} . "_" . $Counter }
                ->{Content}
            ) {
                $css =
                    $Self->{Config}->{CSSHighlight}
                    ->{
                    $Param{Changes}->{ $Param{Part} }->{ $Item->{Key} . "_" . $Counter }
                        ->{Content}
                    };
            }

            # calculate indentation for left-padding css based on 15px per level and 10px as default
            my $Indentation = 10;
            if ( $Param{Level} ) {
                $Indentation += 15 * $Param{Level};
            }

            # build row
            $LayoutObject->Block(
                Name => $Param{LayoutBlock},
                Data => {
                    Name        => $Item->{Name},
                    Value       => $Value,
                    Css         => $css,
                    Indentation => $Indentation,
                },
            );

            # create new Changes
            my $Changes;
            $Changes->{Right} = $Param{Changes}->{Right}->{ $Item->{Key} . "_" . $Counter }->{sub};
            $Changes->{Left}  = $Param{Changes}->{Left}->{ $Item->{Key} . "_" . $Counter }->{sub};

            # start recursion, if "Sub" was found
            if ( $Item->{Sub} ) {
                $Self->_XMLOutput(
                    XMLDefinition => $Item->{Sub},
                    XMLData       => $Param{XMLData}->{ $Item->{Key} }->[$Counter],
                    XMLDataOther  => $Param{XMLDataOther}->{ $Item->{Key} }->[$Counter],
                    Level         => $Param{Level} + 1,
                    LayoutBlock   => $Param{LayoutBlock},
                    Changes       => $Changes,
                    Part          => $Param{Part},
                    OtherPart     => $Param{OtherPart}
                );
            }
        }
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
