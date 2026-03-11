import type { Track } from "./api";

const API_BASE = import.meta.env.BASE_URL + "api";

export const favoritesApi = {
  async getFavorites(): Promise<Track[]> {
    const res = await fetch(`${API_BASE}/favorites`, { credentials: "include" });
    if (!res.ok) throw new Error("Failed to get favorites");
    return res.json();
  },

  async getFavoriteIds(): Promise<string[]> {
    const res = await fetch(`${API_BASE}/favorites/ids`, { credentials: "include" });
    if (!res.ok) throw new Error("Failed to get favorite ids");
    return res.json();
  },

  async addFavorite(track: Track): Promise<{ id: number }> {
    const res = await fetch(`${API_BASE}/favorites`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      credentials: "include",
      body: JSON.stringify({
        video_id: track.id,
        title: track.title,
        artist: track.artist || "",
        thumbnail: track.thumbnail || "",
        duration: track.duration || 0,
      }),
    });
    if (!res.ok) throw new Error("Failed to add favorite");
    return res.json();
  },

  async removeFavorite(videoId: string): Promise<void> {
    const res = await fetch(`${API_BASE}/favorites/${videoId}`, {
      method: "DELETE",
      credentials: "include",
    });
    if (!res.ok) throw new Error("Failed to remove favorite");
  },
};
