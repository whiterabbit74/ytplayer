import type { ReactNode } from "react";
import { Queue } from "./Queue";
import { SettingsMenu } from "./SettingsMenu";

interface LayoutProps {
  children: ReactNode;
  desktopPlayer?: ReactNode;
  mobileBottom?: ReactNode;
}

export function Layout({ children, desktopPlayer, mobileBottom }: LayoutProps) {
  return (
    <div className="h-screen bg-background text-foreground flex flex-col">
      <header className="border-b px-4 py-3 shrink-0 flex items-center justify-between">
        <div className="flex items-baseline gap-2">
          <h1 className="text-xl font-bold">MusicPlay</h1>
          <span className="text-[10px] text-muted-foreground">{__APP_VERSION__}</span>
        </div>
        <div className="flex items-center gap-1">
          <SettingsMenu />
        </div>
      </header>
      <div className="flex flex-1 min-h-0 overflow-hidden">
        <main className="flex-1 min-h-0 flex flex-col overflow-hidden">{children}</main>
        <div className="hidden md:flex h-full">
          <Queue />
        </div>
      </div>
      {/* Desktop player */}
      <div className="hidden md:block shrink-0">
        {desktopPlayer}
      </div>
      {/* Mobile: MiniPlayer + MobileNav */}
      {mobileBottom}
    </div>
  );
}
