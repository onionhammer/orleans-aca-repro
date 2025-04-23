var builder = WebApplication.CreateBuilder(args);

builder.AddServiceDefaults();
builder.AddKeyedAzureTableClient("clustering");
builder.AddKeyedAzureBlobClient("grainstate");
builder.UseOrleans();

var app = builder.Build();

app.MapGet("/", () => "Hello World!");

app.Run();
