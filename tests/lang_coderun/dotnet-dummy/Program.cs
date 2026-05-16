using DotnetDummy.Models;
using DotnetDummy.Services;
using Microsoft.Extensions.DependencyInjection;

// ── DI setup ──────────────────────────────────────────────────────────────────
var services = new ServiceCollection()
    .AddSingleton<IProductRepository, InMemoryProductRepository>()
    .AddSingleton<OrderService>()
    .BuildServiceProvider();

var repo = services.GetRequiredService<IProductRepository>();
var orderSvc = services.GetRequiredService<OrderService>();

// ── List all products ─────────────────────────────────────────────────────────
Console.WriteLine("=== All Products ===");
var all = await repo.GetAllAsync();
foreach (var p in all)
    Console.WriteLine($"  [{p.Id}] {p.Name,-20} ${p.Price,8:F2}  ({p.Category})");

// ── LINQ: group by category ───────────────────────────────────────────────────
Console.WriteLine("\n=== Average price by category ===");
var avgByCategory = await orderSvc.GetAveragePriceByCategoryAsync();
foreach (var (cat, avg) in avgByCategory.OrderBy(kv => kv.Key.ToString()))
    Console.WriteLine($"  {cat,-15} avg ${avg:F2}");

// ── Search ────────────────────────────────────────────────────────────────────
Console.WriteLine("\n=== Search: 'c#' ===");
var found = await repo.SearchAsync("c#");
Console.WriteLine(found.Count == 0 ? "  (no results)" : string.Join(", ", found.Select(p => p.Name)));

// ── Create order ──────────────────────────────────────────────────────────────
Console.WriteLine("\n=== Order ===");
var order = await orderSvc.CreateOrderAsync("Alice", [(1, 2), (4, 1)]);
Console.WriteLine($"  Customer : {order.CustomerName}");
Console.WriteLine($"  Order ID : {order.Id}");
foreach (var line in order.Lines)
    Console.WriteLine($"  {line.Product.Name,-20} x{line.Quantity}  = ${line.Subtotal:F2}");
Console.WriteLine($"  Total    : ${order.Total:F2}");

// ── Generic helper (exercises generic type hover) ─────────────────────────────
static void PrintList<T>(IEnumerable<T> items, Func<T, string> format)
{
    foreach (var item in items)
        Console.WriteLine($"  {format(item)}");
}

Console.WriteLine("\n=== Electronics via generic helper ===");
var electronics = await orderSvc.GetByCategory(Category.Electronics);
PrintList(electronics, p => $"{p.Name} ${p.Price:F2}");
