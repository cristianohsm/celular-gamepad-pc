(() => {
  "use strict";

  const overlay = document.getElementById("pairingOverlay");
  const pairingForm = document.getElementById("pairingForm");
  const pinInput = document.getElementById("pinInput");
  const playerSelect = document.getElementById("playerSelect");
  const pairMessage = document.getElementById("pairMessage");
  const statusEl = document.getElementById("status");
  const tabs = [...document.querySelectorAll(".tab")];
  const views = {
    snes: document.getElementById("snesLayout"),
    ps5: document.getElementById("ps5Layout"),
  };

  let socket = null;
  let authenticated = false;
  let assignedPlayer = null;
  let outputMode = "keyboard";
  const activeButtons = new Set();
  const buttonMap = {
    snes_up: ["dpad", "up"], snes_down: ["dpad", "down"], snes_left: ["dpad", "left"], snes_right: ["dpad", "right"],
    snes_a: ["buttons", "a"], snes_b: ["buttons", "b"], snes_x: ["buttons", "x"], snes_y: ["buttons", "y"],
    snes_l: ["buttons", "lb"], snes_r: ["buttons", "rb"], snes_start: ["buttons", "menu"], snes_select: ["buttons", "view"],
    ps5_dpad_up: ["dpad", "up"], ps5_dpad_down: ["dpad", "down"], ps5_dpad_left: ["dpad", "left"], ps5_dpad_right: ["dpad", "right"],
    ps5_cross: ["buttons", "a"], ps5_circle: ["buttons", "b"], ps5_square: ["buttons", "x"], ps5_triangle: ["buttons", "y"],
    ps5_l1: ["buttons", "lb"], ps5_r1: ["buttons", "rb"], ps5_create: ["buttons", "view"], ps5_options: ["buttons", "menu"],
    ps5_l3: ["buttons", "leftStick"], ps5_r3: ["buttons", "rightStick"],
  };
  const makeNeutralState = () => ({
    buttons: { a: false, b: false, x: false, y: false, lb: false, rb: false, view: false, menu: false, leftStick: false, rightStick: false },
    dpad: { up: false, down: false, left: false, right: false },
    axes: { lx: 0, ly: 0, rx: 0, ry: 0, lt: 0, rt: 0 },
  });
  let gamepadState = makeNeutralState();
  let gamepadSequence = 0;
  let lastGamepadSend = 0;
  let pendingGamepadTimer = null;

  function setStatus(connected, message = connected ? "Conectado" : "Desconectado") {
    statusEl.classList.toggle("connected", connected);
    statusEl.classList.toggle("disconnected", !connected);
    statusEl.lastChild.nodeValue = message;
  }

  function wsUrl() {
    const protocol = location.protocol === "https:" ? "wss:" : "ws:";
    return `${protocol}//${location.host}/ws`;
  }

  function send(payload) {
    if (!socket || socket.readyState !== WebSocket.OPEN) return;
    socket.send(JSON.stringify(payload));
  }

  function sendGamepadState(immediate = false) {
    if (!authenticated || outputMode !== "xinput" || !assignedPlayer) return;
    const now = performance.now();
    const wait = Math.max(0, 1000 / 60 - (now - lastGamepadSend));
    if (!immediate && wait > 0) {
      if (pendingGamepadTimer === null) pendingGamepadTimer = window.setTimeout(() => {
        pendingGamepadTimer = null;
        sendGamepadState(true);
      }, wait);
      return;
    }
    lastGamepadSend = performance.now();
    send({ type: "gamepad_state", protocolVersion: 2, player: assignedPlayer, sequence: ++gamepadSequence,
      timestamp: Date.now(), buttons: { ...gamepadState.buttons }, dpad: { ...gamepadState.dpad }, axes: { ...gamepadState.axes } });
  }

  function setVirtualButton(button, value) {
    const target = buttonMap[button];
    if (!target) return false;
    gamepadState[target[0]][target[1]] = value;
    sendGamepadState();
    return true;
  }

  function connect(pin, requestedPlayer) {
    pairMessage.textContent = "Conectando...";
    setStatus(false, "Conectando");
    socket = new WebSocket(wsUrl());

    socket.addEventListener("open", () => {
      send({ type: "auth", pin, player: requestedPlayer });
    });

    socket.addEventListener("message", (event) => {
      let message;
      try {
        message = JSON.parse(event.data);
      } catch {
        return;
      }

      if (message.type === "auth") {
        if (message.ok) {
          authenticated = true;
          assignedPlayer = Number(message.player) || null;
          outputMode = message.outputMode === "xinput" ? "xinput" : "keyboard";
          gamepadState = makeNeutralState();
          gamepadSequence = 0;
          pairMessage.textContent = "";
          overlay.classList.add("hidden");
          const modeLabel = outputMode === "xinput" ? "Controle virtual" : "Teclado";
          setStatus(true, assignedPlayer ? `Jogador ${assignedPlayer} · ${modeLabel}` : modeLabel);
          try {
            localStorage.setItem("gamepadPin", pin);
            localStorage.setItem("gamepadPlayerPreference", requestedPlayer);
          } catch {}
        } else {
          authenticated = false;
          pairMessage.textContent = message.message || "PIN incorreto.";
          setStatus(false);
          socket.close();
        }
      } else if (message.type === "input_error") {
        console.error("Falha de entrada no Windows:", message.message);
        setStatus(true, "Erro de entrada");
        window.setTimeout(() => {
          if (authenticated) setStatus(true, assignedPlayer ? `Jogador ${assignedPlayer}` : "Conectado");
        }, 2500);
      }
    });

    socket.addEventListener("close", () => {
      releaseAllLocal(false);
      authenticated = false;
      assignedPlayer = null;
      outputMode = "keyboard";
      setStatus(false);
      overlay.classList.remove("hidden");
      pairMessage.textContent = pairMessage.textContent || "A conexão foi encerrada. Digite o PIN atual do PC.";
    });

    socket.addEventListener("error", () => {
      pairMessage.textContent = "Não foi possível conectar. Confira o Wi-Fi e o Firewall do Windows.";
    });
  }

  pairingForm.addEventListener("submit", (event) => {
    event.preventDefault();
    const pin = pinInput.value.replace(/\D/g, "").slice(0, 4);
    if (pin.length !== 4) {
      pairMessage.textContent = "Digite os quatro números do PIN.";
      return;
    }
    connect(pin, playerSelect.value);
  });

  pinInput.addEventListener("input", () => {
    pinInput.value = pinInput.value.replace(/\D/g, "").slice(0, 4);
  });

  try {
    const savedPin = localStorage.getItem("gamepadPin");
    const savedPlayer = localStorage.getItem("gamepadPlayerPreference");
    if (savedPin && /^\d{4}$/.test(savedPin)) pinInput.value = savedPin;
    if (["auto", "1", "2"].includes(savedPlayer)) playerSelect.value = savedPlayer;
  } catch {}

  tabs.forEach((tab) => {
    tab.addEventListener("click", () => {
      const layout = tab.dataset.layout;
      tabs.forEach((item) => item.classList.toggle("active", item === tab));
      Object.entries(views).forEach(([name, view]) => view.classList.toggle("active", name === layout));
      releaseAllLocal();
    });
  });

  function haptic() {
    try { navigator.vibrate?.(10); } catch {}
  }

  function press(button, element) {
    if (!authenticated || !button || activeButtons.has(button)) return;
    activeButtons.add(button);
    element?.classList.add("active");
    if (outputMode === "xinput") setVirtualButton(button, true);
    else send({ type: "button", button, state: "down" });
    haptic();
  }

  function release(button, element) {
    if (!button || !activeButtons.has(button)) return;
    activeButtons.delete(button);
    element?.classList.remove("active");
    if (outputMode === "xinput") setVirtualButton(button, false);
    else send({ type: "button", button, state: "up" });
  }

  function releaseAllLocal(notifyServer = true) {
    activeButtons.clear();
    document.querySelectorAll(".active[data-button]").forEach((element) => element.classList.remove("active"));
    document.querySelectorAll(".stick-knob").forEach((knob) => { knob.style.transform = "translate(0, 0)"; });
    gamepadState = makeNeutralState();
    if (outputMode === "xinput") sendGamepadState(true);
    if (notifyServer) send({ type: "release_all" });
  }

  document.querySelectorAll("[data-button]").forEach((element) => {
    const button = element.dataset.button;
    if (["ps5_l2", "ps5_r2"].includes(button)) return;
    element.addEventListener("pointerdown", (event) => {
      event.preventDefault();
      element.setPointerCapture?.(event.pointerId);
      press(button, element);
    });
    const end = (event) => {
      event.preventDefault();
      release(button, element);
    };
    element.addEventListener("pointerup", end);
    element.addEventListener("pointercancel", end);
    element.addEventListener("lostpointercapture", end);
    element.addEventListener("contextmenu", (event) => event.preventDefault());
  });

  function setupStick(stick) {
    const prefix = stick.dataset.stick;
    const clickButton = stick.dataset.click;
    const knob = stick.querySelector(".stick-knob");
    let pointerId = null;
    let currentDirections = new Set();
    let startTime = 0;
    let maxDistance = 0;

    function applyDirections(nextDirections) {
      if (outputMode === "xinput") return;
      for (const direction of currentDirections) {
        if (!nextDirections.has(direction)) release(`${prefix}_${direction}`);
      }
      for (const direction of nextDirections) {
        if (!currentDirections.has(direction)) press(`${prefix}_${direction}`);
      }
      currentDirections = nextDirections;
    }

    function move(event) {
      if (event.pointerId !== pointerId) return;
      const rect = stick.getBoundingClientRect();
      const centerX = rect.left + rect.width / 2;
      const centerY = rect.top + rect.height / 2;
      const dx = event.clientX - centerX;
      const dy = event.clientY - centerY;
      const radius = rect.width * 0.34;
      const distance = Math.hypot(dx, dy);
      maxDistance = Math.max(maxDistance, distance);
      const factor = distance > radius ? radius / distance : 1;
      const clampedX = dx * factor;
      const clampedY = dy * factor;
      knob.style.transform = `translate(${clampedX}px, ${clampedY}px)`;

      const normalizedX = clampedX / radius;
      const normalizedY = clampedY / radius;
      const threshold = 0.36;
      const next = new Set();
      if (normalizedX < -threshold) next.add("left");
      if (normalizedX > threshold) next.add("right");
      if (normalizedY < -threshold) next.add("up");
      if (normalizedY > threshold) next.add("down");
      applyDirections(next);
      if (outputMode === "xinput") {
        const xAxis = prefix === "ps5_lstick" ? "lx" : "rx";
        const yAxis = prefix === "ps5_lstick" ? "ly" : "ry";
        const deadZone = 0.12;
        const smooth = 0.15;
        const filteredX = Math.abs(normalizedX) < deadZone ? 0 : normalizedX;
        const filteredY = Math.abs(normalizedY) < deadZone ? 0 : normalizedY;
        gamepadState.axes[xAxis] += (Math.max(-1, Math.min(1, filteredX)) - gamepadState.axes[xAxis]) * (1 - smooth);
        gamepadState.axes[yAxis] += (Math.max(-1, Math.min(1, filteredY)) - gamepadState.axes[yAxis]) * (1 - smooth);
        sendGamepadState();
      }
    }

    function finish(event) {
      if (pointerId === null || event.pointerId !== pointerId) return;
      event.preventDefault();
      const elapsed = performance.now() - startTime;
      applyDirections(new Set());
      knob.style.transform = "translate(0, 0)";
      if (outputMode === "xinput") {
        gamepadState.axes[prefix === "ps5_lstick" ? "lx" : "rx"] = 0;
        gamepadState.axes[prefix === "ps5_lstick" ? "ly" : "ry"] = 0;
        sendGamepadState(true);
      }
      if (elapsed < 220 && maxDistance < stick.clientWidth * 0.12) {
        press(clickButton, stick);
        setTimeout(() => release(clickButton, stick), 80);
      }
      pointerId = null;
    }

    stick.addEventListener("pointerdown", (event) => {
      event.preventDefault();
      if (pointerId !== null) return;
      pointerId = event.pointerId;
      startTime = performance.now();
      maxDistance = 0;
      stick.setPointerCapture?.(event.pointerId);
      move(event);
      haptic();
    });
    stick.addEventListener("pointermove", move);
    stick.addEventListener("pointerup", finish);
    stick.addEventListener("pointercancel", finish);
    stick.addEventListener("lostpointercapture", finish);
    stick.addEventListener("contextmenu", (event) => event.preventDefault());
  }

  document.querySelectorAll("[data-stick]").forEach(setupStick);

  function setupTrigger(element, axis) {
    let pointerId = null;
    const update = (event) => {
      if (event.pointerId !== pointerId || outputMode !== "xinput") return;
      const rect = element.getBoundingClientRect();
      const positional = 1 - Math.max(0, Math.min(1, (event.clientY - rect.top) / rect.height));
      gamepadState.axes[axis] = event.pressure > 0 && event.pointerType === "pen" ? event.pressure : Math.max(0.15, positional);
      element.classList.add("active");
      sendGamepadState();
    };
    const finish = (event) => {
      if (event.pointerId !== pointerId) return;
      event.preventDefault(); pointerId = null; gamepadState.axes[axis] = 0; element.classList.remove("active");
      if (outputMode === "xinput") sendGamepadState(true); else send({ type: "button", button: element.dataset.button, state: "up" });
    };
    element.addEventListener("pointerdown", (event) => {
      event.preventDefault(); pointerId = event.pointerId; element.setPointerCapture?.(pointerId);
      if (outputMode === "xinput") update(event); else { element.classList.add("active"); send({ type: "button", button: element.dataset.button, state: "down" }); }
    });
    element.addEventListener("pointermove", update);
    element.addEventListener("pointerup", finish);
    element.addEventListener("pointercancel", finish);
    element.addEventListener("lostpointercapture", finish);
  }
  setupTrigger(document.querySelector('[data-button="ps5_l2"]'), "lt");
  setupTrigger(document.querySelector('[data-button="ps5_r2"]'), "rt");

  window.addEventListener("blur", () => releaseAllLocal());
  document.addEventListener("visibilitychange", () => {
    if (document.hidden) releaseAllLocal();
  });
  window.addEventListener("pagehide", () => releaseAllLocal());

  setInterval(() => {
    if (authenticated) send({ type: "ping" });
  }, 15000);
})();
