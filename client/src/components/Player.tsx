import { useEffect } from "react";
import { getThumbUrl } from "@/lib/api";
import { usePlayerStore } from "@/stores/player";
import { usePlaylistsStore } from "@/stores/playlists";
import { Button } from "@/components/ui/button";
import { Slider } from "@/components/ui/slider";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { Play, Pause, SkipForward, Volume2, Repeat1, ListPlus, ListMinus, FolderPlus, Plus, ExternalLink, Heart } from "lucide-react";
import { handleImgError } from "@/lib/img-fallback";
import { useTranslation } from "@/i18n";
import { useFavoritesStore } from "@/stores/favorites";

function formatTime(sec: number): string {
  if (!sec || !isFinite(sec)) return "0:00";
  const h = Math.floor(sec / 3600);
  const m = Math.floor((sec % 3600) / 60);
  const s = Math.floor(sec % 60);
  if (h > 0) return `${h}:${m.toString().padStart(2, "0")}:${s.toString().padStart(2, "0")}`;
  return `${m}:${s.toString().padStart(2, "0")}`;
}

interface PlayerProps {
  currentTime: number;
  duration: number;
  volume: number;
  onPlayPause: () => void;
  onNext: () => void;
  onSeek: (time: number) => void;
  onVolumeChange: (vol: number) => void;
}

export function Player({
  currentTime,
  duration,
  volume,
  onPlayPause,
  onNext,
  onSeek,
  onVolumeChange,
}: PlayerProps) {
  const { t } = useTranslation();
  const currentTrack = usePlayerStore((s) => s.currentTrack);
  const storeIsPlaying = usePlayerStore((s) => s.isPlaying);
  const queue = usePlayerStore((s) => s.queue);
  const addToQueue = usePlayerStore((s) => s.addToQueue);
  const removeFromQueue = usePlayerStore((s) => s.removeFromQueue);
  const repeatMode = usePlayerStore((s) => s.repeatMode);
  const toggleRepeat = usePlayerStore((s) => s.toggleRepeat);
  const playlists = usePlaylistsStore((s) => s.playlists);
  const createPlaylist = usePlaylistsStore((s) => s.createPlaylist);
  const addTrackToPlaylist = usePlaylistsStore((s) => s.addTrack);
  const loadPlaylists = usePlaylistsStore((s) => s.loadPlaylists);
  const isFavorite = useFavoritesStore((s) => s.isFavorite);
  const toggleFavorite = useFavoritesStore((s) => s.toggleFavorite);

  useEffect(() => { loadPlaylists(); }, [loadPlaylists]);

  if (!currentTrack) return null;

  const queueIndex = queue.findIndex((t) => t.id === currentTrack.id);
  const isInQueue = queueIndex >= 0;
  const isFav = isFavorite(currentTrack.id);

  return (
    <div data-testid="player" className="border-t bg-card px-4 py-3">
      <div className="flex items-center gap-4 max-w-4xl mx-auto">
        <img src={getThumbUrl(currentTrack.thumbnail)} alt={currentTrack.title} className="w-12 h-12 rounded" onError={handleImgError} />
        <div className="flex-1 min-w-0">
          <p className="text-sm font-medium truncate">{currentTrack.title}</p>
          <p className="text-xs text-muted-foreground truncate">{currentTrack.artist}</p>
          <div className="flex items-center gap-2 mt-1">
            <span className="text-xs text-muted-foreground w-10 text-right">
              {formatTime(currentTime)}
            </span>
            <Slider
              value={[currentTime]}
              max={duration || 100}
              step={1}
              onValueChange={([v]) => onSeek(v)}
              className="flex-1"
            />
            <span className="text-xs text-muted-foreground w-10">
              {formatTime(duration)}
            </span>
          </div>
        </div>
        <div className="flex items-center gap-1">
          <Button variant="ghost" size="icon" onClick={onPlayPause}>
            {storeIsPlaying ? <Pause className="h-5 w-5" /> : <Play className="h-5 w-5" />}
          </Button>
          <Button variant="ghost" size="icon" onClick={onNext}>
            <SkipForward className="h-5 w-5" />
          </Button>
          <Button variant="ghost" size="icon" onClick={toggleRepeat}>
            <Repeat1 className={`h-5 w-5 ${repeatMode === "one" ? "text-green-500" : ""}`} />
          </Button>
          <Button 
            variant="ghost" 
            size="icon" 
            onClick={() => toggleFavorite(currentTrack)}
            title={isFav ? t("favorites.removed") : t("favorites.added")}
          >
            <Heart className={`h-5 w-5 ${isFav ? "fill-red-500 text-red-500" : ""}`} />
          </Button>
          <Button
            variant="ghost"
            size="icon"
            onClick={() => isInQueue ? removeFromQueue(queueIndex) : addToQueue(currentTrack)}
            title={isInQueue ? t("queue.removeFromQueue") : t("queue.addToQueue")}
          >
            {isInQueue ? (
              <ListMinus className="h-5 w-5 text-green-500" />
            ) : (
              <ListPlus className="h-5 w-5" />
            )}
          </Button>
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button variant="ghost" size="icon" title={t("playlist.addToPlaylist")}>
                <FolderPlus className="h-5 w-5" />
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end">
              {playlists.map((pl) => (
                <DropdownMenuItem key={pl.id} onClick={() => addTrackToPlaylist(pl.id, currentTrack)}>
                  {pl.name}
                </DropdownMenuItem>
              ))}
              {playlists.length > 0 && <DropdownMenuSeparator />}
              <DropdownMenuItem onClick={async () => {
                const name = prompt(t("playlist.createPrompt"));
                if (!name?.trim()) return;
                await createPlaylist(name.trim());
                const { playlists: updated } = usePlaylistsStore.getState();
                if (updated.length > 0) addTrackToPlaylist(updated[0].id, currentTrack);
              }}>
                <Plus className="h-4 w-4 mr-2 text-green-500" />
                <span className="text-green-500">{t("playlist.createNew")}</span>
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
          <a
            href={`https://www.youtube.com/watch?v=${currentTrack.id}`}
            target="_blank"
            rel="noopener noreferrer"
            title="YouTube"
          >
            <Button variant="ghost" size="icon">
              <ExternalLink className="h-5 w-5" />
            </Button>
          </a>
          <div className="flex items-center gap-1 ml-2">
            <Volume2 className="h-4 w-4 text-muted-foreground" />
            <Slider
              value={[volume * 100]}
              max={100}
              step={1}
              onValueChange={([v]) => onVolumeChange(v / 100)}
              className="w-20"
            />
          </div>
        </div>
      </div>
    </div>
  );
}
