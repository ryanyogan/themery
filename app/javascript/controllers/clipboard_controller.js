import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source"]
  static classes = ["copied"]

  async copy(event) {
    await navigator.clipboard.writeText(this.sourceTarget.textContent.trim())
    const button = event.currentTarget
    button.classList.add(this.copiedClass)
    const label = button.textContent
    button.textContent = "copied"
    setTimeout(() => { button.classList.remove(this.copiedClass); button.textContent = label }, 1600)
  }
}
