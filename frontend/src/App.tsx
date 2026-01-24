import { useEffect, useState } from "react";
import { apiGet } from "./api";
import { apiPost } from "./api";

type Company = {
    id: number;
    name: string;
    cash: number;
};

type InventoryItem = {
    good_id: number;
    quantity: number;
    good_name?: string;
};

type MarketOrder = {
    id: number;
    order_type: "buy" | "sell";
    quantity: number;
    price_per_unit: number;
    status: string;

    good_id: number;
    good_name: string;

    company_id: number;
    company_name: string;
};

type Good = {
    id: number;
    name: string;
};




function App() {
    const [companies, setCompanies] = useState<Company[]>([]);
    const [companyId, setCompanyId] = useState<number | null>(null);
    const [inventory, setInventory] = useState<InventoryItem[]>([]);
    const [error, setError] = useState<string | null>(null);
    const [orders, setOrders] = useState<MarketOrder[]>([]);
    const [orderType, setOrderType] = useState<"buy" | "sell">("buy");
    const [goodId, setGoodId] = useState<number | null>(null);
    const [price, setPrice] = useState<number>(0);
    const [quantity, setQuantity] = useState<number>(0);

    const [goods, setGoods] = useState<Good[]>([]);

    const loadOrders = async () => {
        try {
            const data = await apiGet<MarketOrder[]>("/market/orders");
            setOrders(data);
        } catch (err: any) {
            setError(err.message);
        }
    };

    const loadInventory = async () => {
        if (!companyId) {
            setInventory([]);
            return;
        }

        try {
            const data = await apiGet<InventoryItem[]>(
                `/inventories/company/${companyId}`
            );
            setInventory(data);
        } catch (err: any) {
            setError(err.message);
        }
    };

    //Order book
    useEffect(() => {
        loadOrders();
        const interval = setInterval(loadOrders, 2000);
        return () => clearInterval(interval);
    }, []);

    useEffect(() => {
    if (!companyId) return;
    loadInventory();
}, [orders]);


    useEffect(() => {
        apiGet<Good[]>("/goods")
            .then(setGoods)
            .catch((err) => setError(err.message));
    }, []);


    // Load companies once
    useEffect(() => {
        apiGet<Company[]>("/companies")
            .then(setCompanies)
            .catch((err) => setError(err.message));
    }, []);

    // Load inventory when company changes
    useEffect(() => {
        loadInventory();
    }, [companyId]);


    const selectedCompany = companies.find((c) => c.id === companyId);

    const buyOrders = orders
        .filter((o) => o.status === "open" && o.order_type === "buy")
        .sort(
            (a, b) =>
                b.price_per_unit - a.price_per_unit || a.id - b.id
        );

    const sellOrders = orders
        .filter((o) => o.status === "open" && o.order_type === "sell")
        .sort(
            (a, b) =>
                a.price_per_unit - b.price_per_unit || a.id - b.id
    );

    const submitOrder = async () => {
        if (!companyId || !goodId) {
            setError("Select company and good");
            return;
        }

        try {
            await apiPost(`/market/orders/${companyId}`, {
                order_type: orderType,
                good_id: goodId,
                price_per_unit: price,
                quantity,
            });

            // 🔁 Explicitly sync state
            await Promise.all([
                loadOrders(),
                loadInventory(), // 👈 THIS is what you were missing
            ]);

            setPrice(0);
            setQuantity(0);
            setError(null);
        } catch (err: any) {
            setError(err.message || "Order failed");
        }
    };

    const cancelOrder = async (orderId: number) => {
        if (!companyId) return;

        try {
            await apiPost(
                `/market/orders/${orderId}/cancel?company_id=${companyId}`,
                {}
            );

            await Promise.all([
                loadOrders(),
                loadInventory(),
            ]);
        } catch (e: any) {
            setError(e.message);
        }
    };



    return (
        <div style={{ padding: 20, fontFamily: "sans-serif" }}>
            <h1>Economy Dashboard</h1>

            {error && (
                <div style={{ color: "red", marginBottom: 10 }}>
                    {error}
                </div>
            )}

            {/* Company Selector */}
            <div style={{ marginBottom: 20 }}>
                <label>
                    Company:&nbsp;
                    <select
                        value={companyId ?? ""}
                        onChange={(e) =>
                            setCompanyId(
                                e.target.value ? Number(e.target.value) : null
                            )
                        }
                    >
                        <option value="">Select company</option>
                        {companies.map((c) => (
                            <option key={c.id} value={c.id}>
                                {c.name}
                            </option>
                        ))}
                    </select>
                </label>

                {selectedCompany && (
                    <span style={{ marginLeft: 20 }}>
                        💰 Cash: <strong>{selectedCompany.cash}</strong>
                    </span>
                )}
            </div>

            {/* Inventory */}
            {companyId && (
                <>
                    <h2>Inventory</h2>

                    {inventory.length === 0 ? (
                        <p>No inventory</p>
                    ) : (
                        <table border={1} cellPadding={6}>
                            <thead>
                                <tr>
                                    <th>Good</th>
                                    <th>Quantity</th>
                                </tr>
                            </thead>
                            <tbody>
                                {inventory.map((item) => (
                                    <tr key={item.good_id}>
                                        <td>{item.good_name ?? item.good_id}</td>
                                        <td>
                                            {item.quantity - item.reserved} available
                                            {item.reserved > 0 && (
                                                <span style={{ color: "gray" }}>
                                                    {" "}({item.reserved} reserved)
                                                </span>
                                            )}
                                        </td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                    )}
                </>
            )}
            {(
                <>
                    <h2>Market</h2>

                    <table border={1} cellPadding={6}>
                        <thead>
                            <tr>
                                <th>Type</th>
                                <th>Good</th>
                                <th>Price</th>
                                <th>Quantity</th>
                                <th>Company</th>
                                <th>Action</th>
                            </tr>
                        </thead>
                        <tbody>
                            {orders
                                .filter((o) => o.status === "open")
                                .sort((a, b) =>
                                    a.good_name.localeCompare(b.good_name) ||
                                    (a.order_type === "buy"
                                        ? b.price_per_unit - a.price_per_unit
                                        : a.price_per_unit - b.price_per_unit)
                                )
                                .map((o) => (
                                    <tr key={o.id}>
                                        <td>{o.order_type}</td>
                                        <td>{o.good_name}</td>
                                        <td>{o.price_per_unit}</td>
                                        <td>{o.quantity}</td>
                                        <td>{o.company_name}</td>
                                        <td>
                                            {companyId === o.company_id && o.status === "open" && (
                                                <button onClick={() => cancelOrder(o.id)}>
                                                    Cancel
                                                </button>
                                            )}
                                        </td>
                                    </tr>
                                ))}
                        </tbody>
                    </table>
                    {companyId && (
                        <>
                            <h2>Place Order</h2>

                            <div style={{ display: "flex", gap: 10, alignItems: "center" }}>
                                <select
                                    value={orderType}
                                    onChange={(e) => setOrderType(e.target.value as any)}
                                >
                                    <option value="buy">Buy</option>
                                    <option value="sell">Sell</option>
                                </select>

                                <select
                                    value={goodId ?? ""}
                                    onChange={(e) => setGoodId(Number(e.target.value))}
                                >
                                    <option value="">Select good</option>
                                    {goods.map((g) => (
                                        <option key={g.id} value={g.id}>
                                            {g.name}
                                        </option>
                                    ))}
                                </select>

                                <label style={{ marginLeft: 10 }}>
                                    Price&nbsp;
                                    <input
                                        type="number"
                                        value={price}
                                        onChange={(e) => setPrice(Number(e.target.value))}
                                        style={{ width: 80 }}
                                    />
                                </label>

                                <label style={{ marginLeft: 10 }}>
                                    Quantity&nbsp;
                                    <input
                                        type="number"
                                        value={quantity}
                                        onChange={(e) => setQuantity(Number(e.target.value))}
                                        style={{ width: 80 }}
                                    />
                                </label>


                                <button onClick={submitOrder}>Submit</button>
                            </div>
                        </>
                    )}

                </>
            )}
        </div>
    );
}

export default App;
