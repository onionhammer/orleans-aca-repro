using Projects;

var builder = DistributedApplication.CreateBuilder(args);

var storage         = builder.AddAzureStorage("storage").RunAsEmulator();
var clusteringTable = storage.AddTables("clustering");

var orleans = builder.AddOrleans("my-app")
    .WithClustering(clusteringTable);

var silo = builder.AddProject<orleans_repro_Silo>("silo")
    .WithReference(orleans)
    .WithHttpHealthCheck("/")
    .WaitFor(clusteringTable);

var client = builder.AddProject<orleans_repro_Client>("client")
    .WithReference(silo)
    .WithReference(orleans)
    .WithHttpHealthCheck("/")
    .WaitFor(silo);

builder.Build().Run();
