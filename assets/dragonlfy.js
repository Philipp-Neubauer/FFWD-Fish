(function() {
    "use strict";
    var $$menu$$section = 'none';

    var $$menu$$default = function() {
        var menu = $('.centered-navigation-menu');
        var menuToggle = $('.centered-navigation-menu-button');
        var wrapper = $('.centered-navigation-wrapper');

        $(menuToggle).on('click', function(e) {
            e.preventDefault();
            var current = wrapper.attr('data-section');
            if (current !== 'open') {
                wrapper.attr('data-section', 'open');
                $$menu$$section = current;
            } else {
                    wrapper.attr('data-section', $$menu$$section);
            }
            menu.slideToggle(function(){
                if(menu.is(':hidden')) {
                    menu.removeAttr('style');
                }
            });
        });
    };

    /* global $ */

    $(document).ready(function() {
        $$menu$$default();
    });
}).call(this);