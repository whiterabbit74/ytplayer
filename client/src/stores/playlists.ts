import { create } from "zustand";
import type { Track } from "@/lib/api";
import type { Playlist } from "@/lib/playlist-api";
import * as api from "@/lib/playlist-api";

interface PlaylistsState {
  playlists: Playlist[];
  activePlaylistId: number | null;
  activePlaylistTracks: Track[];

  loadPlaylists: () => Promise<void>;
  createPlaylist: (name: string) => Promise<void>;
  deletePlaylist: (id: number) => Promise<void>;
  selectPlaylist: (id: number | null) => Promise<void>;
  addTrack: (playlistId: number, track: Track) => Promise<void>;
  removeTrack: (playlistId: number, trackId: number) => Promise<void>;
  reorderTracks: (playlistId: number, trackIds: number[]) => Promise<void>;
  isLoading: boolean;
  lastLoaded: number;
}
const LOAD_THRESHOLD = 5000; // 5 seconds
let inFlightLoad: Promise<void> | null = null;

export const usePlaylistsStore = create<PlaylistsState>((set, get) => ({
  playlists: [],
  activePlaylistId: null,
  activePlaylistTracks: [],
  isLoading: false,
  lastLoaded: 0,

  loadPlaylists: async () => {
    const { lastLoaded, isLoading } = get();
    if (isLoading && inFlightLoad) return inFlightLoad;
    if (Date.now() - lastLoaded < LOAD_THRESHOLD) return;

    set({ isLoading: true });
    inFlightLoad = (async () => {
      try {
        const playlists = await api.fetchPlaylists();
        set({ playlists, lastLoaded: Date.now() });
      } catch (err) {
        console.error("Failed to load playlists:", err);
      } finally {
        set({ isLoading: false });
        inFlightLoad = null;
      }
    })();

    return inFlightLoad;
  },

  createPlaylist: async (name) => {
    try {
      await api.createPlaylist(name);
      await get().loadPlaylists();
    } catch (err) {
      console.error("Failed to create playlist:", err);
    }
  },

  deletePlaylist: async (id) => {
    try {
      await api.deletePlaylist(id);
      const { activePlaylistId } = get();
      if (activePlaylistId === id) {
        set({ activePlaylistId: null, activePlaylistTracks: [] });
      }
      await get().loadPlaylists();
    } catch (err) {
      console.error("Failed to delete playlist:", err);
    }
  },

  selectPlaylist: async (id) => {
    if (id === null) {
      set({ activePlaylistId: null, activePlaylistTracks: [] });
      return;
    }
    try {
      const tracks = await api.fetchPlaylistTracks(id);
      set({ activePlaylistId: id, activePlaylistTracks: tracks });
    } catch (err) {
      console.error("Failed to load playlist tracks:", err);
    }
  },

  addTrack: async (playlistId, track) => {
    try {
      await api.addTrackToPlaylist(playlistId, track);
      const { activePlaylistId } = get();
      if (activePlaylistId === playlistId) {
        await get().selectPlaylist(playlistId);
      }
    } catch (err) {
      console.error("Failed to add track:", err);
    }
  },

  removeTrack: async (playlistId, trackId) => {
    try {
      await api.removeTrackFromPlaylist(playlistId, trackId);
      const { activePlaylistId } = get();
      if (activePlaylistId === playlistId) {
        await get().selectPlaylist(playlistId);
      }
    } catch (err) {
      console.error("Failed to remove track:", err);
    }
  },

  reorderTracks: async (playlistId, trackIds) => {
    try {
      await api.reorderPlaylistTracks(playlistId, trackIds);
      const { activePlaylistId } = get();
      if (activePlaylistId === playlistId) {
        await get().selectPlaylist(playlistId);
      }
    } catch (err) {
      console.error("Failed to reorder tracks:", err);
    }
  },
}));
