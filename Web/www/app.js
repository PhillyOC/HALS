const API = "/api";

let state = {
  status: null,
  devices: [],
  knowledge: [],
  pendingPlan: null,
  scanning: false,
  selectedDevice: null,
};

// ----------------------------------------------------------
// API helpers
// ----------------------------------------------------------

async function api(path, options = {}) {
  const res = await fetch(`${API}${path}`, {
    headers: { "Content-Type": "application/json", ...options.headers },
    ...options,
  });
  const json = await res.json();
  if (!json.ok) throw new Error(json.error || "Request failed");
  return json.data;
}

// ----------------------------------------------------------
// UI helpers
// ----------------------------------------------------------

function $(sel) { return document.querySelector(sel); }
function $$(sel) { return [...document.querySelectorAll(sel)]; }

function showToast(message, type = "success") {
  const toast = $("#toast");
  toast.textContent = message;
  toast.className = `toast ${type}`;
  setTimeout(() => toast.classList.add("hidden"), 3500);
}

function setConnectionStatus(online) {
  const el = $("#connection-status");
  el.textContent = online ? "Connected" : "Offline";
  el.className = `status-pill ${online ? "online" : "offline"}`;
}

function statusBadge(status) {
  const map = {
    Healthy: "healthy",
    Offline: "offline",
    NotConfigured: "unconfigured",
  };
  const cls = map[status] || "unconfigured";
  const label = status === "NotConfigured" ? "Not configured" : status;
  return `<span class="badge ${cls}">${label}</span>`;
}

// ----------------------------------------------------------
// Navigation
// ----------------------------------------------------------

$$(".nav-btn").forEach((btn) => {
  btn.addEventListener("click", () => {
    $$(".nav-btn").forEach((b) => b.classList.remove("active"));
    $$(".view").forEach((v) => v.classList.remove("active"));
    btn.classList.add("active");
    $(`#view-${btn.dataset.view}`).classList.add("active");
  });
});

// ----------------------------------------------------------
// Dashboard
// ----------------------------------------------------------

function renderStats(overview) {
  const stats = [
    { value: overview.TotalDevices, label: "Total Devices" },
    { value: overview.Lights, label: "Lights" },
    { value: overview.Sensors, label: "Sensors" },
    { value: overview.Switches, label: "Switches" },
    { value: overview.Locks, label: "Locks" },
    { value: overview.MediaPlayers, label: "Media" },
  ].filter((s) => s.value > 0 || s.label === "Total Devices");

  $("#stats-grid").innerHTML = stats
    .map(
      (s) => `
    <div class="stat-card">
      <div class="stat-value">${s.value}</div>
      <div class="stat-label">${s.label}</div>
    </div>`
    )
    .join("");
}

function renderIntegrations(integrations) {
  $("#integrations-list").innerHTML = integrations
    .map(
      (i) => `
    <div class="integration-row">
      <span class="name">${i.Name}</span>
      ${statusBadge(i.Status)}
    </div>`
    )
    .join("");
}

function renderAIProviders(providers) {
  if (!providers || !providers.length) {
    $("#ai-providers-list").innerHTML = '<p class="muted">AI not configured.</p>';
    renderAIProviderSelect([]);
    return;
  }

  $("#ai-providers-list").innerHTML = providers
    .map((p) => {
      let badge;
      if (p.Active) badge = '<span class="badge active">Active</span>';
      else if (p.Configured) badge = '<span class="badge healthy">Ready</span>';
      else badge = '<span class="badge unconfigured">Not configured</span>';

      const model = p.Model ? ` <span class="muted">(${p.Model})</span>` : "";
      return `
      <div class="integration-row">
        <span class="name">${p.Name}${model}</span>
        ${badge}
      </div>`;
    })
    .join("");

  renderAIProviderSelect(providers);
}

