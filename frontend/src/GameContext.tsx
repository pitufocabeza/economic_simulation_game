import { createContext, useContext, useState } from "react";

type GameContextType = {
    companyId: number | null;
    setCompanyId: (id: number | null) => void;
};

const GameContext = createContext<GameContextType | null>(null);

export function GameProvider({ children }: { children: React.ReactNode }) {
    const [companyId, setCompanyId] = useState<number | null>(null);

    return (
        <GameContext.Provider value={{ companyId, setCompanyId }}>
            {children}
        </GameContext.Provider>
    );
}

export function useGame() {
    const ctx = useContext(GameContext);
    if (!ctx) {
        throw new Error("useGame must be used inside GameProvider");
    }
    return ctx;
}
