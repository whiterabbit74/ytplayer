import { useEffect } from "react";
import { getThumbUrl } from "@/lib/api";
import { usePlayerStore } from "@/stores/player";
import { usePlaylistsStore } from "@/stores/playlists";
import { Slider } from "@/components/ui/slider";
import { Button } from "@/components/ui/button";
import {
  Drawer,
  DrawerContent,
  DrawerTitle,
} from "@/components/ui/drawer";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { Play, Pause, SkipBack, SkipForward, ChevronDown, Repeat1, ListPlus, ListMinus, FolderPlus, Plus, Heart } from "lucide-react";
import { handleImgError } from "@/lib/img-fallback";
import { useTranslation } from "@/i18n";
import { useFavoritesStore } from "@/stores/favorites";
import { VisuallyHidden } from "radix-ui";
const VisuallyHiddenRoot = VisuallyHidden.Root;

interface FullscreenPlayerProps {
  open: boolean;
  onClose: () => void;
  currentTime: number;
  duration: number;
  onPlayPause: () => void;
  onNext: () => void;
  onPrev: () => void;
  onSeek: (time: number) => void;
}

function formatTime(sec: number): string {
  if (!sec || !isFinite(sec)) return "0:00";
  const h = Math.floor(sec / 3600);
  const m = Math.floor((sec % 3600) / 60);
  const s = Math.floor(sec % 60);
  if (h > 0) return `${h}:${m.toString().padStart(2, "0")}:${s.toString().padStart(2, "0")}`;
  return `${m}:${s.toString().padStart(2, "0")}`;
}

export function FullscreenPlayer({
  open,
  onClose,
  currentTime,
  duration,
  onPlayPause,
  onNext,
  onPrev,
  onSeek,
}: FullscreenPlayerProps) {
  const { t } = useTranslation();
  const currentTrack = usePlayerStore((s) => s.currentTrack);
  const isPlaying = usePlayerStore((s) => s.isPlaying);
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
    <Drawer open={open} onOpenChange={(o) => !o && onClose()}>
      <DrawerContent className="!h-[100dvh] !max-h-[100dvh] !rounded-none !border-0 !mt-0">
        <VisuallyHiddenRoot>
          <DrawerTitle>{t("player.title")}</DrawerTitle>
        </VisuallyHiddenRoot>

        <div className="flex flex-col h-full px-6 pb-8">
          {/* Header with close button */}
          <div className="flex items-center justify-center py-4 relative">
            <Button
              variant="ghost"
              size="icon"
              className="absolute left-0"
              onClick={onClose}
            >
              <ChevronDown className="h-6 w-6" />
            </Button>
            <span className="text-xs text-muted-foreground uppercase tracking-wider">
              {t("player.nowPlaying")}
            </span>
          </div>

          {/* Album cover */}
          <div className="flex-1 flex items-center justify-center py-4">
            <img
              src={getThumbUrl(currentTrack.thumbnail)}
              alt={currentTrack.title}
              className="w-72 h-72 rounded-lg object-cover shadow-2xl"
              onError={handleImgError}
            />
          </div>

          {/* Track info */}
          <div className="mb-6">
            <p className="text-lg font-semibold truncate">
              {currentTrack.title}
            </p>
            <p className="text-sm text-muted-foreground truncate">
              {currentTrack.artist}
            </p>
          </div>

          {/* Progress bar */}
          <div className="mb-6">
            <Slider
              value={[currentTime]}
              max={duration || 100}
              step={1}
              onValueChange={([v]) => onSeek(v)}
            />
            <div className="flex justify-between mt-1">
              <span className="text-xs text-muted-foreground">
                {formatTime(currentTime)}
              </span>
              <span className="text-xs text-muted-foreground">
                {formatTime(duration)}
              </span>
            </div>
          </div>

          {/* Controls */}
          <div className="flex items-center justify-center gap-6 mb-4">
            <Button variant="ghost" size="icon" className="h-12 w-12" onClick={onPrev}>
              <SkipBack className="h-6 w-6" />
            </Button>
            <button
              className="h-16 w-16 rounded-full bg-green-500 hover:bg-green-400 flex items-center justify-center transition-colors"
              onClick={onPlayPause}
            >
              {isPlaying ? (
                <Pause className="h-7 w-7 text-black" />
              ) : (
                <Play className="h-7 w-7 text-black ml-1" />
              )}
            </button>
            <Button variant="ghost" size="icon" className="h-12 w-12" onClick={onNext}>
              <SkipForward className="h-6 w-6" />
            </Button>
          </div>
          <div className="flex items-center justify-center gap-4">
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
            <Button variant="ghost" size="icon" onClick={toggleRepeat}>
              <Repeat1 className={`h-5 w-5 ${repeatMode === "one" ? "text-green-500" : ""}`} />
            </Button>
            <Button variant="ghost" size="icon" onClick={() => toggleFavorite(currentTrack)}>
              <Heart className={`h-5 w-5 ${isFav ? "fill-red-500 text-red-500" : ""}`} />
            </Button>
            <DropdownMenu>
              <DropdownMenuTrigger asChild>
                <Button variant="ghost" size="icon" title={t("playlist.addToPlaylist")}>
                  <FolderPlus className="h-5 w-5" />
                </Button>
              </DropdownMenuTrigger>
              <DropdownMenuContent align="center">
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
          </div>
        </div>
      </DrawerContent>
    </Drawer>
  );
}
