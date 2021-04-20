// --
// Copyright (C) 2006-2021 c.a.p.e. IT GmbH, https://www.cape-it.de
// --
// This software comes with ABSOLUTELY NO WARRANTY. For details, see
// the enclosed file LICENSE for license information (AGPL). If you
// did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
// --

"use strict";

/**
 * @namespace
 * @exports TargetNS as DynamicFieldRemoteDB
 * @description
 *      This namespace contains the functionality for AJAX calls of DynamicFieldRemoteDB.
 */
var DynamicFieldRemoteDB = (function (TargetNS) {

    var Identifiers = new Object();

    /**
     * @function
     * @description
     *      Initialize the edit field
     * @param {String} Identifier - The name of the field which should be initialized
     * @param {String} IdentifierID - The id of the field which should be initialized
     * @param {String} MaxArraySize - Maximum number of entries
     * @param {String} IDCounter - Initial counter for entry ids
     * @param {String} QueryDelay - Delay before autocomplete search
     * @param {String} MinQueryLength - Minimum length for autocomplete search
     * @param {String} Constriction - Semicolon separated string of constriction relevant parameters
     * @return nothing
     */
    TargetNS.InitEditField = function (Identifier, IdentifierID, MaxArraySize, IDCounter, QueryDelay, MinQueryLength, Constriction) {
        Identifiers[Identifier] = new Object();
        Identifiers[Identifier]['AutoCompleteField']   = Identifier + '_AutoComplete';
        Identifiers[Identifier]['ContainerField']      = Identifier + '_Container';
        Identifiers[Identifier]['LoaderField']         = Identifier + '_Loader';
        Identifiers[Identifier]['ValidateField']       = Identifier + '_Validate';
        Identifiers[Identifier]['ValueField']          = Identifier + '_';
        Identifiers[Identifier]['FieldID']             = '#' + Identifier;
        Identifiers[Identifier]['AutoCompleteFieldID'] = '#' + Identifiers[Identifier]['AutoCompleteField'];
        Identifiers[Identifier]['ContainerFieldID']    = '#' + Identifiers[Identifier]['ContainerField'];
        Identifiers[Identifier]['LoaderFieldID']       = '#' + Identifiers[Identifier]['LoaderField'];
        Identifiers[Identifier]['ValidateFieldID']     = '#' + Identifiers[Identifier]['ValidateField'];
        Identifiers[Identifier]['ValueFieldID']        = '#' + Identifiers[Identifier]['ValueField'];
        Identifiers[Identifier]['IDCounter']           = IDCounter;
        Identifiers[Identifier]['MaxArraySize']        = MaxArraySize;
        Identifiers[Identifier]['MinQueryLength']      = MinQueryLength;
        Identifiers[Identifier]['QueryDelay']          = QueryDelay;
        Identifiers[Identifier]['Constriction']        = new Object();

        var ConstrictionArray = Constriction.split(";");
        for (var i = 0; i < ConstrictionArray.length; i++) {
            Identifiers[Identifier]['Constriction'][ConstrictionArray[i]] = 1;
        }

        if ($('.InputField_Selection > input[name=' + Identifier + ']').length >= Identifiers[Identifier]['MaxArraySize']) {
            $(Identifiers[Identifier]['AutoCompleteFieldID']).hide();
        }

        $(Identifiers[Identifier]['AutoCompleteFieldID']).autocomplete({
            delay: Identifiers[Identifier]['QueryDelay'],
            minLength: Identifiers[Identifier]['MinQueryLength'],
            source: function (Request, Response) {
                var Data = {};
                Data.Action         = 'DynamicFieldRemoteDBAJAXHandler';
                Data.Subaction      = 'Search';
                Data.Search         = Request.term;
                Data.DynamicFieldID = IdentifierID;

                var QueryString = Core.AJAX.SerializeForm($(Identifiers[Identifier]['AutoCompleteFieldID']), Data);
                $.each(Data, function (Key, Value) {
                    QueryString += ';' + encodeURIComponent(Key) + '=' + encodeURIComponent(Value);
                });

                // show loader
                $(Identifiers[Identifier]['LoaderFieldID']).show();

                if ($(Identifiers[Identifier]['AutoCompleteFieldID']).data('AutoCompleteXHR')) {
                    $(Identifiers[Identifier]['AutoCompleteFieldID']).data('AutoCompleteXHR').abort();
                    $(Identifiers[Identifier]['AutoCompleteFieldID']).removeData('AutoCompleteXHR');
                }
                $(Identifiers[Identifier]['AutoCompleteFieldID']).data('AutoCompleteXHR', Core.AJAX.FunctionCall(Core.Config.Get('CGIHandle'), QueryString, function (Result) {
                    var Data = [];
                    $.each(Result, function () {
                        Data.push({
                            key:   this.Key,
                            value: this.Value,
                            title: this.Title
                        });
                    });
                    $(Identifiers[Identifier]['AutoCompleteFieldID']).data('AutoCompleteData', Data);
                    $(Identifiers[Identifier]['AutoCompleteFieldID']).removeData('AutoCompleteXHR');
                    Response(Data);
                }).fail(function() {
                    Response($(Identifiers[Identifier]['AutoCompleteFieldID']).data('AutoCompleteData'));
                }));
            },
            response: function() {
                // hide loader again
                $(Identifiers[Identifier]['LoaderFieldID']).hide();
            },
            select: function (Event, UI) {
                Identifiers[Identifier]['IDCounter']++;
                $(Identifiers[Identifier]['ContainerFieldID']).append(
                    '<div class="InputField_Selection" style="display:block;position:inherit;top:0px;">'
                    + '<input id="'
                    + Identifiers[Identifier]['ValueField']
                    + Identifiers[Identifier]['IDCounter']
                    + '" type="hidden" name="'
                    + Identifier
                    + '" value="'
                    + UI.item.key
                    + '" />'
                    + '<div class="Text" title="'
                    + UI.item.title
                    + '">'
                    + UI.item.value
                    + '</div>'
                    + '<div class="Remove"><a href="#" role="button" title="'
                    + Core.Config.Get('DynamicFieldRemoteDB.TranslateRemoveSelection')
                    + '" tabindex="-1" aria-label="'
                    + Core.Config.Get('DynamicFieldRemoteDB.TranslateRemoveSelection')
                    + ': '
                    + UI.item.value
                    + '">x</a></div><div class="Clear"></div>'
                    + '</div>'
                );
                DynamicFieldRemoteDB.InitEditValue(Identifier, Identifiers[Identifier]['IDCounter']);
                $(Identifiers[Identifier]['ContainerFieldID']).show();
                $(Identifiers[Identifier]['ContainerFieldID'] + ' > .InputField_Dummy').remove();
                $(Identifiers[Identifier]['AutoCompleteFieldID']).val('');
                if ($('.InputField_Selection > input[name=' + Identifier + ']').length >= Identifiers[Identifier]['MaxArraySize']) {
                    $(Identifiers[Identifier]['AutoCompleteFieldID']).hide();
                }
                $(Identifiers[Identifier]['FieldID']).trigger('change');
                Event.preventDefault();
                return false;
            },
        });

        $(Identifiers[Identifier]['AutoCompleteFieldID']).blur(function() {
            $(this).val('');
            Core.Form.ErrorTooltips.HideTooltip();
            if ( $(Identifiers[Identifier]['ValidateFieldID']).hasClass('Error') ) {
                $('label[for=' + Identifier + ']').addClass('LabelError');
                $(Identifiers[Identifier]['AutoCompleteFieldID']).addClass('Error');
            } else {
                $('label[for=' + Identifier + ']').removeClass('LabelError');
                $(Identifiers[Identifier]['AutoCompleteFieldID']).removeClass('Error');
            }
        });

        if ( $(Identifiers[Identifier]['ValidateFieldID']).hasClass('Error') ) {
            $('label[for=' + Identifier + ']').addClass('LabelError');
            $(Identifiers[Identifier]['AutoCompleteFieldID']).addClass('Error');
            $(Identifiers[Identifier]['FieldID']).addClass('Error');

            if ( $(Identifiers[Identifier]['ValidateFieldID']).hasClass('ServerError') ) {
                $(Identifiers[Identifier]['AutoCompleteFieldID']).addClass('ServerError');
                $(Identifiers[Identifier]['FieldID']).addClass('ServerError');
            }
        }

        $(Identifiers[Identifier]['AutoCompleteFieldID']).off('focus').on('focus', function() {
            if ($(this).hasClass('Error')) {
                Core.Form.ErrorTooltips.ShowTooltip(
                    $(this), $(Identifiers[Identifier]['FieldID'] + 'Error').html(), 'TongueTop'
                );
            }
            if ($(this).hasClass('ServerError')) {
                Core.Form.ErrorTooltips.ShowTooltip(
                    $(this), $(Identifiers[Identifier]['FieldID'] + 'ServerError').html(), 'TongueTop'
                );
            }
        });

        $(Identifiers[Identifier]['FieldID']).change(function() {
            if ($(Identifiers[Identifier]['FieldID']).data('AJAXRequest')) {
                $(Identifiers[Identifier]['FieldID']).data('AJAXRequest').abort();
                $(Identifiers[Identifier]['FieldID']).removeData('AJAXRequest');
            }

            $(Identifiers[Identifier]['ValidateFieldID']).val('');
            $('.InputField_Selection > input[name=' + Identifier + ']').each(function () {
                if($(this).val()){
                    $(Identifiers[Identifier]['ValidateFieldID']).removeClass('Error');
                    $(Identifiers[Identifier]['ValidateFieldID']).val('1');
                    return false;
                }
            });

            if ($(Identifiers[Identifier]['FieldID']).val().length == 0) {
                return false;
            }

            var Data = {};
            Data.Action         = 'DynamicFieldRemoteDBAJAXHandler';
            Data.Subaction      = 'AddValue';
            Data.Key            = $(Identifiers[Identifier]['FieldID']).val();
            Data.DynamicFieldID = IdentifierID;

            // add data from session
            $.extend(Data, GetSessionInformation());

            var QueryString = Core.AJAX.SerializeForm($(Identifiers[Identifier]['AutoCompleteFieldID']), Data);
            $.each(Data, function (Key, Value) {
                QueryString += ';' + encodeURIComponent(Key) + '=' + encodeURIComponent(Value);
            });

            $(Identifiers[Identifier]['FieldID']).data('AJAXRequest', $.ajax({
                type    : 'POST',
                url     : Core.Config.Get('CGIHandle'),
                data    : QueryString,
                dataType: 'html',
                async   : false,
                success : function (Response) {
                    if (Response) {
                        var Result = jQuery.parseJSON(Response);
                        $(Identifiers[Identifier]['FieldID']).val('');
                        while ($('.InputField_Selection > input[name=' + Identifier + ']').length >= Identifiers[Identifier]['MaxArraySize']) {
                            $('.InputField_Selection > input[name=' + Identifier + ']').last().siblings('div.Remove').find('a').trigger('click');
                        }
                        Identifiers[Identifier]['IDCounter']++;
                        $(Identifiers[Identifier]['ContainerFieldID']).append(
                            '<div class="InputField_Selection" style="display:block;position:inherit;top:0px;">'
                            + '<input id="'
                            + Identifiers[Identifier]['ValueField']
                            + Identifiers[Identifier]['IDCounter']
                            + '" type="hidden" name="'
                            + Identifier
                            + '" value="'
                            + Result.Key
                            + '" />'
                            + '<div class="Text" title="'
                            + Result.Title
                            + '">'
                            + Result.Value
                            + '</div>'
                            + '<div class="Remove"><a href="#" role="button" title="'
                            + Core.Config.Get('DynamicFieldRemoteDB.TranslateRemoveSelection')
                            + '" tabindex="-1" aria-label="'
                            + Core.Config.Get('DynamicFieldRemoteDB.TranslateRemoveSelection')
                            + ': '
                            + Result.Value
                            + '">x</a></div><div class="Clear"></div>'
                            + '</div>'
                        );
                        DynamicFieldRemoteDB.InitEditValue(Identifier, Identifiers[Identifier]['IDCounter']);
                        $(Identifiers[Identifier]['ContainerFieldID']).show();
                        $(Identifiers[Identifier]['ContainerFieldID'] + ' > .InputField_Dummy').remove();
                        $(Identifiers[Identifier]['AutoCompleteFieldID']).val('');
                        if ($('.InputField_Selection > input[name=' + Identifier + ']').length >= Identifiers[Identifier]['MaxArraySize']) {
                            $(Identifiers[Identifier]['AutoCompleteFieldID']).hide();
                        }
                        $(Identifiers[Identifier]['FieldID']).trigger('change');
                        return false;
                    }
                },
                error: function (jqXHR, textStatus, errorThrown) {
                    if (textStatus != 'abort') {
                        alert('Error thrown by AJAX: ' + textStatus + ': ' + errorThrown);
                    }
                }
            }));
        });

        $(Identifiers[Identifier]['ValidateFieldID']).closest('form').bind('submit', function() {
            if ( $(Identifiers[Identifier]['ValidateFieldID']).hasClass('Error') ) {
                $('label[for=' + Identifier + ']').addClass('LabelError');
                $(Identifiers[Identifier]['AutoCompleteFieldID']).addClass('Error');
            } else {
                $('label[for=' + Identifier + ']').removeClass('LabelError');
                $(Identifiers[Identifier]['AutoCompleteFieldID']).removeClass('Error');
            }
        });

        CheckInputFields(Identifier);

        Core.App.Subscribe('Event.AJAX.FormUpdate.Callback', function (Request, Response) {
            if ($('.InputField_Selection > input[name=' + Identifier + ']').length > 0) {
                var Data = {};
                Data.Action         = 'DynamicFieldRemoteDBAJAXHandler';
                Data.Subaction      = 'PossibleValueCheck';
                Data.DynamicFieldID = IdentifierID;

                var QueryString = SerializeForm($(Identifiers[Identifier]['AutoCompleteFieldID']), Identifiers[Identifier]['Constriction']);
                $.each(Data, function (Key, Value) {
                    QueryString += ';' + encodeURIComponent(Key) + '=' + encodeURIComponent(Value);
                });

                if ($(Identifiers[Identifier]['FieldID']).data('PossibleValueCheck') != QueryString) {
                    $(Identifiers[Identifier]['FieldID']).data('PossibleValueCheck', QueryString);
                    Core.AJAX.FunctionCall(Core.Config.Get('CGIHandle'), QueryString, function (Response) {
                        var Change = 0;
                        $('.InputField_Selection > input[name=' + Identifier + ']').each(function() {
                            var Found = 0;
                            var $Element = $(this);
                            $.each(Response, function(Key, Value) {
                                if ( $Element.val() == Value ) {
                                    Found = 1;
                                }
                            });
                            if (Found == 0) {
                                $Element.closest('.InputField_Selection').remove();
                                Change = 1;
                            }
                        });
                        if (Change) {
                            CheckInputFields(Identifier);
                            $(Identifiers[Identifier]['FieldID']).trigger('change');
                        }
                    }, undefined, false);
                }
            }
        });
    };

    /**
     * @function
     * @description
     *      Initialize the edit value
     * @param {String} Identifier - The name of the field the entry belongs to
     * @param {String} Counter - The counter of the entry which should be initialized
     * @return nothing
     */
    TargetNS.InitEditValue = function (Identifier, Counter) {
        $(Identifiers[Identifier]['ValueFieldID'] + Counter).siblings('div.Remove').find('a').bind('click', function() {
            $(this).closest('.InputField_Selection').remove();
            CheckInputFields(Identifier);
            $(Identifiers[Identifier]['FieldID']).trigger('change');
            return false;
        });
    };

    /**
     * @function
     * @description
     *      Initialize the ajax update
     * @param {String} Identifier - The name of field which should be initialized
     * @param {Array} FieldsToUpdate - Array of field names that should be included
     * @return nothing
     */
    TargetNS.InitAJAXUpdate = function (Identifier, FieldsToUpdate) {
        $(Identifiers[Identifier]['FieldID']).bind('change', function (Event) {
            var CurrentValue = '';
            $('.InputField_Selection > input[name=' + Identifier + ']').each(function() {
                if (CurrentValue.length > 0) {
                    CurrentValue += ';';
                }
                CurrentValue += encodeURIComponent($(this).val());
            });
            if ($(this).data('CurrentValue') != CurrentValue) {
                $(this).data('CurrentValue', CurrentValue);
                Core.AJAX.FormUpdate($(this).parents('form'), 'AJAXUpdate', Identifier, FieldsToUpdate, function(){}, undefined, false);
            }
        });
    };

    /**
     * @private
     * @name CheckInputFields
     * @memberof DynamicFieldRemoteDB
     * @function
     * @param {String} Identifier - The name of the field
     * @returns nothing
     * @description
     *      Checks if input field should be shown or dummyfield is needed
     */
    function CheckInputFields(Identifier) {
        if ($('.InputField_Selection > input[name=' + Identifier + ']').length == 0) {
            $(Identifiers[Identifier]['ContainerFieldID']).hide().append(
                '<input class="InputField_Dummy" type="hidden" name="' + Identifier + '" value="" />'
            );
        }
        if ($('.InputField_Selection > input[name=' + Identifier + ']').length < Identifiers[Identifier]['MaxArraySize']) {
            $(Identifiers[Identifier]['AutoCompleteFieldID']).show();
        }
    }

    /**
     * @private
     * @name SerializeForm
     * @memberof DynamicFieldRemoteDB
     * @function
     * @returns {String} The query string.
     * @param {jQueryObject} $Element - The jQuery object of the form  or any element within this form that should be serialized
     * @param {Object} [Include] - Elements (Keys) which should be included in the serialized form string (optional)
     * @description
     *      Serializes the form data into a query string.
     */
    function SerializeForm($Element, Include) {
        var QueryString = "";
        if (isJQueryObject($Element) && $Element.length) {
            $Element.closest('form').find('input:not(:file), textarea, select').filter(':not([disabled=disabled])').each(function () {
                var Name = $(this).attr('name') || '';

                // only look at fields with name
                // only add element to the string, if there is no key in the data hash with the same name
                if (
                    !Name.length
                    || (
                        typeof Include !== 'undefined'
                        && typeof Include[Name] === 'undefined'
                    )
                ){
                    return;
                }

                if ($(this).is(':checkbox, :radio')) {
                    if ($(this).is(':checked')) {
                        QueryString += encodeURIComponent(Name) + '=' + encodeURIComponent($(this).val() || 'on') + ";";
                    }
                }
                else if ($(this).is('select')) {
                    $.each($(this).find('option:selected'), function(){
                        QueryString += encodeURIComponent(Name) + '=' + encodeURIComponent($(this).val() || '') + ";";
                    });
                }
                else {
                    QueryString += encodeURIComponent(Name) + '=' + encodeURIComponent($(this).val() || '') + ";";
                }
            });
        }
        return QueryString;
    };

    /**
     * @private
     * @name GetSessionInformation
     * @memberof DynamicFieldRemoteDB
     * @function
     * @returns {Object} Hash with session data, if needed.
     * @description
     *      Collects session data in a hash if available.
     */
    function GetSessionInformation() {
        var Data = {};
        if (!Core.Config.Get('SessionIDCookie')) {
            Data[Core.Config.Get('SessionName')] = Core.Config.Get('SessionID');
            Data[Core.Config.Get('CustomerPanelSessionName')] = Core.Config.Get('SessionID');
        }
        Data.ChallengeToken = Core.Config.Get('ChallengeToken');
        return Data;
    }

    return TargetNS;
}(DynamicFieldRemoteDB || {}));
