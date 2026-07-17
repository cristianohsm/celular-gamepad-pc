namespace PhoneGamepad.Bridge;

public sealed class BridgeEngine : IDisposable
{
    private readonly IVirtualGamepadBackend backend;
    private readonly TimeSpan watchdog;
    private readonly Dictionary<int, long> sequences = new() { [1] = -1, [2] = -1 };
    private readonly Dictionary<int, DateTimeOffset> lastSeen = new();
    private readonly HashSet<int> timedOut = [];
    private readonly object sync = new();
    public BridgeEngine(IVirtualGamepadBackend backend, TimeSpan? watchdog = null) { this.backend = backend; this.watchdog = watchdog ?? TimeSpan.FromMilliseconds(750); }
    public void CreateSlots() => backend.CreateSlots();
    public bool Apply(GamepadFrame frame, DateTimeOffset now)
    {
        lock (sync)
        {
            if (frame.Sequence <= sequences[frame.Player]) return false;
            backend.Apply(frame);
            sequences[frame.Player] = frame.Sequence;
            lastSeen[frame.Player] = now;
            timedOut.Remove(frame.Player);
            return true;
        }
    }
    public void Neutralize(int player)
    {
        lock (sync)
        {
            backend.Neutralize(player);
            sequences[player] = -1;
            lastSeen.Remove(player);
            timedOut.Add(player);
        }
    }
    public void Tick(DateTimeOffset now)
    {
        lock (sync)
            foreach (var player in new[] { 1, 2 })
                if (!timedOut.Contains(player) && lastSeen.TryGetValue(player, out var seen) && now - seen >= watchdog)
                {
                    backend.Neutralize(player);
                    timedOut.Add(player);
                }
    }
    public void Dispose() => backend.Dispose();
}
