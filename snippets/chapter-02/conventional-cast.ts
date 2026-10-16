declare function reserve(sku: Sku, qty: number): void;

const line: OrderLine = { sku: "" as Sku, qty: 0, cents: -1 };
reserve(line.sku, line.qty); // compiles
