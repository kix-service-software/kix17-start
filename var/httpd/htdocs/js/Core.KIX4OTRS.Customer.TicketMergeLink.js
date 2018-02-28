// --
// Copyright (C) 2006-2018 c.a.p.e. IT GmbH, http://www.cape-it.de
// --
// This software comes with ABSOLUTELY NO WARRANTY. For details, see
// the enclosed file COPYING for license information (AGPL). If you
// did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
// --

"use strict";

var Core = Core || {};
Core.KIX4OTRS = Core.KIX4OTRS || {};
Core.KIX4OTRS.Customer = Core.KIX4OTRS.Customer || {};

/**
 * @namespace
 * @exports TargetNS as Core.KIX4OTRS.Customer.TicketMergeLink
 * @description This namespace contains the special module functions to create
 *              clickable link for merged tickets.
 */
Core.KIX4OTRS.Customer.TicketMergeLink = (function(TargetNS) {
    if (!$('iframe').length)
        return TargetNS;

    $('iframe').bind('load', function() {
        var $body = $(this.contentDocument).find('body'), content = $body.html();

        if (content.search(/<!-- KIX4OTRS MergeTargetLinkEnd -->/) != -1) {
            content = content.replace(/<!--\sKIX4OTRS\sMergeTargetLinkStart\s::(.*)::\s-->/g, '<a  href="customer.pl?Action=CustomerTicketZoom;TicketID=$1" target="new">');
            content = content.replace(/<!-- KIX4OTRS MergeTargetLinkEnd -->/g, "</a>");
            $body.html(content);
        }
    });

    return TargetNS;
}(Core.KIX4OTRS.Customer.TicketMergeLink || {}));
