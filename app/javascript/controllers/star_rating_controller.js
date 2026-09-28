import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "star", "label"]

  static labels = {
    1: "1 / 5 - Ruim 🙁",
    2: "2 / 5 - Razoável 😐",
    3: "3 / 5 - Bom 🙂",
    4: "4 / 5 - Muito Bom 😊",
    5: "5 / 5 - Excelente! ⭐"
  }

  connect() {
    this.updateDisplay()
  }

  change() {
    this.updateDisplay()
  }

  hover(event) {
    const hoverVal = parseInt(event.currentTarget.dataset.rating, 10)
    this.highlightStars(hoverVal)
    if (this.hasLabelTarget && this.constructor.labels[hoverVal]) {
      this.labelTarget.textContent = this.constructor.labels[hoverVal]
    }
  }

  reset() {
    this.updateDisplay()
  }

  updateDisplay() {
    const checked = this.inputTargets.find(input => input.checked)
    const val = checked ? parseInt(checked.value, 10) : 0
    this.highlightStars(val)

    if (this.hasLabelTarget) {
      if (val > 0 && this.constructor.labels[val]) {
        this.labelTarget.textContent = this.constructor.labels[val]
      } else {
        this.labelTarget.textContent = "Clique para escolher de 1 a 5 estrelas"
      }
    }
  }

  highlightStars(rating) {
    this.starTargets.forEach(star => {
      const starRating = parseInt(star.dataset.rating, 10)
      if (starRating <= rating) {
        star.classList.add("text-amber-400")
        star.classList.remove("text-slate-300")
      } else {
        star.classList.remove("text-amber-400")
        star.classList.add("text-slate-300")
      }
    })
  }
}
