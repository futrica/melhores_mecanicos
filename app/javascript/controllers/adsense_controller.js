import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    try {
      (window.adsbygoogle = window.adsbygoogle || []).push({})
    } catch (e) {
      // Ignore if adsbygoogle is blocked or already pushed
    }
  }
}