function renderAIProviderSelect(providers) {
  const select = $("#ai-provider-select");
  if (!select) return;

  const active = providers.find((p) => p.Active);
  const cur = select.value;

  const options = providers.map((p) => {
    const label = p.Configured
      ? `${p.Name}${p.Model ? ` (${p.Model})` : ""}`
      : `${p.Name} (not configured)`;
    return `<option value="${esc(p.Key)}" ${p.Configured ? "" : "disabled"}>${esc(label)}</option>`;
  });

  select.innerHTML = options.join("");
  select.value = active?.Key || cur || "";
  select.disabled = !providers.some((p) => p.Configured);
}

async function switchAIProvider(provider) {
  if (!provider || provider === state.status?.AI?.Active) return;

  try {
    const result = await api("/ai/switch", {
      method: "POST",
      body: JSON.stringify({ provider }),
    });
    showToast(`Switched to ${result.Active}${result.Model ? ` (${result.Model})` : ""}`);
    await refresh();
  } catch (err) {
    showToast(err.message, "error");
    if (state.status?.AI?.Active) {
      $("#ai-provider-select").value = state.status.AI.Active;
    }
  }
}

function renderChanges(comparison) {
  const el = $("#changes-summary");

  if (!comparison.HasComparison) {
    el.innerHTML = `<p class="muted">${comparison.Message || "No comparison available."}</p>`;
    return;
  }

  let html = `<p class="muted" style="margin-bottom:0.75rem">Comparing <strong>${comparison.Previous}</strong> → <strong>${comparison.Current}</strong></p>`;

  if (comparison.New.length) {
    html += `<div class="change-group"><h3>New devices (${comparison.New.length})</h3>`;
    html += comparison.New.map((d) => `<div class="change-item change-new">+ ${d.Name} <span class="muted">(${d.Source})</span></div>`).join("");
    html += "</div>";
  }

  if (comparison.Missing.length) {
    html += `<div class="change-group"><h3>Missing (${comparison.Missing.length})</h3>`;
    html += comparison.Missing.map((d) => `<div class="change-item change-missing">− ${d.Name}</div>`).join("");
    html += "</div>";
  }

  if (comparison.Changed.length) {
    html += `<div class="change-group"><h3>IP changes (${comparison.Changed.length})</h3>`;
    html += comparison.Changed.map((d) => `<div class="change-item change-ip">~ ${d.Name}: ${d.OldIP} → ${d.NewIP}</div>`).join("");
    html += "</div>";
  }

  if (!comparison.New.length && !comparison.Missing.length && !comparison.Changed.length) {
    html += '<p class="muted">No changes since the previous snapshot.</p>';
  }

  el.innerHTML = html;
}

// ----------------------------------------------------------
// Devices
// ----------------------------------------------------------

function isControllable(device) {
  return device.Source === "SmartThings" && device.Category === "Light Bulb";
}

function renderDeviceCard(d) {
  const status = d.Status ? `<div class="device-status">${esc(d.Status)}</div>` : "";
  const known = d.Known ? '<span class="badge healthy">Known</span>' : "";

  return `
    <div class="device-card clickable" data-mac="${esc(d.MAC)}" tabindex="0" role="button">
      <div class="device-card-header">
        <h3>${esc(d.Name)}</h3>
        ${known}
      </div>
      <div class="device-meta">
        <span class="source">${esc(d.Source)}</span>
        <span>${esc(d.Category)}</span>
        ${d.IP ? `<span>${esc(d.IP)}</span>` : ""}
      </div>
      ${status}
    </div>`;
}

function renderDevices(devices) {
  const grid = $("#devices-grid");

  if (!devices.length) {
    grid.innerHTML = '<p class="muted">No devices found. Run a scan to populate inventory.</p>';
    return;
  }

  grid.innerHTML = devices.map(renderDeviceCard).join("");
  $("#device-count").textContent = `${devices.length} device${devices.length !== 1 ? "s" : ""}`;

  grid.querySelectorAll(".device-card").forEach((card) => {
    card.addEventListener("click", () => openDeviceModal(card.dataset.mac));
    card.addEventListener("keydown", (e) => {
      if (e.key === "Enter" || e.key === " ") {
        e.preventDefault();
        openDeviceModal(card.dataset.mac);
      }
    });
  });
}

