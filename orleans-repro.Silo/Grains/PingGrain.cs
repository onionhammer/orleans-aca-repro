using orleans_repro.GrainInterfaces;

namespace orleans_repro.Silo;

public class PingGrain : Grain, IPingGrain
{
    public PingGrain()
    {
    }

    public Task PingAsync()
    {
        Console.WriteLine("Ping!");
        return Task.CompletedTask;
    }
}