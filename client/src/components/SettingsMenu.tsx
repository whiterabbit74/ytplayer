import { Settings as SettingsIcon, LogOut, User as UserIcon } from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
  PopoverHeader,
  PopoverTitle,
} from "@/components/ui/popover";
import { LanguageSwitcher } from "./LanguageSwitcher";
import { useAuth } from "@/contexts/AuthContext";
import { useTranslation } from "@/i18n";

export function SettingsMenu() {
  const { user, logout } = useAuth();
  const { t } = useTranslation();

  return (
    <Popover>
      <PopoverTrigger asChild>
        <Button variant="ghost" size="icon" className="text-muted-foreground hover:text-foreground">
          <SettingsIcon className="h-5 w-5" />
        </Button>
      </PopoverTrigger>
      <PopoverContent align="end" className="w-72 p-0 overflow-hidden border-border bg-popover/95 backdrop-blur-md">
        <PopoverHeader className="px-4 py-3 border-b bg-muted/20">
          <PopoverTitle className="text-sm font-bold tracking-tight">{t("settings.title")}</PopoverTitle>
        </PopoverHeader>
        
        <div className="flex flex-col">
          {/* Account Section */}
          <div className="px-4 py-4 border-b">
            <h3 className="text-[10px] font-bold uppercase tracking-wider text-muted-foreground/70 mb-2.5 flex items-center gap-1.5">
              <UserIcon className="h-3 w-3" />
              {t("settings.account")}
            </h3>
            <div className="flex flex-col gap-1">
              <p className="text-[10px] text-muted-foreground leading-none">{t("settings.loggedInAs")}</p>
              <p className="text-sm font-semibold truncate leading-tight">{user?.email}</p>
            </div>
          </div>

          <div className="p-1 space-y-0.5">
            {/* Language Selection */}
            <div className="flex items-center justify-between px-3 py-2 text-sm rounded-md transition-colors">
              <span className="text-muted-foreground font-medium">Язык / Language</span>
              <LanguageSwitcher />
            </div>

            <div className="h-px bg-border/50 mx-2 my-1" />

            {/* Logout Button */}
            <Button 
              variant="ghost" 
              onClick={logout} 
              className="w-full justify-start gap-2.5 text-red-500 hover:text-red-600 hover:bg-red-500/10 h-10 px-3 rounded-md mx-0"
            >
              <LogOut className="h-4 w-4" />
              <span className="font-medium text-sm">{t("auth.logout")}</span>
            </Button>
          </div>
        </div>
      </PopoverContent>
    </Popover>
  );
}
