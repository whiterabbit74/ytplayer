import type { Track } from "./api";

const API_BASE = import.meta.env.BASE_URL + "api";

export interface PlayerStateData {
  queue: Track[];
  currentIndex: number;
  position: number;
  repeatMode: "off" | "one";
  currentTrack: Track | null;
  updatedAt?: string;
}

export async function fetchPlayerState(): Promise<PlayerStateData> {
  const res = await fetch(`${API_BASE}/player/state`, {
    credentials: "include",
  });
  if (!res.ok) throw new Error("Failed to fetch player state");
  return res.json();
}

export async function savePlayerState(state: Omit<PlayerStateData, "updatedAt">): Promise<void> {
  await fetch(`${API_BASE}/player/state`, {
    method: "PUT",
    headers: { "Content-Type": "application/json" },
    credentials: "include",
    body: JSON.stringify(state),
  });
}
