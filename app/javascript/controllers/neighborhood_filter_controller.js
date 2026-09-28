import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "dropdown",
    "selectBtn",
    "countBadge",
    "searchInput",
    "checkboxList"
  ]

  connect() {
    this.closeOutsideHandler = this.closeOutside.bind(this)
    document.addEventListener("click", this.closeOutsideHandler)
    this.updateDisplay()
    this.reorderCheckboxes()
  }

  disconnect() {
    if (this.closeOutsideHandler) {
      document.removeEventListener("click", this.closeOutsideHandler)
    }
  }

  toggleDropdown(event) {
    if (event && typeof event.stopPropagation === "function") {
      event.stopPropagation()
    }
    if (this.hasDropdownTarget) {
      this.dropdownTarget.classList.toggle("active")
      if (this.dropdownTarget.classList.contains("active") && this.hasSearchInputTarget) {
        this.searchInputTarget.focus()
        this.searchInputTarget.value = ""
        this.filterList()
      }
    }
  }

  closeOutside(event) {
    if (this.hasDropdownTarget && !this.element.contains(event.target)) {
      this.dropdownTarget.classList.remove("active")
    }
  }

  filterList() {
    if (!this.hasSearchInputTarget || !this.hasCheckboxListTarget) return

    const query = this.searchInputTarget.value
      .toLowerCase()
      .normalize("NFD")
      .replace(/[\u0300-\u036f]/g, "")
      
    const labels = this.checkboxListTarget.querySelectorAll(".city-checkbox-label")
    
    labels.forEach(label => {
      const name = (label.dataset.neighborhoodName || "")
        .toLowerCase()
        .normalize("NFD")
        .replace(/[\u0300-\u036f]/g, "")
      
      if (name.includes(query)) {
        label.style.display = "flex"
      } else {
        label.style.display = "none"
      }
    })
  }

  itemToggled() {
    this.updateDisplay()
    this.reorderCheckboxes()
  }

  updateDisplay() {
    if (!this.hasCheckboxListTarget || !this.hasSelectBtnTarget) return

    const checkedBoxes = this.checkboxListTarget.querySelectorAll("input[type='checkbox']:checked")
    const count = checkedBoxes.length

    if (count === 0) {
      this.selectBtnTarget.innerText = "Selecionar bairros..."
      if (this.hasCountBadgeTarget) {
        this.countBadgeTarget.style.display = "none"
        this.countBadgeTarget.innerText = "0"
      }
    } else if (count === 1) {
      const nameSpan = checkedBoxes[0].nextElementSibling
      this.selectBtnTarget.innerText = nameSpan ? nameSpan.innerText : "1 bairro"
      if (this.hasCountBadgeTarget) {
        this.countBadgeTarget.style.display = "inline-flex"
        this.countBadgeTarget.innerText = "1"
      }
    } else {
      this.selectBtnTarget.innerText = `${count} bairros selecionados`
      if (this.hasCountBadgeTarget) {
        this.countBadgeTarget.style.display = "inline-flex"
        this.countBadgeTarget.innerText = count.toString()
      }
    }
  }

  reorderCheckboxes() {
    if (!this.hasCheckboxListTarget) return

    const labels = Array.from(this.checkboxListTarget.querySelectorAll(".city-checkbox-label"))
    const checkedLabels = labels.filter(l => {
      const input = l.querySelector("input[type='checkbox']")
      return input && input.checked
    })
    const uncheckedLabels = labels.filter(l => {
      const input = l.querySelector("input[type='checkbox']")
      return input && !input.checked
    })

    const sortNeighborhoodNames = (aStr, bStr) => {
      const isNumA = /^\d/.test(aStr)
      const isNumB = /^\d/.test(bStr)
      if (isNumA !== isNumB) {
        return isNumA ? 1 : -1
      }
      return aStr.localeCompare(bStr)
    }

    // Sort unchecked placing names starting with numbers last
    uncheckedLabels.sort((a, b) => {
      const nameA = (a.dataset.neighborhoodName || "").toLowerCase()
      const nameB = (b.dataset.neighborhoodName || "").toLowerCase()
      return sortNeighborhoodNames(nameA, nameB)
    })

    // Sort checked placing names starting with numbers last
    checkedLabels.sort((a, b) => {
      const nameA = (a.dataset.neighborhoodName || "").toLowerCase()
      const nameB = (b.dataset.neighborhoodName || "").toLowerCase()
      return sortNeighborhoodNames(nameA, nameB)
    })

    this.checkboxListTarget.innerHTML = ""

    if (checkedLabels.length > 0) {
      const sectionTitle = document.createElement("div")
      sectionTitle.className = "checkbox-section-title"
      sectionTitle.innerText = "Selecionados"
      sectionTitle.style = "padding: 0.4rem 0.8rem; font-weight: 800; font-size: 0.78rem; color: var(--orange); text-transform: uppercase; border-bottom: 1px dashed var(--orange); margin-bottom: 0.4rem; width: 100%;"
      this.checkboxListTarget.appendChild(sectionTitle)

      checkedLabels.forEach(l => {
        l.style.display = "flex"
        this.checkboxListTarget.appendChild(l)
      })

      const divider = document.createElement("div")
      divider.style = "border-bottom: 1px solid var(--bg-tertiary); margin: 0.4rem 0; width: 100%;"
      this.checkboxListTarget.appendChild(divider)
    }

    if (uncheckedLabels.length > 0) {
      uncheckedLabels.forEach(l => this.checkboxListTarget.appendChild(l))
    }
  }
}
