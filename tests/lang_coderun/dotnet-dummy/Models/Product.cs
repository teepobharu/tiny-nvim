namespace DotnetDummy.Models;

public record Product(int Id, string Name, decimal Price, Category Category);

public enum Category
{
    Electronics,
    Books,
    Clothing,
    Food,
}
