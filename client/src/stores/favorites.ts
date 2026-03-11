import { create } from "zustand";
import { favoritesApi } from "../lib/favorites-api";
import type { Track } from "../lib/api";

type FavoritesState = {
  favoriteIds: Set<string>;
  favorites: Track[];
  isLoading: boolean;
  loadFavorites: () => Promise<void>;
  loadFavoriteIds: () => Promise<void>;
  toggleFavorite: (track: Track) => Promise<void>;
  isFavorite: (videoId: string) => boolean;
};

export const useFavoritesStore = create<FavoritesState>((set, get) => ({
  favoriteIds: new Set(),
  favorites: [],
  isLoading: false,

  loadFavorites: async () => {
    set({ isLoading: true });
    try {
      const tracks = await favoritesApi.getFavorites();
      const ids = new Set(tracks.map(t => t.id));
      set({ favorites: tracks, favoriteIds: ids, isLoading: false });
    } catch (err) {
      console.error("Failed to load favorites", err);
      set({ isLoading: false });
    }
  },

  loadFavoriteIds: async () => {
    try {
      const idsArray = await favoritesApi.getFavoriteIds();
      set({ favoriteIds: new Set(idsArray) });
    } catch (err) {
      console.error("Failed to load favorite ids", err);
    }
  },

  toggleFavorite: async (track: Track) => {
    const { favoriteIds, favorites } = get();
    const isFav = favoriteIds.has(track.id);
    
    // Optimistic update
    const newIds = new Set(favoriteIds);
    let newFavorites = [...favorites];
    
    if (isFav) {
      newIds.delete(track.id);
      newFavorites = newFavorites.filter(t => t.id !== track.id);
    } else {
      newIds.add(track.id);
      newFavorites = [track, ...newFavorites]; // Add to top
    }
    
    set({ favoriteIds: newIds, favorites: newFavorites });
    
    // API call
    try {
      if (isFav) {
        await favoritesApi.removeFavorite(track.id);
      } else {
        await favoritesApi.addFavorite(track);
      }
    } catch (err) {
      // Revert optimistic update on error
      console.error("Failed to toggle favorite", err);
      set({ favoriteIds, favorites });
    }
  },

  isFavorite: (videoId: string) => {
    return get().favoriteIds.has(videoId);
  },
}));
