import { Controller } from "@hotwired/stimulus"

// The detail-page hero: opens on the theme visual; the clips strip swaps in
// screenshots and wallpapers, and the first thumb brings the visual back.
export default class extends Controller {
  static targets = ["image", "generated"]

  show(event) {
    this.imageTarget.src = event.params.url
    this.imageTarget.hidden = false
    this.generatedTarget.hidden = true
    this.activate(event.currentTarget)
  }

  showGenerated(event) {
    this.imageTarget.hidden = true
    this.generatedTarget.hidden = false
    this.activate(event.currentTarget)
  }

  activate(active) {
    this.element.querySelectorAll(".clips__thumb").forEach((thumb) =>
      thumb.classList.toggle("is-active", thumb === active))
  }
}
