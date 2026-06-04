import { Gtk } from "ags/gtk4"
import { createState, For } from "ags"
import { execAsync } from "ags/process"

// Clipboard history via cliphist. Click the icon to open the list; click an
// entry to copy it back (wl-copy). Clear wipes history.
export function Clipboard() {
  const [items, setItems] = createState<{ id: string; preview: string }[]>([])
  let pop: Gtk.Popover | null = null

  const load = () =>
    execAsync(["bash", "-c", "cliphist list"])
      .then((out) => {
        setItems(
          out
            .split("\n")
            .filter(Boolean)
            .slice(0, 50)
            .map((line) => {
              const tab = line.indexOf("\t")
              return tab < 0
                ? { id: line, preview: line }
                : { id: line.slice(0, tab), preview: line.slice(tab + 1) }
            }),
        )
      })
      .catch(() => setItems([]))

  const copy = (id: string) => {
    // id is numeric; safe to interpolate. decode reads the id from stdin.
    execAsync(["bash", "-c", `printf '%s' ${id} | cliphist decode | wl-copy`]).catch(() => {})
    pop?.popdown()
  }

  return (
    <menubutton class="clipboard">
      <image iconName="edit-paste-symbolic" pixelSize={16} />
      <popover
        class="clipboard-popover"
        $={(self) => {
          pop = self
          self.connect("notify::visible", () => {
            if (self.visible) load()
          })
        }}
      >
        <box class="clip-panel" orientation={Gtk.Orientation.VERTICAL}>
          <box class="clip-header">
            <label label="Clipboard" hexpand halign={Gtk.Align.START} />
            <button
              class="clip-clear"
              onClicked={() =>
                execAsync(["bash", "-c", "cliphist wipe"]).then(load).catch(() => {})
              }
            >
              <label label="Clear" />
            </button>
          </box>

          <Gtk.ScrolledWindow heightRequest={380} hscrollbarPolicy={Gtk.PolicyType.NEVER}>
            <box class="clip-list" orientation={Gtk.Orientation.VERTICAL} spacing={10}>
              <label
                class="clip-empty"
                label="Empty"
                visible={items((i) => i.length === 0)}
              />
              <For each={items}>
                {(it: { id: string; preview: string }) => (
                  <button class="clip-item" onClicked={() => copy(it.id)}>
                    <label
                      label={it.preview}
                      xalign={0}
                      halign={Gtk.Align.START}
                      ellipsize={3 /* END */}
                      maxWidthChars={46}
                    />
                  </button>
                )}
              </For>
            </box>
          </Gtk.ScrolledWindow>
        </box>
      </popover>
    </menubutton>
  )
}
