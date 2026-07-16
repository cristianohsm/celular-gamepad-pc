using HIDMaestro;

namespace PhoneGamepad.Bridge;

public interface IVirtualGamepadBackend : IDisposable
{
    void CreateSlots();
    void Apply(GamepadFrame frame);
    void Neutralize(int player);
}

public sealed class FakeGamepadBackend : IVirtualGamepadBackend
{
    public Dictionary<int, GamepadFrame> States { get; } = new();
    public bool Created { get; private set; }
    public bool Disposed { get; private set; }
    public bool FailApply { get; set; }
    public void CreateSlots() { Created = true; States[1] = GamepadFrame.Neutral(1); States[2] = GamepadFrame.Neutral(2); }
    public void Apply(GamepadFrame frame) { if (FailApply) throw new InvalidOperationException("fake backend failure"); States[frame.Player] = frame; }
    public void Neutralize(int player) => States[player] = GamepadFrame.Neutral(player);
    public void Dispose() { if (!Disposed) { Neutralize(1); Neutralize(2); Disposed = true; } }
}

public static class HidMaestroStateMapper
{
    public static float StickX(float value) => 0.5f + Math.Clamp(value, -1f, 1f) * 0.5f;
    public static float StickY(float value) => 0.5f - Math.Clamp(value, -1f, 1f) * 0.5f;

    public static HMGamepadState Map(HMProfile profile, GamepadFrame frame)
    {
        HMButton buttons = HMButton.None;
        if (frame.Buttons["a"]) buttons |= HMButton.A;
        if (frame.Buttons["b"]) buttons |= HMButton.B;
        if (frame.Buttons["x"]) buttons |= HMButton.X;
        if (frame.Buttons["y"]) buttons |= HMButton.Y;
        if (frame.Buttons["lb"]) buttons |= HMButton.LeftBumper;
        if (frame.Buttons["rb"]) buttons |= HMButton.RightBumper;
        if (frame.Buttons["view"]) buttons |= HMButton.Back;
        if (frame.Buttons["menu"]) buttons |= HMButton.Start;
        if (frame.Buttons["leftStick"]) buttons |= HMButton.LeftStick;
        if (frame.Buttons["rightStick"]) buttons |= HMButton.RightStick;
        var x = frame.Dpad["right"] ? 1 : frame.Dpad["left"] ? -1 : 0;
        var y = frame.Dpad["down"] ? 1 : frame.Dpad["up"] ? -1 : 0;
        var hat = (x, y) switch { (0,-1) => HMHat.North, (1,-1) => HMHat.NorthEast, (1,0) => HMHat.East, (1,1) => HMHat.SouthEast, (0,1) => HMHat.South, (-1,1) => HMHat.SouthWest, (-1,0) => HMHat.West, (-1,-1) => HMHat.NorthWest, _ => HMHat.None };
        return new HMGamepadState
        {
            Buttons = buttons,
            Hat = hat,
            Axes = HMGamepadStateHelpers.StandardAxes(profile,
                StickX(frame.Axes["lx"]),
                StickY(frame.Axes["ly"]),
                StickX(frame.Axes["rx"]),
                StickY(frame.Axes["ry"]),
                frame.Axes["lt"], frame.Axes["rt"])
        };
    }
}

public sealed class HidMaestroGamepadBackend : IVirtualGamepadBackend
{
    private readonly HMContext context = new();
    private readonly Dictionary<int, HMController> controllers = new();
    private HMProfile? profile;

    public bool IsInstalled => context.IsDriverInstalled;
    public void Install() => context.InstallDriver();
    public static void CleanupAll() => HMContext.RemoveAllVirtualControllers();
    public void CreateSlots()
    {
        if (!context.IsDriverInstalled) throw new InvalidOperationException("Controle virtual não instalado");
        context.LoadDefaultProfiles();
        profile = context.GetProfile("xbox-360-wired") ?? throw new InvalidOperationException("Perfil xbox-360-wired ausente");
        controllers[1] = context.CreateController(profile);
        controllers[2] = context.CreateController(profile);
    }
    public void Apply(GamepadFrame frame)
    {
        if (profile is null || !controllers.TryGetValue(frame.Player, out var controller)) throw new InvalidOperationException("Slot não criado");
        controller.SubmitState(HidMaestroStateMapper.Map(profile, frame));
    }
    public void Neutralize(int player) { if (profile is not null && controllers.TryGetValue(player, out var controller)) controller.SubmitState(HidMaestroStateMapper.Map(profile, GamepadFrame.Neutral(player))); }
    public void Dispose() { foreach (var player in controllers.Keys.ToArray()) { try { Neutralize(player); } catch { } } context.Dispose(); controllers.Clear(); }
}
