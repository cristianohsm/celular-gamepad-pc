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
  const activeButtons = new Set();

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
          pairMessage.textContent = "";
          overlay.classList.add("hidden");
          setStatus(true, assignedPlayer ? `Jogador ${assignedPlayer}` : "Conectado");
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
    send({ type: "button", button, state: "down" });
    haptic();
  }

  function release(button, element) {
    if (!button || !activeButtons.has(button)) return;
    activeButtons.delete(button);
    element?.classList.remove("active");
    send({ type: "button", button, state: "up" });
  }

  function releaseAllLocal(notifyServer = true) {
    activeButtons.clear();
    document.querySelectorAll(".active[data-button]").forEach((element) => element.classList.remove("active"));
    document.querySelectorAll(".stick-knob").forEach((knob) => { knob.style.transform = "translate(0, 0)"; });
    if (notifyServer) send({ type: "release_all" });
  }

  document.querySelectorAll("[data-button]").forEach((element) => {
    const button = element.dataset.button;
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
    }

    function finish(event) {
      if (pointerId === null || event.pointerId !== pointerId) return;
      event.preventDefault();
      const elapsed = performance.now() - startTime;
      applyDirections(new Set());
      knob.style.transform = "translate(0, 0)";
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

  window.addEventListener("blur", () => releaseAllLocal());
  document.addEventListener("visibilitychange", () => {
    if (document.hidden) releaseAllLocal();
  });
  window.addEventListener("pagehide", () => releaseAllLocal());

  setInterval(() => {
    if (authenticated) send({ type: "ping" });
  }, 15000);
})();
