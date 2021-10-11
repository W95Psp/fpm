module LibA.Native

[@@plugin]
let rec sum (n: int): int = 
  if n <= 0 then 0 else 1 + sum (n - 1)