function esc(str) {
  return String(str)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

async function loadDevices() {
  const search = $("#device-search").value;
  const source = $("#device-source-filter").value;
  const category = $("#device-category-filter").value;

  const params = new URLSearchParams();
  if (search) params.set("search", search);
  if (source) params.set("source", source);
  if (category) params.set("category", category);

  const query = params.toString();
  const path = query ? `/devices?${query}` : "/devices";

  // GET with query via POST body workaround - use fetch with encoded path
  state.devices = await api(`/devices${query ? "?" + query : ""}`);
  renderDevices(state.devices);
}

function populateFilters(devices) {
  const sources = [...new Set(devices.map((d) => d.Source))].sort();
  const categories = [...new Set(devices.map((d) => d.Category))].sort();

  const sourceSel = $("#device-source-filter");
  const catSel = $("#device-category-filter");

  const curSource = sourceSel.value;
  const curCat = catSel.value;

  sourceSel.innerHTML = '<option value="">All sources</option>' +
    sources.map((s) => `<option value="${esc(s)}">${esc(s)}</option>`).join("");

  catSel.innerHTML = '<option value="">All categories</option>' +
    categories.map((c) => `<option value="${esc(c)}">${esc(c)}</option>`).join("");

  sourceSel.value = curSource;
  catSel.value = curCat;
}

async function deviceAction(name, command) {
  try {
    await api("/actions", {
      method: "POST",
      body: JSON.stringify({
        provider: "SmartThings",
        device: name,
        command,
      }),
    });
    showToast(`${command} sent to ${name}`);
    setTimeout(loadDevices, 1500);
    if (state.selectedDevice) {
      setTimeout(() => openDeviceModal(state.selectedDevice.MAC), 1600);
    }
  } catch (err) {
    showToast(err.message, "error");
  }
}

async function openDeviceModal(mac) {
  try {
    const device = await api(`/devices?mac=${encodeURIComponent(mac)}`);
    state.selectedDevice = device;

    $("#device-modal-title").textContent = device.Name;
    $("#device-modal-info").innerHTML = `
      <dt>Source</dt><dd>${esc(device.Source)}</dd>
      <dt>Category</dt><dd>${esc(device.Category)}</dd>
      <dt>MAC</dt><dd>${esc(device.MAC)}</dd>
      ${device.IP ? `<dt>IP</dt><dd>${esc(device.IP)}</dd>` : ""}
      ${device.Domain ? `<dt>Domain</dt><dd>${esc(device.Domain)}</dd>` : ""}
      ${device.Status ? `<dt>Status</dt><dd>${esc(device.Status)}</dd>` : ""}
    `;

    const entities = device.Entities || [];
    $("#device-modal-entities").innerHTML = entities.length
      ? entities.map((e) => `
          <div class="entity-row">
            <span class="entity-name">${esc(e.Name)}</span>
            <span class="entity-value">${esc(e.Value)}</span>
          </div>`).join("")
      : '<p class="muted">No entity data.</p>';

    const actionsEl = $("#device-modal-actions");
    if (isControllable(device)) {
      actionsEl.innerHTML = `
        <button class="btn btn-sm btn-ghost" onclick="deviceAction('${esc(device.Name)}','TurnOnLight')">Turn On</button>
        <button class="btn btn-sm btn-ghost" onclick="deviceAction('${esc(device.Name)}','TurnOffLight')">Turn Off</button>`;
    } else {
      actionsEl.innerHTML = "";
    }

    $("#device-modal").classList.remove("hidden");
  } catch (err) {
    showToast(err.message, "error");
  }
}

function closeModal(id) {
  $(`#${id}`).classList.add("hidden");
  if (id === "device-modal") state.selectedDevice = null;
}

$$("[data-close]").forEach((el) => {
  el.addEventListener("click", () => closeModal(el.dataset.close));
});

window.deviceAction = deviceAction;

// ----------------------------------------------------------
// AI Assistant
// ----------------------------------------------------------

function addChatBubble(text, role) {
  const div = document.createElement("div");
  div.className = `chat-bubble ${role}`;
  div.textContent = text;
  $("#chat-messages").appendChild(div);
  div.scrollIntoView({ behavior: "smooth" });
}

function showPlanModal(data) {
  state.pendingPlan = data.Plan;
  $("#plan-preamble").textContent = data.Preamble || "";
  $("#plan-actions").innerHTML = data.Plan.Actions.map(
    (a) => `
    <div class="plan-action-row">
      <strong>${esc(a.Command)}</strong> → ${esc(a.Device)}
      <span class="muted"> (${esc(a.Provider)})</span>
    </div>`
  ).join("");
  $("#plan-modal").classList.remove("hidden");
}

function hidePlanModal() {
  $("#plan-modal").classList.add("hidden");
  state.pendingPlan = null;
}

async function sendQuestion(question) {
  if (!question.trim()) return;

  addChatBubble(question, "user");
  $("#chat-input").value = "";
  $("#chat-input").disabled = true;

  try {
    const result = await api("/ai/ask", {
      method: "POST",
      body: JSON.stringify({ question }),
    });

    if (result.Type === "plan") {
      addChatBubble("I prepared an execution plan. Please review and confirm.", "assistant");
      showPlanModal(result);
    } else {
      addChatBubble(result.Message, "assistant");
    }
  } catch (err) {
    addChatBubble(`Error: ${err.message}`, "assistant");
  } finally {
    $("#chat-input").disabled = false;
    $("#chat-input").focus();
  }
}

$("#chat-form").addEventListener("submit", (e) => {
  e.preventDefault();
  sendQuestion($("#chat-input").value);
});

$("#ai-provider-select").addEventListener("change", (e) => {
  switchAIProvider(e.target.value);
});

$$(".quick-btn").forEach((btn) => {
  btn.addEventListener("click", () => sendQuestion(btn.dataset.prompt));
});

$("#plan-cancel").addEventListener("click", hidePlanModal);
$("#plan-modal .modal-backdrop").addEventListener("click", hidePlanModal);

$("#plan-execute").addEventListener("click", async () => {
  if (!state.pendingPlan) return;

  try {
    await api("/ai/execute", {
      method: "POST",
      body: JSON.stringify({ plan: state.pendingPlan }),
    });
    addChatBubble("Plan executed successfully.", "assistant");
    showToast("Plan executed");
    hidePlanModal();
    setTimeout(loadDevices, 1500);
  } catch (err) {
    showToast(err.message, "error");
  }
});

// ----------------------------------------------------------
// Knowledge
// ----------------------------------------------------------

function renderKnowledge(items) {
  const list = $("#knowledge-list");

  if (!items.length) {
    list.innerHTML = '<p class="muted">No known devices registered yet.</p>';
    $("#knowledge-count").textContent = "0 known";
    return;
  }

  list.innerHTML = items
    .map(
      (k) => `
    <div class="knowledge-row">
      <div>
        <strong>${esc(k.FriendlyName)}</strong>
        <div class="muted">${esc(k.Category)}${k.Tags ? ` · ${esc(k.Tags)}` : ""}</div>
      </div>
      <span class="mono muted">${esc(k.MAC)}</span>
    </div>`
    )
    .join("");

  $("#knowledge-count").textContent = `${items.length} known`;
}

async function loadKnowledge() {
  const search = $("#knowledge-search").value.trim().toLowerCase();
  let items = await api("/knowledge");

  if (search) {
    items = items.filter(
      (k) =>
        k.FriendlyName.toLowerCase().includes(search) ||
        k.MAC.toLowerCase().includes(search) ||
        k.Category.toLowerCase().includes(search)
    );
  }

  state.knowledge = items;
  renderKnowledge(items);
}

let knowledgeTimeout;
$("#knowledge-search").addEventListener("input", () => {
  clearTimeout(knowledgeTimeout);
  knowledgeTimeout = setTimeout(loadKnowledge, 300);
});

// ----------------------------------------------------------
// System
// ----------------------------------------------------------

function renderServerInfo(status) {
  $("#server-info").innerHTML = `
    <dt>HALS Version</dt><dd>${esc(status.HALSVersion)}</dd>
    <dt>Web Version</dt><dd>${esc(status.Version)}</dd>
    <dt>Computer</dt><dd>${esc(status.Computer)}</dd>
    <dt>Started</dt><dd>${esc(new Date(status.Started).toLocaleString())}</dd>
    <dt>Active AI</dt><dd>${status.AI?.Active || "—"} ${status.AI?.Model ? `(${status.AI.Model})` : ""}</dd>
    <dt>Data source</dt><dd>${esc(status.Overview?.LoadedFrom || "live")}</dd>
  `;
}

function renderSnapshots(snapshots) {
  if (!snapshots.length) {
    $("#snapshots-list").innerHTML = '<p class="muted">No snapshots yet.</p>';
    return;
  }

  $("#snapshots-list").innerHTML = snapshots
    .slice(0, 10)
    .map(
      (s) => `
    <div class="snapshot-row">
      <span>${esc(s.Name)}</span>
      <span class="muted">${esc(s.SizeKB)} KB</span>
    </div>`
    )
    .join("");
}

// ----------------------------------------------------------
// Scan
// ----------------------------------------------------------

async function runScan() {
  if (state.scanning) return;

  state.scanning = true;
  const btn = $("#btn-scan");
  btn.disabled = true;
  btn.classList.add("loading");
  btn.innerHTML = '<span class="btn-icon">↻</span> Scanning…';

  try {
    const result = await api("/scan", { method: "POST" });
    showToast(`Scan complete — ${result.DeviceCount} devices`);
    await refresh();
  } catch (err) {
    showToast(err.message, "error");
  } finally {
    state.scanning = false;
    btn.disabled = false;
    btn.classList.remove("loading");
    btn.innerHTML = '<span class="btn-icon">↻</span> Scan';
  }
}

$("#btn-scan").addEventListener("click", runScan);

// ----------------------------------------------------------
// Device filters
// ----------------------------------------------------------

let searchTimeout;
$("#device-search").addEventListener("input", () => {
  clearTimeout(searchTimeout);
  searchTimeout = setTimeout(loadDevices, 300);
});

$("#device-source-filter").addEventListener("change", loadDevices);
$("#device-category-filter").addEventListener("change", loadDevices);

// ----------------------------------------------------------
// Refresh
// ----------------------------------------------------------

async function refresh() {
  try {
    const [status, comparison, snapshots, knowledge] = await Promise.all([
      api("/status"),
      api("/snapshots/compare"),
      api("/snapshots"),
      api("/knowledge"),
    ]);

    state.status = status;
    setConnectionStatus(true);

    renderStats(status.Overview);
    renderIntegrations(status.Integrations);
    renderAIProviders(status.AIProviders);
    renderChanges(comparison);
    renderServerInfo(status);

    state.devices = await api("/devices");
    populateFilters(state.devices);
    renderDevices(state.devices);
    renderSnapshots(snapshots);

    state.knowledge = knowledge;
    renderKnowledge(knowledge);
  } catch (err) {
    setConnectionStatus(false);
    console.error(err);
  }
}

refresh();
setInterval(refresh, 60000);
