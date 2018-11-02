// --
// Copyright (C) 2006-2018 c.a.p.e. IT GmbH, https://www.cape-it.de
// --
// This software comes with ABSOLUTELY NO WARRANTY. For details, see
// the enclosed file LICENSE for license information (AGPL). If you
// did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
// --

"use strict";

var Core = Core || {};
Core.KIX4OTRS = Core.KIX4OTRS || {};
Core.KIX4OTRS.Agent = Core.KIX4OTRS.Agent || {};

/**
 * @namespace
 * @exports TargetNS as Core.Agent.CustomerSearch
 * @description This namespace contains the special module functions for the dynamic field object reference autocomplete search
 */
Core.KIX4OTRS.Agent.DynamicFieldObjectReference = (function(TargetNS) {
    var BackupData = {
        CustomerInfo : '',
        CustomerEmail : '',
        CustomerKey : ''
    };

    /**
     * @function
     * @param {jQueryObject}
     *            $Element The jQuery object of the input field with
     *            autocomplete
     * @param {Boolean}
     *            ActiveAutoComplete Set to false, if autocomplete should only
     *            be started by click on a button next to the input field
     * @param {String}
     *            ObjectReference choose the kind of ObjectReference type
     * @return nothing This function initializes the special module functions
     */
    TargetNS.Init = function($Element, ActiveAutoComplete, ObjectReference) {
        if (isJQueryObject($Element)) {
            // Hide tooltip in autocomplete field, if user already typed something to prevent the autocomplete list to be hidden under the tooltip. (Only needed for serverside errors)
            $Element.unbind('keyup.Validate').bind('keyup.Validate', function() {
                var Value = $Element.val();
                if ($Element.hasClass('ServerError') && Value.length) {
                    $('#OTRS_UI_Tooltips_ErrorTooltip').hide();
                }
            });

            var CallingAction = $Element.closest('form').find('input[name="Action"]').val(),
                PretendAction = $Element.closest('form').find('input[name="PretendAction"]').val();

            // get action for use in tabs
            if ( typeof PretendAction != 'undefined' && PretendAction != '') {
                CallingAction = PretendAction;
            }

            $Element.autocomplete({
                minLength : ActiveAutoComplete ? Core.Config.Get('Autocomplete.MinQueryLength') : 500,
                delay : Core.Config.Get('Autocomplete.QueryDelay'),
                source : function(Request, Response) {
                    var ElementID = $Element.attr('id').substr(0,$Element.attr('id').length-4);
                    var URL = Core.Config.Get('Baselink'),
                        Data = {
                            Action : 'DynamicFieldObjectReferenceAJAXHandler',
                            ObjectReference : ObjectReference,
                            Term : Request.term,
                            MaxResults : Core.Config.Get('Autocomplete.MaxResultsDisplayed'),
                            CallingAction : CallingAction,
                            FormData : Core.AJAX.SerializeForm($Element.closest('form')),
                            DynamicField : ElementID
                            },
                        DynamicFieldName = ElementID.split("_")[0] === "Search" ? ElementID.split("_")[2] : ElementID.split("_")[1];

                    // if an old ajax request is already running, stop the old request and start the new one
                    if ($Element.data('AutoCompleteXHR')) {
                        $Element.data('AutoCompleteXHR').abort();
                        $Element.removeData('AutoCompleteXHR');
                        // run the response function to hide the request animation
                        Response({});
                    }

                    $Element.data('AutoCompleteXHR', Core.AJAX.FunctionCall(URL, Data, function(Result) {
                        var Data = [];
                        $Element.removeData('AutoCompleteXHR');
                        for(var Property in Result) {

                            // get all dynamic field possible value hashes from result
                            if(Result.hasOwnProperty(Property)) {
                                var FieldObject = Result[Property],
                                    FieldName = Property;

                                // if field is source get data back for autocomplete
                                if ( FieldName == DynamicFieldName ) {
                                    $.each(FieldObject, function() {
                                        Data.push({
                                            label : this.Value + " (" + this.Key + ")",
                                            // customer list representation (see CustomerUserListFields from Defaults.pm)
                                            value : this.Value,
                                            // customer user id
                                            key : this.Key
                                        });
                                    });
                                    Response(Data);
                                }

                                // check if other dynamic fields should be updated
                                else {
                                    if ( $('#DynamicField_'+FieldName).length && $('#DynamicField_'+FieldName).is('select') ) {
                                        var $FieldElement = $('#DynamicField_'+FieldName),
                                            // if used get selected value
                                            Selected = $("#DynamicField_"+FieldName+" option:selected").val();

                                        // clear selection
                                        $FieldElement.find('option').remove();

                                        $.each(FieldObject, function() {
                                            // append possible values
                                            $FieldElement.append($('<option>', { value :  this.Key }).text( this.Value));
                                            if ( this.Key == Selected )
                                                $("#DynamicField_"+FieldName+" option[value='"+this.Key+"']").attr('selected','selected');
                                        });
                                    }
                                }
                            }
                        }
                    }));
                },
                select : function(Event, UI) {
                    var Key         = UI.item.key, Value = UI.item.value,
                        ElementID   = $Element.attr('id').substr(0,$Element.attr('id').length-4);

                    $Element.val(Value);
                    $Element.data('LastValue', Value);
                    $('#'+ElementID).val(Key);
                    Event.preventDefault();
                    return false;
                }
            });
            $Element.bind('blur', function() {
                var ElementID   = $(this).attr('id').substr(0,$(this).attr('id').length-4);
                if ($(this).val().length > 0) {
                    $(this).val($(this).data('LastValue'));
                } else {
                    $(this).val('');
                    $(this).data('LastValue', '');
                    $('#'+ElementID).val('');
                    $('#'+ElementID).trigger('change');
                }

            })
            $Element.data('LastValue', $Element.val());

            if (!ActiveAutoComplete) {
                $Element
                    .after('<button id="' + $Element.attr('id') + 'Search" type="button">' + Core.Config.Get('Autocomplete.SearchButtonText') + '</button>');
                $('#' + $Element.attr('id') + 'Search').click(function() {
                    $Element.autocomplete("option", "minLength", 0);
                    $Element.autocomplete("search");
                    $Element.autocomplete("option", "minLength", 500);
                });
            }
        }

        // On unload remove old selected data. If the page is reloaded (with F5) this data stays in the field and invokes an ajax request otherwise
        $(window).bind('unload', function() {
            $('#SelectedCustomerUser').val('');
        });

    };

    /**
     * @function
     * @return nothing This function clear all selected customer info
     */
    TargetNS.ResetCustomerInfo = function() {

        $('#SelectedCustomerUser').val('');
        $('#CustomerUserID').val('');
        $('#CustomerID').val('');
        $('#CustomerUserOption').val('');
        $('#ShowCustomerID').html('');

        // reset customer info table
        $('#CustomerInfo .Content').html('none');
    };

    /**
     * @function
     * @param {string}
     *            Field ID object of the element should receive the focus on
     *            close event.
     * @return nothing This function shows an alert dialog for duplicated
     *         entries.
     */
    TargetNS.ShowDuplicatedDialog = function(Field) {
        Core.UI.Dialog.ShowAlert(Core.Config.Get('Duplicated.TitleText'), Core.Config.Get('Duplicated.ContentText') + ' '
            + Core.Config.Get('Duplicated.RemoveText'), function() {
            Core.UI.Dialog.CloseDialog($('.Alert'));
            $('#' + Field).val('');
            $('#' + Field).focus();
            return false;
        });
    };

    return TargetNS;
}(Core.KIX4OTRS.Agent.DynamicFieldObjectReference || {}));
