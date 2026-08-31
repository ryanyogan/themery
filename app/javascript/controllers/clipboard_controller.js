import { Controller } from "@hotwired/stimulus"

// Click-to-copy: the whole element is the button; the hint confirms.
export default class extends Controller {
  static targets = ["source", "hint"]
  static classes = ["copied"]

  async copy() {
    const text = this.sourceTarget.textContent.replace(/^\s*❯\s*/, "").trim()
    await navigator.clipboard.writeText(text)
    this.element.classList.add(this.copiedClass)
    if (this.hasHintTarget) this.hintTarget.textContent = "copied ✓"
    clearTimeout(this.reset)
    this.reset = setTimeout(() => {
      this.element.classList.remove(this.copiedClass)
      if (this.hasHintTarget) this.hintTarget.textContent = "click to copy"
    }, 1800)
  }
}
