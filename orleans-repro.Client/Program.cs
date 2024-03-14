using orleans_repro.GrainInterfaces;

var builder = WebApplication.CreateBuilder(args);

builder.AddServiceDefaults();
builder.AddKeyedAzureTableService("clustering");
builder.UseOrleansClient();

var app = builder.Build();

app.MapGet("/", async (IClusterClient client, string name = "test") => 
{
    var rand = new Random();
    var id = rand.Next(0, 100);

    try
    {
        return Results.Ok(
            await client.GetGrain<IPingGrain>(id).PingAsync(name)
        );
    }
    catch (Exception ex)
    {
        return Results.Problem(ex.Message, statusCode: 500);
    }
});

app.Run();
