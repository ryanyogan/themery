import { Controller } from "@hotwired/stimulus"

// Search-as-you-type for the catalog. The input lives OUTSIDE the results
// frame so it never re-renders under the user's fingers; each debounced
// keystroke points the frame at the current URL with the new query, and the
// frame's data-turbo-action="advance" keeps the address bar honest.
// Ctrl-K (or /) focuses it from anywhere.
export default class extends Controller {
  static targets = ["input"]
  static values = { frame: String, delay: { type: Number, default: 250 } }

  connect() {
    this.keydown = (event) => {
      const typing = /^(INPUT|TEXTAREA|SELECT)$/.test(document.activeElement?.tagName)
      const ctrlK = (event.ctrlKey || event.metaKey) && event.key.toLowerCase() === "k"
      if (!ctrlK && !(event.key === "/" && !typing)) return
      event.preventDefault()
      this.inputTarget.focus()
      this.inputTarget.select()
    }
    document.addEventListener("keydown", this.keydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.keydown)
    clearTimeout(this.debounce)
  }

  search() {
    clearTimeout(this.debounce)
    this.debounce = setTimeout(() => this.navigate(), this.delayValue)
  }

  submit(event) {
    event.preventDefault()
    clearTimeout(this.debounce)
    this.navigate()
  }

  navigate() {
    const frame = document.getElementById(this.frameValue)
    if (!frame) return
    const url = new URL(window.location.href)
    const query = this.inputTarget.value.trim()
    query ? url.searchParams.set("q", query) : url.searchParams.delete("q")
    frame.src = url
  }
}
