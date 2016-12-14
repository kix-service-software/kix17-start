# --
# multiselect fields to assign dynamic fields easily to frontend modules
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Dorothea(dot)Doerffel(at)cape(dash)it(dot)de
# * Rene(dot)Boehm(at)cape(dash)it(dot)de
# --
# $Id$
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::OutputFilter::AdminDynamicFieldSysConfigSettings;

use strict;
use warnings;

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {%Param};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # create needed objects
    my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');
    my $LayoutObject       = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    my $DynamicFieldName = '';

    # get dynamic field information
    my $ID = $Kernel::OM->Get('Kernel::System::Web::Request')->GetParam( Param => 'ID' );
    if ( defined $ID && $ID ) {

        my $DynamicField = $Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldGet(
            ID => $ID
        );
        $DynamicFieldName = $DynamicField->{Name};
    }

    # get all available frontendmodules which use dynamic fields
    # get already assigned dynamic fields
    my %FrontendModules = $Self->_GetAllAvailableFrontendModules( Name => $DynamicFieldName );

    # create available dynamic field multiselect field
    $Param{AvailableFrontendModulesStrg} = $LayoutObject->BuildSelection(
        Data          => $FrontendModules{AvailableFrontends},
        Name          => 'AvailableFrontends',
        SelectedValue => $FrontendModules{SelectedFrontends},
        PossibleNone  => 0,
        Translation   => 0,
        Multiple      => 1,
        Size          => 10,
        Class         => 'DynamicFieldAvailableInFrontend'
    );

    # create mandatory dynamic field multiselect field
    $Param{MandatoryFrontendModulesStrg} = $LayoutObject->BuildSelection(
        Data          => $FrontendModules{SelectedFrontends},
        Name          => 'MandatoryFrontends',
        SelectedValue => $FrontendModules{MandatoryFrontends},
        PossibleNone  => 0,
        Translation   => 0,
        Multiple      => 1,
        Size          => 10,
        Class         => 'DynamicFieldAvailableInFrontend'
    );

    # create HMTL
    # append multiselect for changing sysconfig settings
    my $SearchPattern
        = '<fieldset\sclass\=\"TableLike\">\s*<div\sclass\=\"Field\sSpacingTop\">\s*<button';
    my $ReplacementString = '<div class="WidgetSimple">'
        . '<div class="Header">'
        . '<h2>'
        . $LayoutObject->{LanguageObject}->Translate('DynamicField SysConfig Settings')
        . '</h2>'
        . '</div>'
        . '<div class="Content">'
        . '<fieldset class="TableLike">'
        . '<label for="Rows">'
        . $LayoutObject->{LanguageObject}
        ->Translate('Show DynamicField in frontend modules')
        . ':<br /><br />('
        . $LayoutObject->{LanguageObject}
        ->Get('Please select all frontend modules which should display the dynamic field.')
        . ')</label>'
        . '<div class="Field">'
        . $Param{AvailableFrontendModulesStrg}
        . '</div>'
        . '<div class="Clear"></div>'
        . '<label for="Rows">'
        . $LayoutObject->{LanguageObject}->Translate('Mandatory in frontend modules')
        . ':<br /><br />('
        . $LayoutObject->{LanguageObject}->Translate(
        'Please select all frontend modules which should have the dynamic field as a mandatory field.'
        )
        . ')</label>'
        . '<div class="Field">'
        . $Param{MandatoryFrontendModulesStrg}
        . '</div>'
        . '<div class="Clear"></div>'
        . '</fieldset>'
        . '</div>'
        . '</div>';

    # do replace
    if ( ${ $Param{Data} } =~ m{ $SearchPattern }ixms )
    {
        ${ $Param{Data} } =~ s{ ($SearchPattern) }{ $ReplacementString$1 }ixms;
    }

    # add some javascript / jquery to move selected fields into mandatory fields
    $SearchPattern     = 'Core\.Agent\.Admin\.DynamicField\.ValidationInit';
    $ReplacementString = '$(\'#AvailableFrontends\').bind(\'click\',function(){'
        . '    var OptionStrg = \'\','
        . '    SelectedOptions = new Array();'
        . '    $(\'#MandatoryFrontends\').find(\'option:selected\').each(function(){'
        . '        SelectedOptions.push($(this).html());'
        . '    });'
        . '    $(this).find(\'option:selected\').each(function(){'
        . '        OptionStrg += \'<option value="\'+$(this).val()+\'">\'+$(this).html()+\'</option>\';'
        . '    });'
        . '    $(\'#MandatoryFrontends\').html(OptionStrg);'
        . '    $.each(SelectedOptions,function(index,item){'
        . '        $("#MandatoryFrontends option[value=\'" + item + "\']").attr("selected","selected");'
        . '    });'
        . '});'
        . 'var $Form  = $(\'#AvailableFrontends\').closest(\'form\'),'
        . '    $Action = $Form.find(\'input[name="Action"]\'), '
        . '    ActionValue = $Action.val();'
        . '$Form.find(\'button[type="Submit"]\').bind(\'click\',function(){'
        . '    $(this).attr("disabled", "disabled");'
        . '    $(this).parents(\'fieldset\').find(\'div.Clear\').parent().append("<div class=\"Field\">'
        . $LayoutObject->{LanguageObject}
        ->Translate('Saving module assignments in SysConfig')
        . '...<img src=\"'
        . $Kernel::OM->Get('Kernel::Config')->Get('Frontend::ImagePath')
        . 'loader.gif\"></div><div class=\"Clear\"></div>");'
        . '    $Action.val(\'AdminDynamicFieldSysConfigSettingsAJAXHandler\');'
        . '    Core.AJAX.FunctionCall(Core.Config.Get(\'Baselink\'),Core.AJAX.SerializeForm($Form),function(){'
        . '        $Action.val(ActionValue);'
        . '        $Form.submit();'
        . '    });'
        . '    return false;'
        . '});';

    # do replace
    if ( ${ $Param{Data} } =~ m{ $SearchPattern }ixms )
    {
        ${ $Param{Data} } =~ s{ ($SearchPattern) }{ $ReplacementString$1 }ixms;
    }

    my $SearchPattern1 = 'Core\.Agent';
    if ( ${ $Param{Data} } =~ m{ $SearchPattern1 }ixms )
    {

    }

    # return
    return 1;
}

