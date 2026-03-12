import { create } from "zustand";
import type { Track } from "@/lib/api";

interface PlayerState {
  currentTrack: Track | null;
  queue: Track[];
  currentIndex: number;
  isPlaying: boolean;
  repeatMode: "off" | "one";
  searchResults: Track[];
  nextPageToken: string | null;

  play: (track: Track) => void;
  playTrackInContext: (track: Track, queue: Track[]) => void;
  playFromQueue: (index: number) => void;
  pause: () => void;
  resume: () => void;
  addToQueue: (track: Track) => void;
  removeFromQueue: (index: number) => void;
  playNext: () => void;
  playPrev: () => void;
  toggleRepeat: () => void;
  setSearchResults: (tracks: Track[], nextPageToken?: string) => void;
  appendSearchResults: (tracks: Track[], nextPageToken?: string) => void;
  clearQueue: () => void;
  setQueue: (tracks: Track[], index?: number) => void;
  shuffle: () => void;
}

export const usePlayerStore = create<PlayerState>()(
    (set, get) => ({
      currentTrack: null,
      queue: [],
      currentIndex: -1,
      isPlaying: false,
      repeatMode: "off" as const,
      searchResults: [],
      nextPageToken: null,

      play: (track) => {
        const { queue } = get();
        const idx = queue.findIndex((t) => t.id === track.id);
        if (idx >= 0) {
          set({ currentTrack: track, isPlaying: true, currentIndex: idx });
        } else {
          // If not in queue, add it and play
          set({
            queue: [...queue, track],
            currentTrack: track,
            isPlaying: true,
            currentIndex: queue.length
          });
        }
      },

      playTrackInContext: (track, newQueue) => {
        const idx = newQueue.findIndex((t) => t.id === track.id);
        set({
          queue: newQueue,
          currentTrack: track,
          currentIndex: idx >= 0 ? idx : 0,
          isPlaying: true
        });
      },

      playFromQueue: (index) => {
        const { queue } = get();
        if (index < 0 || index >= queue.length) return;
        set({
          currentTrack: queue[index],
          currentIndex: index,
          isPlaying: true,
        });
      },

      pause: () => set({ isPlaying: false }),
      resume: () => set({ isPlaying: true }),

      addToQueue: (track) =>
        set((state) => ({ queue: [...state.queue, track] })),

      removeFromQueue: (index) =>
        set((state) => {
          const newQueue = state.queue.filter((_, i) => i !== index);
          let newIndex = state.currentIndex;
          if (index < state.currentIndex) {
            newIndex--;
          } else if (index === state.currentIndex) {
            // Removing current track: stay at same index (next track slides in)
            // If it was the last item, step back
            if (newIndex >= newQueue.length) {
              newIndex = newQueue.length - 1;
            }
          }
          return { queue: newQueue, currentIndex: newIndex };
        }),

      playNext: () => {
        const { queue, currentIndex, repeatMode } = get();
        if (queue.length === 0) return;

        let nextIdx = currentIndex + 1;
        if (nextIdx >= queue.length) {
          if (repeatMode === "off") {
            set({ isPlaying: false });
            return;
          } else {
            // "one" is handled by useAudio, so "off" here means we stop.
            // If we had "all", we would loop here.
            set({ isPlaying: false });
            return;
          }
        }
        
        set({
          currentTrack: queue[nextIdx],
          currentIndex: nextIdx,
          isPlaying: true,
        });
      },

      toggleRepeat: () =>
        set((state) => ({
          repeatMode: state.repeatMode === "off" ? "one" : "off",
        })),

      playPrev: () => {
        const { queue, currentIndex } = get();
        if (currentIndex <= 0) return;
        const prevIdx = currentIndex - 1;
        set({
          currentTrack: queue[prevIdx],
          currentIndex: prevIdx,
          isPlaying: true,
        });
      },

      setSearchResults: (tracks, nextPageToken) =>
        set({ searchResults: tracks, nextPageToken: nextPageToken ?? null }),

      appendSearchResults: (tracks, nextPageToken) =>
        set((state) => {
          const existingIds = new Set(state.searchResults.map((t) => t.id));
          const newTracks = tracks.filter((t) => !existingIds.has(t.id));
          return {
            searchResults: [...state.searchResults, ...newTracks],
            nextPageToken: nextPageToken ?? null,
          };
        }),

      clearQueue: () =>
        set({ queue: [], currentIndex: -1, currentTrack: null, isPlaying: false }),

      setQueue: (tracks, index = 0) =>
        set({ queue: tracks, currentIndex: index }),

      shuffle: () =>
        set((state) => {
          const { currentIndex } = state;
          const before = state.queue.slice(0, currentIndex + 1);
          const after = [...state.queue.slice(currentIndex + 1)];
          for (let i = after.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1));
            [after[i], after[j]] = [after[j], after[i]];
          }
          return { queue: [...before, ...after] };
        }),
    }),
);
