# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
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
    my $SearchPattern     = '<fieldset\sclass\=\"TableLike\">\s*<div\sclass\=\"Field\sSpacingTop\">\s*<button';
    my $ReplacementString = '<div class="WidgetSimple">
<div class="Header">
<h2><span>'
        . $LayoutObject->{LanguageObject}->Translate('DynamicField SysConfig Settings')
        . '</span></h2>
</div>
<div class="Content">
<fieldset class="TableLike">
<label for="Rows">'
        . $LayoutObject->{LanguageObject}->Translate('Show DynamicField in frontend modules')
        . ':<br /><br />('
        . $LayoutObject->{LanguageObject}->Translate('Please select all frontend modules which should display the dynamic field.')
        . ')</label><div class="Field">'
        . $Param{AvailableFrontendModulesStrg}
        . '</div>
<div class="Clear"></div>
<label for="Rows">'
        . $LayoutObject->{LanguageObject}->Translate('Mandatory in frontend modules')
        . ':<br /><br />('
        . $LayoutObject->{LanguageObject}->Translate('Please select all frontend modules which should have the dynamic field as a mandatory field.')
        . ')</label><div class="Field">'
        . $Param{MandatoryFrontendModulesStrg}
        . '</div>
<div class="Clear"></div>
</fieldset>
</div>
</div>';

    # do replace
    if ( ${ $Param{Data} } =~ m{ $SearchPattern }ixms )
    {
        ${ $Param{Data} } =~ s{ ($SearchPattern) }{ $ReplacementString$1 }ixms;
    }

    # add some javascript / jquery to move selected fields into mandatory fields
    $SearchPattern     = 'Core\.Agent\.Admin\.DynamicField\.ValidationInit';
    $ReplacementString = '$(\'#AvailableFrontends\').bind(\'click\',function(){
    var OptionStrg = \'\',
        SelectedOptions = new Array();
    $(\'#MandatoryFrontends\').find(\'option:selected\').each(function(){
        SelectedOptions.push($(this).html());
    });
    $(this).find(\'option:selected\').each(function(){
        OptionStrg += \'<option value="\'+$(this).val()+\'">\'+$(this).html()+\'</option>\';
    });
    $(\'#MandatoryFrontends\').html(OptionStrg);
    $.each(SelectedOptions,function(index,item){
        $("#MandatoryFrontends option[value=\'" + item + "\']").attr("selected","selected");
    });
});
var $Action = $(\'#AvailableFrontends\').closest(\'form\').find(\'input[name="Action"]\'),
    ActionValue = $Action.val();
Core.Form.Validate.SetSubmitFunction( $(\'#AvailableFrontends\').closest(\'form\'), function (Form) {
    $(Form).find(\'button[type="Submit"]\').parents(\'fieldset\').find(\'div.Clear\').parent().append("<div class=\"Field\">'
        . $LayoutObject->{LanguageObject}->Translate('Saving module assignments in SysConfig')
        . '...<img src=\"'
        . $Kernel::OM->Get('Kernel::Config')->Get('Frontend::ImagePath')
        . 'loader.gif\"></div><div class=\"Clear\"></div>");
    $Action.val(\'AdminDynamicFieldSysConfigSettingsAJAXHandler\');
    Core.AJAX.FunctionCall(Core.Config.Get(\'Baselink\'),Core.AJAX.SerializeForm($(Form)),function(){
        Core.Form.EnableForm($(Form));
        $Action.val(ActionValue);
        Form.submit();
        window.setTimeout(function () {
            Core.Form.DisableForm($(Form));
        }, 0);
    });
});';

    # do replace
    if ( ${ $Param{Data} } =~ m{ $SearchPattern }ixms )
    {
        ${ $Param{Data} } =~ s{ ($SearchPattern) }{ $ReplacementString$1 }ixms;
    }

    # return
    return 1;
}

sub _GetAllAvailableFrontendModules {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    my %Result;

    # get all frontend modules
    # get agent frontend modules
    my $ConfigHashAgent = $ConfigObject->Get('Frontend::Module');

    # get customer frontend modules
    my $ConfigHashCustomer = $ConfigObject->Get('CustomerFrontend::Module');

    # get admin frontend modules
    my %ConfigHash = ( %{$ConfigHashAgent}, %{$ConfigHashCustomer} );

    # get all tabs
    my $ConfigHashTabs = $ConfigObject->Get('AgentTicketZoomBackend');
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
            = $ConfigObject->Get( $Frontend . '::KIXSidebarBackend' );
        if ( $SidebarConfig && ref($SidebarConfig) eq 'HASH' ) {
            foreach my $Key ( sort keys %{$SidebarConfig} ) {
                my $SidebarBackendConfig = $ConfigObject
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
        my $ItemConfig = $ConfigObject->Get( "Ticket::Frontend::" . $Item );

        # if dynamic field config exists
        next if !( defined $ItemConfig && defined $ItemConfig->{DynamicField} );
        $AvailableFrontends{$Item} = $Item;

        # if dynamic field is activated
        # for CustomerTicketZoom check also FollowUpDynamicFields
        if ( $Item eq 'CustomerTicketZoom'
            && defined $ItemConfig->{FollowUpDynamicField}->{ $Param{Name} } )
        {
            if ( $ItemConfig->{FollowUpDynamicField}->{ $Param{Name} } eq '1' ) {
                push @SelectedFrontends, 'CustomerTicketZoomFollowUp';
            }
            elsif ( $ItemConfig->{FollowUpDynamicField}->{ $Param{Name} } eq '2' ) {
                push @SelectedFrontends,  'CustomerTicketZoomFollowUp';
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

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
