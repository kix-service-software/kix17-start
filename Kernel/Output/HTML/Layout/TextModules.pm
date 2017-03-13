# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::Layout::TextModules;

use strict;
use warnings;

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::Output::HTML::Layout::TextModules - all TextModules-related HTML functions

=head1 SYNOPSIS

All TextModules-related HTML functions

=head1 PUBLIC INTERFACE

=over 4

=item TextModuleCategoryTree()

Create a new TextModule category tree

    my $Result = $LayoutObject->TextModuleCategoryTree(
        TextModuleObject => OBJECT        # required
        Categories    => HASH,            # required
        CategoryCount => HASH             # required
        SelectedCategoryID => 123         # optional
        IncludeTextModules => 0|1         # optional
        NoCategoryLink     => 1           # optional
        NoCategoriesWithoutTextModules => 1 # optional
        NoVirtualCategories => 1            # optional (includes NoALLCategory and NoUNASSIGNEDCategory)
        NoALLCategory => 1                  # optional
        NoUNASSIGNEDCategory => 1          # optional
    );

=cut

sub TextModuleCategoryTree {
    my ( $Self, %Param ) = @_;
    my %VirtualCategories;
    my $TextModuleObject;

    if ( $Kernel::OM->Get('Kernel::System::Main')->Require('Kernel::System::TextModule') ) {
        $TextModuleObject = Kernel::System::TextModule->new( %{$Self}, LayoutObject => $Self );
    }

    return if !$TextModuleObject;

    if ( $Param{NoVirtualCategories} ) {
        $Param{NoALLCategory}        = 1;
        $Param{NoUNASSIGNEDCategory} = 1;
    }

    my %AllCategories = %{ $Param{Categories} };

    if ( !$Param{NoALLCategory} ) {
        $AllCategories{'_ALL_'} = $Kernel::OM->Get('Kernel::Output::HTML::Layout')->{LanguageObject}->Translate('ALL');
        $Param{CategoryCount}->{'_ALL_'} = $TextModuleObject->TextModuleCount();
    }
    if ( !$Param{NoUNASSIGNEDCategory} ) {
        $AllCategories{'_UNASSIGNED_'} = $Kernel::OM->Get('Kernel::Output::HTML::Layout')->{LanguageObject}->Translate('NOT ASSIGNED');
        $Param{CategoryCount}->{'_UNASSIGNED_'} = $TextModuleObject->TextModuleCount(
            Type => 'UNASSIGNED::TextModuleCategory',
        );
    }
    my %CategoryList        = $TextModuleObject->TextModuleCategoryList();
    my %CategoryReverseList = reverse %CategoryList;
    my %AllCategoriesData;
    my $Limit = $Param{Limit} || 100;

    if ( !$Param{SelectedCategoryID} ) {
        $Param{SelectedCategoryID} = 0
    }

    my @SelectedSplit;
    if ( $Param{SelectedCategoryID} ) {
        @SelectedSplit = split( /::/, $AllCategories{ $Param{SelectedCategoryID} } );
    }
    my $Level = $#SelectedSplit + 2;

    # build tree information
    my $Count;
    for my $CategoryID ( sort { $AllCategories{$a} cmp $AllCategories{$b} } keys %AllCategories ) {
        my $CategoryCount = $Param{CategoryCount}->{$CategoryID} || 0;
        my @CategorySplit = split( /::/, $AllCategories{$CategoryID} );

        $AllCategoriesData{ $AllCategories{$CategoryID} } = {
            Count => $CategoryCount || 0,
            AllCount => 0,
            Name     => $CategorySplit[-1],
            ID       => $CategoryID,
            Split    => \@CategorySplit,
            Type     => 'Category',
        };

        # process current category information to all parents
        my $CategoryName = '';
        for ( 0 .. $#CategorySplit - 1 ) {
            $CategoryName .= '::' if $CategoryName;
            $CategoryName .= $CategorySplit[$_];

            # parent not initialized yet?
            if ( !$AllCategoriesData{$CategoryName} ) {
                my @CategorySplit = split( /::/, $CategoryName );
                $AllCategoriesData{$CategoryName} = {
                    Count    => 0,
                    AllCount => 0,
                    Name     => $CategorySplit[$_],
                    ID       => $CategoryReverseList{ $CategorySplit[$_] },
                    Split    => \@CategorySplit,
                    Type     => 'Category',
                };
            }

            # add current textmodule count to parent category if parent is not expanded
            $AllCategoriesData{$CategoryName}->{AllCount} += $CategoryCount;
        }

        # include textmodules if needed
        if ( $Param{IncludeTextModules} && $Param{CategoryTextModules}->{$CategoryID} ) {
            for my $CurrHashID (
                sort {
                    $Param{CategoryTextModules}->{$CategoryID}->{$a}->{Name}
                        cmp $Param{CategoryTextModules}->{$CategoryID}->{$b}->{Name}
                }
                keys %{ $Param{CategoryTextModules}->{$CategoryID} }
                )
            {
                my $TextModuleName = $AllCategories{$CategoryID} . '::'
                    . $Param{CategoryTextModules}->{$CategoryID}->{$CurrHashID}->{Name};
                my @Split = split( /::/, $TextModuleName );

                $AllCategoriesData{$TextModuleName} = {
                    Name => $Param{CategoryTextModules}->{$CategoryID}->{$CurrHashID}->{Name},
                    ID   => $CurrHashID,
                    Language =>
                        $Param{CategoryTextModules}->{$CategoryID}->{$CurrHashID}->{Language},
                    Split => \@Split,
                    Type  => 'TextModule',
                };
            }
        }
        $Count++;
        last if $Count == $Limit;
    }

    # prevent sorting problems using empty spaces e.g in category names
    my %NewHash = ();
    for my $Current ( keys %AllCategoriesData ) {
        my $HashKey = $Current;
        $HashKey =~ s/(\:\:)/ $1/g;
        $HashKey .= ' ';
        $NewHash{$HashKey} = $AllCategoriesData{$Current};
    }
    %AllCategoriesData = %NewHash;

    # build category string
    my $CategoryBuildLastLevel = 0;
    my $CategoryStrg;

    for my $Current ( sort keys %AllCategoriesData ) {
        my %Object     = %{ $AllCategoriesData{$Current} };
        my @Split      = @{ $Object{Split} };
        my $ObjectName = $Object{Name};
        my $ObjectNodeID = $ObjectName;
        $ObjectNodeID =~ s/\s//g;

        # build entry
        my $ObjectStrg  = '';
        my $ListClass   = '';
        my $AnchorClass = '';
        if ( $Object{Type} eq 'Category' ) {

            # should I focus and expand this category
            if ( defined $Object{ID} && $Object{ID} eq $Param{SelectedCategoryID}) {
                $ListClass   .= ' Active';
                $AnchorClass .= ' selected';
            }

            # add count to all categories except virtual ones
            if ( !$Param{NoContentCounters} ) {
                if ( defined $Object{ID} && $Object{ID} =~ /^_/ ) {
                    $ObjectName  .= ' (' . $Object{Count} . ')';
                    $AnchorClass .= ' Italic';
                }
                else {
                    $ObjectName .= ' (' . $Object{AllCount} . ', ' . $Object{Count} . ')';
                }
            }

            $ObjectStrg
                .= '<a href="index.pl?Action='
                . $Self->{Action}
                . ';SelectedCategoryID='
                . $Object{ID}
                . ';"><span class="TextModuleCategory NoReload'.$AnchorClass;
            if ( $Self->{Action} eq 'AdminTextModuleCategories' ) {
                $ObjectStrg .= ' Edit';
            }
            $ObjectStrg .= '">' . $ObjectName . '</span></a>';
        }
        elsif ( $Object{Type} eq 'TextModule' ) {
            $ObjectStrg
                .= '<a href="?#"><span id="'
                . $Object{ID}
                . '" class="TextModule">'
                . $ObjectName . ' ('
                . $Object{Language}
                . ')</span></a>';
        }

        # open sub category menu
        if ( $CategoryBuildLastLevel < $#Split ) {
            $CategoryStrg .= '<ul>';
        }

        # close former sub category menu
        elsif ( $CategoryBuildLastLevel > $#Split ) {
            $CategoryStrg .= '</li>';
            $CategoryStrg .= '</ul>' x ( $CategoryBuildLastLevel - $#Split );
            $CategoryStrg .= '</li>';
        }

        # close former list element
        elsif ($CategoryStrg) {
            $CategoryStrg .= '</li>';
        }

        $CategoryStrg .= '<li  class="'.$ListClass;
        if ( $Object{Type} eq 'Category' ) {
            $CategoryStrg .= 'data-jstree="{\'type\':\'category\'}';
        }
        $CategoryStrg .= ">" . $ObjectStrg;

        # keep current queue level for next category
        $CategoryBuildLastLevel = $#Split;
    }

    # build category tree (and close all sub category menus)
    my $Result;
    $Result .= '<ul class="CategoryTreeView">';
    $Result .= $CategoryStrg || '';
    $Result .= '</li></ul>' x $CategoryBuildLastLevel;
    $Result .= '</li></ul>';
    return $Result;
}

=item ShowAllTextModules()

Returns HTML-output for all (filtered) textmodules .

    my $HashRef = $TextModuleObject->ShowAllTextModules(
        CategoryID => 123       #optional
        TicketTypeID => 123     #optional
        TicketStateID => 123    #optional
        QueueID => 123,         #optional
        %TicketData,            #optional
        %CustomerUserData,
        Agent      => 1,        #optional, set autom. if neither Customer nor Public is set
        Customer   => 1,        #optional
        Public     => 1,        #optional
        ShowEmptyList  => 0|1,  #optional
    );

=cut

sub ShowAllTextModules {
    my ( $Self, %Param ) = @_;

    # create needed objects
    my $ConfigObject  = $Kernel::OM->Get('Kernel::Config');
    my $MainObject    = $Kernel::OM->Get('Kernel::System::Main');

    if ( !$Param{ShowEmptyList} ) {

        my $TextModuleObject;
        if ( $Kernel::OM->Get('Kernel::System::Main')->Require('Kernel::System::TextModule') ) {
            $TextModuleObject = Kernel::System::TextModule->new( %{$Self}, LayoutObject => $Self );
        }

        return $Self->Output(
            TemplateFile => 'TextModulesSelection',
            Data         => {
                %Param,
                }
        ) if !$TextModuleObject;

        # get available text modules
        my %TextModuleContentData = $TextModuleObject->TextModuleList(
            ValidID => 1,
            Result  => 'HASH',
            %Param,
        );

        # check for any available text module...
        return $Self->Output(
            TemplateFile => 'TextModulesSelection',
            Data         => {
                %Param,
                }
        ) if !%TextModuleContentData;

        # get categorylist for selected textmodules
        my %Categories = $TextModuleObject->TextModuleCategoryList();
        my %CategoriesReverse = reverse %Categories;

        my %CategoryTextModules;
        my %CategoryCount;
        my %CategoryList;
        for my $ID ( keys %TextModuleContentData ) {

            my $LinkedCategoriesRef = $TextModuleObject->TextModuleObjectLinkGet(
                ObjectType   => 'TextModuleCategory',
                TextModuleID => $ID,
            );

            foreach my $CategoryID ( @{$LinkedCategoriesRef} ) {
                $CategoryTextModules{$CategoryID}->{$ID} = $TextModuleContentData{$ID},
                    $CategoryCount{$CategoryID}++;
                my @TempArray = split(/::/,$Categories{$CategoryID});

                # check if parent category empty
                if ( scalar @TempArray > 1 ) {
                    my $ParentCategory = "";
                    my @ArrayParts = ();
                    for my $ArrayPart ( @TempArray ) {
                        push @ArrayParts, $ArrayPart;
                        $ParentCategory = join('::',@ArrayParts);
                        if (!$CategoryList{$CategoriesReverse{$ParentCategory}}) {
                            $CategoryList{$CategoriesReverse{$ParentCategory}} = $ParentCategory;
                        }
                    }
                }
                $CategoryList{$CategoryID} = $Categories{$CategoryID};
            }
        }

        my $ShowCategories = $Kernel::OM->Get('Kernel::Config')->Get('TextModule::ShowCategories');

        if ($ShowCategories) {

            $Param{TextModuleSelection} = $Self->TextModuleCategoryTree(
                Categories          => \%CategoryList,
                CategoryCount       => \%CategoryCount,
                CategoryTextModules => \%CategoryTextModules,
                NoVirtualCategories => 1,
                NoCategoryLink      => 1,
                IncludeTextModules  => 1,
                NoContentCounters   => 1,
            );

            $Self->Block(
                Name => 'TextModuleCategory',
                Data => {
                    TextModuleSelection => $Param{TextModuleSelection},
                    }
            );

            $Param{DisplayType} = 'Category';

        }
        else {
            foreach
                my $TextModuleID (
                sort { $TextModuleContentData{$a}->{Name} cmp $TextModuleContentData{$b}->{Name} }
                keys %TextModuleContentData
                )
            {
                $Self->Block(
                    Name => 'TextModuleList',
                    Data => $TextModuleContentData{$TextModuleID},
                );
            }

            $Param{DisplayType} = 'List';
        }

        return $Self->Output(
            TemplateFile => 'TextModulesSelection',
            Data         => {
                %Param,
                }
        );
    }
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