sub _GetAllAvailableFrontendModules {
    my ( $Self, %Param ) = @_;

    my %Result;

    # get all frontend modules
    # get agent frontend modules
    my $ConfigHashAgent = $Kernel::OM->Get('Kernel::Config')->Get('Frontend::Module');

    # get customer frontend modules
    my $ConfigHashCustomer = $Kernel::OM->Get('Kernel::Config')->Get('CustomerFrontend::Module');
    my %ConfigHash = ( %{$ConfigHashAgent}, %{$ConfigHashCustomer} );

    # get all tabs
    my $ConfigHashTabs = $Kernel::OM->Get('Kernel::Config')->Get('AgentTicketZoomBackend');
    for my $Item ( keys %{$ConfigHashTabs} ) {

        # if no link is given
        next if !defined $ConfigHashTabs->{$Item}->{Link};

        # look for PretendAction
        $ConfigHashTabs->{$Item}->{Link} =~ /^(.*?)\;PretendAction=(.*?)\;(.*)$/;
        next if ( !$2 || $ConfigHash{$2} );

     # if given and not already registered as frontend module - add width empty value to config hash
        $ConfigHash{$2} = '';
    }

    # ticket overview - add width empty value to config hash
    $ConfigHash{'OverviewCustom'}  = '';
    $ConfigHash{'OverviewSmall'}   = '';
    $ConfigHash{'OverviewMedium'}  = '';
    $ConfigHash{'OverviewPreview'} = '';

    # KIXSidebars - add width empty value to config hash
    foreach my $Frontend (qw(Frontend CustomerFrontend)) {
        my $SidebarConfig
            = $Kernel::OM->Get('Kernel::Config')->Get( $Frontend . '::KIXSidebarBackend' );
        if ( $SidebarConfig && ref($SidebarConfig) eq 'HASH' ) {
            foreach my $Key ( sort keys %{$SidebarConfig} ) {
                my $SidebarBackendConfig = $Kernel::OM->Get('Kernel::Config')
                    ->Get( 'Ticket::Frontend::KIXSidebar' . $Key );
                if ( exists( $SidebarBackendConfig->{DynamicField} ) ) {
                    $ConfigHash{ 'KIXSidebar' . $Key } = '';
                }
            }
        }
    }

    my %AvailableFrontends;
    my @SelectedFrontends  = ();
    my @MandatoryFrontends = ();

    $AvailableFrontends{CustomerTicketZoomFollowUp} = 'CustomerTicketZoomFollowUp';

    # get all frontend modules with dynamic field config
    for my $Item ( keys %ConfigHash ) {
        my $ItemConfig = $Kernel::OM->Get('Kernel::Config')->Get( "Ticket::Frontend::" . $Item );

        # if dynamic field config exists
        next if !( defined $ItemConfig && defined $ItemConfig->{DynamicField} );
        $AvailableFrontends{$Item} = $Item;


        # for CustomerTicketZoom check also FollowUpDynamicFields
        if ( $Item eq 'CustomerTicketZoom' && defined $ItemConfig->{FollowUpDynamicField}->{ $Param{Name} } ) {
            if ( $ItemConfig->{FollowUpDynamicField}->{ $Param{Name} } eq '1' ) {
                push @SelectedFrontends, 'CustomerTicketZoomFollowUp';
            }
            elsif ( $ItemConfig->{FollowUpDynamicField}->{ $Param{Name} } eq '2' ) {
                push @SelectedFrontends, 'CustomerTicketZoomFollowUp';
                push @MandatoryFrontends, 'CustomerTicketZoomFollowUp';
            }
        }

        # if dynamic field is activated
        next
            if (
            !defined $ItemConfig->{DynamicField}->{ $Param{Name} }
            || $ItemConfig->{DynamicField}->{ $Param{Name} } eq '0'
            );
        push @SelectedFrontends, $Item;

        # if dynamic field is mandatory
        next if $ItemConfig->{DynamicField}->{ $Param{Name} } ne '2';
        push @MandatoryFrontends, $Item;
    }

    # return result
    $Result{AvailableFrontends} = \%AvailableFrontends;
    $Result{SelectedFrontends}  = \@SelectedFrontends;
    $Result{MandatoryFrontends} = \@MandatoryFrontends;

    return %Result;
}

1;
