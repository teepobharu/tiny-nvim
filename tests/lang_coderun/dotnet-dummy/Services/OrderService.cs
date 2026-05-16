using DotnetDummy.Models;

namespace DotnetDummy.Services;

public sealed class OrderService(IProductRepository products)
{
    public async Task<Order> CreateOrderAsync(
        string customerName,
        IEnumerable<(int ProductId, int Qty)> lines,
        CancellationToken ct = default)
    {
        var orderLines = new List<OrderLine>();

        foreach (var (productId, qty) in lines)
        {
            var product = await products.FindByIdAsync(productId, ct)
                ?? throw new InvalidOperationException($"Product {productId} not found.");

            orderLines.Add(new OrderLine { Product = product, Quantity = qty });
        }

        return new Order
        {
            CustomerName = customerName,
            Lines = orderLines,
        };
    }

    public async Task<IReadOnlyList<Product>> GetByCategory(Category category, CancellationToken ct = default)
    {
        var all = await products.GetAllAsync(ct);
        return all.Where(p => p.Category == category).ToList();
    }

    public async Task<Dictionary<Category, decimal>> GetAveragePriceByCategoryAsync(CancellationToken ct = default)
    {
        var all = await products.GetAllAsync(ct);
        return all
            .GroupBy(p => p.Category)
            .ToDictionary(g => g.Key, g => g.Average(p => p.Price));
    }
}
