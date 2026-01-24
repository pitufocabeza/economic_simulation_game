import { useEffect, useState } from "react";
import { apiGet } from "./api";
import { apiPost } from "./api";

import {
    ComposedChart,
    XAxis,
    YAxis,
    Tooltip,
    CartesianGrid,
    Bar
} from "recharts";


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

type OrderBookLevel = {
    price: number;
    quantity: number;
};

type OrderBook = {
    buy: OrderBookLevel[];
    sell: OrderBookLevel[];
};

type MarketStats = {
    last_price: number | null;
    best_bid: number | null;
    best_ask: number | null;
    spread: number | null;
};

type Candle = {
    time: string;
    open: number;
    high: number;
    low: number;
    close: number;
    volume: number;
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
    const [trades, setTrades] = useState<MarketTrade[]>([]);
    const [orderBook, setOrderBook] = useState<OrderBook | null>(null);
    const [marketStats, setMarketStats] = useState<MarketStats | null>(null);

    const [candles, setCandles] = useState<Candle[]>([]);
    const [selectedGoodForChart, setSelectedGoodForChart] = useState<number | null>(null);


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

    useEffect(() => {
        if (!goodId) {
            setOrderBook(null);
            return;
        }

        const loadOrderBook = () => {
            apiGet<OrderBook>(`/market/orderbook/${goodId}`)
                .then(setOrderBook)
                .catch((err) => setError(err.message));
        };

        loadOrderBook();
        const interval = setInterval(loadOrderBook, 2000);

        return () => clearInterval(interval);
    }, [goodId]);

    //Market history
    useEffect(() => {
        const loadTrades = () => {
            apiGet<MarketTrade[]>("/market/trades")
                .then(setTrades)
                .catch((err) => setError(err.message));
        };

        loadTrades();
        const interval = setInterval(loadTrades, 3000);

        return () => clearInterval(interval);
    }, []);


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

    //Market statistics
    useEffect(() => {
        if (!goodId) {
            setMarketStats(null);
            return;
        }

        const loadStats = () => {
            apiGet<MarketStats>(`/market/stats/${goodId}`)
                .then(setMarketStats)
                .catch((err) => setError(err.message));
        };

        loadStats();
        const interval = setInterval(loadStats, 2000);

        return () => clearInterval(interval);
    }, [goodId]);

    useEffect(() => {
        if (!selectedGoodForChart) {
            setCandles([]);
            return;
        }

        apiGet<Candle[]>(`/market/candles/${selectedGoodForChart}?minutes=60`)
            .then(setCandles)
            .catch(err => setError(err.message));
    }, [selectedGoodForChart]);


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

                    <h2>Market Chart</h2>

                    <select
                        value={selectedGoodForChart ?? ""}
                        onChange={(e) =>
                            setSelectedGoodForChart(
                                e.target.value ? Number(e.target.value) : null
                            )
                        }
                    >
                        <option value="">Select good</option>
                        {goods.map(g => (
                            <option key={g.id} value={g.id}>
                                {g.name}
                            </option>
                        ))}
                    </select>

                    {candles.length > 0 && (
                        <ComposedChart
                            width={800}
                            height={400}
                            data={candles}
                            margin={{ top: 20, right: 30, left: 20, bottom: 20 }}
                        >
                            <CartesianGrid strokeDasharray="3 3" />
                            <XAxis dataKey="time" />
                            <YAxis />
                            <Tooltip />

                            {/* Volume bars */}
                            <Bar
                                dataKey="volume"
                                fill="#8884d8"
                                yAxisId={0}
                            />

                            {/* Fake candlestick bodies */}
                            <Bar
                                dataKey={(d) => Math.abs(d.close - d.open)}
                                fill={(d: any) =>
                                    d.close >= d.open ? "#4caf50" : "#f44336"
                                }
                                yAxisId={0}
                            />
                        </ComposedChart>
                    )}


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
                    <h2>Market Trade History</h2>

                    {trades.length === 0 ? (
                        <p>No trades yet</p>
                    ) : (
                        <table border={1} cellPadding={6}>
                            <thead>
                                <tr>
                                    <th>Good</th>
                                    <th>Price</th>
                                    <th>Quantity</th>
                                    <th>Buyer</th>
                                    <th>Seller</th>
                                    <th>Time</th>
                                </tr>
                            </thead>
                            <tbody>
                                {trades.map((t) => (
                                    <tr key={t.id}>
                                        <td>{t.good_id}</td>
                                        <td>{t.price_per_unit}</td>
                                        <td>{t.quantity}</td>
                                        <td>{t.buyer_company_id}</td>
                                        <td>{t.seller_company_id}</td>
                                        <td>{new Date(t.created_at).toLocaleTimeString()}</td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                    )}
                    {marketStats && (
                        <div style={{ marginBottom: 20 }}>
                            <h2>Market Stats</h2>
                            <div style={{ display: "flex", gap: 20 }}>
                                <div>Last price: <strong>{marketStats.last_price ?? "–"}</strong></div>
                                <div>Best bid: <strong>{marketStats.best_bid ?? "–"}</strong></div>
                                <div>Best ask: <strong>{marketStats.best_ask ?? "–"}</strong></div>
                                <div>Spread: <strong>{marketStats.spread ?? "–"}</strong></div>
                            </div>
                        </div>
                    )}
                    {orderBook && (
                        <>
                            <h2>Order Book Depth</h2>

                            <div style={{ display: "flex", gap: 40 }}>
                                <div>
                                    <h3>Buy</h3>
                                    <table border={1} cellPadding={6}>
                                        <thead>
                                            <tr>
                                                <th>Price</th>
                                                <th>Total Qty</th>
                                            </tr>
                                        </thead>
                                        <tbody>
                                            {orderBook.buy.map((b, i) => (
                                                <tr key={i}>
                                                    <td>{b.price}</td>
                                                    <td>{b.quantity}</td>
                                                </tr>
                                            ))}
                                        </tbody>
                                    </table>
                                </div>

                                <div>
                                    <h3>Sell</h3>
                                    <table border={1} cellPadding={6}>
                                        <thead>
                                            <tr>
                                                <th>Price</th>
                                                <th>Total Qty</th>
                                            </tr>
                                        </thead>
                                        <tbody>
                                            {orderBook.sell.map((s, i) => (
                                                <tr key={i}>
                                                    <td>{s.price}</td>
                                                    <td>{s.quantity}</td>
                                                </tr>
                                            ))}
                                        </tbody>
                                    </table>
                                </div>
                            </div>
                        </>
                    )}

                </>
            )}
        </div>
    );
}

export default App;
