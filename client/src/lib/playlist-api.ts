import type { Track } from "./api";

const API_BASE = import.meta.env.BASE_URL + "api";

export interface Playlist {
  id: number;
  name: string;
  created_at: string;
}

export async function fetchPlaylists(): Promise<Playlist[]> {
  const res = await fetch(`${API_BASE}/playlists`, { credentials: "include" });
  if (!res.ok) throw new Error("Failed to fetch playlists");
  return res.json();
}

export async function createPlaylist(name: string): Promise<Playlist> {
  const res = await fetch(`${API_BASE}/playlists`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    credentials: "include",
    body: JSON.stringify({ name }),
  });
  if (!res.ok) throw new Error("Failed to create playlist");
  return res.json();
}

export async function deletePlaylist(id: number): Promise<void> {
  await fetch(`${API_BASE}/playlists/${id}`, { method: "DELETE", credentials: "include" });
}

export async function fetchPlaylistTracks(playlistId: number): Promise<Track[]> {
  const res = await fetch(`${API_BASE}/playlists/${playlistId}/tracks`, { credentials: "include" });
  if (!res.ok) throw new Error("Failed to fetch playlist tracks");
  return res.json();
}

export async function addTrackToPlaylist(playlistId: number, track: Track): Promise<void> {
  await fetch(`${API_BASE}/playlists/${playlistId}/tracks`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    credentials: "include",
    body: JSON.stringify({
      video_id: track.id,
      title: track.title,
      artist: track.artist,
      thumbnail: track.thumbnail,
      duration: track.duration,
      view_count: track.viewCount,
      like_count: track.likeCount,
    }),
  });
}

export async function removeTrackFromPlaylist(playlistId: number, trackId: number): Promise<void> {
  await fetch(`${API_BASE}/playlists/${playlistId}/tracks/${trackId}`, { method: "DELETE", credentials: "include" });
}

export async function reorderPlaylistTracks(playlistId: number, trackIds: number[]): Promise<void> {
  await fetch(`${API_BASE}/playlists/${playlistId}/tracks/reorder`, {
    method: "PUT",
    headers: { "Content-Type": "application/json" },
    credentials: "include",
    body: JSON.stringify({ trackIds }),
  });
}
