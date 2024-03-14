using orleans_repro.GrainInterfaces;

namespace orleans_repro.Silo;

public class PingGrain : Grain, IPingGrain
{
    public PingGrain()
    {
    }

    public Task<string> PingAsync(string name)
    {
        return Task.FromResult($"Hello, {name}!");
    }
}