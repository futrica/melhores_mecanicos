import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "stateInput",
    "stateSelectBtn",
    "stateDropdown",
    "stateSearch",
    "stateList",
    "cityInput",
    "citySelectBtn",
    "cityDropdown",
    "citySearch",
    "cityList",
    "neighborhoodSelectBtn",
    "neighborhoodDropdown",
    "neighborhoodSearch",
    "neighborhoodList",
    "neighborhoodCount",
    "categoryInput",
    "stateRequiredModal"
  ]

  static values = {
    defaultCityId: String,
    initialStateId: String,
    initialCityId: String,
    initialNeighborhoodId: String
  }

  connect() {
    const urlParams = new URLSearchParams(window.location.search);
    let stateId = (this.hasStateInputTarget && this.stateInputTarget.value) || urlParams.get("state_id") || (this.hasInitialStateIdValue ? this.initialStateIdValue : "");

    if (stateId) {
      if (this.hasStateInputTarget) {
        this.stateInputTarget.value = stateId;
      }
      const selectedOption = this.element.querySelector(`.state-option[data-id="${stateId}"]`);
      if (selectedOption) {
        this.stateSelectBtnTarget.innerText = selectedOption.dataset.name;
      }

      this.fetchCities(stateId).then(() => {
        let cityId = (this.hasCityInputTarget && this.cityInputTarget.value) || urlParams.get("city_id") || urlParams.get("city_ids[]") || (this.hasInitialCityIdValue ? this.initialCityIdValue : "");
        if (!cityId && this.hasDefaultCityIdValue && this.defaultCityIdValue) {
          cityId = this.defaultCityIdValue;
        }

        if (cityId) {
          if (this.hasCityInputTarget) {
            this.cityInputTarget.value = cityId;
          }
          const selectedCityOption = this.cityListTarget.querySelector(`.city-option[data-id="${cityId}"]`);
          if (selectedCityOption) {
            this.citySelectBtnTarget.innerText = selectedCityOption.dataset.name;
          }

          this.fetchNeighborhoods().then(() => {
            let neighborhoodIds = urlParams.getAll("neighborhood_ids[]");
            if (neighborhoodIds.length === 0 && urlParams.get("neighborhood_id")) {
              neighborhoodIds = [urlParams.get("neighborhood_id")];
            } else if (neighborhoodIds.length === 0 && this.hasInitialNeighborhoodIdValue && this.initialNeighborhoodIdValue) {
              neighborhoodIds = this.initialNeighborhoodIdValue.split(",").map(id => id.trim()).filter(Boolean);
            }

            if (neighborhoodIds.length > 0) {
              neighborhoodIds.forEach(id => {
                const checkbox = this.neighborhoodListTarget.querySelector(`input[value="${id}"]`);
                if (checkbox) checkbox.checked = true;
              });
              this.updateSelectedNeighborhoodsDisplay();
            }
          });
        }
      });
    }
    
    // Close dropdowns when clicking outside
    this.closeDropdownsOutsideHandler = this.closeDropdownsOutside.bind(this);
    document.addEventListener("click", this.closeDropdownsOutsideHandler);

    this.handleKeyDown = (event) => {
      if (event.key === "Escape" && this.hasStateRequiredModalTarget && this.stateRequiredModalTarget.style.display === "flex") {
        this.closeStateRequiredModal();
      }
    };
    document.addEventListener("keydown", this.handleKeyDown);
  }

  disconnect() {
    if (this.closeDropdownsOutsideHandler) {
      document.removeEventListener("click", this.closeDropdownsOutsideHandler);
    }
    if (this.handleKeyDown) {
      document.removeEventListener("keydown", this.handleKeyDown);
    }
  }

  handleSubmit(event) {
    if (!this.stateInputTarget.value) {
      event.preventDefault();
      this.openStateRequiredModal();
    }
  }

  openStateRequiredModal() {
    if (this.hasStateRequiredModalTarget) {
      this.stateRequiredModalTarget.style.display = "flex";
      document.body.style.overflow = "hidden";
    }
  }

  closeStateRequiredModal() {
    if (this.hasStateRequiredModalTarget) {
      this.stateRequiredModalTarget.style.display = "none";
      document.body.style.overflow = "";
    }
  }

  closeStateRequiredModalOnOverlay(event) {
    if (event.target === this.stateRequiredModalTarget) {
      this.closeStateRequiredModal();
    }
  }

  openStateSelectFromModal(event) {
    this.closeStateRequiredModal();
    this.toggleStateDropdown(event);
  }

  // Toggles the state single-select dropdown
  toggleStateDropdown(event) {
    if (event && typeof event.stopPropagation === "function") {
      event.stopPropagation();
    }
    this.closeAllDropdownsExcept(this.stateDropdownTarget);
    if (this.hasStateDropdownTarget) {
      this.stateDropdownTarget.classList.toggle("active");
      if (this.stateDropdownTarget.classList.contains("active") && this.hasStateSearchTarget) {
        this.stateSearchTarget.focus();
        this.stateSearchTarget.value = "";
        this.filterStates();
      }
    }
  }

  // Action for choosing a state
  selectState(event) {
    event.stopPropagation();
    const option = event.currentTarget;
    const id = option.dataset.id;
    const name = option.dataset.name;

    this.stateInputTarget.value = id;
    this.stateSelectBtnTarget.innerText = name;
    
    if (this.hasStateDropdownTarget) {
      this.stateDropdownTarget.classList.remove("active");
    }

    this.stateChanged(id);
  }

  // Filter states list in the dropdown
  filterStates() {
    const query = this.stateSearchTarget.value.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "");
    const options = this.stateListTarget.querySelectorAll(".state-option");
    
    options.forEach(option => {
      const stateName = option.dataset.name.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "");
      if (stateName.includes(query)) {
        option.style.display = "block";
      } else {
        option.style.display = "none";
      }
    });
  }

  // Toggles the cities dropdown list
  toggleCityDropdown(event) {
    event.stopPropagation();
    this.closeAllDropdownsExcept(this.cityDropdownTarget);
    if (this.hasCityDropdownTarget) {
      this.cityDropdownTarget.classList.toggle("active");
      if (this.cityDropdownTarget.classList.contains("active") && this.hasCitySearchTarget) {
        this.citySearchTarget.focus();
      }
    }
  }

  // Toggles the neighborhoods dropdown list
  toggleNeighborhoodDropdown(event) {
    event.stopPropagation();
    this.closeAllDropdownsExcept(this.neighborhoodDropdownTarget);
    if (this.hasNeighborhoodDropdownTarget) {
      this.neighborhoodDropdownTarget.classList.toggle("active");
      if (this.neighborhoodDropdownTarget.classList.contains("active") && this.hasNeighborhoodSearchTarget) {
        this.neighborhoodSearchTarget.focus();
      }
    }
  }

  // Handles state changes and fetches cities
  stateChanged(stateId) {
    if (stateId) {
      this.fetchCities(stateId);
    } else {
      this.clearCities();
      this.clearNeighborhoods();
    }
  }

  // Fetch cities via API
  async fetchCities(stateId) {
    try {
      const response = await fetch(`/api/cities?state_id=${stateId}`);
      const cities = await response.json();
      this.renderCitiesList(cities);
      this.clearNeighborhoods();
    } catch (error) {
      console.error("Error fetching cities:", error);
    }
  }

  // Render options for cities (single select)
  renderCitiesList(cities) {
    if (!this.hasCityListTarget) return;

    if (cities.length === 0) {
      this.cityListTarget.innerHTML = `<div class="px-3 py-2 text-xs text-slate-500 italic text-center">Nenhuma cidade encontrada</div>`;
      this.citySelectBtnTarget.disabled = true;
      this.citySelectBtnTarget.innerText = "Nenhuma cidade disponível";
      return;
    }

    this.citySelectBtnTarget.disabled = false;
    this.citySelectBtnTarget.innerText = "Selecionar cidade...";

    let html = "";
    cities.forEach(city => {
      html += `
        <div class="city-option px-3 py-2 text-xs font-semibold text-slate-700 hover:bg-blue-50 hover:text-blue-900 cursor-pointer rounded-lg transition-colors" data-id="${city.id}" data-name="${city.name}" data-action="click->search-form#selectCity">
          ${city.name}
        </div>
      `;
    });
    this.cityListTarget.innerHTML = html;
  }

  // Action for choosing a city
  selectCity(event) {
    event.stopPropagation();
    const option = event.currentTarget;
    const id = option.dataset.id;
    const name = option.dataset.name;

    if (this.hasCityInputTarget) {
      this.cityInputTarget.value = id;
    }
    this.citySelectBtnTarget.innerText = name;
    
    if (this.hasCityDropdownTarget) {
      this.cityDropdownTarget.classList.remove("active");
    }

    this.fetchNeighborhoods();
  }

  // Search/Filter cities in the list
  filterCities() {
    const query = this.citySearchTarget.value.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "");
    const options = this.cityListTarget.querySelectorAll(".city-option");
    
    options.forEach(option => {
      const cityName = option.dataset.name.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "");
      if (cityName.includes(query)) {
        option.style.display = "block";
      } else {
        option.style.display = "none";
      }
    });
  }

  // Fetch neighborhoods based on selected single city
  async fetchNeighborhoods() {
    const cityId = this.hasCityInputTarget ? this.cityInputTarget.value : "";
    
    if (!cityId) {
      this.clearNeighborhoods();
      return;
    }

    try {
      const response = await fetch(`/api/neighborhoods?city_ids[]=${cityId}`);
      const neighborhoods = await response.json();
      this.renderNeighborhoodsList(neighborhoods);
    } catch (error) {
      console.error("Error fetching neighborhoods:", error);
    }
  }

  // Render checkboxes for neighborhoods
  renderNeighborhoodsList(neighborhoods) {
    if (!this.hasNeighborhoodListTarget) return;

    if (neighborhoods.length === 0) {
      this.neighborhoodListTarget.innerHTML = `<div class="px-3 py-2 text-xs text-slate-500 italic text-center">Nenhum bairro encontrado</div>`;
      this.neighborhoodSelectBtnTarget.disabled = true;
      this.neighborhoodSelectBtnTarget.innerText = "Nenhum bairro disponível";
      return;
    }

    this.neighborhoodSelectBtnTarget.disabled = false;
    this.neighborhoodSelectBtnTarget.innerText = "Selecionar bairros...";
    this.neighborhoodCountTarget.style.display = "none";
    this.neighborhoodCountTarget.innerText = "";
    
    let html = "";
    neighborhoods.forEach(n => {
      html += `
        <label class="city-checkbox-label flex items-center gap-2 px-3 py-2 text-xs font-semibold text-slate-700 hover:bg-blue-50 hover:text-blue-900 rounded-lg cursor-pointer transition-colors" data-neighborhood-name="${n.name.toLowerCase()}" data-city-name="${n.city_name}">
          <input type="checkbox" name="neighborhood_ids[]" value="${n.id}" class="w-4 h-4 text-blue-600 rounded border-slate-300 focus:ring-blue-500 cursor-pointer" data-action="change->search-form#neighborhoodToggled">
          <span>${n.name}</span>
        </label>
      `;
    });
    this.neighborhoodListTarget.innerHTML = html;
    this.reorderCheckboxes(this.neighborhoodListTarget, "neighborhood");
  }

  // Search/Filter neighborhoods in the list
  filterNeighborhoods() {
    const query = this.neighborhoodSearchTarget.value.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "");
    const labels = this.neighborhoodListTarget.querySelectorAll(".city-checkbox-label");
    
    labels.forEach(label => {
      const nName = label.dataset.neighborhoodName.normalize("NFD").replace(/[\u0300-\u036f]/g, "");
      const cName = (label.dataset.cityName || "").toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "");
      if (nName.includes(query) || cName.includes(query)) {
        label.style.display = "flex";
      } else {
        label.style.display = "none";
      }
    });
  }

  // Event handler for neighborhood checkbox toggle
  neighborhoodToggled() {
    this.updateSelectedNeighborhoodsDisplay();
    this.reorderCheckboxes(this.neighborhoodListTarget, "neighborhood");
  }

  // Update button text and selected neighborhoods count badge
  updateSelectedNeighborhoodsDisplay() {
    const checkedCheckboxes = this.neighborhoodListTarget.querySelectorAll("input[type='checkbox']:checked");
    const count = checkedCheckboxes.length;
    
    if (count === 0) {
      this.neighborhoodSelectBtnTarget.innerText = "Selecionar bairros...";
      this.neighborhoodCountTarget.style.display = "none";
      this.neighborhoodCountTarget.innerText = "";
    } else if (count === 1) {
      const nName = checkedCheckboxes[0].nextElementSibling.innerText;
      this.neighborhoodSelectBtnTarget.innerText = nName;
      this.neighborhoodCountTarget.style.display = "inline-flex";
      this.neighborhoodCountTarget.innerText = "1";
    } else {
      this.neighborhoodSelectBtnTarget.innerText = `${count} bairros`;
      this.neighborhoodCountTarget.style.display = "inline-flex";
      this.neighborhoodCountTarget.innerText = count.toString();
    }
  }

  // Reorder checkbox list to put checked ones at the top
  reorderCheckboxes(container, type = "city") {
    const labels = Array.from(container.querySelectorAll(".city-checkbox-label"));
    const checkedLabels = labels.filter(l => l.querySelector("input").checked);
    const uncheckedLabels = labels.filter(l => !l.querySelector("input").checked);

    container.innerHTML = "";

    // 1. Render checked items at the top
    if (checkedLabels.length > 0) {
      const sectionTitle = document.createElement("div");
      sectionTitle.className = "checkbox-section-title px-3 py-1 text-[11px] font-extrabold text-blue-600 uppercase tracking-wider border-b border-blue-100 mb-1 w-full flex items-center gap-1";
      sectionTitle.innerText = "✓ Selecionados";
      container.appendChild(sectionTitle);
      
      checkedLabels.forEach(l => {
        l.style.display = "flex"; // Ensure it is visible if it was filtered out
        container.appendChild(l);
      });
      
      const divider = document.createElement("div");
      divider.className = "border-b border-slate-100 my-1.5 w-full";
      container.appendChild(divider);
    }

    // 2. Render unchecked items below
    if (uncheckedLabels.length > 0) {
      if (type === "neighborhood") {
        // Sort unchecked list by city name first, then by neighborhood name (numbers last)
        uncheckedLabels.sort((a, b) => {
          const cityA = a.dataset.cityName || "";
          const cityB = b.dataset.cityName || "";
          const nameA = a.dataset.neighborhoodName || "";
          const nameB = b.dataset.neighborhoodName || "";
          
          const compCity = cityA.localeCompare(cityB);
          if (compCity !== 0) return compCity;

          const isNumA = /^\d/.test(nameA);
          const isNumB = /^\d/.test(nameB);
          if (isNumA !== isNumB) {
            return isNumA ? 1 : -1;
          }
          return nameA.localeCompare(nameB);
        });

        let currentCity = "";
        uncheckedLabels.forEach(label => {
          const cityName = label.dataset.cityName;
          if (cityName !== currentCity) {
            currentCity = cityName;
            const groupHeader = document.createElement("div");
            groupHeader.className = "city-group-title px-3 py-1 text-[11px] font-bold text-slate-500 uppercase tracking-wider bg-slate-100/80 rounded-md my-1 w-full";
            groupHeader.innerText = cityName.toUpperCase();
            container.appendChild(groupHeader);
          }
          container.appendChild(label);
        });
      } else {
        // Simple alphabetical sort for cities
        uncheckedLabels.sort((a, b) => {
          const nameA = a.textContent.trim();
          const nameB = b.textContent.trim();
          return nameA.localeCompare(nameB);
        });
        uncheckedLabels.forEach(l => container.appendChild(l));
      }
    }
  }

  // Select category tab
  selectCategory(event) {
    event.preventDefault();
    const btn = event.currentTarget;
    const value = btn.dataset.categoryValue;
    
    // Update hidden input
    if (this.hasCategoryInputTarget) {
      this.categoryInputTarget.value = value;
    }

    // Toggle active classes on tabs
    const tabs = this.element.querySelectorAll(".category-tab-btn");
    tabs.forEach(tab => {
      if (tab === btn) {
        tab.classList.add("active");
      } else {
        tab.classList.remove("active");
      }
    });
  }

  // Helper clearers
  clearCities() {
    if (this.hasCityInputTarget) {
      this.cityInputTarget.value = "";
    }
    if (this.hasCityListTarget) {
      this.cityListTarget.innerHTML = "";
    }
    this.citySelectBtnTarget.innerText = "Selecionar cidade...";
    this.citySelectBtnTarget.disabled = true;
  }

  clearNeighborhoods() {
    if (this.hasNeighborhoodListTarget) {
      this.neighborhoodListTarget.innerHTML = "";
    }
    this.neighborhoodSelectBtnTarget.innerText = "Selecionar bairros...";
    this.neighborhoodSelectBtnTarget.disabled = true;
    this.neighborhoodCountTarget.style.display = "none";
    this.neighborhoodCountTarget.innerText = "";
  }

  clearForm(event) {
    if (event) event.preventDefault();
    
    if (this.hasStateInputTarget) this.stateInputTarget.value = "";
    if (this.hasStateSelectBtnTarget) this.stateSelectBtnTarget.innerText = "Selecione o Estado";
    this.clearCities();
    this.clearNeighborhoods();
    
    if (this.hasCategoryInputTarget) this.categoryInputTarget.value = "all";
    const tabs = this.element.querySelectorAll(".category-tab-btn");
    tabs.forEach(tab => {
      if (tab.dataset.categoryValue === "all") {
        tab.classList.add("active");
      } else {
        tab.classList.remove("active");
      }
    });

    const qInput = this.element.querySelector("#search-q");
    if (qInput) qInput.value = "";

    const checkboxes = this.element.querySelectorAll(".checkbox-filter-label input[type='checkbox']");
    checkboxes.forEach(cb => cb.checked = false);

    if (window.location.pathname === "/busca") {
      window.location.href = "/busca";
    }
  }

  closeAllDropdownsExcept(exceptDropdown) {
    const dropdowns = [this.stateDropdownTarget, this.cityDropdownTarget, this.neighborhoodDropdownTarget];
    dropdowns.forEach(dd => {
      if (dd !== exceptDropdown) {
        dd.classList.remove("active");
      }
    });
  }

  closeDropdownsOutside(event) {
    if (this.hasStateDropdownTarget && !this.stateDropdownTarget.contains(event.target)) {
      this.stateDropdownTarget.classList.remove("active");
    }
    if (this.hasCityDropdownTarget && !this.cityDropdownTarget.contains(event.target)) {
      this.cityDropdownTarget.classList.remove("active");
    }
    if (this.hasNeighborhoodDropdownTarget && !this.neighborhoodDropdownTarget.contains(event.target)) {
      this.neighborhoodDropdownTarget.classList.remove("active");
    }
  }
}
