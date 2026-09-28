import { Controller } from "@hotwired/stimulus"

const DISCLAIMER_STORAGE_KEY = "hd_contact_disclaimer_accepted"
let pendingRevealBtn = null

function sendRevealLog(btn) {
  if (!btn) return
  const companyId = btn.getAttribute("data-company-id")
  const contactType = btn.getAttribute("data-type") || "unknown"
  if (!companyId) return

  fetch(`/companies/${companyId}/reveal_contact`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.getAttribute("content") || ""
    },
    body: JSON.stringify({ contact_type: contactType })
  }).catch(err => console.error("Error logging contact reveal:", err))
}

function performReveal(btn) {
  if (!btn) return

  const full = (btn.getAttribute("data-full") || "").trim()
  const targetId = btn.getAttribute("data-target")
  const type = btn.getAttribute("data-type")
  const isWhatsapp = btn.getAttribute("data-whatsapp") === "true"

  let targetEl = null
  if (targetId) {
    targetEl = document.getElementById(targetId)
  }
  if (!targetEl) {
    targetEl = btn.previousElementSibling || (btn.parentElement ? btn.parentElement.querySelector(".masked-text") : null)
  }

  if (!targetEl || !full) return

  if (type === "phone") {
    const cleanDigits = full.replace(/\D/g, "")
    let waNumber = cleanDigits
    let localDigits = cleanDigits

    if (cleanDigits.startsWith("55") && cleanDigits.length >= 12) {
      waNumber = cleanDigits
      localDigits = cleanDigits.slice(2)
    } else {
      waNumber = "55" + cleanDigits
    }

    let formattedPhone = full
    if (localDigits.length === 11) {
      formattedPhone = `(${localDigits.slice(0, 2)}) ${localDigits.slice(2, 7)}-${localDigits.slice(7)}`
    } else if (localDigits.length === 10) {
      formattedPhone = `(${localDigits.slice(0, 2)}) ${localDigits.slice(2, 6)}-${localDigits.slice(6)}`
    }

    const companyName = btn.getAttribute("data-company-name") || ""
    const customMsg = btn.getAttribute("data-message") || (companyName ? `Olá! Vi o perfil de ${companyName} no site Hospedagem Direta e gostaria de informações sobre disponibilidade e reservas.` : "Olá! Vi seu contato no site Hospedagem Direta e gostaria de informações sobre disponibilidade e reservas.")
    const encodedText = encodeURIComponent(customMsg)

    if (isWhatsapp) {
      targetEl.innerHTML = `<a href="https://wa.me/${waNumber}?text=${encodedText}" target="_blank" rel="noopener" style="color: #25D366; font-weight: 700; text-decoration: none;">${formattedPhone} 💬</a>`
    } else {
      targetEl.innerHTML = `<a href="tel:${cleanDigits}" style="color: var(--navy, #1e293b); font-weight: 700;">${formattedPhone}</a>`
    }
  } else if (type === "email") {
    targetEl.innerHTML = `<a href="mailto:${full}" class="company-email-link" style="font-weight: 700;">${full}</a>`
  }

  btn.remove()
  sendRevealLog(btn)
}

function handleRevealClick(btn) {
  if (!btn) return

  const alreadyAccepted = localStorage.getItem(DISCLAIMER_STORAGE_KEY) === "true"
  if (alreadyAccepted) {
    performReveal(btn)
  } else {
    pendingRevealBtn = btn
    const modal = document.getElementById("contact-disclaimer-modal")
    if (modal) {
      modal.classList.remove("hidden")
    } else {
      // Fallback if modal is not present
      performReveal(btn)
    }
  }
}

function setupDisclaimerModalListeners() {
  if (typeof window === "undefined" || window.__disclaimerListenersBound) return
  window.__disclaimerListenersBound = true

  document.addEventListener("click", function(e) {
    const acceptBtn = e.target.closest("#btn-accept-disclaimer")
    if (acceptBtn) {
      e.preventDefault()
      localStorage.setItem(DISCLAIMER_STORAGE_KEY, "true")
      const modal = document.getElementById("contact-disclaimer-modal")
      if (modal) modal.classList.add("hidden")

      if (pendingRevealBtn) {
        performReveal(pendingRevealBtn)
        pendingRevealBtn = null
      }
      return
    }

    const cancelBtn = e.target.closest("#btn-cancel-disclaimer, #btn-close-disclaimer")
    if (cancelBtn) {
      e.preventDefault()
      const modal = document.getElementById("contact-disclaimer-modal")
      if (modal) modal.classList.add("hidden")
      pendingRevealBtn = null
      return
    }
  })
}

// Global click event delegation for maximum robustness across Turbo & dynamic page renders
if (typeof window !== "undefined" && !window.__globalContactRevealBound) {
  window.__globalContactRevealBound = true
  setupDisclaimerModalListeners()

  document.addEventListener("click", function(e) {
    const btn = e.target.closest(".btn-reveal-contact")
    if (!btn) return

    e.preventDefault()
    e.stopPropagation()
    handleRevealClick(btn)
  })
}

export default class extends Controller {
  connect() {
    setupDisclaimerModalListeners()
  }

  reveal(event) {
    if (event) {
      event.preventDefault()
      event.stopPropagation()
    }
    const btn = event ? event.currentTarget : this.element
    handleRevealClick(btn)
  }
}
