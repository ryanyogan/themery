import { Controller } from "@hotwired/stimulus"

// Light/dark toggle: three states worth of behavior with one bit of storage.
// No stored choice = follow the system; a click stores the opposite of
// whatever is currently showing.
export default class extends Controller {
  flip() {
    const root = document.documentElement
    const showingDark = root.dataset.theme
      ? root.dataset.theme === "dark"
      : matchMedia("(prefers-color-scheme: dark)").matches
    const next = showingDark ? "light" : "dark"
    root.dataset.theme = next
    try { localStorage.setItem("themery-scheme", next) } catch {}
  }
}
