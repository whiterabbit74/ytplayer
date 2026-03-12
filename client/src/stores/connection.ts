import { create } from "zustand";

interface ConnectionState {
  isAvailable: boolean;
  setAvailable: (available: boolean) => void;
}

export const useConnectionStore = create<ConnectionState>((set) => ({
  isAvailable: true,
  setAvailable: (available) => set({ isAvailable: available }),
}));
