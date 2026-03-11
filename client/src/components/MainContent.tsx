import { useState } from "react";
import { PlaylistList } from "@/components/PlaylistList";
import { PlaylistDetail } from "@/components/PlaylistDetail";
import { Search, ListMusic, Heart } from "lucide-react";
import { useTranslation } from "@/i18n";
import { FavoritesList } from "@/components/FavoritesList";

type Tab = "search" | "playlists" | "favorites";

interface MainContentProps {
  searchContent: React.ReactNode;
}

export function MainContent({ searchContent }: MainContentProps) {
  const { t } = useTranslation();
  const [tab, setTab] = useState<Tab>("search");
  const [openPlaylistId, setOpenPlaylistId] = useState<number | null>(null);

  const renderPlaylistsContent = () => {
    if (openPlaylistId !== null) {
      return <PlaylistDetail playlistId={openPlaylistId} onBack={() => setOpenPlaylistId(null)} />;
    }
    return <PlaylistList onOpenPlaylist={setOpenPlaylistId} />;
  };

  return (
    <div className="flex flex-col flex-1 min-h-0">
      <div className="flex border-b border-border">
        <button
          className={`flex items-center gap-1.5 px-5 py-3 text-sm font-medium border-b-2 transition-colors ${
            tab === "search" ? "border-green-500 text-green-500" : "border-transparent text-muted-foreground hover:text-foreground"
          }`}
          onClick={() => setTab("search")}
        >
          <Search className="h-4 w-4" /> {t("nav.search")}
        </button>
        <button
          className={`flex items-center gap-1.5 px-5 py-3 text-sm font-medium border-b-2 transition-colors ${
            tab === "playlists" ? "border-green-500 text-green-500" : "border-transparent text-muted-foreground hover:text-foreground"
          }`}
          onClick={() => setTab("playlists")}
        >
          <ListMusic className="h-4 w-4" /> {t("nav.playlists")}
        </button>
        <button
          className={`flex items-center gap-1.5 px-5 py-3 text-sm font-medium border-b-2 transition-colors ${
            tab === "favorites" ? "border-green-500 text-green-500" : "border-transparent text-muted-foreground hover:text-foreground"
          }`}
          onClick={() => setTab("favorites")}
        >
          <Heart className="h-4 w-4" /> {t("nav.favorites")}
        </button>
      </div>
      <div className="flex-1 overflow-auto min-h-0">
        {tab === "search" ? searchContent : tab === "playlists" ? renderPlaylistsContent() : <FavoritesList />}
      </div>
    </div>
  );
}
