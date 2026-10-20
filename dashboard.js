const cards = document.getElementById("cards");
const statusBox = document.getElementById("status");
const layout = document.getElementById("layout");

// Send form data to the Common Lisp server
async function post(path, fields) {
  const response = await fetch(path, {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded"
    },
    body: new URLSearchParams(fields)
  });

  if (!response.ok) {
    throw new Error("Request failed: " + path);
  }

  return response.json();
}

// Create a button safely
function makeButton(label, action, primary = false) {
  const button = document.createElement("button");
  button.textContent = label;

  if (primary) {
    button.className = "primary";
  }

  button.addEventListener("click", action);
  return button;
}

// Load counters saved in SQLite
async function loadCounters() {
  try {
    const response = await fetch("/api/counters");

    if (!response.ok) {
      throw new Error("Could not load counters");
    }

    const data = await response.json();
    cards.replaceChildren();

    for (const item of data) {
      const card = document.createElement("article");
      card.className = "card";

      const name = document.createElement("input");
      name.value = item.name;
      name.maxLength = 100;
      name.setAttribute("aria-label", "Counter name");

      const goal = document.createElement("input");
      goal.type = "number";
      goal.min = "1";
      goal.value = item.goal;
      goal.setAttribute("aria-label", "Counter goal");

      const count = document.createElement("div");
      count.className = "count";
      count.textContent = Number(item.count).toLocaleString();

      const detail = document.createElement("small");
      detail.textContent =
        "Goal: " + Number(item.goal).toLocaleString();

      const progress = document.createElement("div");
      progress.className = "progress";

      const bar = document.createElement("div");
      bar.className = "bar";

      bar.style.width =
        Math.min(100, Number(item.count) / Number(item.goal) * 100) + "%";

      progress.append(bar);

      const actions = document.createElement("div");
      actions.className = "actions";

      actions.append(
  makeButton("+1", async () => {
    try {
      await post("/api/increment", { id: item.id });
      await loadCounters();
    } catch (error) {
      statusBox.textContent = error.message;
    }
  }, true),

  makeButton("Save", async () => {
    try {
      const n = name.value.trim();
      const g = Number(goal.value);

      if (!n || !Number.isSafeInteger(g) || g < 1) {
        throw new Error("Enter a name and valid goal.");
      }

      await post("/api/edit", {
        id: item.id,
        name: n,
        goal: g
      });

      await loadCounters();
      statusBox.textContent = "Counter saved.";
    } catch (error) {
      statusBox.textContent = error.message;
    }
  }),

  makeButton("Reset", async () => {
    if (!confirm("Reset this counter to zero?")) return;

    try {
      await post("/api/reset", { id: item.id });
      await loadCounters();
    } catch (error) {
      statusBox.textContent = error.message;
    }
  }),

  makeButton("Delete", async () => {
    if (!confirm("Delete this counter?")) return;

    try {
      await post("/api/delete", { id: item.id });
      await loadCounters();
    } catch (error) {
      statusBox.textContent = error.message;
    }
  })
);
      
      card.append(name, goal, count, detail, progress, actions);
      cards.append(card);
    }

    statusBox.textContent = data.length + " counter(s) loaded.";
  } catch (error) {
    statusBox.textContent = "Error: " + error.message;
  }
}


// Add a new counter
document.getElementById("add").addEventListener("click", async () => {
  try {
    const name = document.getElementById("newName").value.trim();
    const goal = Number(document.getElementById("newGoal").value);

    if (!name || !Number.isSafeInteger(goal) || goal < 1) {
      throw new Error("Enter a counter name and valid goal.");
    }

    await post("/api/add", { name, goal });

    document.getElementById("newName").value = "";
    statusBox.textContent = "Counter added.";

    await loadCounters();
  } catch (error) {
    statusBox.textContent = error.message;
  }
});

// Switch dashboard layout
layout.addEventListener("change", () => {
  cards.className = layout.value;
});

// Load saved counters when the page opens
loadCounters();


// Export counters to a JSON file
document.getElementById("export").addEventListener("click", async () => {
  try {
    const response = await fetch("/api/counters");

    if (!response.ok) {
      throw new Error("Could not export counters.");
    }

    const data = await response.json();

    const file = new Blob(
      [JSON.stringify({ version: 1, counters: data }, null, 2)],
      { type: "application/json" }
    );

    const url = URL.createObjectURL(file);
    const link = document.createElement("a");

    link.href = url;
    link.download = "zikr-counters.json";
    link.click();

    URL.revokeObjectURL(url);
    statusBox.textContent = "Counters exported.";
  } catch (error) {
    statusBox.textContent = error.message;
  }
});

// Open the JSON file picker
document.getElementById("importButton").addEventListener("click", () => {
  document.getElementById("importFile").click();
});

// Import counters from a JSON file
document.getElementById("importFile").addEventListener("change", async (event) => {
  const file = event.target.files[0];
  if (!file) return;

  try {
    const parsed = JSON.parse(await file.text());
    const imported = Array.isArray(parsed) ? parsed : parsed.counters;

    if (!Array.isArray(imported)) {
      throw new Error("Invalid file: counters array not found.");
    }

    if (!confirm("Import " + imported.length +
      " counter(s)? Existing counters will be kept.")) {
      return;
    }

    let added = 0;

    for (const item of imported) {
      const name = String(item.name || "").trim();
      const goal = Number(item.goal ?? item.target ?? 1000);
      const count = Number(item.count ?? 0);

      if (
        !name ||
        name.length > 100 ||
        !Number.isSafeInteger(goal) ||
        goal < 1 ||
        goal > 1000000000 ||
        !Number.isSafeInteger(count) ||
        count < 0
      ) {
        continue;
      }

      await post("/api/add", { name, goal });

      // Find the newly added counter by its ID
      const response = await fetch("/api/counters");
      if (!response.ok) throw new Error("Could not reload counters.");

      const current = await response.json();
      const created = current[current.length - 1];

      if (created && count > 0) {
        for (let i = 0; i < Math.min(count, 10000); i++) {
          await post("/api/increment", { id: created.id });
        }
      }

      added++;
    }

    await loadCounters();
    statusBox.textContent = added + " counter(s) imported.";
  } catch (error) {
    statusBox.textContent = "Import failed: " + error.message;
  } finally {
    event.target.value = "";
  }
});