import Toybox.Activity;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class GarminAppBackyardView extends WatchUi.DataField {

    function initialize() {
        DataField.initialize();
    }

    function compute(info as Activity.Info) as Void {
        // Logique de calcul Backyard Ultra
    }

    function onUpdate(dc as Dc) as Void {
        var bgColor = Graphics.COLOR_WHITE;
        var fgColor = Graphics.COLOR_BLACK;

        dc.setColor(bgColor, bgColor);
        dc.clear();

        dc.setColor(fgColor, Graphics.COLOR_TRANSPARENT);
        var width = dc.getWidth();
        var height = dc.getHeight();

        dc.drawText(
            width / 2,
            height / 2,
            Graphics.FONT_LARGE,
            "Backyard",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }

}
