import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["links"]

  toggle() {
    if (!this.hasLinksTarget) return

    // Toggle 'active' class (used by app layout CSS)
    this.linksTarget.classList.toggle("active")

    // Handle Tailwind 'hidden' class toggle (used by application.html.erb layout)
    if (this.linksTarget.classList.contains("hidden")) {
      this.linksTarget.classList.remove("hidden")
      this.linksTarget.dataset.mobileOpened = "true"
    } else if (this.linksTarget.dataset.mobileOpened === "true") {
      this.linksTarget.classList.add("hidden")
      delete this.linksTarget.dataset.mobileOpened
    }

    const btn = this.element.querySelector(".hamburger-btn") || this.element.querySelector("button[data-action*='menu#toggle']")
    if (btn) {
      btn.classList.toggle("active")
    }
  }
}

