using DotnetDummy.Models;

namespace DotnetDummy.Services;

public interface IProductRepository
{
    Task<IReadOnlyList<Product>> GetAllAsync(CancellationToken ct = default);
    Task<Product?> FindByIdAsync(int id, CancellationToken ct = default);
    Task<IReadOnlyList<Product>> SearchAsync(string query, CancellationToken ct = default);
}
