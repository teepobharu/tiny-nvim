using DotnetDummy.Models;

namespace DotnetDummy.Services;

public sealed class InMemoryProductRepository : IProductRepository
{
    private static readonly List<Product> _seed =
    [
        new(1, "Laptop",        1299.99m, Category.Electronics),
        new(2, "Clean Code",      34.99m, Category.Books),
        new(3, "T-Shirt",         19.99m, Category.Clothing),
        new(4, "C# in Depth",     44.99m, Category.Books),
        new(5, "Mechanical KB",  159.99m, Category.Electronics),
    ];

    public Task<IReadOnlyList<Product>> GetAllAsync(CancellationToken ct = default) =>
        Task.FromResult<IReadOnlyList<Product>>(_seed);

    public Task<Product?> FindByIdAsync(int id, CancellationToken ct = default) =>
        Task.FromResult(_seed.FirstOrDefault(p => p.Id == id));

    public Task<IReadOnlyList<Product>> SearchAsync(string query, CancellationToken ct = default)
    {
        var results = _seed
            .Where(p => p.Name.Contains(query, StringComparison.OrdinalIgnoreCase))
            .ToList();
        return Task.FromResult<IReadOnlyList<Product>>(results);
    }
}
