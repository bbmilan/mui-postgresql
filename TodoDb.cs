using Microsoft.EntityFrameworkCore;

public class TodoDb : DbContext
{
    public TodoDb(DbContextOptions<TodoDb> options) : base(options) { }

    public DbSet<Todo> Todos { get; set; }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.HasDefaultSchema("todoschema");
        modelBuilder.Entity<Todo>().ToTable("Todo");
    }
}

