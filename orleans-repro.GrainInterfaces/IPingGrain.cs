using Orleans;

namespace orleans_repro.GrainInterfaces;

public interface IPingGrain : IGrainWithIntegerKey
{
    Task<string> PingAsync(string name);
}
