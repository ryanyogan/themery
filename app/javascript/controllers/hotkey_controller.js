import { Controller } from "@hotwired/stimulus"

// Ctrl-K (or /) jumps to the catalog search from anywhere on the page.
export default class extends Controller {
  static targets = ["input"]

  connect() {
    this.keydown = (event) => {
      const typing = /^(INPUT|TEXTAREA|SELECT)$/.test(document.activeElement?.tagName)
      const ctrlK = (event.ctrlKey || event.metaKey) && event.key.toLowerCase() === "k"
      const slash = event.key === "/" && !typing
      if (!ctrlK && !slash) return
      event.preventDefault()
      this.inputTarget.focus()
      this.inputTarget.select()
    }
    document.addEventListener("keydown", this.keydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.keydown)
  }
}
