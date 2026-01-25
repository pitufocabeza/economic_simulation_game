import { BrowserRouter, Routes, Route, Link } from "react-router-dom";
import { GameProvider } from "./GameContext";
import MarketPage from "./pages/Market";
import CompanyPage from "./pages/Company";
import ProductionPage from "./pages/Production";
import MapPage from "./pages/Map";
import SimulationSpeedControl from "./components/SimulationSpeedControl"

function App() {
    return (
        <GameProvider>
            <SimulationSpeedControl />
            <BrowserRouter>
                <nav style={{ padding: 10, borderBottom: "1px solid #ccc" }}>
                    <Link to="/company">Company</Link>{" | "}
                    <Link to="/exploration">Exploration</Link>{" | "}
                    <Link to="/market">Market</Link>{" | "}
                    <Link to="/production">Production</Link>
                </nav>

                <div style={{ padding: 20, fontFamily: "sans-serif" }}>
                    <Routes>
                        <Route path="/company" element={<CompanyPage />} />
                        <Route path="/exploration" element={<MapPage />} />
                        <Route path="/market" element={<MarketPage />} />
                        <Route path="/production" element={<ProductionPage />} />
                        <Route path="*" element={<CompanyPage />} />
                    </Routes>
                </div>
            </BrowserRouter>
        </GameProvider>
    );
}

export default App;