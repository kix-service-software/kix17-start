# Documentation of KIX JavaScript Namespaces

This is the documentation of all JavaScript namespaces used in KIX Helpdesk.

If you find any error or inconsistency, please feel free to fix the issue and send us a pull request!

## Structure of JavaScript Namespaces

Every namespace has a matching JavaScript file. Some namespaces are used in every KIX screen or dialog
(e.g. [Core.Form](Core.Form.html), [Core.AJAX](Core.AJAX.html)), some others are only loaded and used for a specific screen
(e.g. [Core.Agent.Admin.SysConfig](Core.Agent.Admin.SysConfig.html), [Core.Agent.Admin.ProcessManagement](Core.Agent.Admin.ProcessManagement.html)).

For the Agent Interface Core.Agent it a good starting point, the main functions for the Customer Interface can be found in
the Core.Customer Namespace. For frontend-specific JavaScript have a look at the [Core.UI.*](Core.UI.html) Namespaces.