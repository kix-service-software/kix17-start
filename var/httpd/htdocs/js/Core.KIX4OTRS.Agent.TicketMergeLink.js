// --
// Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
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
 * @exports TargetNS as Core.KIX4OTRS.Agent.TicketMergeLink
 * @description This namespace contains the special module functions to create
 *              clickable link for merged tickets.
 */
Core.KIX4OTRS.Agent.TicketMergeLink = (function(TargetNS) {
    if (!$('iframe').length)
        return TargetNS;

    $('iframe').bind('load', function() {
        var $body = $(this.contentDocument).find('body'), content = $body.html();

        if (content.search(/<!-- KIX4OTRS MergeTargetLinkEnd -->/) != -1) {
            content = content.replace(/<!--\sKIX4OTRS\sMergeTargetLinkStart\s::(.*)::\s-->/g, '<a  href="index.pl?Action=AgentTicketZoom;TicketID=$1" target="new">');
            content = content.replace(/<!-- KIX4OTRS MergeTargetLinkEnd -->/g, "</a>");
            $body.html(content);
        }
    });

    return TargetNS;
}(Core.KIX4OTRS.Agent.TicketMergeLink || {}));
