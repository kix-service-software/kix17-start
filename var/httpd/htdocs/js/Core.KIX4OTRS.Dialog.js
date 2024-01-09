// --
// Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
// --
// This software comes with ABSOLUTELY NO WARRANTY. For details, see
// the enclosed file LICENSE for license information (AGPL). If you
// did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
// --

"use strict";

var Core = Core || {};
Core.KIX4OTRS = Core.KIX4OTRS || {};

/**
 * @namespace
 * @exports TargetNS as Core.KIX4OTRS.Dialog
 * @description This namespace contains the dialog functions
 */
Core.KIX4OTRS.Dialog = (function(TargetNS) {
    /**
     * @function
     * @description Shows a alert dialog.
     * @param Headline
     *            The bold headline
     * @param Text
     *            The description
     * @param YesFunction
     *            The special function which is started on closing the dialog
     *            via Yes button (optional, if used also the removing of the
     *            dialog itself must be handled)
     * @param NoFunction
     *            The special function which is started on closing the dialog
     *            via No button (optional, if used also the removing of the
     *            dialog itself must be handled)
     * @return nothing
     */
    TargetNS.ShowQuestion = function(Headline, Text, YesLabel, YesFunction, NoLabel, NoFunction) {
        Core.UI.Dialog.ShowDialog({
            Type : "Question",
            Modal : true,
            Title : Headline,
            HTML : Text,
            PositionTop : "50%",
            PositionLeft : "Center",
            Buttons : [ {
                Label : YesLabel,
                Function : YesFunction
            }, {
                Label : NoLabel,
                Function : NoFunction
            } ]
        });
    };

    return TargetNS;
}(Core.KIX4OTRS.Dialog || {}));