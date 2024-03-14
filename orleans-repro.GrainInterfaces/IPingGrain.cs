using Orleans;

namespace orleans_repro.GrainInterfaces;

public interface IPingGrain : IGrainWithIntegerKey
{
    Task PingAsync();
}
