import { create } from "zustand";
import { persist } from "zustand/middleware";

interface SettingsState {
  squareCovers: boolean;
  setSquareCovers: (value: boolean) => void;
}

export const useSettingsStore = create<SettingsState>()(
  persist(
    (set) => ({
      squareCovers: false,
      setSquareCovers: (value) => set({ squareCovers: value }),
    }),
    {
      name: "settings-storage",
    }
  )
);
