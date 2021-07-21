// --
// Copyright (C) 2006-2021 c.a.p.e. IT GmbH, https://www.cape-it.de
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
 * @exports TargetNS as Core.KIX4OTRS.ConfigItemZoomTabs
 * @description This namespace contains the special module functions for
 *              ConfigItemZoomTab.
 */
Core.KIX4OTRS.ConfigItemZoomTabs = (function(TargetNS) {

    /**
     * @function
     * @param {String}
     *            TicketID of ticket which get's shown
     * @return nothing Mark all articles as seen in frontend and backend.
     *         Article Filters will not be considered
     */
    TargetNS.ShowDialog = function() {
        Core.UI.Dialog.ShowContentDialog($('#CIImageDialog'), Core.Config.Get('SetImageText'), '20px', 'Center', true, [ {
            Label : Core.Config.Get('Submit'),
            Type : 'Submit',
        } ]);
    };

    /**
     * @function
     * @return nothing This function initializes the application and executes
     *         the needed functions the differenct to the global init function
     *         is the disabled InitNavigation call.
     */
    TargetNS.Init = function() {

        var Action = Core.Config.Get('Action');
        if ( Action.match(/AgentITSMConfigItemZoomTab/) ) {
            Core.UI.Popup.Init();
            Core.UI.InputFields.Init();

            // init widget toggle
            Core.UI.InitWidgetActionTabToggle();

            if ( !Action.match(/AgentITSMConfigItemZoomTabImages/) ) {
                return false;
            }
        }

        // open text dialog if new image inserted or open error dialog if
        // supported file is no image
        if ($('#CIImageFileUpload > input[name="ImageID"]').val() != '') {
            $('#CIImageDialog > input[name="ImageID"]').val($('#CIImageFileUpload > input[name="ImageID"]').val());
            Core.KIX4OTRS.ConfigItemZoomTabs.ShowDialog();
        } else if ($('#CIImageFileUpload > input[name="FileUploaded"]').val() == 1) {
            Core.UI.Dialog.ShowContentDialog($('#CIImageDialogWrongType'), Core.Config.Get('WrongType'), '150px', 'Center', true, [ {
                Type : 'Close',
                Label : 'OK',
                Function : function() {
                    Core.UI.Dialog.CloseDialog($('.Dialog:visible'));
                    Core.Form.EnableForm($('form[name="CIImageFileUpload"]'));
                    return false;
                }
            } ]);
        }

        // show preview
        $('.CIImageImage').on('click', function() {
            var that         = $(this);
            var imgContainer = $('#CIImageDialogPreviewImage');
            imgContainer.html('');
            that.find('img').clone().css('width', '').css('height', '').appendTo(imgContainer);
            var dialogImg = imgContainer.find('img');
            var width     = parseInt(window.innerWidth/100 * 90) + 'px';
            var height    = 'auto';

            if (dialogImg[0].width < dialogImg[0].height) {
                width  = 'auto';
                height = parseInt(window.innerHeight/100 * 80) + 'px';
            }
            imgContainer.find('img').css('width', width).css('height', height);
            $('#CIImageDialogPreviewText').html($('#Text_' + that.attr('id').split("_")[1]).html());

            Core.UI.Dialog.ShowContentDialog($('#CIImageDialogPreview'), Core.Config.Get('ImageDetails'), '20px', 'Center', true, []);
        });

        // resize images
        $('.CIImagePreview').find('img').each(function() {
            var Width, Height, NewWidth, NewHeight, $Image = $(this);

            $("<img/>").attr("src", $(this).attr("src")).on("load", function() {
                Width = this.width;
                Height = this.height;

                var Minimum = 200;
                if (Width < Height && Height > 200) {
                    NewWidth = Minimum;
                    NewHeight = NewWidth * Height / Width;
                } else if (Width > 200) {
                    NewHeight = Minimum;
                    NewWidth = NewHeight * Width / Height;
                } else {
                    NewHeight = Height;
                    NewWidth = Width;
                }

                // set new
                $Image.width(NewWidth).height(NewHeight);
            });

        });

        // close button
        $('.ActionMenu > .Close').on('click', function(event) {

            var URL = $(this).find('a').attr('href'), RegexpImageID = /\;ImageID\=(.*?)\;/, RegexpImageType = /\;ImageType\=(.*?)\;/, ImageID, ImageType;

            RegexpImageID.exec(URL);
            ImageID = RegExp.$1;
            RegexpImageType.exec(URL);
            ImageType = RegExp.$1;

            $('#CIImageDialogDelete > input[name="ImageID"]').val(ImageID);
            $('#CIImageDialogDelete > input[name="ImageType"]').val(ImageType);

            Core.UI.Dialog.ShowContentDialog($('#CIImageDialogDelete'), Core.Config.Get('DeleteImage'), '150px', 'Center', true, [ {
                Label : Core.Config.Get('Yes'),
                Type : 'Submit'
            }, {
                Type : 'Close',
                Label : Core.Config.Get('No'),
                Function : function() {
                    Core.UI.Dialog.CloseDialog($('.Dialog:visible'));
                    Core.Form.EnableForm($('form[name="compose"]'));
                    return false;
                }
            } ]);
            event.preventDefault();
        });

        // edit button
        $('.Settings').on('click', function(event) {

            var URL = $(this).find('a').attr('href'), RegexpImageID = /\;ImageID\=(.*?)\;/, ImageID;

            RegexpImageID.exec(URL);
            ImageID = RegExp.$1;

            $('#CIImageDialog > input[name="ImageID"]').val(ImageID);
            Core.KIX4OTRS.ConfigItemZoomTabs.ShowDialog();

            event.preventDefault();
        });

        // manage file upload
        $('#FileUpload').on('change', function() {
            var $Form = $('#FileUpload').closest('form');
            Core.Form.Validate.DisableValidation($Form);
            $Form.find('#AttachmentUpload').val('1').end().submit();
        });

        // edit image text
        $('.CIImageText').on('click', function() {
            var ImageID = $(this).attr('id').split("_")[1];

            $('#ImageNote').html($('#Text_' + ImageID).html());
            $('#CIImageDialog > input[name="ImageID"]').val(ImageID);
            Core.KIX4OTRS.ConfigItemZoomTabs.ShowDialog();
        });

    };

    return TargetNS;
}(Core.KIX4OTRS.ConfigItemZoomTabs || {}));
