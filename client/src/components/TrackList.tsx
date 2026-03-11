import { useState, useMemo, useEffect } from "react";
import { type Track, getThumbUrl } from "@/lib/api";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { usePlaylistsStore } from "@/stores/playlists";
import { useFavoritesStore } from "@/stores/favorites";
import { Eye, ThumbsUp, Clock, ArrowUpDown, Loader2, ListPlus, ListMinus, Plus, Volume2, Pause, ExternalLink, FolderPlus, MoreVertical, Heart } from "lucide-react";
import { usePlayerStore } from "@/stores/player";
import { handleImgError } from "@/lib/img-fallback";
import { useTranslation } from "@/i18n";

interface TrackListProps {
  tracks: Track[];
  onPlay: (track: Track) => void;
  onAddToQueue: (track: Track) => void;
  onLoadMore?: () => void;
  hasMore?: boolean;
  isLoading?: boolean;
}

type SortField = "default" | "duration" | "viewCount" | "likeCount";

function formatDuration(seconds: number): string {
  if (!seconds) return "";
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = seconds % 60;
  if (h > 0) return `${h}:${m.toString().padStart(2, "0")}:${s.toString().padStart(2, "0")}`;
  return `${m}:${s.toString().padStart(2, "0")}`;
}

function formatCount(n: number): string {
  if (n >= 1_000_000_000) return `${(n / 1_000_000_000).toFixed(1)}B`;
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M`;
  if (n >= 1_000) return `${(n / 1_000).toFixed(1)}K`;
  return String(n);
}

import type { TranslationKey } from "@/i18n";

const sortOptions: { field: SortField; labelKey: TranslationKey; icon: typeof Clock }[] = [
  { field: "duration", labelKey: "sort.duration", icon: Clock },
  { field: "viewCount", labelKey: "sort.views", icon: Eye },
  { field: "likeCount", labelKey: "sort.likes", icon: ThumbsUp },
];

function TrackPlaylistMenu({ track }: { track: Track }) {
  const { t } = useTranslation();
  const playlists = usePlaylistsStore((s) => s.playlists);
  const createPlaylist = usePlaylistsStore((s) => s.createPlaylist);
  const addTrack = usePlaylistsStore((s) => s.addTrack);
  const loadPlaylists = usePlaylistsStore((s) => s.loadPlaylists);

  useEffect(() => { loadPlaylists(); }, [loadPlaylists]);

  const handleAdd = (playlistId: number) => {
    addTrack(playlistId, track);
  };

  const handleCreateAndAdd = async () => {
    const name = prompt(t("playlist.createPrompt"));
    if (!name?.trim()) return;
    await createPlaylist(name.trim());
    const { playlists: updated } = usePlaylistsStore.getState();
    if (updated.length > 0) {
      addTrack(updated[0].id, track);
    }
  };

  return (
    <>
      {playlists.map((pl) => (
        <DropdownMenuItem key={pl.id} onClick={() => handleAdd(pl.id)}>
          {pl.name}
        </DropdownMenuItem>
      ))}
      {playlists.length > 0 && <DropdownMenuSeparator />}
      <DropdownMenuItem onClick={handleCreateAndAdd}>
        <Plus className="h-4 w-4 mr-2 text-green-500" />
        <span className="text-green-500">{t("playlist.createNew")}</span>
      </DropdownMenuItem>
    </>
  );
}

export function TrackList({ tracks, onPlay, onAddToQueue, onLoadMore, hasMore, isLoading }: TrackListProps) {
  const { t } = useTranslation();
  const currentTrackId = usePlayerStore((s) => s.currentTrack?.id);
  const storeIsPlaying = usePlayerStore((s) => s.isPlaying);
  const queue = usePlayerStore((s) => s.queue);
  const removeFromQueue = usePlayerStore((s) => s.removeFromQueue);
  const toggleFavorite = useFavoritesStore((s) => s.toggleFavorite);
  const isFavorite = useFavoritesStore((s) => s.isFavorite);
  const [sortField, setSortField] = useState<SortField>("default");
  const [sortAsc, setSortAsc] = useState(false);

  const sortedTracks = useMemo(() => {
    if (sortField === "default") return tracks;
    return [...tracks].sort((a, b) => {
      const diff = a[sortField] - b[sortField];
      return sortAsc ? diff : -diff;
    });
  }, [tracks, sortField, sortAsc]);

  const queueMap = useMemo(() => {
    const m = new Map<string, number>();
    queue.forEach((t, i) => {
      if (!m.has(t.id)) m.set(t.id, i);
    });
    return m;
  }, [queue]);

  if (tracks.length === 0) return null;

  const handleSortClick = (field: SortField) => {
    if (sortField === field) {
      setSortAsc((prev) => !prev);
    } else {
      setSortField(field);
      setSortAsc(false);
    }
  };

  return (
    <div className="space-y-2">
      <div className="flex items-center gap-1.5 flex-wrap">
        <Button
          variant={sortField === "default" ? "secondary" : "ghost"}
          size="sm"
          className="h-7 text-xs px-2.5"
          onClick={() => { setSortField("default"); setSortAsc(false); }}
        >
          <ArrowUpDown className="h-3 w-3 mr-1" />
          YouTube
        </Button>
        {sortOptions.map(({ field, labelKey, icon: Icon }) => (
          <Button
            key={field}
            variant={sortField === field ? "secondary" : "ghost"}
            size="sm"
            className="h-7 text-xs px-2.5"
            onClick={() => handleSortClick(field)}
          >
            <Icon className="h-3 w-3 mr-1" />
            {t(labelKey)}
            {sortField === field && (
              <span className="ml-0.5">{sortAsc ? "↑" : "↓"}</span>
            )}
          </Button>
        ))}
      </div>
      <div className="space-y-1">
        {sortedTracks.map((track) => {
          const isCurrent = track.id === currentTrackId;
          const queueIndex = queueMap.get(track.id);
          const isInQueue = queueIndex !== undefined;
          const isFav = isFavorite(track.id);
          return (
          <div
            key={track.id}
            className={`flex items-center gap-3 p-2 rounded-md cursor-pointer group ${isCurrent ? "bg-accent" : "hover:bg-muted"}`}
            onClick={() => onPlay(track)}
          >
            {isCurrent ? (
              <div className="w-12 h-12 rounded flex items-center justify-center bg-primary/10 shrink-0">
                {storeIsPlaying ? (
                  <Volume2 className="h-5 w-5 text-primary" />
                ) : (
                  <Pause className="h-5 w-5 text-primary" />
                )}
              </div>
            ) : (
              <img src={getThumbUrl(track.thumbnail)} alt={track.title} className="w-12 h-12 rounded object-cover shrink-0" onError={handleImgError} loading="lazy" />
            )}
            <div className="flex-1 min-w-0">
              <p className="text-sm font-medium truncate">{track.title}</p>
              <div className="flex items-center gap-2 text-xs text-muted-foreground">
                <span className="truncate">{track.artist}</span>
                <span className="shrink-0">{formatDuration(track.duration)}</span>
              </div>
              <div className="flex items-center gap-3 text-xs text-muted-foreground md:hidden">
                {track.viewCount > 0 && (
                  <span className="flex items-center gap-0.5">
                    <Eye className="h-3 w-3" />
                    {formatCount(track.viewCount)}
                  </span>
                )}
                {track.likeCount > 0 && (
                  <span className="flex items-center gap-0.5">
                    <ThumbsUp className="h-3 w-3" />
                    {formatCount(track.likeCount)}
                  </span>
                )}
              </div>
            </div>
            {/* Desktop: inline stats + duration */}
            <div className="hidden md:flex items-center gap-3 text-xs text-muted-foreground shrink-0">
              {track.viewCount > 0 && (
                <span className="flex items-center gap-0.5">
                  <Eye className="h-3 w-3" />
                  {formatCount(track.viewCount)}
                </span>
              )}
              {track.likeCount > 0 && (
                <span className="flex items-center gap-0.5">
                  <ThumbsUp className="h-3 w-3" />
                  {formatCount(track.likeCount)}
                </span>
              )}
            </div>
            {/* Desktop: hover action buttons */}
            <a
              href={`https://www.youtube.com/watch?v=${track.id}`}
              target="_blank"
              rel="noopener noreferrer"
              className="hidden md:inline-flex opacity-0 group-hover:opacity-100 shrink-0 items-center justify-center h-8 w-8 rounded-md text-muted-foreground hover:text-foreground hover:bg-muted"
              onClick={(e) => e.stopPropagation()}
              title="YouTube"
            >
              <ExternalLink className="h-4 w-4" />
            </a>
            <Button
              variant="ghost"
              size="icon"
              className="hidden md:inline-flex opacity-0 group-hover:opacity-100 shrink-0"
              onClick={(e) => { e.stopPropagation(); isInQueue ? removeFromQueue(queueIndex) : onAddToQueue(track); }}
              title={isInQueue ? t("queue.removeFromQueue") : t("queue.addToQueue")}
            >
              {isInQueue ? (
                <ListMinus className="h-4 w-4 text-green-500" />
              ) : (
                <ListPlus className="h-4 w-4" />
              )}
            </Button>
            <Button
              variant="ghost"
              size="icon"
              className="hidden md:inline-flex opacity-0 group-hover:opacity-100 shrink-0"
              onClick={(e) => { e.stopPropagation(); toggleFavorite(track); }}
              title={isFav ? t("favorites.removed") : t("favorites.added")}
            >
              <Heart className={`h-4 w-4 ${isFav ? "fill-red-500 text-red-500" : ""}`} />
            </Button>
            <DropdownMenu>
              <DropdownMenuTrigger asChild>
                <Button
                  variant="ghost"
                  size="icon"
                  className="hidden md:inline-flex opacity-0 group-hover:opacity-100 shrink-0"
                  onClick={(e) => e.stopPropagation()}
                  title={t("playlist.addToPlaylist")}
                >
                  <FolderPlus className="h-4 w-4" />
                </Button>
              </DropdownMenuTrigger>
              <DropdownMenuContent align="end">
                <TrackPlaylistMenu track={track} />
              </DropdownMenuContent>
            </DropdownMenu>
            {/* Mobile: ⋮ menu with all actions */}
            <DropdownMenu>
              <DropdownMenuTrigger asChild>
                <Button
                  variant="ghost"
                  size="icon"
                  className="md:hidden shrink-0 h-8 w-8"
                  onClick={(e) => e.stopPropagation()}
                >
                  <MoreVertical className="h-4 w-4" />
                </Button>
              </DropdownMenuTrigger>
              <DropdownMenuContent align="end">
                <DropdownMenuItem onClick={(e) => { e.stopPropagation(); isInQueue ? removeFromQueue(queueIndex) : onAddToQueue(track); }}>
                  {isInQueue ? (
                    <ListMinus className="h-4 w-4 mr-2 text-green-500" />
                  ) : (
                    <ListPlus className="h-4 w-4 mr-2" />
                  )}
                  {isInQueue ? t("queue.removeFromQueue") : t("queue.addToQueue")}
                </DropdownMenuItem>
                <DropdownMenuItem onClick={(e) => { e.stopPropagation(); toggleFavorite(track); }}>
                  <Heart className={`h-4 w-4 mr-2 ${isFav ? "fill-red-500 text-red-500" : ""}`} />
                  {isFav ? t("favorites.removed") : t("favorites.added")}
                </DropdownMenuItem>
                <DropdownMenuSeparator />
                <TrackPlaylistMenu track={track} />
                <DropdownMenuSeparator />
                <DropdownMenuItem asChild>
                  <a
                    href={`https://www.youtube.com/watch?v=${track.id}`}
                    target="_blank"
                    rel="noopener noreferrer"
                    onClick={(e) => e.stopPropagation()}
                  >
                    <ExternalLink className="h-4 w-4 mr-2" />
                    YouTube
                  </a>
                </DropdownMenuItem>
              </DropdownMenuContent>
            </DropdownMenu>
          </div>
          );
        })}
      </div>
      {hasMore && onLoadMore && (
        <div className="flex justify-center pt-2 pb-4">
          <Button
            variant="outline"
            size="sm"
            onClick={onLoadMore}
            disabled={isLoading}
          >
            {isLoading ? (
              <Loader2 className="h-4 w-4 mr-2 animate-spin" />
            ) : null}
            {t("search.loadMore")}
          </Button>
        </div>
      )}
    </div>
  );
}
