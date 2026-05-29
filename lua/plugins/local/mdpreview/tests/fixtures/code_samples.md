# Code Samples — Test Fixture

Tests for S3 (code view) and S5.2 (relative code link).

---

## Code view toggle (S3.3 / S3.4)

This file is an `.md` — click **Code** in the renderer row to see raw source.
Click any renderer button to return to rendered view.

---

## Links to code files (S3.1 / S3.2 / S5.2)

Clicking these opens them in code view with syntax highlighting:

| File | Language |
|------|----------|
| [script.sh](./script.sh) | bash |
| [long_lines.txt](./long_lines.txt) | plain text |

---

## Fenced blocks vs code view

Below is a fenced block rendered by the MD renderer (not code view):

```python
def fibonacci(n):
    a, b = 0, 1
    for _ in range(n):
        a, b = b, a + b
    return a

print(fibonacci(10))
```

```typescript
interface User {
  id: number;
  name: string;
  email?: string;
}

const greet = (u: User): string => `Hello, ${u.name}`;
```

```csharp
using System;

namespace Demo {
    class Program {
        static void Main(string[] args) {
            Console.WriteLine("Hello from C#");
        }
    }
}
```
