using Projects;

var builder = DistributedApplication.CreateBuilder(args);

var storage         = builder.AddAzureStorage("storage").RunAsEmulator();
var clusteringTable = storage.AddTables("clustering");

var orleans = builder.AddOrleans("my-app")
    .WithClustering(clusteringTable);

var silo = builder.AddProject<orleans_repro_Silo>("silo")
    .WithReference(orleans);

var client = builder.AddProject<orleans_repro_Client>("client")
    .WithReference(silo)
    .WithReference(orleans);

builder.Build().Run();
