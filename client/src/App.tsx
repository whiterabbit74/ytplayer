import { useState, useCallback, useEffect, useRef } from "react";
import { Layout } from "@/components/Layout";
import { SearchBar } from "@/components/SearchBar";
import { TrackList } from "@/components/TrackList";
import { Player } from "@/components/Player";
import { MainContent } from "@/components/MainContent";
import { PlaylistList } from "@/components/PlaylistList";
import { PlaylistDetail } from "@/components/PlaylistDetail";
import { Queue } from "@/components/Queue";
import { MobileNav, type MobileTab } from "@/components/MobileNav";
import { MiniPlayer } from "@/components/MiniPlayer";
import { FullscreenPlayer } from "@/components/FullscreenPlayer";
import { FavoritesList } from "@/components/FavoritesList";
import { searchTracks, getThumbUrl } from "@/lib/api";
import { usePlayerStore } from "@/stores/player";
import { useAudio } from "@/hooks/useAudio";
import { useMediaSession } from "@/hooks/useMediaSession";
import { usePlayerSync } from "@/hooks/usePlayerSync";
import { useAuth } from "@/contexts/AuthContext";
import { useFavoritesStore } from "@/stores/favorites";
import { LoginPage } from "@/components/LoginPage";
import { useTranslation } from "@/i18n";

function MobilePlaylistsView() {
  const [openId, setOpenId] = useState<number | null>(null);
  if (openId !== null) {
    return <PlaylistDetail playlistId={openId} onBack={() => setOpenId(null)} />;
  }
  return <PlaylistList onOpenPlaylist={setOpenId} />;
}

function App() {
  const { user, isLoading } = useAuth();
  const { t } = useTranslation();

  if (isLoading) {
    return <div className="h-screen bg-background flex items-center justify-center">
      <p className="text-muted-foreground">{t("common.loading")}</p>
    </div>;
  }

  if (!user) return <LoginPage />;

  return <AuthenticatedApp />;
}

