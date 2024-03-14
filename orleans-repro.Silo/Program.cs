var builder = WebApplication.CreateBuilder(args);

builder.AddServiceDefaults();
builder.AddKeyedAzureTableService("clustering");
builder.AddKeyedAzureBlobService("grainstate");
builder.UseOrleans();

var app = builder.Build();

app.MapGet("/", () => "Hello World!");

app.Run();
