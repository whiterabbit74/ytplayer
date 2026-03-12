import { useEffect } from "react";
import { useFavoritesStore } from "@/stores/favorites";
import { TrackList } from "@/components/TrackList";
import { usePlayerStore } from "@/stores/player";
import { useTranslation } from "@/i18n";
import { Heart } from "lucide-react";

export function FavoritesList() {
  const { t } = useTranslation();
  const favorites = useFavoritesStore((s) => s.favorites);
  const isLoading = useFavoritesStore((s) => s.isLoading);
  const loadFavorites = useFavoritesStore((s) => s.loadFavorites);
  
  const addToQueue = usePlayerStore((s) => s.addToQueue);
  
  useEffect(() => {
    loadFavorites();
  }, [loadFavorites]);


  if (isLoading) {
    return (
      <div className="flex justify-center p-8">
        <p className="text-muted-foreground">{t("common.loading")}</p>
      </div>
    );
  }

  if (favorites.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center p-8 text-center bg-card rounded-lg mt-4 mx-4 border">
        <Heart className="h-12 w-12 text-muted-foreground mb-4" />
        <p className="text-lg font-medium">{t("favorites.empty")}</p>
      </div>
    );
  }

  return (
    <div className="p-4 flex-1 overflow-auto">
      <div className="mb-4">
        <h2 className="text-2xl font-bold flex items-center gap-2">
          <Heart className="h-6 w-6 text-red-500 fill-red-500" />
          {t("nav.favorites")}
        </h2>
        <p className="text-sm text-muted-foreground mt-1">
          {favorites.length} {favorites.length === 1 ? 'track' : 'tracks'}
        </p>
      </div>
      <TrackList 
        tracks={favorites} 
        onAddToQueue={addToQueue} 
      />
    </div>
  );
}
