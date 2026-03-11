import { Search, ListMusic, ListOrdered, Heart } from "lucide-react";
import { useTranslation } from "@/i18n";
import type { TranslationKey } from "@/i18n";

export type MobileTab = "search" | "playlists" | "favorites" | "queue";

interface MobileNavProps {
  activeTab: MobileTab;
  onTabChange: (tab: MobileTab) => void;
}

const tabs: { id: MobileTab; labelKey: TranslationKey; icon: typeof Search }[] = [
  { id: "search", labelKey: "nav.search", icon: Search },
  { id: "playlists", labelKey: "nav.playlists", icon: ListMusic },
  { id: "favorites", labelKey: "nav.favorites", icon: Heart },
  { id: "queue", labelKey: "nav.queue", icon: ListOrdered },
];

export function MobileNav({ activeTab, onTabChange }: MobileNavProps) {
  const { t } = useTranslation();

  return (
    <nav className="md:hidden border-t bg-card flex">
      {tabs.map(({ id, labelKey, icon: Icon }) => (
        <button
          key={id}
          className={`flex-1 flex flex-col items-center gap-0.5 py-2 text-xs transition-colors ${
            activeTab === id
              ? "text-green-500"
              : "text-muted-foreground"
          }`}
          onClick={() => onTabChange(id)}
        >
          <Icon className="h-5 w-5" />
          {t(labelKey)}
        </button>
      ))}
    </nav>
  );
}
