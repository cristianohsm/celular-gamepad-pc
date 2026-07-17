namespace PhoneGamepad.Bridge;

public sealed record GamepadFrame(
    int Player,
    long Sequence,
    IReadOnlyDictionary<string, bool> Buttons,
    IReadOnlyDictionary<string, bool> Dpad,
    IReadOnlyDictionary<string, float> Axes)
{
    public static GamepadFrame Neutral(int player, long sequence = 0) => new(
        player,
        sequence,
        Protocol.ButtonNames.ToDictionary(name => name, _ => false),
        Protocol.DpadNames.ToDictionary(name => name, _ => false),
        Protocol.AxisNames.ToDictionary(name => name, _ => 0f));
}
