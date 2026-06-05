import app from "ags/gtk4/app"
import { Astal, Gtk, Gdk } from "ags/gtk4"
import cairo from "gi://cairo"
import { config } from "../config"

type Place = "tl" | "tr" | "bl" | "br"

const { TOP, BOTTOM, LEFT, RIGHT } = Astal.WindowAnchor
const ANCHOR: Record<Place, number> = {
  tl: TOP | LEFT,
  tr: TOP | RIGHT,
  bl: BOTTOM | LEFT,
  br: BOTTOM | RIGHT,
}

// Draw a single concave corner wedge: solid fill in the outer corner with a
// quarter-circle carved toward screen center (Aylur's RoundedCorner trick).
function drawCorner(place: Place, r: number, cr: any) {
  cr.setSourceRGBA(0.141, 0.141, 0.141, 1) // #242424, matches $bar-bg
  switch (place) {
    case "tl":
      cr.arc(r, r, r, Math.PI, 1.5 * Math.PI)
      cr.lineTo(0, 0)
      break
    case "tr":
      cr.arc(0, r, r, 1.5 * Math.PI, 2 * Math.PI)
      cr.lineTo(r, 0)
      break
    case "bl":
      cr.arc(r, 0, r, 0.5 * Math.PI, Math.PI)
      cr.lineTo(0, r)
      break
    case "br":
      cr.arc(0, 0, r, 0, 0.5 * Math.PI)
      cr.lineTo(r, r)
      break
  }
  cr.closePath()
  cr.fill()
}

function Corner(gdkmonitor: Gdk.Monitor, place: Place, r: number) {
  return (
    <window
      name={`corner-${place}`}
      namespace="screencorner"
      class="ScreenCorner"
      gdkmonitor={gdkmonitor}
      visible
      layer={Astal.Layer.OVERLAY}
      anchor={ANCHOR[place]}
      exclusivity={Astal.Exclusivity.NONE}
      application={app}
      // Click-through: empty input region so events pass to windows below.
      $={(self) =>
        self.connect("realize", () => self.get_surface()?.set_input_region(new cairo.Region()))
      }
    >
      <Gtk.DrawingArea
        widthRequest={r}
        heightRequest={r}
        $={(self) => self.set_draw_func((_a: any, cr: any) => drawCorner(place, r, cr))}
      />
    </window>
  )
}

// Four concave corners framing the monitor, matching the bar's rounding.
export default function ScreenCorners(gdkmonitor: Gdk.Monitor) {
  const r = config.screenCornerRadius
  if (r <= 0) return
  ;(["tl", "tr", "bl", "br"] as Place[]).forEach((p) => Corner(gdkmonitor, p, r))
}