function AuthenticatedApp() {
  const { syncToServer } = usePlayerSync();
  const [mobileTab, setMobileTab] = useState<MobileTab>("search");
  const [fullscreenOpen, setFullscreenOpen] = useState(false);
  const [lastQuery, setLastQuery] = useState(() => {
    // Priority: URL ?q= param > localStorage
    const urlQuery = new URLSearchParams(window.location.search).get("q");
    if (urlQuery) return urlQuery;
    return localStorage.getItem("musicplay-query") || "";
  });
  const [isSearching, setIsSearching] = useState(false);
  const isFirstMountRef = useRef(true);
  const prevTrackIdRef = useRef<string | undefined>(undefined);
  const hasAutoSearchedRef = useRef(false);

  const setSearchResults = usePlayerStore((s) => s.setSearchResults);
  const appendSearchResults = usePlayerStore((s) => s.appendSearchResults);
  const searchResults = usePlayerStore((s) => s.searchResults);
  const nextPageToken = usePlayerStore((s) => s.nextPageToken);
  const play = usePlayerStore((s) => s.play);
  const addToQueue = usePlayerStore((s) => s.addToQueue);
  const loadFavoriteIds = useFavoritesStore((s) => s.loadFavoriteIds);
  const currentTrack = usePlayerStore((s) => s.currentTrack);
  const storeIsPlaying = usePlayerStore((s) => s.isPlaying);
  const storePause = usePlayerStore((s) => s.pause);
  const storeResume = usePlayerStore((s) => s.resume);
  const playNext = usePlayerStore((s) => s.playNext);
  const playPrev = usePlayerStore((s) => s.playPrev);
  const repeatMode = usePlayerStore((s) => s.repeatMode);

  // Single audio instance shared across desktop and mobile
  const audio = useAudio(playNext, repeatMode === "one");

  // Play track when currentTrack changes; on hydration just load without playing
  useEffect(() => {
    if (!currentTrack) return;

    // On hydration: load audio + restore position, don't auto-play
    // (Chrome blocks autoplay without user interaction)
    if (isFirstMountRef.current) {
      isFirstMountRef.current = false;
      prevTrackIdRef.current = currentTrack.id;
      if (storeIsPlaying) storePause();
      audio.load(currentTrack.id);
      const pos = localStorage.getItem("musicplay-position");
      if (pos) {
        audio.restorePosition(parseFloat(pos));
      }
      return;
    }

    // Strict mode double-fire guard: skip if same track ID
    if (currentTrack.id === prevTrackIdRef.current) return;
    prevTrackIdRef.current = currentTrack.id;

    audio.play(currentTrack.id);
  }, [currentTrack?.id]);

  const handlePlayPause = useCallback(() => {
    if (storeIsPlaying) {
      audio.pause();
      storePause();
      syncToServer();
    } else {
      audio.resume();
      storeResume();
    }
  }, [storeIsPlaying, audio, storePause, storeResume, syncToServer]);

  const handlePlay = useCallback(() => {
    audio.resume();
    storeResume();
  }, [audio, storeResume]);

  const handlePauseAction = useCallback(() => {
    audio.pause();
    storePause();
  }, [audio, storePause]);

  // Media Session for mobile background playback
  useMediaSession({
    title: currentTrack?.title,
    artist: currentTrack?.artist,
    artwork: currentTrack?.thumbnail ? getThumbUrl(currentTrack.thumbnail) : undefined,
    isPlaying: storeIsPlaying,
    onPlay: handlePlay,
    onPause: handlePauseAction,
    onNextTrack: playNext,
  });

  // Auto-search on page load if URL has ?q= parameter (with StrictMode protection)
  useEffect(() => {
    loadFavoriteIds();
    if (lastQuery && !hasAutoSearchedRef.current) {
      hasAutoSearchedRef.current = true;
      handleSearch(lastQuery);
    }
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  const handleSearch = async (query: string) => {
    setLastQuery(query);
    localStorage.setItem("musicplay-query", query);
    const url = new URL(window.location.href);
    url.searchParams.set("q", query);
    window.history.replaceState({}, "", url.toString());
    setIsSearching(true);
    try {
      const result = await searchTracks(query);
      setSearchResults(result.tracks, result.nextPageToken);
    } catch (err) {
      console.error("Search failed:", err);
    } finally {
      setIsSearching(false);
    }
  };

  const handleLoadMore = async () => {
    if (!nextPageToken || !lastQuery || isSearching) return;
    setIsSearching(true);
    try {
      const result = await searchTracks(lastQuery, nextPageToken);
      appendSearchResults(result.tracks, result.nextPageToken);
    } catch (err) {
      console.error("Load more failed:", err);
    } finally {
      setIsSearching(false);
    }
  };

  // Mobile content based on active tab
  const renderMobileContent = () => {
    switch (mobileTab) {
      case "search":
        return (
          <>
            <div className="p-4 flex justify-center">
              <SearchBar onSearch={handleSearch} initialQuery={lastQuery} />
            </div>
            <div className="flex-1 overflow-auto p-4">
              <TrackList tracks={searchResults} onPlay={play} onAddToQueue={addToQueue} onLoadMore={handleLoadMore} hasMore={!!nextPageToken} isLoading={isSearching} />
            </div>
          </>
        );
      case "playlists":
        return (
          <div className="flex-1 overflow-auto">
            <MobilePlaylistsView />
          </div>
        );
      case "favorites":
        return (
          <div className="flex-1 overflow-auto">
            <FavoritesList />
          </div>
        );
      case "queue":
        return (
          <div className="flex-1 min-h-0 overflow-hidden">
            <Queue />
          </div>
        );
    }
  };

  return (
    <>
      <Layout
        desktopPlayer={
          <Player
            currentTime={audio.currentTime}
            duration={audio.duration}
            volume={audio.volume}
            onPlayPause={handlePlayPause}
            onNext={playNext}
            onSeek={audio.seek}
            onVolumeChange={audio.setVolume}
          />
        }
        mobileBottom={
          <div className="md:hidden">
            <MiniPlayer
              currentTime={audio.currentTime}
              duration={audio.duration}
              onPlayPause={handlePlayPause}
              onNext={playNext}
              onTap={() => setFullscreenOpen(true)}
            />
            <MobileNav activeTab={mobileTab} onTabChange={setMobileTab} />
          </div>
        }
      >
        {/* Desktop: MainContent with tabs */}
        <div className="hidden md:flex md:flex-col md:flex-1 min-h-0">
          <MainContent
            searchContent={
              <>
                <div className="p-4 flex justify-center">
                  <SearchBar onSearch={handleSearch} initialQuery={lastQuery} />
                </div>
                <div className="flex-1 overflow-auto p-4">
                  <TrackList tracks={searchResults} onPlay={play} onAddToQueue={addToQueue} onLoadMore={handleLoadMore} hasMore={!!nextPageToken} isLoading={isSearching} />
                </div>
              </>
            }
          />
        </div>

        {/* Mobile: tab-based content */}
        <div className="flex flex-col flex-1 min-h-0 md:hidden">
          {renderMobileContent()}
        </div>
      </Layout>

      {/* Fullscreen player (mobile only) */}
      <FullscreenPlayer
        open={fullscreenOpen}
        onClose={() => setFullscreenOpen(false)}
        currentTime={audio.currentTime}
        duration={audio.duration}
        onPlayPause={handlePlayPause}
        onNext={playNext}
        onPrev={playPrev}
        onSeek={audio.seek}
      />
    </>
  );
}

export default App;
