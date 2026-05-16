namespace DotnetDummy.Models;

public class Order
{
    public Guid Id { get; init; } = Guid.NewGuid();
    public required string CustomerName { get; init; }
    public List<OrderLine> Lines { get; init; } = [];
    public DateTime CreatedAt { get; init; } = DateTime.UtcNow;

    public decimal Total => Lines.Sum(l => l.Subtotal);
}

public class OrderLine
{
    public required Product Product { get; init; }
    public int Quantity { get; set; }
    public decimal Subtotal => Product.Price * Quantity;
}
