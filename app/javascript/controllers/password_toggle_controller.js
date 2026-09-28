import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "eyeOpen", "eyeClosed"]

  connect() {
    this.visible = false
    this.updateVisibility()
  }

  toggle(event) {
    if (event) event.preventDefault()
    this.visible = !this.visible
    this.updateVisibility()
  }

  updateVisibility() {
    if (!this.hasInputTarget) return

    const btn = this.element.querySelector(".auth-password-toggle-btn")

    if (this.visible) {
      this.inputTarget.type = "text"
      if (this.hasEyeOpenTarget) this.eyeOpenTarget.style.display = "none"
      if (this.hasEyeClosedTarget) this.eyeClosedTarget.style.display = "block"
      if (btn) {
        btn.setAttribute("aria-label", "Ocultar senha")
        btn.setAttribute("title", "Ocultar senha")
      }
    } else {
      this.inputTarget.type = "password"
      if (this.hasEyeOpenTarget) this.eyeOpenTarget.style.display = "block"
      if (this.hasEyeClosedTarget) this.eyeClosedTarget.style.display = "none"
      if (btn) {
        btn.setAttribute("aria-label", "Mostrar senha")
        btn.setAttribute("title", "Mostrar senha")
      }
    }
  }
}
