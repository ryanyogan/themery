import { Controller } from "@hotwired/stimulus"

// The wallpaper strip under the hero preview: clicking a thumb re-dresses
// the mock desktop in that background.
export default class extends Controller {
  swap(event) {
    const wallpaper = this.element.querySelector(".preview__wallpaper")
    if (wallpaper) wallpaper.style.backgroundImage = `url(${event.params.url})`
    this.element.querySelectorAll(".clips__thumb").forEach((thumb) =>
      thumb.classList.toggle("is-active", thumb === event.currentTarget))
  }
}
