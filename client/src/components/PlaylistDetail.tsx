import { useEffect, useCallback } from "react";
import { usePlaylistsStore } from "@/stores/playlists";
import { usePlayerStore } from "@/stores/player";
import { Button } from "@/components/ui/button";
import { ArrowLeft, Play, GripVertical, X, Volume2, Pause, ExternalLink } from "lucide-react";
import { handleImgError } from "@/lib/img-fallback";
import { type Track, getThumbUrl } from "@/lib/api";
import { useTranslation } from "@/i18n";

interface PlaylistDetailProps {
  playlistId: number;
  onBack: () => void;
}

type TrackWithRowId = Track & { _rowId?: number };

export function PlaylistDetail({ playlistId, onBack }: PlaylistDetailProps) {
  const { t } = useTranslation();
  const playlists = usePlaylistsStore((s) => s.playlists);
  const tracks = usePlaylistsStore((s) => s.activePlaylistTracks) as TrackWithRowId[];
  const selectPlaylist = usePlaylistsStore((s) => s.selectPlaylist);
  const removeTrack = usePlaylistsStore((s) => s.removeTrack);
  const reorderTracks = usePlaylistsStore((s) => s.reorderTracks);
  const play = usePlayerStore((s) => s.play);
  const clearQueue = usePlayerStore((s) => s.clearQueue);
  const addToQueue = usePlayerStore((s) => s.addToQueue);
  const currentTrackId = usePlayerStore((s) => s.currentTrack?.id);
  const isPlaying = usePlayerStore((s) => s.isPlaying);

  const playlist = playlists.find((p) => p.id === playlistId);

  useEffect(() => {
    selectPlaylist(playlistId);
  }, [playlistId, selectPlaylist]);

  const handlePlayAll = useCallback(() => {
    if (tracks.length === 0) return;
    clearQueue();
    tracks.slice(1).forEach((t) => addToQueue(t));
    play(tracks[0]);
  }, [tracks, clearQueue, addToQueue, play]);

  const handleRemove = async (track: TrackWithRowId) => {
    if (track._rowId) {
      await removeTrack(playlistId, track._rowId);
    }
  };

  const handleDragStart = (e: React.DragEvent, index: number) => {
    e.dataTransfer.setData("text/plain", String(index));
    e.dataTransfer.effectAllowed = "move";
  };

  const handleDrop = async (e: React.DragEvent, targetIndex: number) => {
    e.preventDefault();
    const sourceIndex = Number(e.dataTransfer.getData("text/plain"));
    if (sourceIndex === targetIndex) return;

    const newTracks = [...tracks];
    const [moved] = newTracks.splice(sourceIndex, 1);
    newTracks.splice(targetIndex, 0, moved);

    const trackIds = newTracks.map((t) => t._rowId).filter((id): id is number => id != null);
    if (trackIds.length > 0) {
      await reorderTracks(playlistId, trackIds);
    }
  };

  const handleDragOver = (e: React.DragEvent) => {
    e.preventDefault();
    e.dataTransfer.dropEffect = "move";
  };

  return (
    <div className="flex flex-col gap-4 p-4">
      <div className="flex items-center gap-3">
        <Button variant="ghost" size="icon" onClick={onBack} className="h-8 w-8 shrink-0">
          <ArrowLeft className="h-5 w-5" />
        </Button>
        <h2 className="text-lg font-bold truncate">{playlist?.name ?? t("playlist.title")}</h2>
        <span className="text-sm text-muted-foreground shrink-0">
          {t("playlist.tracks", { count: tracks.length })}
        </span>
        <div className="flex-1" />
        <Button onClick={handlePlayAll} size="sm" className="bg-green-500 hover:bg-green-600 text-black shrink-0">
          <Play className="h-4 w-4 mr-1" /> {t("playlist.playAll")}
        </Button>
      </div>
      <div className="space-y-0.5">
        {tracks.map((track, index) => {
          const isCurrent = track.id === currentTrackId;
          return (
          <div
            key={track._rowId ?? track.id}
            className={`flex items-center gap-2 p-2 rounded-md group ${isCurrent ? "bg-accent" : "hover:bg-muted"}`}
            draggable
            onDragStart={(e) => handleDragStart(e, index)}
            onDragOver={handleDragOver}
            onDrop={(e) => handleDrop(e, index)}
          >
            <GripVertical className="h-4 w-4 text-muted-foreground/40 cursor-grab shrink-0" />
            {isCurrent ? (
              <div className="w-10 h-10 rounded flex items-center justify-center bg-primary/10 shrink-0">
                {isPlaying ? (
                  <Volume2 className="h-4 w-4 text-primary" />
                ) : (
                  <Pause className="h-4 w-4 text-primary" />
                )}
              </div>
            ) : (
              <img src={getThumbUrl(track.thumbnail)} alt="" className="w-10 h-10 rounded object-cover shrink-0" onError={handleImgError} loading="lazy" />
            )}
            <div className="flex-1 min-w-0 cursor-pointer" onClick={() => play(track)}>
              <p className="text-sm font-medium truncate">{track.title}</p>
              <p className="text-xs text-muted-foreground truncate">{track.artist}</p>
            </div>
            <a
              href={`https://www.youtube.com/watch?v=${track.id}`}
              target="_blank"
              rel="noopener noreferrer"
              className="h-7 w-7 opacity-0 group-hover:opacity-100 shrink-0 inline-flex items-center justify-center rounded-md text-muted-foreground hover:text-foreground"
              onClick={(e) => e.stopPropagation()}
              title="YouTube"
            >
              <ExternalLink className="h-3.5 w-3.5" />
            </a>
            <Button
              variant="ghost"
              size="icon"
              className="h-7 w-7 opacity-0 group-hover:opacity-100 text-destructive shrink-0"
              onClick={() => handleRemove(track)}
            >
              <X className="h-4 w-4" />
            </Button>
          </div>
          );
        })}
        {tracks.length === 0 && (
          <p className="text-sm text-muted-foreground text-center py-8">{t("playlist.empty")}</p>
        )}
      </div>
    </div>
  );
}
