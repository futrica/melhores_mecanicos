import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "queryInput",
    "clearQueryBtn",
    "clearBtn",
    "stateInput",
    "stateSlugInput",
    "stateSelectBtn",
    "stateBtnText",
    "stateDropdown",
    "stateSearch",
    "stateList",
    "cityInput",
    "citySlugInput",
    "citySelectBtn",
    "cityBtnText",
    "cityDropdown",
    "citySearch",
    "cityList",
    "neighborhoodSelectBtn",
    "neighborhoodBtnText",
    "neighborhoodDropdown",
    "neighborhoodSearch",
    "neighborhoodList",
    "neighborhoodCount",
    "neighborhoodSlugInput",
    "stateRequiredModal"
  ]

  static values = {
    initialStateId: String,
    initialStateSlug: String,
    initialCityId: String,
    initialCitySlug: String,
    initialNeighborhoodId: String,
    initialNeighborhoodSlug: String,
    currentPath: String
  }

  connect() {
    const urlParams = new URLSearchParams(window.location.search);
    let stateId = (this.hasStateInputTarget && this.stateInputTarget.value) || 
                  urlParams.get("state_id") || 
                  (this.hasInitialStateIdValue ? this.initialStateIdValue : "");

    if (stateId) {
      if (this.hasStateInputTarget) {
        this.stateInputTarget.value = stateId;
      }
      const selectedOption = this.element.querySelector(`.state-option[data-id="${stateId}"]`);
      if (selectedOption) {
        if (this.hasStateBtnTextTarget) {
          this.stateBtnTextTarget.innerText = selectedOption.dataset.name;
        }
        if (this.hasStateSlugInputTarget && selectedOption.dataset.slug) {
          this.stateSlugInputTarget.value = selectedOption.dataset.slug;
        }
      }

      this.fetchCities(stateId).then(() => {
        let cityId = (this.hasCityInputTarget && this.cityInputTarget.value) || 
                     urlParams.get("city_id") || 
                     urlParams.get("city_ids[]") || 
                     (this.hasInitialCityIdValue ? this.initialCityIdValue : "");

        if (cityId && this.hasCityListTarget) {
          if (this.hasCityInputTarget) {
            this.cityInputTarget.value = cityId;
          }
          const selectedCityOption = this.cityListTarget.querySelector(`.city-option[data-id="${cityId}"]`);
          if (selectedCityOption) {
            if (this.hasCityBtnTextTarget) {
              this.cityBtnTextTarget.innerText = selectedCityOption.dataset.name;
            }
            if (this.hasCitySlugInputTarget && selectedCityOption.dataset.slug) {
              this.citySlugInputTarget.value = selectedCityOption.dataset.slug;
            }
          }

          this.fetchNeighborhoods().then(() => {
            let neighborhoodIds = urlParams.getAll("neighborhood_ids[]");
            if (neighborhoodIds.length === 0 && urlParams.get("neighborhood_id")) {
              neighborhoodIds = [urlParams.get("neighborhood_id")];
            } else if (neighborhoodIds.length === 0 && this.hasInitialNeighborhoodIdValue && this.initialNeighborhoodIdValue) {
              neighborhoodIds = this.initialNeighborhoodIdValue.split(",").map(id => id.trim()).filter(Boolean);
            }

            if (neighborhoodIds.length > 0 && this.hasNeighborhoodListTarget) {
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

    // Close dropdowns on outside click
    this.closeDropdownsOutsideHandler = this.closeDropdownsOutside.bind(this);
    document.addEventListener("click", this.closeDropdownsOutsideHandler);

    // Escape key modal/dropdown closer
    this.handleKeyDown = (event) => {
      if (event.key === "Escape") {
        if (this.hasStateRequiredModalTarget && this.stateRequiredModalTarget.style.display === "flex") {
          this.closeStateRequiredModal();
        } else {
          this.closeAllDropdowns();
        }
      }
    };
    document.addEventListener("keydown", this.handleKeyDown);

    this.updateClearBtnVisibility();
  }

  disconnect() {
    if (this.closeDropdownsOutsideHandler) {
      document.removeEventListener("click", this.closeDropdownsOutsideHandler);
    }
    if (this.handleKeyDown) {
      document.removeEventListener("keydown", this.handleKeyDown);
    }
  }

  // Handle Query Input
  handleQueryInput() {
    const hasText = this.hasQueryInputTarget && this.queryInputTarget.value.trim().length > 0;
    if (this.hasClearQueryBtnTarget) {
      this.clearQueryBtnTarget.classList.toggle("hidden", !hasText);
    }
    this.updateClearBtnVisibility();
  }

  handleQueryKeydown(event) {
    if (event.key === "Enter") {
      event.preventDefault();
      this.handleSubmit(event);
    }
  }

  clearQuery(event) {
    if (event) event.preventDefault();
    if (this.hasQueryInputTarget) {
      this.queryInputTarget.value = "";
      this.queryInputTarget.focus();
    }
    if (this.hasClearQueryBtnTarget) {
      this.clearQueryBtnTarget.classList.add("hidden");
    }
    this.updateClearBtnVisibility();
  }

  updateClearBtnVisibility() {
    if (!this.hasClearBtnTarget) return;
    const hasQuery = this.hasQueryInputTarget && this.queryInputTarget.value.trim().length > 0;
    const hasCity = this.hasCityInputTarget && this.cityInputTarget.value.trim().length > 0;
    const hasCheckedNeighborhoods = this.hasNeighborhoodListTarget && 
      this.neighborhoodListTarget.querySelectorAll("input[type='checkbox']:checked").length > 0;

    const shouldShow = hasQuery || hasCity || hasCheckedNeighborhoods;
    this.clearBtnTarget.classList.toggle("hidden", !shouldShow);
  }

  // Form submission with intelligent dynamic routing
  handleSubmit(event) {
    if (event && typeof event.preventDefault === "function") {
      event.preventDefault();
    }

    const stateId = this.hasStateInputTarget ? this.stateInputTarget.value.trim() : "";
    if (!stateId) {
      this.openStateRequiredModal();
      return;
    }

    const stateSlug = (this.hasStateSlugInputTarget && this.stateSlugInputTarget.value.trim()) ||
                      (this.hasInitialStateSlugValue ? this.initialStateSlugValue : "");
    const citySlug = (this.hasCitySlugInputTarget && this.citySlugInputTarget.value.trim()) ||
                     (this.hasInitialCitySlugValue ? this.initialCitySlugValue : "");
    const query = this.hasQueryInputTarget ? this.queryInputTarget.value.trim() : "";

    // Checked neighborhoods
    let checkedNeighborhoods = [];
    if (this.hasNeighborhoodListTarget) {
      checkedNeighborhoods = Array.from(this.neighborhoodListTarget.querySelectorAll("input[type='checkbox']:checked"));
    }

    // Determine base canonical URL
    let basePath = "";
    if (stateSlug) {
      if (citySlug) {
        if (checkedNeighborhoods.length === 1 && checkedNeighborhoods[0].dataset.slug) {
          basePath = `/${stateSlug}/${citySlug}/${checkedNeighborhoods[0].dataset.slug}`;
        } else {
          basePath = `/${stateSlug}/${citySlug}`;
        }
      } else {
        basePath = `/${stateSlug}`;
      }
    } else {
      basePath = "/busca";
    }

    // Build URL search parameters
    const params = new URLSearchParams();
    if (query) {
      params.set("q", query);
    }

    if (basePath === "/busca") {
      if (stateId) params.set("state_id", stateId);
      if (this.hasCityInputTarget && this.cityInputTarget.value) {
        params.set("city_id", this.cityInputTarget.value);
      }
    }

    // If multiple neighborhoods selected, append neighborhood_ids[]
    if (checkedNeighborhoods.length > 1 || (checkedNeighborhoods.length === 1 && !basePath.includes(checkedNeighborhoods[0].dataset.slug))) {
      checkedNeighborhoods.forEach(cb => {
        params.append("neighborhood_ids[]", cb.value);
      });
    }

    const queryString = params.toString();
    const finalUrl = queryString ? `${basePath}?${queryString}` : basePath;

    window.location.href = finalUrl;
  }

  // Modal handlers
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

  // Dropdown Toggles
  toggleStateDropdown(event) {
    if (event && typeof event.stopPropagation === "function") {
      event.stopPropagation();
    }
    this.closeAllDropdownsExcept(this.stateDropdownTarget);
    if (this.hasStateDropdownTarget) {
      this.stateDropdownTarget.classList.toggle("active");
      if (this.stateDropdownTarget.classList.contains("active") && this.hasStateSearchTarget) {
        this.stateSearchTarget.value = "";
        this.filterStates();
        setTimeout(() => this.stateSearchTarget.focus(), 50);
      }
    }
  }

  toggleCityDropdown(event) {
    if (event && typeof event.stopPropagation === "function") {
      event.stopPropagation();
    }
    if (this.hasCitySelectBtnTarget && this.citySelectBtnTarget.disabled) return;

    this.closeAllDropdownsExcept(this.cityDropdownTarget);
    if (this.hasCityDropdownTarget) {
      this.cityDropdownTarget.classList.toggle("active");
      if (this.cityDropdownTarget.classList.contains("active") && this.hasCitySearchTarget) {
        this.citySearchTarget.value = "";
        this.filterCities();
        setTimeout(() => this.citySearchTarget.focus(), 50);
      }
    }
  }

  toggleNeighborhoodDropdown(event) {
    if (event && typeof event.stopPropagation === "function") {
      event.stopPropagation();
    }
    if (this.hasNeighborhoodSelectBtnTarget && this.neighborhoodSelectBtnTarget.disabled) return;

    this.closeAllDropdownsExcept(this.neighborhoodDropdownTarget);
    if (this.hasNeighborhoodDropdownTarget) {
      this.neighborhoodDropdownTarget.classList.toggle("active");
      if (this.neighborhoodDropdownTarget.classList.contains("active") && this.hasNeighborhoodSearchTarget) {
        this.neighborhoodSearchTarget.value = "";
        this.filterNeighborhoods();
        setTimeout(() => this.neighborhoodSearchTarget.focus(), 50);
      }
    }
  }

  // Selection actions
  selectState(event) {
    event.stopPropagation();
    const option = event.currentTarget;
    const id = option.dataset.id;
    const slug = option.dataset.slug || "";
    const name = option.dataset.name;

    if (this.hasStateInputTarget) this.stateInputTarget.value = id;
    if (this.hasStateSlugInputTarget) this.stateSlugInputTarget.value = slug;
    if (this.hasStateBtnTextTarget) this.stateBtnTextTarget.innerText = name;

    if (this.hasStateDropdownTarget) {
      this.stateDropdownTarget.classList.remove("active");
    }

    // Reset city and neighborhood
    this.clearCities();
    this.clearNeighborhoods();

    // Visual feedback on city button
    if (this.hasCityBtnTextTarget) this.cityBtnTextTarget.innerText = "Carregando cidades...";
    if (this.hasCitySelectBtnTarget) this.citySelectBtnTarget.disabled = true;

    this.fetchCities(id).then(() => {
      // Auto open city dropdown for seamless dynamic UX
      setTimeout(() => {
        this.toggleCityDropdown();
      }, 100);
    });
  }

  selectCity(event) {
    event.stopPropagation();
    const option = event.currentTarget;
    const id = option.dataset.id || "";
    const slug = option.dataset.slug || "";
    const name = option.dataset.name;

    if (this.hasCityInputTarget) this.cityInputTarget.value = id;
    if (this.hasCitySlugInputTarget) this.citySlugInputTarget.value = slug;
    if (this.hasCityBtnTextTarget) this.cityBtnTextTarget.innerText = name;

    if (this.hasCityDropdownTarget) {
      this.cityDropdownTarget.classList.remove("active");
    }

    this.updateClearBtnVisibility();

    if (!id) {
      // Selected "All cities"
      this.clearNeighborhoods();
      return;
    }

    if (this.hasNeighborhoodBtnTextTarget) {
      this.neighborhoodBtnTextTarget.innerText = "Carregando bairros...";
    }
    if (this.hasNeighborhoodSelectBtnTarget) {
      this.neighborhoodSelectBtnTarget.disabled = true;
    }

    this.fetchNeighborhoods();
  }

  // Filter lists inside dropdowns
  filterStates() {
    const query = (this.stateSearchTarget.value || "").toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "");
    const options = this.stateListTarget.querySelectorAll(".state-option");
    
    options.forEach(option => {
      const stateName = option.dataset.name.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "");
      const acronym = (option.querySelector("span:last-child")?.innerText || "").toLowerCase();
      if (stateName.includes(query) || acronym.includes(query)) {
        option.style.display = "flex";
      } else {
        option.style.display = "none";
      }
    });
  }

  filterCities() {
    const query = (this.citySearchTarget.value || "").toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "");
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

  filterNeighborhoods() {
    const query = (this.neighborhoodSearchTarget.value || "").toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "");
    const labels = this.neighborhoodListTarget.querySelectorAll(".neighborhood-checkbox-label");
    
    labels.forEach(label => {
      const nName = (label.dataset.neighborhoodName || "").normalize("NFD").replace(/[\u0300-\u036f]/g, "");
      if (nName.includes(query)) {
        label.style.display = "flex";
      } else {
        label.style.display = "none";
      }
    });
  }

  // API Fetches
  async fetchCities(stateId) {
    if (!stateId) {
      this.clearCities();
      return;
    }

    try {
      const response = await fetch(`/api/cities?state_id=${stateId}`);
      const cities = await response.json();
      this.renderCitiesList(cities);
    } catch (error) {
      console.error("Erro ao carregar cidades:", error);
      if (this.hasCityBtnTextTarget) this.cityBtnTextTarget.innerText = "Erro ao carregar";
    }
  }

  renderCitiesList(cities) {
    if (!this.hasCityListTarget) return;

    if (cities.length === 0) {
      this.cityListTarget.innerHTML = `<div class="px-3 py-2 text-xs text-slate-500 italic text-center">Nenhuma cidade encontrada</div>`;
      if (this.hasCitySelectBtnTarget) this.citySelectBtnTarget.disabled = true;
      if (this.hasCityBtnTextTarget) this.cityBtnTextTarget.innerText = "Nenhuma cidade disponível";
      return;
    }

    if (this.hasCitySelectBtnTarget) this.citySelectBtnTarget.disabled = false;
    if (this.hasCityBtnTextTarget && (!this.hasCityInputTarget || !this.cityInputTarget.value)) {
      this.cityBtnTextTarget.innerText = "Selecionar cidade...";
    }

    let html = `
      <div class="city-option px-3 py-2 text-xs font-bold text-blue-600 hover:bg-blue-50 cursor-pointer rounded-lg transition-colors border-b border-slate-100 flex items-center gap-1.5" 
           data-id="" 
           data-slug="" 
           data-name="Todas as cidades" 
           data-action="click->search-form#selectCity">
        <span>📍</span>
        <span>Todas as cidades</span>
      </div>
    `;

    cities.forEach(city => {
      html += `
        <div class="city-option px-3 py-2 text-xs font-semibold text-slate-700 hover:bg-blue-50 hover:text-[#093892] cursor-pointer rounded-lg transition-colors" 
             data-id="${city.id}" 
             data-slug="${city.slug || ''}" 
             data-name="${city.name}" 
             data-action="click->search-form#selectCity">
          ${city.name}
        </div>
      `;
    });
    this.cityListTarget.innerHTML = html;
  }

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
      console.error("Erro ao carregar bairros:", error);
      if (this.hasNeighborhoodBtnTextTarget) this.neighborhoodBtnTextTarget.innerText = "Erro ao carregar";
    }
  }

  renderNeighborhoodsList(neighborhoods) {
    if (!this.hasNeighborhoodListTarget) return;

    if (neighborhoods.length === 0) {
      this.neighborhoodListTarget.innerHTML = `<div class="px-3 py-2 text-xs text-slate-500 italic text-center">Nenhum bairro cadastrado</div>`;
      if (this.hasNeighborhoodSelectBtnTarget) this.neighborhoodSelectBtnTarget.disabled = true;
      if (this.hasNeighborhoodBtnTextTarget) this.neighborhoodBtnTextTarget.innerText = "Sem bairros";
      return;
    }

    if (this.hasNeighborhoodSelectBtnTarget) this.neighborhoodSelectBtnTarget.disabled = false;
    if (this.hasNeighborhoodBtnTextTarget) this.neighborhoodBtnTextTarget.innerText = "Selecionar bairros...";
    if (this.hasNeighborhoodCountTarget) {
      this.neighborhoodCountTarget.classList.add("hidden");
      this.neighborhoodCountTarget.innerText = "0";
    }
    
    let html = "";
    neighborhoods.forEach(n => {
      html += `
        <label class="neighborhood-checkbox-label flex items-center gap-2 px-3 py-1.5 text-xs font-semibold text-slate-700 hover:bg-blue-50 hover:text-[#093892] rounded-lg cursor-pointer transition-colors" 
               data-neighborhood-name="${n.name.toLowerCase()}">
          <input type="checkbox" 
                 name="neighborhood_ids[]" 
                 value="${n.id}" 
                 data-slug="${n.slug || ''}" 
                 class="w-4 h-4 text-[#093892] rounded border-slate-300 focus:ring-[#00A1FC] cursor-pointer" 
                 data-action="change->search-form#neighborhoodToggled">
          <span>${n.name}</span>
        </label>
      `;
    });
    this.neighborhoodListTarget.innerHTML = html;
  }

  neighborhoodToggled() {
    this.updateSelectedNeighborhoodsDisplay();
    this.updateClearBtnVisibility();
  }

  updateSelectedNeighborhoodsDisplay() {
    if (!this.hasNeighborhoodListTarget) return;
    const checked = this.neighborhoodListTarget.querySelectorAll("input[type='checkbox']:checked");
    const count = checked.length;

    if (count === 0) {
      if (this.hasNeighborhoodBtnTextTarget) this.neighborhoodBtnTextTarget.innerText = "Selecionar bairros...";
      if (this.hasNeighborhoodCountTarget) this.neighborhoodCountTarget.classList.add("hidden");
    } else if (count === 1) {
      const name = checked[0].nextElementSibling.innerText;
      if (this.hasNeighborhoodBtnTextTarget) this.neighborhoodBtnTextTarget.innerText = name;
      if (this.hasNeighborhoodCountTarget) {
        this.neighborhoodCountTarget.classList.remove("hidden");
        this.neighborhoodCountTarget.innerText = "1";
      }
    } else {
      if (this.hasNeighborhoodBtnTextTarget) this.neighborhoodBtnTextTarget.innerText = `${count} bairros`;
      if (this.hasNeighborhoodCountTarget) {
        this.neighborhoodCountTarget.classList.remove("hidden");
        this.neighborhoodCountTarget.innerText = count.toString();
      }
    }
  }

  // Clear Helpers
  clearCities() {
    if (this.hasCityInputTarget) this.cityInputTarget.value = "";
    if (this.hasCitySlugInputTarget) this.citySlugInputTarget.value = "";
    if (this.hasCityListTarget) this.cityListTarget.innerHTML = "";
    if (this.hasCityBtnTextTarget) this.cityBtnTextTarget.innerText = "Selecionar cidade...";
    if (this.hasCitySelectBtnTarget) this.citySelectBtnTarget.disabled = true;
  }

  clearNeighborhoods() {
    if (this.hasNeighborhoodListTarget) this.neighborhoodListTarget.innerHTML = "";
    if (this.hasNeighborhoodBtnTextTarget) this.neighborhoodBtnTextTarget.innerText = "Selecione a cidade";
    if (this.hasNeighborhoodSelectBtnTarget) this.neighborhoodSelectBtnTarget.disabled = true;
    if (this.hasNeighborhoodCountTarget) {
      this.neighborhoodCountTarget.classList.add("hidden");
      this.neighborhoodCountTarget.innerText = "0";
    }
    if (this.hasNeighborhoodSlugInputTarget) this.neighborhoodSlugInputTarget.value = "";
  }

  clearForm(event) {
    if (event) event.preventDefault();

    if (this.hasQueryInputTarget) this.queryInputTarget.value = "";
    if (this.hasClearQueryBtnTarget) this.clearQueryBtnTarget.classList.add("hidden");

    if (this.hasCityInputTarget) this.cityInputTarget.value = "";
    if (this.hasCitySlugInputTarget) this.citySlugInputTarget.value = "";
    if (this.hasCityBtnTextTarget) this.cityBtnTextTarget.innerText = "Selecionar cidade...";

    this.clearNeighborhoods();
    this.updateClearBtnVisibility();

    // If currently on /busca, reload clean /busca
    if (window.location.pathname === "/busca") {
      window.location.href = "/busca";
    }
  }

  // Dropdown visibility helpers
  closeAllDropdownsExcept(exceptDropdown) {
    const dropdowns = [this.stateDropdownTarget, this.cityDropdownTarget, this.neighborhoodDropdownTarget];
    dropdowns.forEach(dd => {
      if (dd && dd !== exceptDropdown) {
        dd.classList.remove("active");
      }
    });
  }

  closeAllDropdowns() {
    if (this.hasStateDropdownTarget) this.stateDropdownTarget.classList.remove("active");
    if (this.hasCityDropdownTarget) this.cityDropdownTarget.classList.remove("active");
    if (this.hasNeighborhoodDropdownTarget) this.neighborhoodDropdownTarget.classList.remove("active");
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
