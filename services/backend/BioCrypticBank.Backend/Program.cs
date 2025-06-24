// services/backend/Program.cs
using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Configuration;
using System.IO;
using BioCrypticBank.Backend.Services.Blockchain; // Add this using directive

var builder = WebApplication.CreateBuilder(args);

// Load configuration from appsettings.json
builder.Configuration
    .SetBasePath(Directory.GetCurrentDirectory())
    .AddJsonFile("appsettings.json", optional: false, reloadOnChange: true)
    .AddEnvironmentVariables(); // Allow environment variables to override appsettings

// Add services to the container.
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// Configure CORS
builder.Services.AddCors(options =>
{
  options.AddDefaultPolicy(
      policy =>
      {
        policy.AllowAnyOrigin() // For MVP, allow any origin. Restrict in production.
                .AllowAnyHeader()
                .AllowAnyMethod();
      });
});

// Register Blockchain Services
// We use AddSingleton for simplicity in MVP, implying a single instance manages blockchain connections.
// In a highly concurrent production system, consider scope based on connection management.
builder.Services.AddSingleton<INearBlockchainService, NearBlockchainService>();
builder.Services.AddSingleton<IEvmBlockchainService, EvmBlockchainService>();

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
  app.UseSwagger();
  app.UseSwaggerUI();
}

app.UseHttpsRedirection();

app.UseRouting();

app.UseCors();

app.UseAuthorization();

app.MapControllers();

app.Run();
